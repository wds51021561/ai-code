import 'dart:convert';

import 'package:uuid/uuid.dart';

const _uuid = Uuid();

String makeId(String prefix) => '${prefix}_${_uuid.v4()}';

Map<String, dynamic> asJsonMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<dynamic> asJsonList(dynamic value) => value is List ? value : const [];

String readString(dynamic value, [String fallback = '']) =>
    value is String ? value : fallback;

bool readBool(dynamic value, [bool fallback = false]) =>
    value is bool ? value : fallback;

int readInt(dynamic value, [int fallback = 0]) =>
    value is num ? value.toInt() : fallback;

double readDouble(dynamic value, [double fallback = 0]) =>
    value is num ? value.toDouble() : fallback;

enum HttpMethod {
  get('GET'),
  post('POST'),
  put('PUT'),
  patch('PATCH'),
  delete('DELETE'),
  head('HEAD'),
  options('OPTIONS');

  const HttpMethod(this.value);
  final String value;

  static HttpMethod parse(dynamic value) {
    return HttpMethod.values.firstWhere(
      (item) => item.value == value,
      orElse: () => HttpMethod.get,
    );
  }
}

enum ThemeModeOption {
  dark('dark'),
  light('light');

  const ThemeModeOption(this.value);
  final String value;

  static ThemeModeOption parse(dynamic value) {
    return ThemeModeOption.values.firstWhere(
      (item) => item.value == value,
      orElse: () => ThemeModeOption.dark,
    );
  }
}

enum BodyMode {
  none('none'),
  json('json'),
  text('text'),
  formUrlencoded('form-urlencoded'),
  formData('form-data');

  const BodyMode(this.value);
  final String value;

  static BodyMode parse(dynamic value) {
    return BodyMode.values.firstWhere(
      (item) => item.value == value,
      orElse: () => BodyMode.none,
    );
  }
}

enum AuthType {
  none('none'),
  bearer('bearer'),
  basic('basic'),
  apiKey('api-key');

  const AuthType(this.value);
  final String value;

  static AuthType parse(dynamic value) {
    return AuthType.values.firstWhere(
      (item) => item.value == value,
      orElse: () => AuthType.none,
    );
  }
}

enum ApiKeyLocation {
  header('header'),
  query('query');

  const ApiKeyLocation(this.value);
  final String value;

  static ApiKeyLocation parse(dynamic value) {
    return ApiKeyLocation.values.firstWhere(
      (item) => item.value == value,
      orElse: () => ApiKeyLocation.header,
    );
  }
}

class KeyValueItem {
  KeyValueItem({
    String? id,
    this.enabled = true,
    this.key = '',
    this.value = '',
    this.description,
  }) : id = id ?? makeId('kv');

  final String id;
  bool enabled;
  String key;
  String value;
  String? description;

  KeyValueItem copyWith({
    bool? enabled,
    String? key,
    String? value,
    String? description,
  }) {
    return KeyValueItem(
      id: id,
      enabled: enabled ?? this.enabled,
      key: key ?? this.key,
      value: value ?? this.value,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'enabled': enabled,
        'key': key,
        'value': value,
        if (description != null) 'description': description,
      };

  factory KeyValueItem.fromJson(dynamic raw) {
    final json = asJsonMap(raw);
    return KeyValueItem(
      id: readString(json['id']).isEmpty ? null : readString(json['id']),
      enabled: readBool(json['enabled'], true),
      key: readString(json['key']),
      value: readString(json['value']),
      description:
          json['description'] is String ? json['description'] as String : null,
    );
  }
}

class Variable {
  Variable({
    String? id,
    this.enabled = true,
    this.key = '',
    this.value = '',
    this.secret = false,
  }) : id = id ?? makeId('var');

  final String id;
  bool enabled;
  String key;
  String value;
  bool secret;

