import {
  AlertTriangle,
  Braces,
  CheckCircle2,
  Clipboard,
  FileText,
  Loader2,
  Radio,
  Sparkles
} from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
import { toast } from 'sonner'
import { Button } from '../../components/Button'
import { CodeEditor } from '../../components/CodeEditor'
import { StatusBadge } from '../../components/Badge'
import { UnderlineTabs, type TabItem } from '../../components/Tabs'
import { cn, copyText, formatBytes, formatDuration, prettyJson } from '../../lib/utils'
import { useAppStore } from '../../store/useAppStore'

type ResponseTab = 'body' | 'headers' | 'request'

export function ResponsePanel() {
  const response = useAppStore((state) => state.response)
  const sending = useAppStore((state) => state.sending)
  const [tab, setTab] = useState<ResponseTab>('body')
  const [formatted, setFormatted] = useState(true)

  useEffect(() => {
    setTab('body')
    setFormatted(true)
  }, [response])

  const pretty = useMemo(() => prettyJson(response?.body ?? ''), [response?.body])
  const tabs: Array<TabItem<ResponseTab>> = [
    { id: 'body', label: '响应体' },
    { id: 'headers', label: '响应头', count: response?.headers.length ?? 0 },
    { id: 'request', label: '请求详情' }
  ]

  const copyResponse = async (): Promise<void> => {
    if (!response) return
    await copyText(response.body)
    toast.success('响应体已复制')
  }

  return (
    <div className="flex h-full min-h-0 flex-col bg-panel">
      <div className="flex h-11 shrink-0 items-center gap-3 border-b border-line px-4">
        <span className="text-[11px] font-semibold uppercase tracking-wider text-faint">响应</span>

        {sending ? (
          <span className="inline-flex items-center gap-1.5 text-[11px] text-muted">
            <Loader2 size={12} className="animate-spin text-accent" />
            请求中
          </span>
        ) : response ? (
          <>
            <StatusBadge status={response.status} />
            {response.statusText ? (
              <span className="text-[11px] text-muted">{response.statusText}</span>
            ) : null}
            <span className="text-line-strong">·</span>
            <span className="font-mono text-[10.5px] text-muted">
              {formatDuration(response.duration)}
            </span>
            <span className="text-line-strong">·</span>
            <span className="font-mono text-[10.5px] text-muted">
              {formatBytes(response.size)}
            </span>
            {response.truncated ? (
              <span className="rounded bg-warning/10 px-1.5 py-0.5 text-[9.5px] text-warning">
                已截断
              </span>
            ) : null}
          </>
        ) : (
          <span className="text-[11px] text-faint">尚未发送请求</span>
        )}

        <div className="ml-auto flex items-center gap-1">
          {response && pretty.isJson ? (
            <Button
              size="sm"
              variant="ghost"
              icon={formatted ? <FileText size={13} /> : <Braces size={13} />}
              onClick={() => setFormatted((value) => !value)}
            >
              {formatted ? '原始' : '格式化'}
            </Button>
          ) : null}
          <Button
            size="sm"
            variant="ghost"
            icon={<Clipboard size={13} />}
            disabled={!response}
            onClick={copyResponse}
          >
            复制
          </Button>
        </div>
      </div>

      {response || sending ? (
        <UnderlineTabs
          items={tabs}
          value={tab}
          onChange={setTab}
          size="sm"
          className="shrink-0"
        />
      ) : null}

      <div className="min-h-0 flex-1">
        {sending ? (
          <div className="flex h-full flex-col items-center justify-center text-center">
            <div className="mb-4 flex size-11 items-center justify-center rounded-xl border border-line bg-panel-2">
              <Loader2 size={19} className="animate-spin text-accent" />
            </div>
            <div className="text-[12px] font-medium text-muted">正在等待响应</div>
            <p className="mt-1 text-[10.5px] text-faint">可以在请求栏点击「取消」中止请求</p>
          </div>
        ) : !response ? (
          <div className="flex h-full flex-col items-center justify-center px-6 text-center">
            <div className="mb-4 flex size-12 items-center justify-center rounded-2xl border border-line bg-panel-2 text-faint">
              <Radio size={22} />
            </div>
            <div className="text-[12.5px] font-medium text-muted">发送请求后查看响应</div>
            <p className="mt-1.5 max-w-[320px] text-[10.5px] leading-5 text-faint">
              状态码、耗时、响应头与格式化后的响应体会显示在这里。按 Ctrl + Enter 快速发送。
            </p>
          </div>
        ) : (
          <>
            {response.error && response.status > 0 ? (
              <div className="flex items-start gap-2 border-b border-warning/20 bg-warning/10 px-4 py-2 text-[10.5px] leading-4 text-warning">
                <AlertTriangle size={13} className="mt-0.5 shrink-0" />
                <span>{response.error}</span>
              </div>
            ) : null}

            {tab === 'body' ? (
              response.status === 0 && response.error ? (
                <RequestError message={response.error} url={response.finalUrl ?? ''} />
              ) : (
                <div className="flex h-full min-h-0 flex-col">
                  <div className="flex h-8 shrink-0 items-center gap-2 border-b border-line px-3">
                    <span className="max-w-[60%] truncate font-mono text-[10px] text-faint">
                      {response.contentType || 'unknown content type'}
                    </span>
                    <span className="text-line-strong">·</span>
                    <span className="font-mono text-[10px] text-faint">
                      {response.body.length.toLocaleString()} 字符
                    </span>
                    {pretty.isJson ? (
                      <span className="ml-1 inline-flex items-center gap-1 rounded bg-success/10 px-1.5 py-0.5 text-[9px] text-success">
                        <CheckCircle2 size={9} />
                        JSON
                      </span>
                    ) : null}
                  </div>
                  {response.body ? (
                    <div className="min-h-0 flex-1">
                      <CodeEditor
                        value={formatted && pretty.isJson ? pretty.text : response.body}
                        language={pretty.isJson ? 'json' : 'text'}
                        readOnly
                      />
                    </div>
                  ) : (
                    <div className="flex flex-1 flex-col items-center justify-center text-center">
                      <div className="text-[12px] font-medium text-muted">响应体为空</div>
                      <p className="mt-1 text-[10.5px] text-faint">
                        HTTP {response.status} 没有返回内容
                      </p>
                    </div>
                  )}
                </div>
              )
            ) : null}

            {tab === 'headers' ? (
              <ValueTable
                rows={response.headers}
                emptyText="没有响应头"
                firstColumn="响应头"
              />
            ) : null}

            {tab === 'request' ? (
              <div className="h-full overflow-auto p-4">
                <div className="mb-4 rounded-xl border border-line bg-panel-2/25 p-3">
                  <div className="mb-1 text-[10px] font-semibold uppercase tracking-wider text-faint">
                    实际请求
                  </div>
                  <div className="break-all font-mono text-[11.5px] leading-5 text-ink">
                    <span className="mr-2 font-bold text-accent">{response.request.method}</span>
                    {response.finalUrl ?? response.request.url}
                  </div>
                </div>

                {response.pluginLog.length ? (
                  <div className="mb-4 rounded-xl border border-accent/20 bg-accent-soft/40 p-3">
                    <div className="mb-2 flex items-center gap-1.5 text-[10px] font-semibold uppercase tracking-wider text-accent">
                      <Sparkles size={11} />
                      扩展执行日志
                    </div>
                    <div className="space-y-1">
                      {response.pluginLog.map((item, index) => (
                        <div
                          key={`${item}-${index}`}
                          className="flex items-start gap-2 text-[10.5px] leading-4 text-muted"
                        >
                          <span className="mt-1.5 size-1 shrink-0 rounded-full bg-accent" />
                          {item}
                        </div>
                      ))}
                    </div>
                  </div>
                ) : null}

                <div className="mb-2 text-[10px] font-semibold uppercase tracking-wider text-faint">
                  请求头
                </div>
                <div className="mb-4 overflow-hidden rounded-xl border border-line">
                  <ValueTable
                    rows={response.request.headers}
                    emptyText="没有请求头"
                    firstColumn="请求头"
                    embedded
                  />
                </div>

                <div className="mb-2 text-[10px] font-semibold uppercase tracking-wider text-faint">
                  请求体
                </div>
                <div className="rounded-xl border border-line bg-panel-2/25 p-3">
                  {response.request.body ? (
                    <pre className="max-h-64 overflow-auto whitespace-pre-wrap break-all font-mono text-[11px] leading-5 text-ink">
                      {response.request.body}
                    </pre>
                  ) : (
                    <div className="text-[11px] text-faint">无请求体</div>
                  )}
                </div>
              </div>
            ) : null}
          </>
        )}
      </div>
    </div>
  )
}

