import 'plugins.dart';
import 'types.dart';

KeyValueItem createEmptyKeyValue() => KeyValueItem();

Variable createEmptyVariable() => Variable();

AuthConfig createDefaultAuth() => AuthConfig();

BodyConfig createDefaultBody() => BodyConfig(
      mode: BodyMode.none,
      raw: '{\n  \n}',
      form: [createEmptyKeyValue()],
    );

RequestSettings createDefaultSettings() => RequestSettings();

List<RequestPluginConfig> createDefaultPlugins() {
  return pluginDefinitions
      .map(
        (definition) => RequestPluginConfig(
          id: definition.id,
          enabled: false,
          config:
              deepCloneJson(definition.configTemplate) as Map<String, dynamic>,
        ),
      )
      .toList();
}

RequestConfig createEmptyRequest({
  HttpMethod method = HttpMethod.get,
  String url = '',
}) {
  return RequestConfig(
    method: method,
    url: url,
    params: [createEmptyKeyValue()],
    headers: [createEmptyKeyValue()],
    body: createDefaultBody(),
    auth: createDefaultAuth(),
    plugins: createDefaultPlugins(),
    settings: createDefaultSettings(),
  );
}

Workspace createDefaultWorkspace() {
  final environment = Environment(
    name: '开发环境',
    variables: [
      Variable(key: 'baseUrl', value: 'https://jsonplaceholder.typicode.com'),
      Variable(key: 'apiToken', value: 'demo-token', secret: true),
      Variable(key: 'signSecret', value: 'demo-sign-secret', secret: true),
      Variable(key: 'cryptoKey', value: 'demo-crypto-key', secret: true),
    ],
  );

  return Workspace(
    draft: createEmptyRequest(url: '{{baseUrl}}/todos/1'),
    environments: [environment],
    activeEnvId: environment.id,
    globalVariables: [],
    history: [],
    saved: [],
    theme: ThemeModeOption.dark,
  );
}

RequestConfig cloneRequest(RequestConfig request) {
  final clone = RequestConfig.fromJson(deepCloneJson(request.toJson()));
  normalizeRequest(clone);
  return clone;
}

void normalizeRequest(RequestConfig request) {
  if (request.params.isEmpty) request.params.add(createEmptyKeyValue());
  if (request.headers.isEmpty) request.headers.add(createEmptyKeyValue());
  if (request.body.form.isEmpty) request.body.form.add(createEmptyKeyValue());

  final seen = <String>{};
  final ordered = <RequestPluginConfig>[];
  for (final plugin in request.plugins) {
    if (seen.contains(plugin.id)) continue;
    if (!pluginDefinitions.any((definition) => definition.id == plugin.id)) {
      continue;
    }
    seen.add(plugin.id);
    ordered.add(plugin);
  }
  for (final definition in pluginDefinitions) {
    if (seen.contains(definition.id)) continue;
    ordered.add(
      RequestPluginConfig(
        id: definition.id,
        enabled: false,
        config:
            deepCloneJson(definition.configTemplate) as Map<String, dynamic>,
      ),
    );
  }
  request.plugins = ordered;
}
