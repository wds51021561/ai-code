import {
  ChevronDown,
  ChevronUp,
  Fingerprint,
  Info,
  LockKeyhole,
  Loader2,
  Puzzle,
  Save,
  Scissors,
  Send,
  Wand2
} from 'lucide-react'
import { useEffect, useRef, useState, type ReactNode } from 'react'
import { toast } from 'sonner'
import { PLUGIN_DEFINITIONS } from '@shared/plugins'
import { createEmptyKeyValue } from '@shared/defaults'
import type {
  AuthType,
  BodyMode,
  HttpMethod,
  PluginDefinition,
  RequestPluginConfig
} from '@shared/types'
import { Button, inputClass, selectClass } from '../../components/Button'
import { CodeEditor } from '../../components/CodeEditor'
import { KeyValueEditor } from '../../components/KeyValueEditor'
import { SegmentedTabs, UnderlineTabs, type TabItem } from '../../components/Tabs'
import { cn, extractUrlQuery, methodColorVar } from '../../lib/utils'
import { useAppStore } from '../../store/useAppStore'

type RequestTab = 'params' | 'headers' | 'body' | 'auth' | 'plugins' | 'settings'

const methods: HttpMethod[] = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD', 'OPTIONS']

const bodyModes: Array<{ id: BodyMode; label: string }> = [
  { id: 'none', label: 'none' },
  { id: 'json', label: 'JSON' },
  { id: 'text', label: 'Text' },
  { id: 'form-urlencoded', label: 'Form URL' },
  { id: 'form-data', label: 'Form Data' }
]

const authTypes: Array<{ id: AuthType; label: string }> = [
  { id: 'none', label: 'None' },
  { id: 'bearer', label: 'Bearer' },
  { id: 'basic', label: 'Basic' },
  { id: 'api-key', label: 'API Key' }
]

const commonHeaders = [
  'Accept',
  'Accept-Encoding',
  'Accept-Language',
  'Authorization',
  'Cache-Control',
  'Content-Type',
  'Cookie',
  'Origin',
  'Referer',
  'User-Agent',
  'X-Request-Id',
  'X-Signature',
  'X-Timestamp',
  'X-Nonce'
]

interface RequestPanelProps {
  sending: boolean
  onSend: () => void
  onCancel: () => void
  onSave: () => void
}

