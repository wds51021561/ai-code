export type HttpMethod = 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE' | 'HEAD' | 'OPTIONS'
export type ThemeMode = 'dark' | 'light'
export type BodyMode = 'none' | 'json' | 'text' | 'form-urlencoded' | 'form-data'
export type AuthType = 'none' | 'bearer' | 'basic' | 'api-key'
export type ApiKeyLocation = 'header' | 'query'

export interface KeyValueItem {
  id: string
  enabled: boolean
  key: string
  value: string
  description?: string
}

export interface BodyConfig {
  mode: BodyMode
  raw: string
  form: KeyValueItem[]
}

export interface AuthConfig {
  type: AuthType
  token: string
  username: string
  password: string
  key: string
  value: string
  addTo: ApiKeyLocation
}

export interface RequestSettings {
  timeoutMs: number
  rejectUnauthorized: boolean
  proxyUrl: string
}

export interface RequestPluginConfig {
  id: string
  enabled: boolean
  config: Record<string, unknown>
}

export interface RequestConfig {
  method: HttpMethod
  url: string
  params: KeyValueItem[]
  headers: KeyValueItem[]
  body: BodyConfig
  auth: AuthConfig
  plugins: RequestPluginConfig[]
  settings: RequestSettings
}

export interface Variable {
  id: string
  enabled: boolean
  key: string
  value: string
  secret: boolean
}

export interface Environment {
  id: string
  name: string
  variables: Variable[]
}

export interface HistoryEntry {
  id: string
  at: number
  request: RequestConfig
  status?: number
  duration?: number
  error?: string
}

export interface SavedRequest {
  id: string
  name: string
  request: RequestConfig
  updatedAt: number
}

export interface Workspace {
  version: 1
  draft: RequestConfig
  environments: Environment[]
  activeEnvId: string | null
  globalVariables: Variable[]
  history: HistoryEntry[]
  saved: SavedRequest[]
  theme: ThemeMode
}

export interface SendPayload {
  requestId: string
  request: RequestConfig
  variables: Record<string, string>
}

export interface SentRequestSnapshot {
  method: string
  url: string
  headers: Array<[string, string]>
  body: string | null
}

export interface SendResult {
  ok: boolean
  status: number
  statusText: string
  headers: Array<[string, string]>
  body: string
  contentType: string
  size: number
  duration: number
  truncated: boolean
  error?: string
  finalUrl?: string
  request: SentRequestSnapshot
  pluginLog: string[]
}

export interface PluginDefinition {
  id: string
  name: string
  description: string
  configHint: string
  configTemplate: Record<string, unknown>
}

export interface ExportResult {
  ok: boolean
  canceled?: boolean
  path?: string
  error?: string
}

export interface ImportResult {
  ok: boolean
  canceled?: boolean
  path?: string
  data?: unknown
  error?: string
}

export interface ToolboxApi {
  request: {
    send: (payload: SendPayload) => Promise<SendResult>
    cancel: (requestId: string) => Promise<boolean>
  }
  storage: {
    load: () => Promise<unknown>
    save: (workspace: Workspace) => Promise<boolean>
  }
  workspace: {
    export: (workspace: Workspace) => Promise<ExportResult>
    import: () => Promise<ImportResult>
  }
  app: {
    version: () => Promise<string>
  }
}
