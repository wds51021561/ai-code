import { ChevronDown, Globe2, Loader2, Moon, SlidersHorizontal, Sun, Wrench } from 'lucide-react'
import { Suspense, useEffect, useRef, useState } from 'react'
import { Toaster } from 'sonner'
import { createDefaultWorkspace } from '@shared/defaults'
import { normalizeWorkspace } from '@shared/schema'
import { EnvManager } from './components/EnvManager'
import { Button, selectClass } from './components/Button'
import { cn } from './lib/utils'
import { useAppStore } from './store/useAppStore'
import { TOOLS } from './tools/registry'

export default function App() {
  const hydrated = useAppStore((state) => state.hydrated)
  const workspace = useAppStore((state) => state.workspace)
  const setActiveEnv = useAppStore((state) => state.setActiveEnv)
  const setEnvManagerOpen = useAppStore((state) => state.setEnvManagerOpen)
  const setTheme = useAppStore((state) => state.setTheme)
  const [activeToolId, setActiveToolId] = useState(TOOLS[0].id)
  const startedLoad = useRef(false)

  useEffect(() => {
    if (startedLoad.current) return
    startedLoad.current = true
    let active = true
    window.toolbox.storage
      .load()
      .then((raw) => {
        if (!active) return
        const normalized = normalizeWorkspace(raw)
        useAppStore.getState().hydrate(normalized ?? createDefaultWorkspace())
      })
      .catch(() => {
        if (!active) return
        useAppStore.getState().hydrate(createDefaultWorkspace())
      })
    return () => {
      active = false
    }
  }, [])

  useEffect(() => {
    document.documentElement.dataset.theme = workspace.theme
  }, [workspace.theme])

  useEffect(() => {
    if (!hydrated) return
    let timer: number | undefined
    const unsubscribe = useAppStore.subscribe((state, previous) => {
      if (state.workspace === previous.workspace) return
      if (timer) window.clearTimeout(timer)
      timer = window.setTimeout(() => {
        void window.toolbox.storage.save(useAppStore.getState().workspace)
      }, 250)
    })
    return () => {
      unsubscribe()
      if (timer) window.clearTimeout(timer)
    }
  }, [hydrated])

  useEffect(() => {
    if (!hydrated) return
    const flush = (): void => {
      void window.toolbox.storage.save(useAppStore.getState().workspace)
    }
    window.addEventListener('beforeunload', flush)
    return () => window.removeEventListener('beforeunload', flush)
  }, [hydrated])

  const activeTool = TOOLS.find((tool) => tool.id === activeToolId) ?? TOOLS[0]
  const ActiveTool = activeTool.component
  const activeEnvironment = workspace.environments.find(
    (environment) => environment.id === workspace.activeEnvId
  )

  if (!hydrated) {
    return (
      <div className="app-shell flex h-full items-center justify-center">
        <div className="flex flex-col items-center">
          <BrandMark size="lg" />
          <div className="mt-4 flex items-center gap-2 text-[12px] text-muted">
            <Loader2 size={14} className="animate-spin text-accent" />
            正在加载工作区
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="app-shell flex h-full flex-col overflow-hidden">
      <header className="flex h-[56px] shrink-0 items-center gap-4 border-b border-line bg-panel/85 px-4 backdrop-blur">
        <div className="flex shrink-0 items-center gap-2.5">
          <BrandMark />
          <div className="flex items-baseline gap-1.5">
            <span className="text-[13.5px] font-semibold tracking-tight text-ink">Toolbox</span>
            <span className="rounded border border-line bg-panel-2 px-1 py-px text-[8.5px] font-semibold tracking-wider text-faint">
              DEV
            </span>
          </div>
        </div>

        <div className="h-5 w-px shrink-0 bg-line" />

        <nav className="flex min-w-0 max-w-[58vw] items-center gap-1 overflow-x-auto rounded-xl border border-line bg-panel-2/60 p-1">
          {TOOLS.map((tool) => {
            const Icon = tool.icon
            const active = tool.id === activeTool.id
            return (
              <button
                key={tool.id}
                type="button"
                onClick={() => setActiveToolId(tool.id)}
                title={tool.description}
                className={cn(
                  'flex shrink-0 items-center gap-2 rounded-lg px-3 py-1.5 text-[12px] font-medium outline-none transition-all focus-visible:ring-2 focus-visible:ring-accent/35',
                  active
                    ? 'bg-elevated text-ink shadow-sm ring-1 ring-line'
                    : 'text-muted hover:bg-panel-2 hover:text-ink'
                )}
              >
                <Icon size={14} className={active ? 'text-accent' : 'text-faint'} />
                {tool.title}
              </button>
            )
          })}
        </nav>

        <div className="ml-auto flex shrink-0 items-center gap-2">
          <div className="relative">
            <Globe2
              size={13}
              className="pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 text-faint"
            />
            <select
              value={workspace.activeEnvId ?? ''}
              onChange={(event) => setActiveEnv(event.target.value || null)}
              title={activeEnvironment ? `当前环境：${activeEnvironment.name}` : '未使用环境'}
              className={cn(
                selectClass,
                'h-8 w-[172px] appearance-none pl-7 pr-7 text-[11.5px]'
              )}
            >
              <option value="">不使用环境</option>
              {workspace.environments.map((environment) => (
                <option key={environment.id} value={environment.id}>
                  {environment.name}
                </option>
              ))}
            </select>
            <ChevronDown
              size={12}
              className="pointer-events-none absolute right-2.5 top-1/2 -translate-y-1/2 text-faint"
            />
          </div>

          <Button
            variant="ghost"
            size="icon-sm"
            title="环境与变量"
            aria-label="环境与变量"
            onClick={() => setEnvManagerOpen(true)}
          >
            <SlidersHorizontal size={15} />
          </Button>

          <div className="h-5 w-px bg-line" />

          <Button
            variant="ghost"
            size="icon-sm"
            title={workspace.theme === 'dark' ? '切换到浅色主题' : '切换到深色主题'}
            aria-label="切换主题"
            onClick={() => setTheme(workspace.theme === 'dark' ? 'light' : 'dark')}
          >
            {workspace.theme === 'dark' ? <Sun size={15} /> : <Moon size={15} />}
          </Button>
        </div>
      </header>

      <div className="relative min-h-0 flex-1">
        <Suspense
          fallback={
            <div className="flex h-full items-center justify-center">
              <Loader2 size={18} className="animate-spin text-accent" />
            </div>
          }
        >
          <ActiveTool />
        </Suspense>
      </div>

      <EnvManager />

      <Toaster
        theme={workspace.theme}
        position="bottom-right"
        closeButton
        toastOptions={{ style: { fontSize: '12px' } }}
      />
    </div>
  )
}

function BrandMark({ size = 'md' }: { size?: 'md' | 'lg' }) {
  return (
    <div
      className={cn(
        'flex shrink-0 items-center justify-center text-white shadow-lg',
        size === 'lg' ? 'size-12 rounded-2xl' : 'size-8 rounded-[10px]'
      )}
      style={{
        background: 'linear-gradient(135deg, #7c9cff 0%, #a78bfa 55%, #4c6fe8 100%)',
        boxShadow: '0 8px 26px color-mix(in srgb, var(--accent) 24%, transparent)'
      }}
    >
      <Wrench size={size === 'lg' ? 22 : 15} />
    </div>
  )
}
