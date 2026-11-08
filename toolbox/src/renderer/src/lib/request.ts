import { PLUGIN_DEFINITIONS } from '@shared/plugins'
import {
  createDefaultAuth,
  createDefaultBody,
  createDefaultSettings,
  createEmptyKeyValue
} from '@shared/defaults'
import type { RequestConfig } from '@shared/types'

export function cloneRequest(request: RequestConfig): RequestConfig {
  const clone = structuredClone(request)
  const existingPlugins = clone.plugins ?? []
  clone.params = clone.params?.length ? clone.params : [createEmptyKeyValue()]
  clone.headers = clone.headers?.length ? clone.headers : [createEmptyKeyValue()]
  clone.body = {
    ...createDefaultBody(),
    ...clone.body,
    form: clone.body?.form?.length ? clone.body.form : [createEmptyKeyValue()]
  }
  clone.auth = {
    ...createDefaultAuth(),
    ...clone.auth
  }
  clone.settings = {
    ...createDefaultSettings(),
    ...clone.settings
  }

  const seen = new Set<string>()
  const ordered = existingPlugins
    .filter((plugin) => {
      if (seen.has(plugin.id)) return false
      if (!PLUGIN_DEFINITIONS.some((definition) => definition.id === plugin.id)) return false
      seen.add(plugin.id)
      return true
    })
    .map((plugin) => ({
      ...plugin,
      config: structuredClone(plugin.config)
    }))

  for (const definition of PLUGIN_DEFINITIONS) {
    if (seen.has(definition.id)) continue
    ordered.push({
      id: definition.id,
      enabled: false,
      config: JSON.parse(JSON.stringify(definition.configTemplate)) as Record<string, unknown>
    })
  }

  clone.plugins = ordered
  return clone
}
