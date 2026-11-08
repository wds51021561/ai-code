import { Bookmark, Clock3, History, Plus, Trash2 } from 'lucide-react'
import { useState, type ReactNode } from 'react'
import { toast } from 'sonner'
import type { RequestConfig } from '@shared/types'
import { cn, formatRelativeTime, methodColorVar, requestDisplayUrl, statusColorVar } from '../lib/utils'
import { useAppStore } from '../store/useAppStore'
import { ConfirmDialog } from './ConfirmDialog'
import { MethodBadge } from './Badge'

type SidebarTab = 'history' | 'saved'

interface SidebarProps {
  activeSavedId: string | null
  onLoadRequest: (request: RequestConfig, savedId: string | null) => void
  onNewRequest: () => void
}

export function Sidebar({ activeSavedId, onLoadRequest, onNewRequest }: SidebarProps) {
  const workspace = useAppStore((state) => state.workspace)
  const removeHistory = useAppStore((state) => state.removeHistory)
  const clearHistory = useAppStore((state) => state.clearHistory)
  const removeSaved = useAppStore((state) => state.removeSaved)

  const [tab, setTab] = useState<SidebarTab>('history')
  const [clearOpen, setClearOpen] = useState(false)
  const [deleteSavedId, setDeleteSavedId] = useState<string | null>(null)

  const deleteTarget = workspace.saved.find((item) => item.id === deleteSavedId) ?? null

  return (
    <aside className="flex w-[252px] shrink-0 flex-col border-r border-line bg-panel">
      <div className="flex h-[47px] shrink-0 items-center justify-between border-b border-line px-3">
        <span className="text-[11px] font-semibold uppercase tracking-wider text-faint">请求</span>
        <button
          type="button"
          onClick={onNewRequest}
          title="新建请求"
          aria-label="新建请求"
          className="flex size-7 items-center justify-center rounded-md text-muted outline-none transition hover:bg-panel-2 hover:text-ink focus-visible:ring-2 focus-visible:ring-accent/35"
        >
          <Plus size={15} />
        </button>
      </div>

      <div className="grid shrink-0 grid-cols-2 gap-1 border-b border-line px-2 py-2">
        <button
          type="button"
          onClick={() => setTab('history')}
          className={cn(
            'flex items-center justify-center gap-1.5 rounded-md px-2 py-1.5 text-[11.5px] font-medium outline-none transition',
            tab === 'history'
              ? 'bg-panel-2 text-ink shadow-sm'
              : 'text-muted hover:bg-panel-2/60 hover:text-ink'
          )}
        >
          <History size={13} />
          历史
          <span className="font-mono text-[9.5px] text-faint">{workspace.history.length}</span>
        </button>
        <button
          type="button"
          onClick={() => setTab('saved')}
          className={cn(
            'flex items-center justify-center gap-1.5 rounded-md px-2 py-1.5 text-[11.5px] font-medium outline-none transition',
            tab === 'saved'
              ? 'bg-panel-2 text-ink shadow-sm'
              : 'text-muted hover:bg-panel-2/60 hover:text-ink'
          )}
        >
          <Bookmark size={13} />
          收藏
          <span className="font-mono text-[9.5px] text-faint">{workspace.saved.length}</span>
        </button>
      </div>

      <div className="min-h-0 flex-1 overflow-y-auto p-2">
        {tab === 'history' ? (
          workspace.history.length ? (
            <div className="space-y-1">
              {workspace.history.map((entry) => {
                const errored = Boolean(entry.error)
                const color = entry.status
                  ? errored
                    ? 'var(--warning)'
                    : statusColorVar(entry.status)
                  : 'var(--danger)'
                return (
                  <div key={entry.id} className="group relative">
                    <button
                      type="button"
                      onClick={() => onLoadRequest(entry.request, null)}
                      title={entry.error ? `${entry.request.url}\n${entry.error}` : entry.request.url}
                      className="w-full rounded-lg border border-transparent px-2 py-2 pr-7 text-left outline-none transition hover:border-line hover:bg-panel-2 focus-visible:border-accent/40 focus-visible:bg-panel-2"
                    >
                      <div className="flex min-w-0 items-center gap-2">
                        <MethodBadge method={entry.request.method} className="min-w-[44px]" />
                        <span className="min-w-0 flex-1 truncate font-mono text-[11px] text-ink">
                          {requestDisplayUrl(entry.request)}
                        </span>
                      </div>
                      <div className="mt-1.5 flex items-center gap-2 pl-0.5 text-[10px] text-faint">
                        <span>{formatRelativeTime(entry.at)}</span>
                        <span className="text-line-strong">·</span>
                        <span className="inline-flex items-center gap-1" style={{ color }}>
                          <span className="size-1.5 rounded-full" style={{ backgroundColor: color }} />
                          {entry.status || 'ERR'}
                        </span>
                        {typeof entry.duration === 'number' ? (
                          <>
                            <span className="text-line-strong">·</span>
                            <span>{Math.round(entry.duration)} ms</span>
                          </>
                        ) : null}
                      </div>
                    </button>
                    <button
                      type="button"
                      aria-label="删除历史"
                      title="删除历史"
                      onClick={() => removeHistory(entry.id)}
                      className="absolute right-1 top-1 flex size-6 items-center justify-center rounded text-faint opacity-0 outline-none transition hover:bg-danger/10 hover:text-danger focus-visible:opacity-100 focus-visible:ring-2 focus-visible:ring-accent/35 group-hover:opacity-100"
                    >
                      <Trash2 size={12} />
                    </button>
                  </div>
                )
              })}
            </div>
          ) : (
            <EmptyState
              icon={<Clock3 size={24} />}
              title="暂无历史记录"
              description="发送请求后会自动记录在这里"
            />
          )
        ) : workspace.saved.length ? (
          <div className="space-y-1">
            {workspace.saved.map((item) => (
              <div key={item.id} className="group relative">
                <button
                  type="button"
                  onClick={() => onLoadRequest(item.request, item.id)}
                  title={item.request.url}
                  className={cn(
                    'w-full rounded-lg border px-2 py-2 pr-7 text-left outline-none transition',
                    item.id === activeSavedId
                      ? 'border-accent/25 bg-accent-soft'
                      : 'border-transparent hover:border-line hover:bg-panel-2'
                  )}
                >
                  <div className="truncate text-[12px] font-medium text-ink">{item.name}</div>
                  <div className="mt-1 flex min-w-0 items-center gap-1.5">
                    <MethodBadge method={item.request.method} className="min-w-[44px]" />
                    <span className="min-w-0 flex-1 truncate font-mono text-[10.5px] text-muted">
                      {requestDisplayUrl(item.request)}
                    </span>
                  </div>
                  <div className="mt-1 text-[10px] text-faint">
                    更新于 {formatRelativeTime(item.updatedAt)}
                  </div>
                </button>
                <button
                  type="button"
                  aria-label="删除收藏"
                  title="删除收藏"
                  onClick={() => setDeleteSavedId(item.id)}
                  className="absolute right-1 top-1 flex size-6 items-center justify-center rounded text-faint opacity-0 outline-none transition hover:bg-danger/10 hover:text-danger focus-visible:opacity-100 focus-visible:ring-2 focus-visible:ring-accent/35 group-hover:opacity-100"
                >
                  <Trash2 size={12} />
                </button>
              </div>
            ))}
          </div>
        ) : (
          <EmptyState
            icon={<Bookmark size={24} />}
            title="暂无收藏"
            description="点击请求栏右侧「保存」收藏当前请求"
          />
        )}
      </div>

      <div className="flex h-9 shrink-0 items-center justify-between border-t border-line px-3">
        <span className="text-[10px] text-faint">Ctrl + Enter 发送</span>
        {tab === 'history' && workspace.history.length > 0 ? (
          <button
            type="button"
            onClick={() => setClearOpen(true)}
            className="text-[10px] text-faint outline-none transition hover:text-danger focus-visible:text-danger"
          >
            清空
          </button>
        ) : (
          <span className="text-[10px] text-faint">{workspace.saved.length} 条收藏</span>
        )}
      </div>

      <ConfirmDialog
        open={clearOpen}
        title="清空历史记录"
        message="所有历史请求记录将被删除，收藏和当前请求不受影响。确定清空吗？"
        confirmLabel="清空历史"
        onCancel={() => setClearOpen(false)}
        onConfirm={() => {
          clearHistory()
          setClearOpen(false)
          toast.success('历史记录已清空')
        }}
      />

      <ConfirmDialog
        open={Boolean(deleteTarget)}
        title="删除收藏"
        message={`确定删除收藏「${deleteTarget?.name ?? ''}」吗？此操作无法恢复。`}
        confirmLabel="删除收藏"
        onCancel={() => setDeleteSavedId(null)}
        onConfirm={() => {
          if (deleteSavedId) removeSaved(deleteSavedId)
          setDeleteSavedId(null)
          toast.success('收藏已删除')
        }}
      />
    </aside>
  )
}

function EmptyState({
  icon,
  title,
  description
}: {
  icon: ReactNode
  title: string
  description: string
}) {
  return (
    <div className="flex h-full min-h-[220px] flex-col items-center justify-center px-5 text-center">
      <div className="mb-3 flex size-11 items-center justify-center rounded-xl border border-line bg-panel-2 text-faint">
        {icon}
      </div>
      <div className="text-[12px] font-medium text-muted">{title}</div>
      <p className="mt-1 max-w-[170px] text-[10.5px] leading-4 text-faint">{description}</p>
    </div>
  )
}
