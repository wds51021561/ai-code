import { contextBridge, ipcRenderer } from 'electron'
import type { SendPayload, ToolboxApi, Workspace } from '@shared/types'

const api: ToolboxApi = {
  request: {
    send: (payload: SendPayload) => ipcRenderer.invoke('request:send', payload),
    cancel: (requestId: string) => ipcRenderer.invoke('request:cancel', requestId)
  },
  storage: {
    load: () => ipcRenderer.invoke('storage:load'),
    save: (workspace: Workspace) => ipcRenderer.invoke('storage:save', workspace)
  },
  workspace: {
    export: (workspace: Workspace) => ipcRenderer.invoke('workspace:export', workspace),
    import: () => ipcRenderer.invoke('workspace:import')
  },
  app: {
    version: () => ipcRenderer.invoke('app:version')
  }
}

contextBridge.exposeInMainWorld('toolbox', api)
