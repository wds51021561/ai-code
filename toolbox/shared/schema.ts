import { z } from 'zod'
import { PLUGIN_DEFINITIONS } from './plugins'
import type { Workspace } from './types'

const keyValueSchema = z.object({
  id: z.string(),
  enabled: z.boolean(),
  key: z.string(),
  value: z.string(),
  description: z.string().optional()
})

const variableSchema = z.object({
  id: z.string(),
  enabled: z.boolean(),
  key: z.string(),
  value: z.string(),
  secret: z.boolean()
})

const pluginSchema = z.object({
  id: z.string(),
  enabled: z.boolean(),
  config: z.record(z.string(), z.unknown())
})

const requestSchema = z.object({
  method: z.enum(['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD', 'OPTIONS']),
  url: z.string(),
  params: z.array(keyValueSchema),
  headers: z.array(keyValueSchema),
  body: z.object({
    mode: z.enum(['none', 'json', 'text', 'form-urlencoded', 'form-data']),
    raw: z.string(),
    form: z.array(keyValueSchema)
  }),
  auth: z.object({
    type: z.enum(['none', 'bearer', 'basic', 'api-key']),
    token: z.string(),
    username: z.string(),
    password: z.string(),
    key: z.string(),
    value: z.string(),
    addTo: z.enum(['header', 'query'])
  }),
  plugins: z.array(pluginSchema),
  settings: z.object({
    timeoutMs: z.number(),
    rejectUnauthorized: z.boolean(),
    proxyUrl: z.string()
  })
})

const environmentSchema = z.object({
  id: z.string(),
  name: z.string(),
  variables: z.array(variableSchema)
})

const historySchema = z.object({
  id: z.string(),
  at: z.number(),
  request: requestSchema,
  status: z.number().optional(),
  duration: z.number().optional(),
  error: z.string().optional()
})

const savedSchema = z.object({
  id: z.string(),
  name: z.string(),
  request: requestSchema,
  updatedAt: z.number()
})

export const workspaceSchema = z.object({
  version: z.literal(1),
  draft: requestSchema,
  environments: z.array(environmentSchema),
  activeEnvId: z.string().nullable(),
  globalVariables: z.array(variableSchema),
  history: z.array(historySchema),
  saved: z.array(savedSchema),
  theme: z.enum(['dark', 'light'])
})

function mergePlugins(workspace: Workspace): Workspace {
  const existing = workspace.draft.plugins
  const seen = new Set<string>()
  const ordered: Workspace['draft']['plugins'] = []

  for (const plugin of existing) {
    if (seen.has(plugin.id)) continue
    if (!PLUGIN_DEFINITIONS.some((definition) => definition.id === plugin.id)) continue
    seen.add(plugin.id)
    ordered.push(plugin)
  }

  for (const definition of PLUGIN_DEFINITIONS) {
    if (seen.has(definition.id)) continue
    ordered.push({
      id: definition.id,
      enabled: false,
      config: JSON.parse(JSON.stringify(definition.configTemplate)) as Record<string, unknown>
    })
  }

  return {
    ...workspace,
    draft: {
      ...workspace.draft,
      plugins: ordered
    },
    activeEnvId:
      workspace.activeEnvId === null ||
      workspace.environments.some((env) => env.id === workspace.activeEnvId)
        ? workspace.activeEnvId
        : (workspace.environments[0]?.id ?? null),
    history: workspace.history.slice(0, 100)
  }
}

export function normalizeWorkspace(value: unknown): Workspace | null {
  const parsed = workspaceSchema.safeParse(value)
  if (!parsed.success) {
    return null
  }
  return mergePlugins(parsed.data as Workspace)
}