export function RequestPanel({ sending, onSend, onCancel, onSave }: RequestPanelProps) {
  const draft = useAppStore((state) => state.workspace.draft)
  const updateDraft = useAppStore((state) => state.updateDraft)
  const [tab, setTab] = useState<RequestTab>('params')

  const enabledPlugins = draft.plugins.filter((plugin) => plugin.enabled).length
  const activeParams = draft.params.filter((param) => param.enabled && param.key.trim()).length
  const activeHeaders = draft.headers.filter((header) => header.enabled && header.key.trim()).length

  const tabs: Array<TabItem<RequestTab>> = [
    { id: 'params', label: 'Params', count: activeParams },
    { id: 'headers', label: 'Headers', count: activeHeaders },
    { id: 'body', label: 'Body' },
    { id: 'auth', label: 'Auth' },
    { id: 'plugins', label: '扩展', count: enabledPlugins },
    { id: 'settings', label: '设置' }
  ]

  const handleUrlBlur = (): void => {
    const extracted = extractUrlQuery(draft.url)
    if (!extracted) return
    const hasParams = draft.params.some((param) => param.key.trim() || param.value.trim())
    if (hasParams) return
    updateDraft({
      url: extracted.url,
      params: [...extracted.params, createEmptyKeyValue()]
    })
  }

  const handleExtractQuery = (): void => {
    const extracted = extractUrlQuery(draft.url)
    if (!extracted) {
      toast.info('当前 URL 中没有查询参数')
      return
    }
    const existing = draft.params.filter((param) => param.key.trim() || param.value.trim())
    updateDraft({
      url: extracted.url,
      params: [...existing, ...extracted.params, createEmptyKeyValue()]
    })
    toast.success('已把 URL 查询参数拆分到表格')
  }

  return (
    <div className="flex h-full min-h-0 flex-col bg-panel">
      <div className="flex shrink-0 items-center gap-2 border-b border-line px-3 py-2.5">
        <select
          value={draft.method}
          onChange={(event) =>
            updateDraft({ method: event.target.value as HttpMethod })
          }
          style={{ color: methodColorVar(draft.method) }}
          className={cn(selectClass, 'w-[104px] shrink-0 font-mono text-[11px] font-bold')}
        >
          {methods.map((method) => (
            <option key={method} value={method}>
              {method}
            </option>
          ))}
        </select>

        <input
          value={draft.url}
          onChange={(event) => updateDraft({ url: event.target.value })}
          onBlur={handleUrlBlur}
          onKeyDown={(event) => {
            if (event.key === 'Enter' && !sending) onSend()
          }}
          placeholder="https://api.example.com/users 或 {{baseUrl}}/users"
          spellCheck={false}
          className={cn(inputClass, 'flex-1 font-mono text-[12.5px]')}
        />

        <Button
          variant={sending ? 'danger' : 'send'}
          className="w-[86px] shrink-0"
          icon={
            sending ? <Loader2 size={14} className="animate-spin" /> : <Send size={14} />
          }
          onClick={sending ? onCancel : onSend}
        >
          {sending ? '取消' : '发送'}
        </Button>

        <Button
          variant="secondary"
          className="shrink-0"
          icon={<Save size={14} />}
          onClick={onSave}
          title="保存请求（收藏）"
        >
          保存
        </Button>
      </div>

      <UnderlineTabs items={tabs} value={tab} onChange={setTab} className="shrink-0" />

      <div className="min-h-0 flex-1 overflow-auto px-4 py-4">
        {tab === 'params' ? (
          <div className="mx-auto max-w-4xl">
            <PanelHint
              title="查询参数"
              description="值支持 {{变量}}，发送时会自动 URL 编码。粘贴带 ?a=1 的 URL 并移开焦点时，参数会自动拆分到表格。"
              action={
                <Button
                  size="sm"
                  variant="ghost"
                  icon={<Scissors size={13} />}
                  onClick={handleExtractQuery}
                >
                  从 URL 拆分
                </Button>
              }
            />
            <KeyValueEditor
              items={draft.params}
              onChange={(params) => updateDraft({ params })}
              keyPlaceholder="参数名"
              valuePlaceholder="参数值"
            />
          </div>
        ) : null}

        {tab === 'headers' ? (
          <div className="mx-auto max-w-4xl">
            <PanelHint
              title="请求头"
              description="Content-Type 会根据 Body 模式自动补全，也可以在这里手动覆盖。插件和认证写入的请求头同样会出现在实际请求中。"
            />
            <KeyValueEditor
              items={draft.headers}
              onChange={(headers) => updateDraft({ headers })}
              keyPlaceholder="请求头"
              valuePlaceholder="值，支持 {{变量}}"
              keySuggestions={commonHeaders}
            />
          </div>
        ) : null}

        {tab === 'body' ? <BodyPanel /> : null}

        {tab === 'auth' ? <AuthPanel /> : null}

        {tab === 'plugins' ? <PluginsPanel /> : null}

        {tab === 'settings' ? <SettingsPanel /> : null}
      </div>
    </div>
  )
}

function PanelHint({
  title,
  description,
  action
}: {
  title: string
  description: string
  action?: ReactNode
}) {
  return (
    <div className="mb-3 flex items-start justify-between gap-3">
      <div>
        <h3 className="text-[12px] font-semibold text-ink">{title}</h3>
        <p className="mt-1 max-w-3xl text-[11px] leading-5 text-muted">{description}</p>
      </div>
      {action ? <div className="shrink-0">{action}</div> : null}
    </div>
  )
}

