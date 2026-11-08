import { app, dialog, type BrowserWindow } from 'electron'
import { mkdir, readFile, rename, rm, writeFile } from 'node:fs/promises'
import { dirname, join } from 'node:path'
import type { ExportResult, ImportResult, Workspace } from '@shared/types'

function workspacePath(): string {
  return join(app.getPath('userData'), 'workspace.json')
}

export async function loadWorkspace(): Promise<Workspace | null> {
  const file = workspacePath()
  try {
    const raw = await readFile(file, 'utf8')
    return JSON.parse(raw) as Workspace
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === 'ENOENT') {
      return null
    }
    try {
      await rename(file, `${file}.corrupt-${Date.now()}`)
    } catch {
      // Ignore backup failures; a fresh workspace will be created.
    }
    return null
  }
}

export async function saveWorkspace(workspace: Workspace): Promise<boolean> {
  const file = workspacePath()
  await mkdir(dirname(file), { recursive: true })
  const temporary = `${file}.tmp`
  await writeFile(temporary, JSON.stringify(workspace, null, 2), 'utf8')
  try {
    await rename(temporary, file)
  } catch {
    await rm(file, { force: true })
    await rename(temporary, file)
  }
  return true
}

export async function exportWorkspace(
  workspace: Workspace,
  window?: BrowserWindow
): Promise<ExportResult> {
  const options = {
    title: '导出 Toolbox 工作区',
    defaultPath: `toolbox-workspace-${new Date().toISOString().slice(0, 10)}.json`,
    filters: [{ name: 'JSON', extensions: ['json'] }]
  }
  const result = window
    ? await dialog.showSaveDialog(window, options)
    : await dialog.showSaveDialog(options)
  if (result.canceled || !result.filePath) {
    return { ok: false, canceled: true }
  }
  try {
    await writeFile(result.filePath, JSON.stringify(workspace, null, 2), 'utf8')
    return { ok: true, path: result.filePath }
  } catch (error) {
    return { ok: false, error: (error as Error).message }
  }
}

export async function importWorkspace(window?: BrowserWindow): Promise<ImportResult> {
  const options = {
    title: '导入 Toolbox 工作区',
    filters: [{ name: 'JSON', extensions: ['json'] }],
    properties: ['openFile' as const]
  }
  const result = window
    ? await dialog.showOpenDialog(window, options)
    : await dialog.showOpenDialog(options)
  if (result.canceled || !result.filePaths[0]) {
    return { ok: false, canceled: true }
  }
  try {
    const raw = await readFile(result.filePaths[0], 'utf8')
    return { ok: true, path: result.filePaths[0], data: JSON.parse(raw) }
  } catch (error) {
    return { ok: false, error: `读取文件失败：${(error as Error).message}` }
  }
}
