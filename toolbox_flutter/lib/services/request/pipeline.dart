import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../../models/types.dart';
import 'headers.dart';
import 'interpolate.dart';
import 'plugins.dart';

const int maxResponseBytes = 15 * 1024 * 1024;
const int maxPreviewChars = 20000;

class PreparedRequest {
  PreparedRequest({
    required this.method,
    required this.url,
    required this.headers,
    required this.bodyText,
    required this.bodyKind,
    required this.bodyBytes,
    required this.boundary,
    required this.timeoutMs,
    required this.rejectUnauthorized,
    required this.proxyUrl,
    required this.pluginLog,
  });

  final HttpMethod method;
  final Uri url;
  final Map<String, String> headers;
  final String? bodyText;
  final BodyKind bodyKind;
  final Uint8List? bodyBytes;
  final String? boundary;
  final int timeoutMs;
  final bool rejectUnauthorized;
  final String proxyUrl;
  final List<String> pluginLog;

  SentRequestSnapshot toSnapshot() {
    final body = switch (bodyKind) {
      BodyKind.none => null,
      BodyKind.formData => '[multipart/form-data]',
      BodyKind.text => _truncate(bodyText ?? ''),
    };
    return SentRequestSnapshot(
      method: method.value,
      url: url.toString(),
      headers:
          headers.entries.map((entry) => [entry.key, entry.value]).toList(),
      body: body,
    );
  }
}

class _ActiveRequest {
  HttpClient? client;
  HttpClientRequest? request;
  bool cancelled = false;
  bool timedOut = false;

  void abort() {
    try {
      request?.abort();
    } catch (_) {
      // Ignore abort failures.
    }
    try {
      client?.close(force: true);
    } catch (_) {
      // Ignore close failures.
    }
  }
}

String _truncate(String value, [int max = maxPreviewChars]) {
  if (value.length <= max) return value;
  return '${value.substring(0, max)}\n\n…（已截断，共 ${value.length} 字符）';
}

String describeError(Object error) {
  if (error is HttpException) {
    return error.message.isEmpty ? error.toString() : error.message;
  }
  if (error is SocketException) {
    return error.message.isEmpty ? error.toString() : error.message;
  }
  if (error is HandshakeException) {
    return error.message;
  }
  if (error is FormatException) {
    return error.message;
  }
  return error.toString().replaceFirst(RegExp(r'^Exception: '), '');
}

int _positiveNumber(dynamic value, int fallback) {
  if (value is num && value.isFinite && value > 0) return value.toInt();
  final parsed = int.tryParse('$value');
  if (parsed != null && parsed > 0) return parsed;
  return fallback;
}

List<KeyValueItem> _enabledRows(List<KeyValueItem> rows) {
  return rows.where((row) => row.enabled && row.key.trim().isNotEmpty).toList();
}

Uri _addQueryParameter(Uri uri, String key, String value) {
  final merged = <String, List<String>>{};
  uri.queryParametersAll.forEach((name, values) {
    merged[name] = [...values];
  });
  merged.putIfAbsent(key, () => <String>[]).add(value);
  return uri.replace(queryParameters: merged);
}

Uri _applyAuth(
  RequestConfig request,
  Map<String, String> variables,
  Uri url,
  Map<String, String> headers,
  List<String> log,
) {
  final auth = request.auth;
  if (auth.type == AuthType.none) return url;

  if (auth.type == AuthType.bearer) {
    final token = interpolateString(auth.token, variables).trim();
    if (token.isEmpty) throw Exception('Bearer Token 为空');
    setHeader(headers, 'Authorization', 'Bearer $token');
    log.add('认证：Bearer Token 已应用');
    return url;
  }

  if (auth.type == AuthType.basic) {
    final username = interpolateString(auth.username, variables);
    final password = interpolateString(auth.password, variables);
    final encoded = base64Encode(utf8.encode('$username:$password'));
    setHeader(headers, 'Authorization', 'Basic $encoded');
    log.add('认证：Basic Auth 已应用');
    return url;
  }

  final key = interpolateString(auth.key, variables).trim();
  final value = interpolateString(auth.value, variables);
  if (key.isEmpty) throw Exception('API Key 的 key 不能为空');
  if (auth.addTo == ApiKeyLocation.query) {
    log.add('认证：API Key 已写入查询参数');
    return _addQueryParameter(url, key, value);
  }
  setHeader(headers, key, value);
  log.add('认证：API Key 已写入请求头 $key');
  return url;
}

String _multipartBoundary() {
  final random = Random.secure();
  final buffer = StringBuffer('----ToolboxBoundary');
  for (var index = 0; index < 24; index++) {
    buffer.write(random.nextInt(16).toRadixString(16));
  }
  return buffer.toString();
}

String _escapeMultipartName(String value) {
  return value.replaceAll('"', '%22').replaceAll('\r', '').replaceAll('\n', '');
}