function BodyPanel() {
  const draft = useAppStore((state) => state.workspace.draft)
  const updateDraft = useAppStore((state) => state.updateDraft)
  const body = draft.body

  const setMode = (mode: BodyMode): void => {
    updateDraft({
      body: {
        ...body,
        mode,
        raw: mode === 'json' && !body.raw.trim() ? '{\n  \n}' : body.raw
      }
    })
  }

  const formatJson = (): void => {
    try {
      const parsed: unknown = JSON.parse(body.raw)
      updateDraft({
        body: { ...body, raw: JSON.stringify(parsed, null, 2) }
      })
      toast.success('JSON 已格式化')
    } catch (error) {
      toast.error('JSON 格式错误', { description: (error as Error).message })
    }
  }

  return (
    <div className="mx-auto flex h-full max-w-4xl flex-col">
      <div className="mb-3 flex flex-wrap items-center justify-between gap-3">
        <div>
          <h3 className="text-[12px] font-semibold text-ink">请求体</h3>
          <p className="mt-1 text-[11px] leading-5 text-muted">
            支持 JSON、文本、表单编码和 multipart 文本字段；值支持 {'{{变量}}'}。
          </p>
        </div>
        <SegmentedTabs items={bodyModes} value={body.mode} onChange={setMode} />
      </div>

      {body.mode === 'none' ? (
        <div className="flex min-h-[220px] flex-1 flex-col items-center justify-center rounded-xl border border-dashed border-line bg-panel-2/30 text-center">
          <div className="mb-3 flex size-10 items-center justify-center rounded-xl border border-line bg-panel text-faint">
            <Info size={18} />
          </div>
          <div className="text-[12px] font-medium text-muted">该请求没有 Body</div>
          <p className="mt-1 text-[10.5px] text-faint">GET、HEAD 等请求通常不需要请求体</p>
        </div>
      ) : body.mode === 'json' || body.mode === 'text' ? (
        <div className="flex min-h-0 flex-1 flex-col">
          <div className="flex items-center justify-between rounded-t-xl border border-b-0 border-line bg-panel-2/50 px-3 py-1.5">
            <span className="text-[10.5px] font-medium text-muted">
              {body.mode === 'json'
                ? 'application/json'
                : 'text/plain'}
              <span className="ml-2 text-faint">
                {body.raw.length.toLocaleString()} 字符
              </span>
            </span>
            {body.mode === 'json' ? (
              <Button
                size="sm"
                variant="ghost"
                icon={<Wand2 size={12} />}
                onClick={formatJson}
              >
                格式化
              </Button>
            ) : null}
          </div>
          <div className="h-[260px] overflow-hidden rounded-b-xl border border-line bg-panel-2/25">
            <CodeEditor
              value={body.raw}
              onChange={(raw) => updateDraft({ body: { ...body, raw } })}
              language={body.mode === 'json' ? 'json' : 'text'}
              placeholder={body.mode === 'json' ? '{\n  "name": "value"\n}' : '请输入文本内容'}
            />
          </div>
        </div>
      ) : (
        <div className="rounded-xl border border-line bg-panel-2/25 p-3">
          <KeyValueEditor
            items={body.form}
            onChange={(form) => updateDraft({ body: { ...body, form } })}
            keyPlaceholder="字段名"
            valuePlaceholder="字段值，支持 {{变量}}"
          />
          {body.mode === 'form-data' ? (
            <p className="mt-3 border-t border-line pt-2 text-[10.5px] text-faint">
              当前版本 multipart/form-data 支持文本字段，文件上传将在后续版本加入。
            </p>
          ) : null}
        </div>
      )}
    </div>
  )
}

function AuthPanel() {
  const draft = useAppStore((state) => state.workspace.draft)
  const updateDraft = useAppStore((state) => state.updateDraft)
  const auth = draft.auth

  const patch = (next: Partial<typeof auth>): void => {
    updateDraft({ auth: { ...auth, ...next } })
  }

  return (
    <div className="mx-auto max-w-3xl">
      <div className="mb-4">
        <h3 className="text-[12px] font-semibold text-ink">认证</h3>
        <p className="mt-1 text-[11px] leading-5 text-muted">
          认证在请求插件之前应用。需要签名、加密等更复杂的认证流程时，可组合下方扩展插件。
        </p>
      </div>

      <SegmentedTabs
        items={authTypes}
        value={auth.type}
        onChange={(type) => patch({ type })}
        className="mb-4"
      />

      {auth.type === 'none' ? (
        <div className="rounded-xl border border-dashed border-line bg-panel-2/30 px-4 py-6 text-center text-[11.5px] text-muted">
          当前请求不使用认证。
        </div>
      ) : null}

      {auth.type === 'bearer' ? (
        <Field label="Token" hint="会写入 Authorization: Bearer <token>，支持 {{apiToken}}。">
          <input
            value={auth.token}
            onChange={(event) => patch({ token: event.target.value })}
            placeholder="{{apiToken}}"
            spellCheck={false}
            className={cn(inputClass, 'font-mono')}
          />
        </Field>
      ) : null}

      {auth.type === 'basic' ? (
        <div className="grid grid-cols-2 gap-3">
          <Field label="用户名">
            <input
              value={auth.username}
              onChange={(event) => patch({ username: event.target.value })}
              placeholder="username"
              spellCheck={false}
              className={inputClass}
            />
          </Field>
          <Field label="密码">
            <input
              value={auth.password}
              onChange={(event) => patch({ password: event.target.value })}
              placeholder="{{password}}"
              type="password"
              className={inputClass}
            />
          </Field>
        </div>
      ) : null}

      {auth.type === 'api-key' ? (
        <div className="grid grid-cols-[1fr_1.4fr_130px] gap-3">
          <Field label="Key">
            <input
              value={auth.key}
              onChange={(event) => patch({ key: event.target.value })}
              placeholder="X-API-Key"
              spellCheck={false}
              className={inputClass}
            />
          </Field>
          <Field label="Value">
            <input
              value={auth.value}
              onChange={(event) => patch({ value: event.target.value })}
              placeholder="{{apiToken}}"
              spellCheck={false}
              className={cn(inputClass, 'font-mono')}
            />
          </Field>
          <Field label="添加到">
            <select
              value={auth.addTo}
              onChange={(event) =>
                patch({ addTo: event.target.value as typeof auth.addTo })
              }
              className={cn(selectClass, 'w-full')}
            >
              <option value="header">Header</option>
              <option value="query">Query</option>
            </select>
          </Field>
        </div>
      ) : null}
    </div>
  )
}

