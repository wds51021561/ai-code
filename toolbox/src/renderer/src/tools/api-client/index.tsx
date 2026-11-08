import { GripHorizontal } from 'lucide-react'
import { useCallback, useEffect, useRef, useState, type PointerEvent as ReactPointerEvent } from 'react'
import { toast } from 'sonner'
import type { RequestConfig, SendResult } from '@shared/types'
import { makeId } from '@shared/defaults'
import { Sidebar } from '../../components/Sidebar'
import { SaveRequestDialog } from '../../components/SaveRequestDialog'
import { cloneRequest } from '../../lib/request'
import { cn, resolveVariables, suggestedRequestName } from '../../lib/utils'
import { useAppStore } from '../../store/useAppStore'
import { RequestPanel } from './RequestPanel'
import { ResponsePanel } from './ResponsePanel'

export default function ApiClient() {
  const workspace = useAppStore((state) => state.workspace)
  const sending = useAppStore((state) => state.sending)
  const envManagerOpen = useAppStore((state) => state.envManagerOpen)
  const replaceDraft = useAppStore((state) => state.replaceDraft)
  const resetDraft = useAppStore((state) => state.resetDraft)
  const clearResponse = useAppStore((state) => state.clearResponse)
  const saveRequest = useAppStore((state) => state.saveRequest)

  const [currentSavedId, setCurrentSavedId] = useState<string | null>(null)
  const [saveOpen, setSaveOpen] = useState(false)
  const [split, setSplit] = useState(52)
  const mainRef = useRef<HTMLDivElement>(null)

  const currentSaved = workspace.saved.find((item) => item.id === currentSavedId) ?? null
  const draft = workspace.draft

  const sendRequest = useCallback(async (): Promise<void> => {
    const state = useAppStore.getState()
    if (state.sending) return

    const request = cloneRequest(state.workspace.draft)
    const variables = resolveVariables(state.workspace)
    const requestId = makeId('req')
    const startedAt = performance.now()
    state.beginRequest(requestId)

    try {
      const result = await window.toolbox.request.send({
        requestId,
        request,
        variables
      })
      const accepted = useAppStore.getState().finishRequest(requestId, result)
      if (!accepted) return

      useAppStore.getState().addHistory({
        id: makeId('history'),
        at: Date.now(),
        request,
        status: result.status || undefined,
        duration: result.duration,
        error: result.error
      })

      if (result.error) {
        toast.error('请求失败', { description: result.error })
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error)
      const duration = performance.now() - startedAt
      const fallback: SendResult = {
        ok: false,
        status: 0,
        statusText: '',
        headers: [],
        body: '',
        contentType: '',
        size: 0,
        duration,
        truncated: false,
        error: message,
        finalUrl: request.url,
        request: {
          method: request.method,
          url: request.url,
          headers: [],
          body: null
        },
        pluginLog: []
      }
      const accepted = useAppStore.getState().finishRequest(requestId, fallback)
      if (!accepted) return
      useAppStore.getState().addHistory({
        id: makeId('history'),
        at: Date.now(),
        request,
        duration,
        error: message
      })
      toast.error('请求失败', { description: message })
    }
  }, [])

  const cancelRequest = useCallback((): void => {
    useAppStore.getState().cancelActiveRequest()
    toast.info('请求已取消')
  }, [])

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent): void => {
      if (!(event.ctrlKey || event.metaKey) || event.key !== 'Enter') return
      if (envManagerOpen || saveOpen) return
      event.preventDefault()
      if (!useAppStore.getState().sending) {
        void sendRequest()
      }
    }
    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
  }, [envManagerOpen, saveOpen, sendRequest])

  const handleLoadRequest = (request: RequestConfig, savedId: string | null): void => {
    replaceDraft(request)
    clearResponse()
    setCurrentSavedId(savedId)
  }

  const handleNewRequest = (): void => {
    resetDraft()
    clearResponse()
    setCurrentSavedId(null)
  }

  const handleSave = (name: string): void => {
    const updating = Boolean(currentSaved)
    const id = saveRequest(name, currentSaved?.id)
    setCurrentSavedId(id)
    setSaveOpen(false)
    toast.success(updating ? '收藏已更新' : '请求已保存', {
      description: name
    })
  }

  const beginResize = (event: ReactPointerEvent<HTMLDivElement>): void => {
    event.preventDefault()
    const container = mainRef.current
    if (!container) return
    const height = container.getBoundingClientRect().height
    const startY = event.clientY
    const startSplit = split
    document.body.style.cursor = 'row-resize'
    document.body.style.userSelect = 'none'

    const onMove = (moveEvent: PointerEvent): void => {
      const delta = ((moveEvent.clientY - startY) / height) * 100
      setSplit(Math.min(Math.max(startSplit + delta, 28), 76))
    }
    const onUp = (): void => {
      document.body.style.cursor = ''
      document.body.style.userSelect = ''
      window.removeEventListener('pointermove', onMove)
      window.removeEventListener('pointerup', onUp)
    }
    window.addEventListener('pointermove', onMove)
    window.addEventListener('pointerup', onUp)
  }

  return (
    <div className="flex h-full min-h-0">
      <Sidebar
        activeSavedId={currentSavedId}
        onLoadRequest={handleLoadRequest}
        onNewRequest={handleNewRequest}
      />

      <main ref={mainRef} className="flex min-w-0 flex-1 flex-col overflow-hidden bg-canvas">
        <div
          className="min-h-[220px] shrink-0 overflow-hidden border-b border-line"
          style={{ height: `${split}%` }}
        >
          <RequestPanel
            sending={sending}
            onSend={() => void sendRequest()}
            onCancel={cancelRequest}
            onSave={() => setSaveOpen(true)}
          />
        </div>

        <div
          onPointerDown={beginResize}
          onDoubleClick={() => setSplit(52)}
          className={cn(
            'group flex h-[7px] shrink-0 cursor-row-resize items-center justify-center border-b border-line bg-panel transition-colors hover:bg-accent-soft'
          )}
          title="拖动调整请求 / 响应区域高度"
        >
          <GripHorizontal
            size={12}
            className="text-faint transition-colors group-hover:text-accent"
          />
        </div>

        <div className="min-h-0 flex-1 overflow-hidden">
          <ResponsePanel />
        </div>
      </main>

      <SaveRequestDialog
        open={saveOpen}
        initialName={currentSaved?.name ?? suggestedRequestName(draft)}
        updating={Boolean(currentSaved)}
        onCancel={() => setSaveOpen(false)}
        onSave={handleSave}
      />
    </div>
  )
}
