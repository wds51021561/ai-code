import { describe, expect, it } from 'vitest'
import { createDefaultWorkspace } from './defaults'
import { normalizeWorkspace } from './schema'

describe('normalizeWorkspace', () => {
  it('preserves an explicit no-environment selection', () => {
    const workspace = createDefaultWorkspace()
    workspace.activeEnvId = null
    const normalized = normalizeWorkspace(workspace)
    expect(normalized?.activeEnvId).toBeNull()
  })

  it('repairs plugins and caps history length', () => {
    const workspace = createDefaultWorkspace()
    workspace.draft.plugins = []
    workspace.history = Array.from({ length: 120 }, (_, index) => ({
      id: `history_${index}`,
      at: Date.now(),
      request: workspace.draft
    }))

    const normalized = normalizeWorkspace(workspace)
    expect(normalized).not.toBeNull()
    expect(normalized?.draft.plugins).toHaveLength(2)
    expect(normalized?.history).toHaveLength(100)
  })

  it('preserves the configured plugin execution order', () => {
    const workspace = createDefaultWorkspace()
    workspace.draft.plugins.reverse()
    const normalized = normalizeWorkspace(workspace)
    expect(normalized?.draft.plugins.map((plugin) => plugin.id)).toEqual([
      'aes-256-gcm',
      'hmac-sha256'
    ])
  })

  it('rejects malformed workspaces', () => {
    expect(normalizeWorkspace({ version: 1 })).toBeNull()
    expect(normalizeWorkspace(null)).toBeNull()
  })
})
