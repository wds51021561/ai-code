import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';
import 'package:toolbox_flutter/models/types.dart';
import 'package:toolbox_flutter/services/request/plugins.dart';

String _hex(List<int> bytes) {
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

RequestPluginContext _createContext(String body) {
  return RequestPluginContext(
    method: HttpMethod.post,
    url: Uri.parse('https://api.example.com/v1/users?page=2'),
    headers: {},
    bodyText: body,
    bodyKind: BodyKind.text,
    pluginLog: [],
  );
}

void main() {
  group('hmac-sha256 plugin', () {
    test('writes matching timestamp, nonce and signature headers', () {
      final plugin = pluginImplementations['hmac-sha256']!;
      final context = _createContext('{"name":"demo"}');
      plugin.beforeSend(context, {
        'secret': 'top-secret',
        'header': 'X-Signature',
        'timestampHeader': 'X-Timestamp',
        'nonceHeader': 'X-Nonce',
        'includeQuery': true,
        'includeBody': true,
        'encoding': 'hex',
        'prefix': '',
      });

      final timestamp = context.headers['X-Timestamp']!;
      final nonce = context.headers['X-Nonce']!;
      final canonical = [
        'POST',
        '/v1/users?page=2',
        timestamp,
        nonce,
        '{"name":"demo"}',
      ].join('\n');
      final hmac = HMac(SHA256Digest(), 64)
        ..init(KeyParameter(Uint8List.fromList(utf8.encode('top-secret'))));
      final expected =
          _hex(hmac.process(Uint8List.fromList(utf8.encode(canonical))));

      expect(timestamp, isNotEmpty);
      expect(nonce, hasLength(32));
      expect(context.headers['X-Signature'], expected);
      expect(context.pluginLog, contains('HMAC-SHA256：签名头 X-Signature 已写入'));
    });

    test('rejects missing or unresolved secrets', () {
      final plugin = pluginImplementations['hmac-sha256']!;
      expect(
        () => plugin.beforeSend(_createContext(''), {}),
        throwsA(isA<Exception>()),
      );
      expect(
        () => plugin.beforeSend(_createContext(''), {'secret': '{{missing}}'}),
        throwsA(isA<Exception>()),
      );
    });

    test('uses / as canonical path when the URL has no path', () {
      final plugin = pluginImplementations['hmac-sha256']!;
      final context = RequestPluginContext(
        method: HttpMethod.post,
        url: Uri.parse('https://api.example.com?page=2'),
        headers: {},
        bodyText: '',
        bodyKind: BodyKind.text,
        pluginLog: [],
      );
      plugin.beforeSend(context, {
        'secret': 'top-secret',
        'includeQuery': true,
        'encoding': 'hex',
      });

      final canonical = [
        'POST',
        '/?page=2',
        context.headers['X-Timestamp'],
        context.headers['X-Nonce'],
        '',
      ].join('\n');
      final hmac = HMac(SHA256Digest(), 64)
        ..init(KeyParameter(Uint8List.fromList(utf8.encode('top-secret'))));
      expect(
        context.headers['X-Signature'],
        _hex(hmac.process(Uint8List.fromList(utf8.encode(canonical)))),
      );
    });
  });

  group('aes-256-gcm plugin', () {
    test('encrypts a request and decrypts the response envelope', () {
      final plugin = pluginImplementations['aes-256-gcm']!;
      final context = _createContext('{"hello":"world"}');
      final config = {
        'secret': 'aes-secret',
        'encryptRequest': true,
        'decryptResponse': true,
        'headerName': 'X-Payload-Encrypted',
      };

      plugin.beforeSend(context, config);

      expect(context.bodyKind, BodyKind.text);
      expect(
          context.headers['Content-Type'], 'application/json; charset=utf-8');
      expect(context.headers['X-Payload-Encrypted'], 'AES-256-GCM');
      final envelope = jsonDecode(context.bodyText!) as Map<String, dynamic>;
      expect(envelope['alg'], 'AES-256-GCM');
      expect(envelope['iv'], isA<String>());
      expect(envelope['tag'], isA<String>());
      expect(envelope['data'], isA<String>());

      final decrypted = plugin.afterResponse(
        ResponsePluginContext(
          request: context,
          responseBody: context.bodyText!,
          status: 200,
        ),
        config,
      );
      expect(decrypted, '{"hello":"world"}');
      expect(context.pluginLog, contains('AES-256-GCM：请求体已加密'));
      expect(context.pluginLog, contains('AES-256-GCM：响应体已解密'));
    });

    test('rejects multipart bodies and invalid response envelopes', () {
      final plugin = pluginImplementations['aes-256-gcm']!;
      final context = _createContext('')..bodyKind = BodyKind.formData;
      expect(
        () => plugin.beforeSend(
            context, {'secret': 'aes-secret', 'encryptRequest': true}),
        throwsA(isA<Exception>()),
      );

      expect(
        () => plugin.afterResponse(
          ResponsePluginContext(
            request: _createContext(''),
            responseBody: 'not-json',
            status: 200,
          ),
          {'secret': 'aes-secret', 'decryptResponse': true},
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
