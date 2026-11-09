import 'types.dart';

const List<PluginDefinition> pluginDefinitions = [
  PluginDefinition(
    id: 'hmac-sha256',
    name: 'HMAC-SHA256 签名',
    description: '发送前对请求生成 HMAC-SHA256 签名，并写入时间戳、随机数与签名请求头。',
    configHint:
        'secret 为必填，支持 {{变量}}。可选：header / timestampHeader / nonceHeader / includeQuery / includeBody / encoding(hex|base64) / prefix。',
    configTemplate: {
      'secret': '{{signSecret}}',
      'header': 'X-Signature',
      'timestampHeader': 'X-Timestamp',
      'nonceHeader': 'X-Nonce',
      'includeQuery': true,
      'includeBody': true,
      'encoding': 'hex',
      'prefix': '',
    },
  ),
  PluginDefinition(
    id: 'aes-256-gcm',
    name: 'AES-256-GCM 加解密',
    description: '使用 AES-256-GCM 加密请求体，并可自动解密采用了相同信封格式的响应。',
    configHint:
        'secret 为必填。encryptRequest=true 时请求体必须是文本。解密响应需要响应体为 { iv, tag, data } 信封。',
    configTemplate: {
      'secret': '{{cryptoKey}}',
      'encryptRequest': true,
      'decryptResponse': false,
      'headerName': 'X-Payload-Encrypted',
    },
  ),
];

PluginDefinition? getPluginDefinition(String id) {
  for (final definition in pluginDefinitions) {
    if (definition.id == id) return definition;
  }
  return null;
}
