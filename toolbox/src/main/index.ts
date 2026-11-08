import { app, BrowserWindow, ipcMain, Menu, shell } from 'electron'
import { join } from 'node:path'
import type { SendPayload } from '@shared/types'
import { executeRequest } from './request/pipeline'
import { exportWorkspace, importWorkspace, loadWorkspace, saveWorkspace } from './storage'

const inFlight = new Map<string, AbortController>()

function abortAllRequests(): void {
  for (const controller of inFlight.values()) {
    controller.abort()
  }
  inFlight.clear()
}

function registerIpc(): void {
  ipcMain.handle('request:send', async (_event, payload: SendPayload) => {
    if (!payload || typeof payload.requestId !== 'string' || !payload.request) {
      throw new Error('请求参数无效')
    }
    const controller = new AbortController()
    inFlight.set(payload.requestId, controller)
    try {
      return await executeRequest(payload, controller.signal)
    } finally {
      inFlight.delete(payload.requestId)
    }
  })

  ipcMain.handle('request:cancel', (_event, requestId: string) => {
    const controller = inFlight.get(requestId)
    if (!controller) return false
    controller.abort()
    return true
  })

  ipcMain.handle('storage:load', () => loadWorkspace())
  ipcMain.handle('storage:save', async (_event, workspace) => saveWorkspace(workspace))

  ipcMain.handle('workspace:export', async (event, workspace) => {
    return exportWorkspace(workspace, BrowserWindow.fromWebContents(event.sender) ?? undefined)
  })
  ipcMain.handle('workspace:import', async (event) => {
    return importWorkspace(BrowserWindow.fromWebContents(event.sender) ?? undefined)
  })
  ipcMain.handle('app:version', () => app.getVersion())
}

function createWindow(): void {
  const window = new BrowserWindow({
    width: 1480,
    height: 940,
    minWidth: 1120,
    minHeight: 700,
    show: false,
    title: 'Toolbox',
    backgroundColor: '#0a0c10',
    autoHideMenuBar: true,
    ...(app.isPackaged ? {} : { icon: join(__dirname, '../../resources/icon.png') }),
    webPreferences: {
      preload: join(__dirname, '../preload/index.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true
    }
  })

  window.once('ready-to-show', () => {
    window.show()
  })

  window.webContents.setWindowOpenHandler(({ url }) => {
    if (url.startsWith('https://') || url.startsWith('http://')) {
      void shell.openExternal(url)
    }
    return { action: 'deny' }
  })

  window.webContents.on('will-navigate', (event, url) => {
    const currentUrl = window.webContents.getURL()
    if (url !== currentUrl) {
      event.preventDefault()
      if (url.startsWith('https://') || url.startsWith('http://')) {
        void shell.openExternal(url)
      }
    }
  })

  window.on('closed', () => {
    abortAllRequests()
  })

  const devUrl = process.env['ELECTRON_RENDERER_URL']
  if (devUrl) {
    void window.loadURL(devUrl)
  } else {
    void window.loadFile(join(__dirname, '../renderer/index.html'))
  }
}

app.whenReady().then(() => {
  app.setAppUserModelId('com.devtoolbox.app')
  Menu.setApplicationMenu(null)
  registerIpc()
  createWindow()

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow()
    }
  })
})

app.on('window-all-closed', () => {
  abortAllRequests()
  if (process.platform !== 'darwin') {
    app.quit()
  }
})

app.on('before-quit', () => {
  abortAllRequests()
})