  Variable copyWith({
    bool? enabled,
    String? key,
    String? value,
    bool? secret,
  }) {
    return Variable(
      id: id,
      enabled: enabled ?? this.enabled,
      key: key ?? this.key,
      value: value ?? this.value,
      secret: secret ?? this.secret,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'enabled': enabled,
        'key': key,
        'value': value,
        'secret': secret,
      };

  factory Variable.fromJson(dynamic raw) {
    final json = asJsonMap(raw);
    return Variable(
      id: readString(json['id']).isEmpty ? null : readString(json['id']),
      enabled: readBool(json['enabled'], true),
      key: readString(json['key']),
      value: readString(json['value']),
      secret: readBool(json['secret']),
    );
  }
}

class BodyConfig {
  BodyConfig({
    this.mode = BodyMode.none,
    this.raw = '{\n  \n}',
    List<KeyValueItem>? form,
  }) : form = form ?? <KeyValueItem>[];

  BodyMode mode;
  String raw;
  List<KeyValueItem> form;

  BodyConfig copy() => BodyConfig(
        mode: mode,
        raw: raw,
        form: form.map((item) => item.copyWith()).toList(),
      );

  Map<String, dynamic> toJson() => {
        'mode': mode.value,
        'raw': raw,
        'form': form.map((item) => item.toJson()).toList(),
      };

  factory BodyConfig.fromJson(dynamic raw) {
    final json = asJsonMap(raw);
    return BodyConfig(
      mode: BodyMode.parse(json['mode']),
      raw: readString(json['raw'], '{\n  \n}'),
      form: asJsonList(json['form'])
          .map((item) => KeyValueItem.fromJson(item))
          .toList(),
    );
  }
}

class AuthConfig {
  AuthConfig({
    this.type = AuthType.none,
    this.token = '',
    this.username = '',
    this.password = '',
    this.key = '',
    this.value = '',
    this.addTo = ApiKeyLocation.header,
  });

  AuthType type;
  String token;
  String username;
  String password;
  String key;
  String value;
  ApiKeyLocation addTo;

  AuthConfig copy() => AuthConfig(
        type: type,
        token: token,
        username: username,
        password: password,
        key: key,
        value: value,
        addTo: addTo,
      );

  Map<String, dynamic> toJson() => {
        'type': type.value,
        'token': token,
        'username': username,
        'password': password,
        'key': key,
        'value': value,
        'addTo': addTo.value,
      };

  factory AuthConfig.fromJson(dynamic raw) {
    final json = asJsonMap(raw);
    return AuthConfig(
      type: AuthType.parse(json['type']),
      token: readString(json['token']),
      username: readString(json['username']),
      password: readString(json['password']),
      key: readString(json['key']),
      value: readString(json['value']),
      addTo: ApiKeyLocation.parse(json['addTo']),
    );
  }
}

class RequestSettings {
  RequestSettings({
    this.timeoutMs = 30000,
    this.rejectUnauthorized = true,
    this.proxyUrl = '',
  });

  int timeoutMs;
  bool rejectUnauthorized;
  String proxyUrl;

  RequestSettings copy() => RequestSettings(
        timeoutMs: timeoutMs,
        rejectUnauthorized: rejectUnauthorized,
        proxyUrl: proxyUrl,
      );

  Map<String, dynamic> toJson() => {
        'timeoutMs': timeoutMs,
        'rejectUnauthorized': rejectUnauthorized,
        'proxyUrl': proxyUrl,
      };

  factory RequestSettings.fromJson(dynamic raw) {
    final json = asJsonMap(raw);
    return RequestSettings(
      timeoutMs: readInt(json['timeoutMs'], 30000),
      rejectUnauthorized: readBool(json['rejectUnauthorized'], true),
      proxyUrl: readString(json['proxyUrl']),
    );
  }
}

class RequestPluginConfig {
  RequestPluginConfig({
    required this.id,
    this.enabled = false,
    Map<String, dynamic>? config,
  }) : config = config ?? <String, dynamic>{};

  final String id;
  bool enabled;
  Map<String, dynamic> config;

  RequestPluginConfig copy() => RequestPluginConfig(
        id: id,
        enabled: enabled,
        config: deepCloneJson(config) as Map<String, dynamic>,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'enabled': enabled,
        'config': config,
      };