function Field({
  label,
  hint,
  children
}: {
  label: string
  hint?: string
  children: ReactNode
}) {
  return (
    <div>
      <label className="mb-1.5 block text-[11px] font-medium text-muted">{label}</label>
      {children}
      {hint ? <p className="mt-1.5 text-[10.5px] leading-4 text-faint">{hint}</p> : null}
    </div>
  )
}

function PluginsPanel() {
  const draft = useAppStore((state) => state.workspace.draft)
  const updateDraft = useAppStore((state) => state.updateDraft)

  const movePlugin = (id: string, direction: -1 | 1): void => {
    const index = draft.plugins.findIndex((plugin) => plugin.id === id)
    const target = index + direction
    if (index < 0 || target < 0 || target >= draft.plugins.length) return
    const next = [...draft.plugins]
    const [item] = next.splice(index, 1)
    next.splice(target, 0, item)
    updateDraft({ plugins: next })
  }

  const updatePlugin = (id: string, patch: Partial<RequestPluginConfig>): void => {
    updateDraft({
      plugins: draft.plugins.map((plugin) =>
        plugin.id === id ? { ...plugin, ...patch } : plugin
      )
    })
  }

  return (
    <div className="mx-auto max-w-4xl">
      <div className="mb-4 flex items-start gap-3 rounded-xl border border-line bg-panel-2/35 p-3.5">
        <div className="flex size-8 shrink-0 items-center justify-center rounded-lg bg-accent-soft text-accent">
          <Puzzle size={16} />
        </div>
        <div>
          <h3 className="text-[12px] font-semibold text-ink">请求扩展</h3>
          <p className="mt-1 text-[11px] leading-5 text-muted">
            插件在发送前按列表顺序执行，在响应后逆序执行。适合接入签名、加密、解密、自定义请求头等企业网关规范。
          </p>
        </div>
      </div>

      <div className="space-y-2.5">
        {draft.plugins.map((config, index) => {
          const definition = PLUGIN_DEFINITIONS.find((item) => item.id === config.id)
          if (!definition) return null
          return (
            <PluginCard
              key={definition.id}
              definition={definition}
              config={config}
              index={index}
              total={draft.plugins.length}
              onToggle={(enabled) => updatePlugin(definition.id, { enabled })}
              onConfigChange={(nextConfig) =>
                updatePlugin(definition.id, { config: nextConfig })
              }
              onMove={(direction) => movePlugin(definition.id, direction)}
            />
          )
        })}
      </div>
    </div>
  )
}