function RequestError({ message, url }: { message: string; url: string }) {
  return (
    <div className="flex h-full flex-col items-center justify-center px-8 text-center">
      <div className="mb-4 flex size-12 items-center justify-center rounded-2xl border border-danger/20 bg-danger/10 text-danger">
        <AlertTriangle size={22} />
      </div>
      <div className="text-[12.5px] font-medium text-danger">请求失败</div>
      <p className="mt-2 max-w-lg break-words text-[11px] leading-5 text-muted">{message}</p>
      {url ? (
        <p className="mt-2 max-w-lg break-all font-mono text-[10px] text-faint">{url}</p>
      ) : null}
      <p className="mt-4 max-w-md text-[10.5px] leading-5 text-faint">
        请检查 URL、网络连接、代理设置和 HTTPS 证书选项。若请求被取消，也会显示在这里。
      </p>
    </div>
  )
}

function ValueTable({
  rows,
  emptyText,
  firstColumn,
  embedded = false
}: {
  rows: Array<[string, string]>
  emptyText: string
  firstColumn: string
  embedded?: boolean
}) {
  if (!rows.length) {
    return (
      <div className="flex h-full items-center justify-center p-6 text-[11px] text-faint">
        {emptyText}
      </div>
    )
  }

  return (
    <div className={cn('h-full overflow-auto', embedded ? '' : 'p-4')}>
      <div
        className={cn(
          'overflow-hidden rounded-xl border border-line',
          embedded && 'rounded-none border-0'
        )}
      >
        <div className="grid grid-cols-[230px_1fr] border-b border-line bg-panel-2/50 text-[10px] font-semibold uppercase tracking-wider text-faint">
          <div className="border-r border-line px-3 py-2">{firstColumn}</div>
          <div className="px-3 py-2">值</div>
        </div>
        {rows.map(([key, value], index) => (
          <div
            key={`${key}-${index}`}
            className="grid grid-cols-[230px_1fr] border-b border-line/70 last:border-b-0 hover:bg-panel-2/30"
          >
            <div className="break-all border-r border-line px-3 py-2 font-mono text-[10.5px] text-muted">
              {key}
            </div>
            <div className="break-all px-3 py-2 font-mono text-[10.5px] text-ink">{value}</div>
          </div>
        ))}
      </div>
    </div>
  )
}