Uint8List _buildMultipart(
  List<KeyValueItem> rows,
  Map<String, String> variables,
  String boundary,
) {
  final builder = BytesBuilder(copy: false);
  for (final row in _enabledRows(rows)) {
    final key = interpolateString(row.key, variables).trim();
    final value = interpolateString(row.value, variables);
    builder.add(
      utf8.encode(
        '--$boundary\r\n'
        'Content-Disposition: form-data; name="${_escapeMultipartName(key)}"\r\n\r\n'
        '$value\r\n',
      ),
    );
  }
  builder.add(utf8.encode('--$boundary--\r\n'));
  return builder.takeBytes();
}

PreparedRequest prepareRequest(
  RequestConfig request,
  Map<String, String> variables,
) {
  final rawUrl = interpolateString(request.url, variables).trim();
  if (rawUrl.isEmpty) throw Exception('请输入请求 URL');
  if (hasUnresolvedVariables(rawUrl)) {
    throw Exception('URL 中存在未解析变量，请检查当前环境配置');
  }

  Uri? parsed;
  try {
    parsed = Uri.parse(rawUrl);
  } catch (_) {
    throw Exception('URL 格式不正确，请包含 http:// 或 https://');
  }
  if (!parsed.hasScheme ||
      (parsed.scheme != 'http' && parsed.scheme != 'https')) {
    throw Exception('仅支持 http:// 和 https:// 协议');
  }
  if (parsed.host.isEmpty) {
    throw Exception('URL 格式不正确，请包含 http:// 或 https://');
  }

  var url = parsed;
  for (final param in _enabledRows(request.params)) {
    url = _addQueryParameter(
      url,
      interpolateString(param.key, variables).trim(),
      interpolateString(param.value, variables),
    );
  }

  final headers = <String, String>{};
  for (final header in _enabledRows(request.headers)) {
    setHeader(
      headers,
      interpolateString(header.key, variables).trim(),
      interpolateString(header.value, variables),
    );
  }

  final pluginLog = <String>[];
  String? bodyText;
  var bodyKind = BodyKind.none;
  Uint8List? bodyBytes;
  String? boundary;

  switch (request.body.mode) {
    case BodyMode.json:
      bodyText = interpolateString(request.body.raw, variables);
      bodyKind = BodyKind.text;
      if (getHeader(headers, 'Content-Type') == null) {
        setHeader(headers, 'Content-Type', 'application/json; charset=utf-8');
      }
      break;
    case BodyMode.text:
      bodyText = interpolateString(request.body.raw, variables);
      bodyKind = BodyKind.text;
      if (getHeader(headers, 'Content-Type') == null) {
        setHeader(headers, 'Content-Type', 'text/plain; charset=utf-8');
      }
      break;
    case BodyMode.formUrlencoded:
      final parts = <String>[];
      for (final row in _enabledRows(request.body.form)) {
        final key = interpolateString(row.key, variables).trim();
        final value = interpolateString(row.value, variables);
        parts.add(
            '${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent(value)}');
      }
      bodyText = parts.join('&');
      bodyKind = BodyKind.text;
      if (getHeader(headers, 'Content-Type') == null) {
        setHeader(
          headers,
          'Content-Type',
          'application/x-www-form-urlencoded; charset=utf-8',
        );
      }
      break;
    case BodyMode.formData:
      boundary = _multipartBoundary();
      bodyBytes = _buildMultipart(request.body.form, variables, boundary);
      bodyKind = BodyKind.formData;
      deleteHeader(headers, 'Content-Type');
      setHeader(
        headers,
        'Content-Type',
        'multipart/form-data; boundary=$boundary',
      );
      break;
    case BodyMode.none:
      break;
  }

  url = _applyAuth(request, variables, url, headers, pluginLog);

  final context = RequestPluginContext(
    method: request.method,
    url: url,
    headers: headers,
    bodyText: bodyText,
    bodyKind: bodyKind,
    pluginLog: pluginLog,
  );

  for (final pluginConfig in request.plugins) {
    if (!pluginConfig.enabled) continue;
    final implementation = pluginImplementations[pluginConfig.id];
    if (implementation == null) {
      throw Exception('未知的请求插件：${pluginConfig.id}');
    }
    final interpolated = interpolateUnknown(pluginConfig.config, variables);
    final config = interpolated is Map
        ? Map<String, dynamic>.from(interpolated)
        : <String, dynamic>{};
    implementation.beforeSend(context, config);
  }

  if ((context.method == HttpMethod.get || context.method == HttpMethod.head) &&
      context.bodyKind != BodyKind.none) {
    throw Exception(
      'GET/HEAD 请求不支持请求体，请将 Body 设为 none 或移除请求体加密插件',
    );
  }

  final timeoutMs =
      _positiveNumber(request.settings.timeoutMs, 30000).clamp(1000, 300000);

  return PreparedRequest(
    method: context.method,
    url: context.url,
    headers: context.headers,
    bodyText: context.bodyText,
    bodyKind: context.bodyKind,
    bodyBytes: bodyBytes,
    boundary: boundary,
    timeoutMs: timeoutMs,
    rejectUnauthorized: request.settings.rejectUnauthorized,
    proxyUrl: interpolateString(request.settings.proxyUrl, variables).trim(),
    pluginLog: context.pluginLog,
  );
}

