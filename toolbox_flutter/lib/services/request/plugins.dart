import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../../models/types.dart';
import 'headers.dart';
import 'interpolate.dart';

class RequestPluginContext {
  RequestPluginContext({
    required this.method,
    required this.url,
    required this.headers,
    this.bodyText,
    required this.bodyKind,
    required this.pluginLog,
  });

  HttpMethod method;
  Uri url;
  Map<String, String> headers;
  String? bodyText;
  BodyKind bodyKind;
  final List<String> pluginLog;
}

enum BodyKind { none, text, formData }

class ResponsePluginContext {
  ResponsePluginContext({
    required this.request,
    required this.responseBody,
    required this.status,
  });

  final RequestPluginContext request;
  String responseBody;
  final int status;
}

abstract class RequestPlugin {
  String get id;
  void beforeSend(RequestPluginContext context, Map<String, dynamic> config);
  String afterResponse(
      ResponsePluginContext context, Map<String, dynamic> config) {
    return context.responseBody;
  }
}

String _readString(Map<String, dynamic> config, String key,
    [String fallback = '']) {
  final value = config[key];
  return value is String ? value.trim() : fallback;
}

bool _readBoolean(Map<String, dynamic> config, String key, bool fallback) {
  final value = config[key];
  if (value is bool) return value;
  if (value == 'true') return true;
  if (value == 'false') return false;
  return fallback;
}

String _requireSecret(Map<String, dynamic> config, String pluginName) {
  final secret = _readString(config, 'secret');
  if (secret.isEmpty) {
    throw Exception('$pluginName：请填写 secret');
  }
  if (hasUnresolvedVariables(secret)) {
    throw Exception('$pluginName：secret 中存在未解析的环境变量');
  }
  return secret;
}

Uint8List _deriveKey(String secret) {
  return SHA256Digest().process(Uint8List.fromList(utf8.encode(secret)));
}

