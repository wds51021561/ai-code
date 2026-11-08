import {
  Download,
  Globe2,
  Plus,
  ShieldAlert,
  Trash2,
  Upload,
  Variable as VariableIcon
} from 'lucide-react'
import { useEffect, useState } from 'react'
import { toast } from 'sonner'
import { normalizeWorkspace } from '@shared/schema'
import type { Workspace } from '@shared/types'
import { cn } from '../lib/utils'
import { useAppStore } from '../store/useAppStore'
import { Button } from './Button'
import { ConfirmDialog } from './ConfirmDialog'
import { Modal } from './Modal'
import { VariableEditor } from './VariableEditor'

const GLOBAL_ID = '__globals__'

export function EnvManager() {
  const open = useAppStore((state) => state.envManagerOpen)
  const setOpen = useAppStore((state) => state.setEnvManagerOpen)
  const workspace = useAppStore((state) => state.workspace)
  const setActiveEnv = useAppStore((state) => state.setActiveEnv)
  const addEnvironment = useAppStore((state) => state.addEnvironment)
  const updateEnvironment = useAppStore((state) => state.updateEnvironment)
  const deleteEnvironment = useAppStore((state) => state.deleteEnvironment)
  const setGlobalVariables = useAppStore((state) => state.setGlobalVariables)
  const replaceWorkspace = useAppStore((state) => state.replaceWorkspace)

  const [selectedId, setSelectedId] = useState<string>(
    workspace.activeEnvId ?? workspace.environments[0]?.id ?? GLOBAL_ID
  )
  const [deleteTarget, setDeleteTarget] = useState<string | null>(null)
  const [pendingImport, setPendingImport] = useState<Workspace | null>(null)

  useEffect(() => {
    if (!open) return
    if (
      selectedId !== GLOBAL_ID &&
      !workspace.environments.some((environment) => environment.id === selectedId)
    ) {
      setSelectedId(workspace.activeEnvId ?? workspace.environments[0]?.id ?? GLOBAL_ID)
    }
  }, [open, selectedId, workspace.activeEnvId, workspace.environments])

  const selectedEnvironment =
    selectedId === GLOBAL_ID
      ? null
      : (workspace.environments.find((environment) => environment.id === selectedId) ?? null)

  const isGlobal = selectedId === GLOBAL_ID
  const isActive = selectedEnvironment ? workspace.activeEnvId === selectedEnvironment.id : false

  const handleAddEnvironment = (): void => {
    const id = addEnvironment()
    setSelectedId(id)
  }

  const handleExport = async (): Promise<void> => {
    const result = await window.toolbox.workspace.export(workspace)
    if (result.canceled) return
    if (!result.ok) {
      toast.error('导出失败', { description: result.error })
      return
    }
    toast.success('工作区已导出', { description: result.path })
  }

  const handleImport = async (): Promise<void> => {
    const result = await window.toolbox.workspace.import()
    if (result.canceled) return
    if (!result.ok) {
      toast.error('导入失败', { description: result.error })
      return
    }
    const normalized = normalizeWorkspace(result.data)
    if (!normalized) {
      toast.error('导入失败', { description: '文件不是有效的 Toolbox 工作区' })
      return
    }
    setPendingImport(normalized)
  }

  const confirmDelete = (): void => {
    if (!deleteTarget) return
    deleteEnvironment(deleteTarget)
    const remaining = workspace.environments.filter((environment) => environment.id !== deleteTarget)
    setSelectedId(remaining[0]?.id ?? GLOBAL_ID)
    setDeleteTarget(null)
    toast.success('环境已删除')
  }

  const confirmImport = (): void => {
    if (!pendingImport) return
    replaceWorkspace(pendingImport)
    setSelectedId(pendingImport.activeEnvId ?? pendingImport.environments[0]?.id ?? GLOBAL_ID)
    setPendingImport(null)
    toast.success('工作区已导入')
  }

  return (
    <>
      <Modal
        open={open}
        onClose={() => setOpen(false)}
        title="环境与变量"
        description="环境变量和全局变量可用于 URL、请求头、请求体、认证信息与插件配置。同名时环境变量优先。"
        width="xl"
        noPadding
        footer={
          <div className="flex w-full items-center justify-between gap-3">
            <div className="flex items-center gap-2">
              <Button size="sm" variant="ghost" icon={<Upload size={13} />} onClick={handleImport}>
                导入
              </Button>
              <Button size="sm" variant="ghost" icon={<Download size={13} />} onClick={handleExport}>
                导出
              </Button>
              <span className="hidden items-center gap-1 text-[10.5px] text-faint lg:flex">
                <ShieldAlert size={12} />
                导出文件包含敏感变量，请妥善保管
              </span>
            </div>
            <Button size="sm" onClick={() => setOpen(false)}>
              完成
            </Button>
          </div>
        }
      >
        <div className="flex h-[min(620px,calc(88vh-128px))] min-h-[420px]">
          <aside className="flex w-[228px] shrink-0 flex-col border-r border-line bg-panel-2/35">
            <div className="px-3 pb-2 pt-3 text-[10px] font-semibold uppercase tracking-wider text-faint">
              变量集合
            </div>
            <div className="min-h-0 flex-1 space-y-1 overflow-y-auto px-2 pb-2">
              <button
                type="button"
                onClick={() => setSelectedId(GLOBAL_ID)}
                className={cn(
                  'flex w-full items-center gap-2 rounded-lg border px-2.5 py-2 text-left outline-none transition',
                  isGlobal
                    ? 'border-accent/25 bg-accent-soft text-ink'
                    : 'border-transparent text-muted hover:bg-panel-2 hover:text-ink'
                )}
              >
                <VariableIcon size={14} className={isGlobal ? 'text-accent' : 'text-faint'} />
                <span className="min-w-0 flex-1 truncate text-[12px] font-medium">全局变量</span>
                <span className="font-mono text-[9.5px] text-faint">
                  {workspace.globalVariables.length}
                </span>
              </button>

              <div className="px-1 pb-1 pt-2 text-[10px] font-semibold uppercase tracking-wider text-faint">
                环境
              </div>

              {workspace.environments.map((environment) => {
                const selected = environment.id === selectedId
                return (
                  <button
                    key={environment.id}
                    type="button"
                    onClick={() => setSelectedId(environment.id)}
                    className={cn(
                      'flex w-full items-center gap-2 rounded-lg border px-2.5 py-2 text-left outline-none transition',
                      selected
                        ? 'border-accent/25 bg-accent-soft text-ink'
                        : 'border-transparent text-muted hover:bg-panel-2 hover:text-ink'
                    )}
                  >
                    <Globe2 size={14} className={selected ? 'text-accent' : 'text-faint'} />
                    <span className="min-w-0 flex-1 truncate text-[12px] font-medium">
                      {environment.name || '未命名环境'}
                    </span>
                    {workspace.activeEnvId === environment.id ? (
                      <span className="size-1.5 rounded-full bg-success" title="当前环境" />
                    ) : null}
                    <span className="font-mono text-[9.5px] text-faint">
                      {environment.variables.length}
                    </span>
                  </button>
                )
              })}
            </div>
            <div className="border-t border-line p-2">
              <Button
                size="sm"
                variant="ghost"
                className="w-full justify-start"
                icon={<Plus size={13} />}
                onClick={handleAddEnvironment}
              >
                新建环境
              </Button>
            </div>
          </aside>

          <section className="flex min-w-0 flex-1 flex-col">
            <div className="flex items-start justify-between gap-4 border-b border-line px-5 py-4">
              <div className="min-w-0 flex-1">
                {isGlobal ? (
                  <>
                    <div className="flex items-center gap-2">
                      <h3 className="text-[14px] font-semibold text-ink">全局变量</h3>
                      <span className="rounded-md bg-panel-2 px-1.5 py-0.5 text-[9.5px] text-muted">
                        始终生效
                      </span>
                    </div>
                    <p className="mt-1 text-[11.5px] leading-5 text-muted">
                      全局变量对所有环境生效，被当前环境中的同名变量覆盖。
                    </p>
                  </>
                ) : selectedEnvironment ? (
                  <>
                    <div className="flex items-center gap-3">
                      <input
                        value={selectedEnvironment.name}
                        onChange={(event) =>
                          updateEnvironment(selectedEnvironment.id, { name: event.target.value })
                        }
                        className="h-8 w-full max-w-[280px] rounded-md border border-transparent bg-transparent px-1 text-[14px] font-semibold text-ink outline-none transition hover:border-line focus:border-accent/50 focus:bg-panel-2 focus:ring-2 focus:ring-accent/10"
                        placeholder="环境名称"
                      />
                      {isActive ? (
                        <span className="inline-flex items-center gap-1 rounded-md bg-success/10 px-2 py-0.5 text-[10px] font-medium text-success">
                          <span className="size-1.5 rounded-full bg-success" />
                          当前环境
                        </span>
                      ) : (
                        <Button
                          size="sm"
                          variant="soft"
                          onClick={() => setActiveEnv(selectedEnvironment.id)}
                        >
                          设为当前
                        </Button>
                      )}
                    </div>
                    <p className="mt-1 text-[11.5px] leading-5 text-muted">
                      共 {selectedEnvironment.variables.length} 个变量，支持在请求中使用{' '}
                      <code className="rounded bg-panel-2 px-1 font-mono text-[10.5px] text-accent">
                        {'{{变量名}}'}
                      </code>
                      。
                    </p>
                  </>
                ) : null}
              </div>

              {selectedEnvironment ? (
                <Button
                  size="sm"
                  variant="ghost"
                  className="text-faint hover:text-danger"
                  aria-label="删除环境"
                  title="删除环境"
                  onClick={() => setDeleteTarget(selectedEnvironment.id)}
                >
                  <Trash2 size={14} />
                </Button>
              ) : null}
            </div>

            <div className="min-h-0 flex-1 overflow-auto px-5 py-4">
              <VariableEditor
                variables={isGlobal ? workspace.globalVariables : (selectedEnvironment?.variables ?? [])}
                onChange={(variables) => {
                  if (isGlobal) setGlobalVariables(variables)
                  else if (selectedEnvironment) {
                    updateEnvironment(selectedEnvironment.id, { variables })
                  }
                }}
              />
            </div>

            <div className="border-t border-line px-5 py-2.5 text-[10.5px] text-faint">
              变量按“全局 → 环境”顺序合并；值为空或未启用的变量会被忽略。
            </div>
          </section>
        </div>
      </Modal>

      <ConfirmDialog
        open={Boolean(deleteTarget)}
        title="删除环境"
        message="删除后，该环境下的所有变量将被移除，且无法恢复。确定删除吗？"
        confirmLabel="删除环境"
        onCancel={() => setDeleteTarget(null)}
        onConfirm={confirmDelete}
      />

      <ConfirmDialog
        open={Boolean(pendingImport)}
        title="导入工作区"
        message="导入会覆盖当前的全部环境、全局变量、请求草稿、历史记录和收藏。建议先导出备份。确定继续吗？"
        confirmLabel="导入并覆盖"
        onCancel={() => setPendingImport(null)}
        onConfirm={confirmImport}
      />
    </>
  )
}
