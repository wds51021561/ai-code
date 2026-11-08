import { create } from 'zustand'
import { createDefaultWorkspace, createEmptyRequest, makeId } from '@shared/defaults'
import type {
  Environment,
  HistoryEntry,
  RequestConfig,
  SavedRequest,
  SendResult,
  ThemeMode,
  Variable,
  Workspace
} from '@shared/types'
import { cloneRequest } from '../lib/request'

interface AppState {
  workspace: Workspace
  hydrated: boolean
  response: SendResult | null
  sending: boolean
  activeRequestId: string | null
  envManagerOpen: boolean

  hydrate: (workspace: Workspace) => void
  replaceWorkspace: (workspace: Workspace) => void
  setTheme: (theme: ThemeMode) => void
  setActiveEnv: (environmentId: string | null) => void
  setEnvManagerOpen: (open: boolean) => void

  updateDraft: (patch: Partial<RequestConfig>) => void
  replaceDraft: (draft: RequestConfig) => void
  resetDraft: () => void

  addEnvironment: () => string
  updateEnvironment: (id: string, patch: Partial<Pick<Environment, 'name' | 'variables'>>) => void
  deleteEnvironment: (id: string) => void
  setGlobalVariables: (variables: Variable[]) => void

  addHistory: (entry: HistoryEntry) => void
  removeHistory: (id: string) => void
  clearHistory: () => void

  saveRequest: (name: string, existingId?: string | null) => string
  removeSaved: (id: string) => void

  beginRequest: (requestId: string) => void
  finishRequest: (requestId: string, result: SendResult) => boolean
  cancelActiveRequest: () => void
  clearResponse: () => void
}

export const useAppStore = create<AppState>((set, get) => ({
  workspace: createDefaultWorkspace(),
  hydrated: false,
  response: null,
  sending: false,
  activeRequestId: null,
  envManagerOpen: false,

  hydrate: (workspace) => set({ workspace, hydrated: true }),
  replaceWorkspace: (workspace) =>
    set({
      workspace,
      response: null,
      sending: false,
      activeRequestId: null
    }),
  setTheme: (theme) =>
    set((state) => ({
      workspace: { ...state.workspace, theme }
    })),
  setActiveEnv: (environmentId) =>
    set((state) => ({
      workspace: { ...state.workspace, activeEnvId: environmentId }
    })),
  setEnvManagerOpen: (open) => set({ envManagerOpen: open }),

  updateDraft: (patch) =>
    set((state) => ({
      workspace: {
        ...state.workspace,
        draft: { ...state.workspace.draft, ...patch }
      }
    })),
  replaceDraft: (draft) =>
    set((state) => ({
      workspace: { ...state.workspace, draft: cloneRequest(draft) }
    })),
  resetDraft: () =>
    set((state) => ({
      workspace: { ...state.workspace, draft: createEmptyRequest() }
    })),

  addEnvironment: () => {
    const environment: Environment = {
      id: makeId('env'),
      name: `新环境 ${get().workspace.environments.length + 1}`,
      variables: []
    }
    set((state) => ({
      workspace: {
        ...state.workspace,
        environments: [...state.workspace.environments, environment],
        activeEnvId: state.workspace.activeEnvId ?? environment.id
      }
    }))
    return environment.id
  },
  updateEnvironment: (id, patch) =>
    set((state) => ({
      workspace: {
        ...state.workspace,
        environments: state.workspace.environments.map((environment) =>
          environment.id === id ? { ...environment, ...patch } : environment
        )
      }
    })),
  deleteEnvironment: (id) =>
    set((state) => {
      const environments = state.workspace.environments.filter((env) => env.id !== id)
      return {
        workspace: {
          ...state.workspace,
          environments,
          activeEnvId:
            state.workspace.activeEnvId === id
              ? (environments[0]?.id ?? null)
              : state.workspace.activeEnvId
        }
      }
    }),
  setGlobalVariables: (variables) =>
    set((state) => ({
      workspace: { ...state.workspace, globalVariables: variables }
    })),

  addHistory: (entry) =>
    set((state) => ({
      workspace: {
        ...state.workspace,
        history: [entry, ...state.workspace.history].slice(0, 100)
      }
    })),
  removeHistory: (id) =>
    set((state) => ({
      workspace: {
        ...state.workspace,
        history: state.workspace.history.filter((item) => item.id !== id)
      }
    })),
  clearHistory: () =>
    set((state) => ({
      workspace: { ...state.workspace, history: [] }
    })),

  saveRequest: (name, existingId) => {
    const trimmedName = name.trim()
    const now = Date.now()
    const draft = cloneRequest(get().workspace.draft)

    if (existingId) {
      const existing = get().workspace.saved.find((item) => item.id === existingId)
      if (existing) {
        const saved: SavedRequest = {
          ...existing,
          name: trimmedName || existing.name,
          request: draft,
          updatedAt: now
        }
        set((state) => ({
          workspace: {
            ...state.workspace,
            saved: [saved, ...state.workspace.saved.filter((item) => item.id !== existingId)]
          }
        }))
        return existingId
      }
    }

    const saved: SavedRequest = {
      id: makeId('saved'),
      name: trimmedName || '未命名请求',
      request: draft,
      updatedAt: now
    }
    set((state) => ({
      workspace: { ...state.workspace, saved: [saved, ...state.workspace.saved] }
    }))
    return saved.id
  },
  removeSaved: (id) =>
    set((state) => ({
      workspace: {
        ...state.workspace,
        saved: state.workspace.saved.filter((item) => item.id !== id)
      }
    })),

  beginRequest: (requestId) =>
    set({
      activeRequestId: requestId,
      sending: true,
      response: null
    }),
  finishRequest: (requestId, result) => {
    if (get().activeRequestId !== requestId) {
      return false
    }
    set({
      activeRequestId: null,
      sending: false,
      response: result
    })
    return true
  },
  cancelActiveRequest: () => {
    const requestId = get().activeRequestId
    if (!requestId) return
    void window.toolbox.request.cancel(requestId)
    set({
      activeRequestId: null,
      sending: false,
      response: null
    })
  },
  clearResponse: () => set({ response: null })
}))