HttpClient _createClient(PreparedRequest prepared) {
  final client = HttpClient()
    ..connectionTimeout = Duration(milliseconds: prepared.timeoutMs);
  if (!prepared.rejectUnauthorized) {
    client.badCertificateCallback = (cert, host, port) => true;
  }

  if (prepared.proxyUrl.isNotEmpty) {
    final proxy = Uri.tryParse(prepared.proxyUrl);
    if (proxy == null ||
        (proxy.scheme != 'http' && proxy.scheme != 'https') ||
        proxy.host.isEmpty) {
      throw Exception('代理地址仅支持 http:// 或 https://');
    }
    final port =
        proxy.hasPort ? proxy.port : (proxy.scheme == 'https' ? 443 : 80);
    client.findProxy = (uri) => 'PROXY ${proxy.host}:$port';
  }
  return client;
}

bool _isTextualContentType(String contentType) {
  if (contentType.isEmpty) return true;
  final normalized = contentType.toLowerCase();
  return normalized.startsWith('text/') ||
      normalized.contains('json') ||
      normalized.contains('xml') ||
      normalized.contains('javascript') ||
      normalized.contains('x-www-form-urlencoded') ||
      normalized.contains('graphql') ||
      normalized.contains('yaml') ||
      normalized.contains('csv') ||
      normalized.contains('svg');
}

Uri _finalRedirectUri(Uri original, HttpClientResponse response) {
  var current = original;
  for (final redirect in response.redirects) {
    final location = redirect.location;
    current = location.isAbsolute ? location : current.resolveUri(location);
  }
  return current;
}

class _ReadBodyResult {
  _ReadBodyResult(this.bytes, this.size, this.truncated);
  final Uint8List bytes;
  final int size;
  final bool truncated;
}

Future<_ReadBodyResult> _readBody(HttpClientResponse response) async {
  final builder = BytesBuilder(copy: false);
  var size = 0;
  var truncated = false;
  await for (final chunk in response) {
    final remaining = maxResponseBytes - size;
    if (chunk.length > remaining) {
      if (remaining > 0) {
        builder.add(chunk.sublist(0, remaining));
      }
      size = maxResponseBytes;
      truncated = true;
      break;
    }
    builder.add(chunk);
    size += chunk.length;
  }
  return _ReadBodyResult(builder.takeBytes(), size, truncated);
}

class RequestEngine {
  final Map<String, _ActiveRequest> _inFlight = {};

  Future<SendResult> send({
    required String requestId,
    required RequestConfig request,
    required Map<String, String> variables,
  }) async {
    final active = _ActiveRequest();
    _inFlight[requestId] = active;
    final stopwatch = Stopwatch()..start();
    PreparedRequest? prepared;

    try {
      prepared = prepareRequest(request, variables);
      return await _sendPrepared(
        request: request,
        variables: variables,
        prepared: prepared,
        active: active,
        stopwatch: stopwatch,
      );
    } catch (error) {
      final message = active.cancelled
          ? '请求已取消'
          : active.timedOut
              ? '请求超时（${(prepared?.timeoutMs ?? 30000) ~/ 1000} 秒），可在“设置”中调整超时时间'
              : describeError(error);
      return _errorResult(
        request: request,
        prepared: prepared,
        message: message,
        duration: stopwatch.elapsedMilliseconds.toDouble(),
      );
    } finally {
      _inFlight.remove(requestId);
      active.abort();
    }
  }

  Future<bool> cancel(String requestId) async {
    final active = _inFlight[requestId];
    if (active == null) return false;
    active.cancelled = true;
    active.abort();
    return true;
  }

  void abortAll() {
    for (final active in _inFlight.values) {
      active.cancelled = true;
      active.abort();
    }
    _inFlight.clear();
  }