  factory RequestPluginConfig.fromJson(dynamic raw) {
    final json = asJsonMap(raw);
    return RequestPluginConfig(
      id: readString(json['id']),
      enabled: readBool(json['enabled']),
      config: asJsonMap(json['config']),
    );
  }
}

class RequestConfig {
  RequestConfig({
    this.method = HttpMethod.get,
    this.url = '',
    List<KeyValueItem>? params,
    List<KeyValueItem>? headers,
    BodyConfig? body,
    AuthConfig? auth,
    List<RequestPluginConfig>? plugins,
    RequestSettings? settings,
  })  : params = params ?? <KeyValueItem>[],
        headers = headers ?? <KeyValueItem>[],
        body = body ?? BodyConfig(),
        auth = auth ?? AuthConfig(),
        plugins = plugins ?? <RequestPluginConfig>[],
        settings = settings ?? RequestSettings();

  HttpMethod method;
  String url;
  List<KeyValueItem> params;
  List<KeyValueItem> headers;
  BodyConfig body;
  AuthConfig auth;
  List<RequestPluginConfig> plugins;
  RequestSettings settings;

  Map<String, dynamic> toJson() => {
        'method': method.value,
        'url': url,
        'params': params.map((item) => item.toJson()).toList(),
        'headers': headers.map((item) => item.toJson()).toList(),
        'body': body.toJson(),
        'auth': auth.toJson(),
        'plugins': plugins.map((plugin) => plugin.toJson()).toList(),
        'settings': settings.toJson(),
      };

  factory RequestConfig.fromJson(dynamic raw) {
    final json = asJsonMap(raw);
    return RequestConfig(
      method: HttpMethod.parse(json['method']),
      url: readString(json['url']),
      params: asJsonList(json['params'])
          .map((item) => KeyValueItem.fromJson(item))
          .toList(),
      headers: asJsonList(json['headers'])
          .map((item) => KeyValueItem.fromJson(item))
          .toList(),
      body: BodyConfig.fromJson(json['body']),
      auth: AuthConfig.fromJson(json['auth']),
      plugins: asJsonList(json['plugins'])
          .map((item) => RequestPluginConfig.fromJson(item))
          .toList(),
      settings: RequestSettings.fromJson(json['settings']),
    );
  }
}

class Environment {
  Environment({
    String? id,
    this.name = '',
    List<Variable>? variables,
  })  : id = id ?? makeId('env'),
        variables = variables ?? <Variable>[];

  final String id;
  String name;
  List<Variable> variables;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'variables': variables.map((item) => item.toJson()).toList(),
      };

  factory Environment.fromJson(dynamic raw) {
    final json = asJsonMap(raw);
    return Environment(
      id: readString(json['id']).isEmpty ? null : readString(json['id']),
      name: readString(json['name']),
      variables: asJsonList(json['variables'])
          .map((item) => Variable.fromJson(item))
          .toList(),
    );
  }
}

class HistoryEntry {
  HistoryEntry({
    String? id,
    int? at,
    required this.request,
    this.status,
    this.duration,
    this.error,
  })  : id = id ?? makeId('history'),
        at = at ?? DateTime.now().millisecondsSinceEpoch;

  final String id;
  final int at;
  final RequestConfig request;
  final int? status;
  final double? duration;
  final String? error;

  Map<String, dynamic> toJson() => {
        'id': id,
        'at': at,
        'request': request.toJson(),
        if (status != null) 'status': status,
        if (duration != null) 'duration': duration,
        if (error != null) 'error': error,
      };

  factory HistoryEntry.fromJson(dynamic raw) {
    final json = asJsonMap(raw);
    return HistoryEntry(
      id: readString(json['id']).isEmpty ? null : readString(json['id']),
      at: readInt(json['at'], DateTime.now().millisecondsSinceEpoch),
      request: RequestConfig.fromJson(json['request']),
      status: json['status'] is num ? (json['status'] as num).toInt() : null,
      duration:
          json['duration'] is num ? (json['duration'] as num).toDouble() : null,
      error: json['error'] is String ? json['error'] as String : null,
    );
  }
}

class SavedRequest {
  SavedRequest({
    String? id,
    required this.name,
    required this.request,
    int? updatedAt,
  })  : id = id ?? makeId('saved'),
        updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  final String id;
  String name;
  final RequestConfig request;
  int updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'request': request.toJson(),
        'updatedAt': updatedAt,
      };