function PluginCard({
  definition,
  config,
  index,
  total,
  onToggle,
  onConfigChange,
  onMove
}: {
  definition: PluginDefinition
  config: RequestPluginConfig
  index: number
  total: number
  onToggle: (enabled: boolean) => void
  onConfigChange: (config: Record<string, unknown>) => void
  onMove: (direction: -1 | 1) => void
}) {
  const [expanded, setExpanded] = useState(false)
  const [text, setText] = useState(() => JSON.stringify(config.config, null, 2))
  const [error, setError] = useState<string | null>(null)
  const committed = useRef(JSON.stringify(config.config))

  useEffect(() => {
    const next = JSON.stringify(config.config)
    if (next !== committed.current) {
      committed.current = next
      setText(JSON.stringify(config.config, null, 2))
      setError(null)
    }
  }, [config.config])

  const handleChange = (value: string): void => {
    setText(value)
    try {
      const parsed: unknown = JSON.parse(value)
      if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
        setError('配置必须是一个 JSON 对象')
        return
      }
      committed.current = JSON.stringify(parsed)
      onConfigChange(parsed as Record<string, unknown>)
      setError(null)
    } catch {
      setError('JSON 格式不完整或无效，当前修改尚未应用')
    }
  }

  const Icon = definition.id === 'aes-256-gcm' ? LockKeyhole : Fingerprint

  return (
    <div
      className={cn(
        'rounded-xl border transition-colors',
        config.enabled
          ? 'border-accent/25 bg-accent-soft/35'
          : 'border-line bg-panel-2/25'
      )}
    >
      <div className="flex items-start gap-3 p-3.5">
        <div
          className={cn(
            'mt-0.5 flex size-8 shrink-0 items-center justify-center rounded-lg border',
            config.enabled
              ? 'border-accent/25 bg-accent/10 text-accent'
              : 'border-line bg-panel text-faint'
          )}
        >
          <Icon size={15} />
        </div>

        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-2">
            <h4 className="text-[12px] font-semibold text-ink">{definition.name}</h4>
            <span className="rounded bg-panel-2 px-1.5 py-0.5 font-mono text-[9px] text-faint">
              {definition.id}
            </span>
          </div>
          <p className="mt-1 text-[11px] leading-5 text-muted">{definition.description}</p>
        </div>

        <div className="flex shrink-0 items-center gap-1">
          <button
            type="button"
            onClick={() => onMove(-1)}
            disabled={index <= 0}
            title="上移"
            aria-label="上移插件"
            className="flex size-6 items-center justify-center rounded text-faint outline-none transition hover:bg-panel-2 hover:text-ink disabled:opacity-30 focus-visible:ring-2 focus-visible:ring-accent/35"
          >
            <ChevronUp size={13} />
          </button>
          <button
            type="button"
            onClick={() => onMove(1)}
            disabled={index >= total - 1}
            title="下移"
            aria-label="下移插件"
            className="flex size-6 items-center justify-center rounded text-faint outline-none transition hover:bg-panel-2 hover:text-ink disabled:opacity-30 focus-visible:ring-2 focus-visible:ring-accent/35"
          >
            <ChevronDown size={13} />
          </button>

          <button
            type="button"
            role="switch"
            aria-checked={config.enabled}
            aria-label={config.enabled ? '禁用插件' : '启用插件'}
            onClick={() => onToggle(!config.enabled)}
            className={cn(
              'relative ml-1 h-[20px] w-[34px] rounded-full p-[2px] outline-none transition-colors focus-visible:ring-2 focus-visible:ring-accent/35',
              config.enabled ? 'bg-accent' : 'bg-line-strong'
            )}
          >
            <span
              className={cn(
                'block size-4 rounded-full bg-white shadow-sm transition-transform',
                config.enabled ? 'translate-x-[14px]' : 'translate-x-0'
              )}
            />
          </button>

          <Button
            size="sm"
            variant="ghost"
            icon={<ChevronDown size={12} className={cn('transition-transform', expanded && 'rotate-180')} />}
            onClick={() => setExpanded((value) => !value)}
          >
            配置
          </Button>
        </div>
      </div>

      {expanded ? (
        <div className="border-t border-line/80 px-3.5 py-3">
          <div className="mb-2 flex items-start gap-1.5 text-[10.5px] leading-4 text-faint">
            <Info size={12} className="mt-0.5 shrink-0" />
            <span>{definition.configHint}</span>
          </div>
          <textarea
            value={text}
            onChange={(event) => handleChange(event.target.value)}
            spellCheck={false}
            className={cn(
              'min-h-[128px] w-full resize-y rounded-lg border bg-panel px-3 py-2 font-mono text-[11.5px] leading-5 text-ink outline-none transition',
              error
                ? 'border-danger/60 focus:ring-2 focus:ring-danger/15'
                : 'border-line focus:border-accent/50 focus:ring-2 focus:ring-accent/10'
            )}
          />
          {error ? (
            <p className="mt-1.5 text-[10.5px] text-danger">{error}</p>
          ) : (
            <p className="mt-1.5 text-[10.5px] text-faint">
              配置支持 {'{{变量}}'}，有效 JSON 会立即保存到当前请求。
            </p>
          )}
        </div>
      ) : null}
    </div>
  )
}

