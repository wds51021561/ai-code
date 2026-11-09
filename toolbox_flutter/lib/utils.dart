import 'dart:convert';

import '../models/types.dart';

String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB'];
  var index = 0;
  var value = bytes.toDouble();
  while (value >= 1024 && index < units.length - 1) {
    value /= 1024;
    index++;
  }
  final text = value >= 100 || index == 0
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$text ${units[index]}';
}

String formatDuration(double milliseconds) {
  if (!milliseconds.isFinite) return '-';
  if (milliseconds < 1000) return '${milliseconds.round()} ms';
  return '${(milliseconds / 1000).toStringAsFixed(2)} s';
}

String _two(int value) => value.toString().padLeft(2, '0');

String formatRelativeTime(int timestamp) {
  final delta = DateTime.now().millisecondsSinceEpoch - timestamp;
  if (delta < 60000) return '刚刚';
  if (delta < 3600000) return '${delta ~/ 60000} 分钟前';
  if (delta < 86400000) return '${delta ~/ 3600000} 小时前';
  if (delta < 172800000) return '昨天';
  final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
  return '${_two(date.month)}/${_two(date.day)} ${_two(date.hour)}:${_two(date.minute)}';
}

class PrettyJsonResult {
  const PrettyJsonResult(this.text, this.isJson);
  final String text;
  final bool isJson;
}

PrettyJsonResult prettyJson(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return const PrettyJsonResult('', false);
  try {
    final decoded = jsonDecode(value);
    return PrettyJsonResult(
      const JsonEncoder.withIndent('  ').convert(decoded),
      true,
    );
  } catch (_) {
    return PrettyJsonResult(raw, false);
  }
}

String requestDisplayUrl(RequestConfig request) {
  return request.url.isEmpty ? '未填写 URL' : request.url;
}

String suggestedRequestName(RequestConfig request) {
  try {
    var safeUrl = request.url.replaceAll(RegExp(r'\{\{[^{}]+\}\}'), 'variable');
    if (!RegExp(r'^[a-z][a-z\d+.-]*://', caseSensitive: false)
        .hasMatch(safeUrl)) {
      safeUrl = 'https://${safeUrl.replaceFirst(RegExp(r'^/+'), '')}';
    }
    final uri = Uri.parse(safeUrl);
    final segments = uri.pathSegments.where((item) => item.isNotEmpty).toList();
    if (segments.isNotEmpty) {
      final last = segments.last;
      if (RegExp(r'^\d+$').hasMatch(last) && segments.length > 1) {
        return '${segments[segments.length - 2]}/$last';
      }
      return Uri.decodeComponent(last);
    }
    return uri.host;
  } catch (_) {
    final fallback = request.url.trim();
    return fallback.isEmpty ? '${request.method.value} 请求' : fallback;
  }
}

class ExtractedQuery {
  const ExtractedQuery({required this.url, required this.params});
  final String url;
  final List<KeyValueItem> params;
}

ExtractedQuery? extractUrlQuery(String rawUrl) {
  final questionIndex = rawUrl.indexOf('?');
  if (questionIndex < 0) return null;

  final hashIndex = rawUrl.indexOf('#');
  final queryEnd = hashIndex > questionIndex ? hashIndex : rawUrl.length;
  final query = rawUrl.substring(questionIndex + 1, queryEnd);
  if (query.isEmpty) return null;

  final params = <KeyValueItem>[];
  for (final part in query.split('&')) {
    if (part.isEmpty) continue;
    final equals = part.indexOf('=');
    final rawKey = equals < 0 ? part : part.substring(0, equals);
    final rawValue = equals < 0 ? '' : part.substring(equals + 1);
    String key;
    String value;
    try {
      key = Uri.decodeQueryComponent(rawKey);
      value = Uri.decodeQueryComponent(rawValue);
    } catch (_) {
      key = rawKey;
      value = rawValue;
    }
    params.add(KeyValueItem(key: key, value: value));
  }
  if (params.isEmpty) return null;

  final suffix = hashIndex > questionIndex ? rawUrl.substring(hashIndex) : '';
  return ExtractedQuery(
    url: rawUrl.substring(0, questionIndex) + suffix,
    params: params,
  );
}

Map<String, String> resolveVariables(Workspace workspace) {
  final variables = <String, String>{};
  for (final variable in workspace.globalVariables) {
    if (variable.enabled && variable.key.trim().isNotEmpty) {
      variables[variable.key.trim()] = variable.value;
    }
  }
  for (final environment in workspace.environments) {
    if (environment.id != workspace.activeEnvId) continue;
    for (final variable in environment.variables) {
      if (variable.enabled && variable.key.trim().isNotEmpty) {
        variables[variable.key.trim()] = variable.value;
      }
    }
  }
  return variables;
}