String _hex(List<int> bytes) {
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

String _randomHex(int byteCount) {
  final random = Random.secure();
  final bytes = Uint8List(byteCount);
  for (var index = 0; index < bytes.length; index++) {
    bytes[index] = random.nextInt(256);
  }
  return _hex(bytes);
}

String _pathAndQuery(Uri uri) {
  final withoutFragment = uri.removeFragment();
  final base = '${withoutFragment.scheme}://${withoutFragment.authority}';
  final full = withoutFragment.toString();
  final path = full.startsWith(base) ? full.substring(base.length) : full;
  if (path.isEmpty) return '/';
  if (path.startsWith('?')) return '/$path';
  return path;
}

class HmacSha256Plugin extends RequestPlugin {
  @override
  String get id => 'hmac-sha256';

  @override
  void beforeSend(RequestPluginContext context, Map<String, dynamic> config) {
    final secret = _requireSecret(config, 'HMAC-SHA256');
    final header = _readString(config, 'header', 'X-Signature').isEmpty
        ? 'X-Signature'
        : _readString(config, 'header', 'X-Signature');
    final timestampHeader =
        _readString(config, 'timestampHeader', 'X-Timestamp').isEmpty
            ? 'X-Timestamp'
            : _readString(config, 'timestampHeader', 'X-Timestamp');
    final nonceHeader = _readString(config, 'nonceHeader', 'X-Nonce').isEmpty
        ? 'X-Nonce'
        : _readString(config, 'nonceHeader', 'X-Nonce');
    final includeQuery = _readBoolean(config, 'includeQuery', true);
    final includeBody = _readBoolean(config, 'includeBody', true);
    final encoding =
        _readString(config, 'encoding') == 'base64' ? 'base64' : 'hex';
    final prefix = _readString(config, 'prefix');

    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final nonce = _randomHex(16);
    final fullPath = _pathAndQuery(context.url);
    final questionIndex = fullPath.indexOf('?');
    final path = includeQuery || questionIndex < 0
        ? fullPath
        : fullPath.substring(0, questionIndex);

    final canonical = [
      context.method.value.toUpperCase(),
      path,
      timestamp,
      nonce,
      includeBody ? (context.bodyText ?? '') : '',
    ].join('\n');

    final hmac = HMac(SHA256Digest(), 64)
      ..init(KeyParameter(Uint8List.fromList(utf8.encode(secret))));
    final digest = hmac.process(Uint8List.fromList(utf8.encode(canonical)));
    final signature =
        encoding == 'base64' ? base64Encode(digest) : _hex(digest);

    setHeader(context.headers, timestampHeader, timestamp);
    setHeader(context.headers, nonceHeader, nonce);
    setHeader(context.headers, header, '$prefix$signature');
    context.pluginLog.add('HMAC-SHA256：签名头 $header 已写入');
  }
}

class AesEnvelope {
  AesEnvelope({
    required this.iv,
    required this.tag,
    required this.data,
  });

  final String iv;
  final String tag;
  final String data;

  Map<String, dynamic> toJson() => {
        'alg': 'AES-256-GCM',
        'iv': iv,
        'tag': tag,
        'data': data,
      };
}

AesEnvelope _encryptAesGcm(String plaintext, String secret) {
  final key = _deriveKey(secret);
  final random = Random.secure();
  final iv = Uint8List(12);
  for (var index = 0; index < iv.length; index++) {
    iv[index] = random.nextInt(256);
  }

  final cipher = GCMBlockCipher(AESEngine())
    ..init(
      true,
      AEADParameters(
        KeyParameter(key),
        128,
        iv,
        Uint8List(0),
      ),
    );
  final encrypted = cipher.process(Uint8List.fromList(utf8.encode(plaintext)));
  final tagLength = 16;
  final cipherText = encrypted.sublist(0, encrypted.length - tagLength);
  final tag = encrypted.sublist(encrypted.length - tagLength);

  return AesEnvelope(
    iv: base64Encode(iv),
    tag: base64Encode(tag),
    data: base64Encode(cipherText),
  );
}

String _decryptAesGcm(AesEnvelope envelope, String secret) {
  final key = _deriveKey(secret);
  final iv = base64Decode(envelope.iv);
  final tag = base64Decode(envelope.tag);
  final data = base64Decode(envelope.data);
  final input = Uint8List.fromList([...data, ...tag]);

  final cipher = GCMBlockCipher(AESEngine())
    ..init(
      false,
      AEADParameters(
        KeyParameter(key),
        128,
        Uint8List.fromList(iv),
        Uint8List(0),
      ),
    );
  final plaintext = cipher.process(input);
  return utf8.decode(plaintext);
}

AesEnvelope? _parseEnvelope(dynamic value) {
  if (value is! Map) return null;
  final iv = value['iv'];
  final tag = value['tag'];
  final data = value['data'];
  if (iv is! String || tag is! String || data is! String) return null;
  return AesEnvelope(iv: iv, tag: tag, data: data);
}

class Aes256GcmPlugin extends RequestPlugin {
  @override
  String get id => 'aes-256-gcm';

  @override
  void beforeSend(RequestPluginContext context, Map<String, dynamic> config) {
    final secret = _requireSecret(config, 'AES-256-GCM');
    final shouldEncrypt = _readBoolean(config, 'encryptRequest', true);
    if (!shouldEncrypt) return;
    if (context.bodyKind == BodyKind.formData) {
      throw Exception('AES-256-GCM：暂不支持加密 multipart/form-data 请求体');
    }

    final headerName =
        _readString(config, 'headerName', 'X-Payload-Encrypted').isEmpty
            ? 'X-Payload-Encrypted'
            : _readString(config, 'headerName', 'X-Payload-Encrypted');
    final envelope = _encryptAesGcm(context.bodyText ?? '', secret);
    context.bodyKind = BodyKind.text;
    context.bodyText = jsonEncode(envelope.toJson());
    setHeader(
      context.headers,
      'Content-Type',
      'application/json; charset=utf-8',
    );
    setHeader(context.headers, headerName, 'AES-256-GCM');
    context.pluginLog.add('AES-256-GCM：请求体已加密');
  }

  @override
  String afterResponse(
      ResponsePluginContext context, Map<String, dynamic> config) {
    final secret = _requireSecret(config, 'AES-256-GCM');
    final shouldDecrypt = _readBoolean(config, 'decryptResponse', false);
    if (!shouldDecrypt) return context.responseBody;

    dynamic parsed;
    try {
      parsed = jsonDecode(context.responseBody);
    } catch (_) {
      throw Exception('AES-256-GCM：响应体不是 JSON，无法解密');
    }
    final envelope = _parseEnvelope(parsed);
    if (envelope == null) {
      throw Exception('AES-256-GCM：响应体不是受支持的加密信封');
    }
    final plaintext = _decryptAesGcm(envelope, secret);
    context.request.pluginLog.add('AES-256-GCM：响应体已解密');
    return plaintext;
  }
}

final Map<String, RequestPlugin> pluginImplementations = {
  'hmac-sha256': HmacSha256Plugin(),
  'aes-256-gcm': Aes256GcmPlugin(),
};