function SettingsPanel() {
  const draft = useAppStore((state) => state.workspace.draft)
  const updateDraft = useAppStore((state) => state.updateDraft)
  const settings = draft.settings

  return (
    <div className="mx-auto max-w-3xl">
      <div className="mb-4">
        <h3 className="text-[12px] font-semibold text-ink">请求设置</h3>
        <p className="mt-1 text-[11px] leading-5 text-muted">
          控制超时、TLS 校验与代理。设置随当前请求一起保存。
        </p>
      </div>

      <div className="space-y-4 rounded-xl border border-line bg-panel-2/25 p-4">
        <div className="grid grid-cols-[1fr_220px] items-start gap-4">
          <div>
            <div className="text-[12px] font-medium text-ink">超时时间</div>
            <p className="mt-1 text-[10.5px] leading-4 text-muted">
              发起请求后等待响应的最长时间，范围 1 到 300 秒。
            </p>
          </div>
          <div className="relative">
            <input
              type="number"
              min={1000}
              max={300000}
              step={1000}
              value={settings.timeoutMs}
              onChange={(event) =>
                updateDraft({
                  settings: { ...settings, timeoutMs: Number(event.target.value) || 0 }
                })
              }
              onBlur={() =>
                updateDraft({
                  settings: {
                    ...settings,
                    timeoutMs: Math.min(Math.max(settings.timeoutMs || 30_000, 1000), 300_000)
                  }
                })
              }
              className={cn(inputClass, 'pr-12 font-mono')}
            />
            <span className="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 text-[10px] text-faint">
              ms
            </span>
          </div>
        </div>

        <div className="h-px bg-line" />

        <div className="flex items-start justify-between gap-4">
          <div>
            <div className="text-[12px] font-medium text-ink">校验 HTTPS 证书</div>
            <p className="mt-1 text-[10.5px] leading-4 text-muted">
              关闭后允许自签名证书。仅建议在测试环境使用，会降低连接安全性。
            </p>
          </div>
          <button
            type="button"
            role="switch"
            aria-checked={settings.rejectUnauthorized}
            onClick={() =>
              updateDraft({
                settings: {
                  ...settings,
                  rejectUnauthorized: !settings.rejectUnauthorized
                }
              })
            }
            className={cn(
              'relative mt-1 h-[20px] w-[34px] shrink-0 rounded-full p-[2px] outline-none transition-colors focus-visible:ring-2 focus-visible:ring-accent/35',
              settings.rejectUnauthorized ? 'bg-accent' : 'bg-line-strong'
            )}
          >
            <span
              className={cn(
                'block size-4 rounded-full bg-white shadow-sm transition-transform',
                settings.rejectUnauthorized ? 'translate-x-[14px]' : 'translate-x-0'
              )}
            />
          </button>
        </div>

        <div className="h-px bg-line" />

        <div>
          <div className="text-[12px] font-medium text-ink">HTTP 代理</div>
          <p className="mt-1 text-[10.5px] leading-4 text-muted">
            可选。支持 http:// 或 https:// 代理，留空表示直连。
          </p>
          <input
            value={settings.proxyUrl}
            onChange={(event) =>
              updateDraft({ settings: { ...settings, proxyUrl: event.target.value } })
            }
            placeholder="http://127.0.0.1:7890"
            spellCheck={false}
            className={cn(inputClass, 'mt-2 font-mono text-[11.5px]')}
          />
        </div>
      </div>

      <div className="mt-3 flex items-start gap-2 rounded-lg border border-line bg-panel-2/25 px-3 py-2.5 text-[10.5px] leading-4 text-faint">
        <Info size={13} className="mt-0.5 shrink-0" />
        <span>
          请求由 Electron 主进程发送，不经过浏览器同源策略；仅支持 http/https，响应体最多读取 15 MB。
        </span>
      </div>
    </div>
  )
}