  factory SavedRequest.fromJson(dynamic raw) {
    final json = asJsonMap(raw);
    return SavedRequest(
      id: readString(json['id']).isEmpty ? null : readString(json['id']),
      name: readString(json['name'], '未命名请求'),
      request: RequestConfig.fromJson(json['request']),
      updatedAt:
          readInt(json['updatedAt'], DateTime.now().millisecondsSinceEpoch),
    );
  }
}

class Workspace {
  Workspace({
    this.version = 1,
    RequestConfig? draft,
    List<Environment>? environments,
    this.activeEnvId,
    List<Variable>? globalVariables,
    List<HistoryEntry>? history,
    List<SavedRequest>? saved,
    this.theme = ThemeModeOption.dark,
  })  : draft = draft ?? RequestConfig(),
        environments = environments ?? <Environment>[],
        globalVariables = globalVariables ?? <Variable>[],
        history = history ?? <HistoryEntry>[],
        saved = saved ?? <SavedRequest>[];

  final int version;
  RequestConfig draft;
  List<Environment> environments;
  String? activeEnvId;
  List<Variable> globalVariables;
  List<HistoryEntry> history;
  List<SavedRequest> saved;
  ThemeModeOption theme;

  Map<String, dynamic> toJson() => {
        'version': 1,
        'draft': draft.toJson(),
        'environments': environments.map((item) => item.toJson()).toList(),
        'activeEnvId': activeEnvId,
        'globalVariables':
            globalVariables.map((item) => item.toJson()).toList(),
        'history': history.map((item) => item.toJson()).toList(),
        'saved': saved.map((item) => item.toJson()).toList(),
        'theme': theme.value,
      };

  factory Workspace.fromJson(dynamic raw) {
    final json = asJsonMap(raw);
    return Workspace(
      version: readInt(json['version'], 1),
      draft: RequestConfig.fromJson(json['draft']),
      environments: asJsonList(json['environments'])
          .map((item) => Environment.fromJson(item))
          .toList(),
      activeEnvId:
          json['activeEnvId'] is String ? json['activeEnvId'] as String : null,
      globalVariables: asJsonList(json['globalVariables'])
          .map((item) => Variable.fromJson(item))
          .toList(),
      history: asJsonList(json['history'])
          .map((item) => HistoryEntry.fromJson(item))
          .toList(),
      saved: asJsonList(json['saved'])
          .map((item) => SavedRequest.fromJson(item))
          .toList(),
      theme: ThemeModeOption.parse(json['theme']),
    );
  }
}

class SentRequestSnapshot {
  SentRequestSnapshot({
    required this.method,
    required this.url,
    required this.headers,
    this.body,
  });

  final String method;
  final String url;
  final List<List<String>> headers;
  final String? body;

  Map<String, dynamic> toJson() => {
        'method': method,
        'url': url,
        'headers': headers,
        'body': body,
      };
}

class SendResult {
  SendResult({
    required this.ok,
    required this.status,
    required this.statusText,
    required this.headers,
    required this.body,
    required this.contentType,
    required this.size,
    required this.duration,
    required this.truncated,
    this.error,
    this.finalUrl,
    required this.request,
    required this.pluginLog,
  });

  final bool ok;
  final int status;
  final String statusText;
  final List<List<String>> headers;
  final String body;
  final String contentType;
  final int size;
  final double duration;
  final bool truncated;
  final String? error;
  final String? finalUrl;
  final SentRequestSnapshot request;
  final List<String> pluginLog;
}

class PluginDefinition {
  const PluginDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.configHint,
    required this.configTemplate,
  });

  final String id;
  final String name;
  final String description;
  final String configHint;
  final Map<String, dynamic> configTemplate;
}

dynamic deepCloneJson(dynamic value) {
  return jsonDecode(jsonEncode(value));
}