  Future<SendResult> _sendPrepared({
    required RequestConfig request,
    required Map<String, String> variables,
    required PreparedRequest prepared,
    required _ActiveRequest active,
    required Stopwatch stopwatch,
  }) async {
    final client = _createClient(prepared);
    active.client = client;
    final timer = Timer(Duration(milliseconds: prepared.timeoutMs), () {
      active.timedOut = true;
      active.abort();
    });

    try {
      final httpRequest =
          await client.openUrl(prepared.method.value, prepared.url);
      active.request = httpRequest;
      httpRequest.followRedirects = true;
      httpRequest.maxRedirects = 10;

      for (final entry in prepared.headers.entries) {
        if (entry.key.toLowerCase() == 'content-length') continue;
        httpRequest.headers.set(entry.key, entry.value);
      }

      final Uint8List? bodyBytes = switch (prepared.bodyKind) {
        BodyKind.formData => prepared.bodyBytes,
        BodyKind.text =>
          Uint8List.fromList(utf8.encode(prepared.bodyText ?? '')),
        BodyKind.none => null,
      };
      if (bodyBytes != null) {
        httpRequest.contentLength = bodyBytes.length;
        httpRequest.add(bodyBytes);
      }

      final response = await httpRequest.close();
      final headerEntries = <List<String>>[];
      response.headers.forEach((name, values) {
        headerEntries.add([name, values.join(', ')]);
      });
      final contentType =
          response.headers.value(HttpHeaders.contentTypeHeader) ?? '';
      final declaredLength = int.tryParse(
              response.headers.value(HttpHeaders.contentLengthHeader) ?? '') ??
          0;

      final bodyResult = await _readBody(response);
      final size = bodyResult.size;
      String responseBody;
      if (_isTextualContentType(contentType) || size == 0) {
        responseBody = utf8.decode(bodyResult.bytes, allowMalformed: true);
      } else {
        responseBody = '[二进制响应，$size 字节，当前版本暂不支持预览]';
      }

      String? pluginError;
      final responseContext = ResponsePluginContext(
        request: RequestPluginContext(
          method: prepared.method,
          url: prepared.url,
          headers: prepared.headers,
          bodyText: prepared.bodyText,
          bodyKind: prepared.bodyKind,
          pluginLog: prepared.pluginLog,
        ),
        responseBody: responseBody,
        status: response.statusCode,
      );

      for (final pluginConfig in request.plugins.reversed) {
        if (!pluginConfig.enabled) continue;
        final implementation = pluginImplementations[pluginConfig.id];
        if (implementation == null) continue;
        try {
          final interpolated =
              interpolateUnknown(pluginConfig.config, variables);
          final config = interpolated is Map
              ? Map<String, dynamic>.from(interpolated)
              : <String, dynamic>{};
          responseContext.responseBody =
              implementation.afterResponse(responseContext, config);
        } catch (error) {
          pluginError = describeError(error);
          prepared.pluginLog.add('响应插件失败：${pluginConfig.id}');
          break;
        }
      }

      if (active.cancelled || active.timedOut) {
        final message = active.cancelled
            ? '请求已取消'
            : '请求超时（${prepared.timeoutMs ~/ 1000} 秒），可在“设置”中调整超时时间';
        return _errorResult(
          request: request,
          prepared: prepared,
          message: message,
          duration: stopwatch.elapsedMilliseconds.toDouble(),
        );
      }

      final redirectedTo = _finalRedirectUri(prepared.url, response);
      final truncated = bodyResult.truncated ||
          (declaredLength > maxResponseBytes && size >= maxResponseBytes);
      final ok = response.statusCode >= 200 &&
          response.statusCode < 300 &&
          pluginError == null;

      return SendResult(
        ok: ok,
        status: response.statusCode,
        statusText: response.reasonPhrase,
        headers: headerEntries,
        body: responseContext.responseBody,
        contentType: contentType,
        size: size,
        duration: stopwatch.elapsedMilliseconds.toDouble(),
        truncated: truncated,
        error: pluginError,
        finalUrl: redirectedTo.toString(),
        request: prepared.toSnapshot(),
        pluginLog: prepared.pluginLog,
      );
    } catch (error) {
      final message = active.cancelled
          ? '请求已取消'
          : active.timedOut
              ? '请求超时（${prepared.timeoutMs ~/ 1000} 秒），可在“设置”中调整超时时间'
              : describeError(error);
      return _errorResult(
        request: request,
        prepared: prepared,
        message: message,
        duration: stopwatch.elapsedMilliseconds.toDouble(),
      );
    } finally {
      timer.cancel();
      active.abort();
    }
  }

  SendResult _errorResult({
    required RequestConfig request,
    required PreparedRequest? prepared,
    required String message,
    required double duration,
  }) {
    final snapshot = prepared?.toSnapshot() ??
        SentRequestSnapshot(
          method: request.method.value,
          url: request.url,
          headers: const [],
          body: null,
        );
    return SendResult(
      ok: false,
      status: 0,
      statusText: '',
      headers: const [],
      body: '',
      contentType: '',
      size: 0,
      duration: duration,
      truncated: false,
      error: message,
      finalUrl: prepared?.url.toString() ?? request.url,
      request: snapshot,
      pluginLog: prepared?.pluginLog ?? const [],
    );
  }
}
