import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:toolbox_flutter/models/defaults.dart';
import 'package:toolbox_flutter/models/types.dart';
import 'package:toolbox_flutter/services/request/pipeline.dart';

class _CapturedRequest {
  _CapturedRequest({
    required this.method,
    required this.uri,
    required this.headers,
    required this.body,
  });

  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final String body;
}

void main() {
  late HttpServer server;
  late List<_CapturedRequest> captured;

  setUp(() async {
    captured = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      try {
        final bytes = await request.fold<List<int>>(
          <int>[],
          (previous, chunk) => previous..addAll(chunk),
        );
        final headerMap = <String, String>{};
        request.headers.forEach((name, values) {
          headerMap[name.toLowerCase()] = values.join(', ');
        });
        captured.add(
          _CapturedRequest(
            method: request.method,
            uri: request.uri,
            headers: headerMap,
            body: utf8.decode(bytes, allowMalformed: true),
          ),
        );

        if (request.uri.path == '/delay') {
          await Future<void>.delayed(const Duration(milliseconds: 1500));
        }
        request.response.statusCode =
            request.uri.path == '/created' ? 201 : 200;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'ok': true,
            'path': request.uri.path,
            'query': request.uri.query,
            'body': utf8.decode(bytes, allowMalformed: true),
          }),
        );
        await request.response.close();
      } catch (_) {
        // The client may abort while a delayed response is being written.
      }
    });
  });

  tearDown(() async {
    await server.close(force: true);
  });

  String baseUrl() => 'http://127.0.0.1:${server.port}';

  test('sends GET with interpolated URL, query params, headers and auth',
      () async {
    final request = createEmptyRequest(url: '{{baseUrl}}/hello');
    request.params = [
      KeyValueItem(key: 'a', value: '1 2'),
      createEmptyKeyValue(),
    ];
    request.headers = [
      KeyValueItem(key: 'X-Test', value: '42'),
      createEmptyKeyValue(),
    ];
    request.auth = AuthConfig(type: AuthType.bearer, token: '{{token}}');

    final result = await RequestEngine().send(
      requestId: 'get-test',
      request: request,
      variables: {'baseUrl': baseUrl(), 'token': 'abc'},
    );

    expect(result.error, isNull);
    expect(result.status, 200);
    expect(result.ok, isTrue);
    expect(result.body, contains('"path":"/hello"'));
    expect(result.finalUrl, contains('/hello?a=1+2'));

    final capturedRequest = captured.single;
    expect(capturedRequest.method, 'GET');
    expect(capturedRequest.uri.queryParameters['a'], '1 2');
    expect(capturedRequest.headers['x-test'], '42');
    expect(capturedRequest.headers['authorization'], 'Bearer abc');
    expect(
      result.request.headers.any(
        (header) => header.first.toLowerCase() == 'authorization',
      ),
      isTrue,
    );
  });

  test('sends JSON body with interpolated variables', () async {
    final request =
        createEmptyRequest(method: HttpMethod.post, url: '{{baseUrl}}/echo');
    request.body.mode = BodyMode.json;
    request.body.raw = '{"name":"{{name}}"}';

    final result = await RequestEngine().send(
      requestId: 'json-test',
      request: request,
      variables: {'baseUrl': baseUrl(), 'name': 'demo'},
    );

    expect(result.error, isNull);
    expect(result.status, 200);
    final capturedRequest = captured.single;
    expect(capturedRequest.method, 'POST');
    expect(capturedRequest.headers['content-type'],
        'application/json; charset=utf-8');
    expect(capturedRequest.body, '{"name":"demo"}');
    expect(result.request.body, '{"name":"demo"}');
  });

  test('sends multipart form data as text fields', () async {
    final request =
        createEmptyRequest(method: HttpMethod.post, url: '{{baseUrl}}/upload');
    request.body.mode = BodyMode.formData;
    request.body.form = [
      KeyValueItem(key: 'name', value: 'demo'),
      KeyValueItem(key: 'note', value: '{{note}}'),
      createEmptyKeyValue(),
    ];

    final result = await RequestEngine().send(
      requestId: 'form-test',
      request: request,
      variables: {'baseUrl': baseUrl(), 'note': 'hello'},
    );

    expect(result.error, isNull);
    final capturedRequest = captured.single;
    expect(
      capturedRequest.headers['content-type'],
      startsWith('multipart/form-data; boundary='),
    );
    expect(capturedRequest.body, contains('name="name"'));
    expect(capturedRequest.body, contains('demo'));
    expect(capturedRequest.body, contains('hello'));
    expect(result.request.body, '[multipart/form-data]');
  });

  test('returns a timeout error', () async {
    final request = createEmptyRequest(url: '{{baseUrl}}/delay');
    request.settings.timeoutMs = 1000;

    final result = await RequestEngine().send(
      requestId: 'timeout-test',
      request: request,
      variables: {'baseUrl': baseUrl()},
    );

    expect(result.status, 0);
    expect(result.error, contains('请求超时'));
    expect(result.duration, greaterThanOrEqualTo(900));
  });

  test('cancels an in-flight request', () async {
    final engine = RequestEngine();
    final request = createEmptyRequest(url: '{{baseUrl}}/delay');
    final future = engine.send(
      requestId: 'cancel-test',
      request: request,
      variables: {'baseUrl': baseUrl()},
    );

    await Future<void>.delayed(const Duration(milliseconds: 60));
    final canceled = await engine.cancel('cancel-test');
    expect(canceled, isTrue);

    final result = await future;
    expect(result.status, 0);
    expect(result.error, '请求已取消');
  });
}
