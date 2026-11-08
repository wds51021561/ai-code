import { PLUGIN_DEFINITIONS } from './plugins'
import type {
  AuthConfig,
  BodyConfig,
  Environment,
  KeyValueItem,
  RequestConfig,
  RequestPluginConfig,
  RequestSettings,
  Variable,
  Workspace
} from './types'

export function makeId(prefix: string): string {
  return `${prefix}_${globalThis.crypto.randomUUID()}`
}

export function createEmptyKeyValue(): KeyValueItem {
  return {
    id: makeId('kv'),
    enabled: true,
    key: '',
    value: ''
  }
}

export function createEmptyVariable(): Variable {
  return {
    id: makeId('var'),
    enabled: true,
    key: '',
    value: '',
    secret: false
  }
}

export function createDefaultAuth(): AuthConfig {
  return {
    type: 'none',
    token: '',
    username: '',
    password: '',
    key: '',
    value: '',
    addTo: 'header'
  }
}

export function createDefaultBody(): BodyConfig {
  return {
    mode: 'none',
    raw: '{\n  \n}',
    form: [createEmptyKeyValue()]
  }
}

export function createDefaultSettings(): RequestSettings {
  return {
    timeoutMs: 30_000,
    rejectUnauthorized: true,
    proxyUrl: ''
  }
}

export function createDefaultPlugins(): RequestPluginConfig[] {
  return PLUGIN_DEFINITIONS.map((definition) => ({
    id: definition.id,
    enabled: false,
    config: JSON.parse(JSON.stringify(definition.configTemplate)) as Record<string, unknown>
  }))
}

export function createEmptyRequest(patch: Partial<RequestConfig> = {}): RequestConfig {
  return {
    method: 'GET',
    url: '',
    params: [createEmptyKeyValue()],
    headers: [createEmptyKeyValue()],
    body: createDefaultBody(),
    auth: createDefaultAuth(),
    plugins: createDefaultPlugins(),
    settings: createDefaultSettings(),
    ...patch
  }
}

export function createDefaultWorkspace(): Workspace {
  const environment: Environment = {
    id: makeId('env'),
    name: '开发环境',
    variables: [
      {
        id: makeId('var'),
        enabled: true,
        key: 'baseUrl',
        value: 'https://jsonplaceholder.typicode.com',
        secret: false
      },
      {
        id: makeId('var'),
        enabled: true,
        key: 'apiToken',
        value: 'demo-token',
        secret: true
      },
      {
        id: makeId('var'),
        enabled: true,
        key: 'signSecret',
        value: 'demo-sign-secret',
        secret: true
      },
      {
        id: makeId('var'),
        enabled: true,
        key: 'cryptoKey',
        value: 'demo-crypto-key',
        secret: true
      }
    ]
  }

  return {
    version: 1,
    draft: createEmptyRequest({
      url: '{{baseUrl}}/todos/1'
    }),
    environments: [environment],
    activeEnvId: environment.id,
    globalVariables: [],
    history: [],
    saved: [],
    theme: 'dark'
  }
}
