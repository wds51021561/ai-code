import {
  Agent,
  FormData as UndiciFormData,
  ProxyAgent,
  fetch,
  type BodyInit,
  type Dispatcher
} from 'undici'
import type {
  RequestConfig,
  SendPayload,
  SendResult,
  SentRequestSnapshot
} from '@shared/types'
import { getHeader, deleteHeader, setHeader } from './headers'
import { hasUnresolvedVariables, interpolateString, interpolateUnknown } from './interpolate'
import {
  PLUGIN_IMPLEMENTATIONS,
  type RequestPluginContext,
  type ResponsePluginContext
} from './plugins'

const MAX_RESPONSE_BYTES = 15 * 1024 * 1024
const MAX_PREVIEW_CHARS = 20_000

interface PreparedRequest {
  context: RequestPluginContext
  formData?: UndiciFormData
  timeoutMs: number
  rejectUnauthorized: boolean
  proxyUrl: string
}

function positiveNumber(value: unknown, fallback: number): number {
  const parsed = typeof value === 'number' ? value : Number(value)
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback
}

function describeError(error: unknown): string {
  if (error instanceof Error) {
    const cause = (error as Error & { cause?: unknown }).cause
    if (cause instanceof Error && cause.message) {
      return `${error.message}（${cause.message}）`
    }
    return error.message
  }
  return String(error)
}

function truncate(value: string, max = MAX_PREVIEW_CHARS): string {
  if (value.length <= max) return value
  return `${value.slice(0, max)}\n\n…（已截断，共 ${value.length} 字符）`
}

function enabledRows(rows: RequestConfig['headers']): Array<{ key: string; value: string }> {
  return rows
    .filter((row) => row.enabled && row.key.trim())
    .map((row) => ({ key: row.key, value: row.value }))
}

function applyAuth(
  request: RequestConfig,
  variables: Record<string, string>,
  url: URL,
  headers: Record<string, string>,
  log: string[]
): void {
  const auth = request.auth
  if (auth.type === 'none') return

  if (auth.type === 'bearer') {
    const token = interpolateString(auth.token, variables).trim()
    if (!token) throw new Error('Bearer Token 为空')
    setHeader(headers, 'Authorization', `Bearer ${token}`)
    log.push('认证：Bearer Token 已应用')
    return
  }

  if (auth.type === 'basic') {
    const username = interpolateString(auth.username, variables)
    const password = interpolateString(auth.password, variables)
    const encoded = Buffer.from(`${username}:${password}`, 'utf8').toString('base64')
    setHeader(headers, 'Authorization', `Basic ${encoded}`)
    log.push('认证：Basic Auth 已应用')
    return
  }

  const key = interpolateString(auth.key, variables).trim()
  const value = interpolateString(auth.value, variables)
  if (!key) throw new Error('API Key 的 key 不能为空')
  if (auth.addTo === 'query') {
    url.searchParams.set(key, value)
    log.push('认证：API Key 已写入查询参数')
  } else {
    setHeader(headers, key, value)
    log.push(`认证：API Key 已写入请求头 ${key}`)
  }
}

function prepareRequest(
  request: RequestConfig,
  variables: Record<string, string>
): PreparedRequest {
  const rawUrl = interpolateString(request.url, variables).trim()
  if (!rawUrl) throw new Error('请输入请求 URL')
  if (hasUnresolvedVariables(rawUrl)) {
    throw new Error('URL 中存在未解析变量，请检查当前环境配置')
  }

  let url: URL
  try {
    url = new URL(rawUrl)
  } catch {
    throw new Error('URL 格式不正确，请包含 http:// 或 https://')
  }
  if (url.protocol !== 'http:' && url.protocol !== 'https:') {
    throw new Error('仅支持 http:// 和 https:// 协议')
  }

  for (const param of enabledRows(request.params)) {
    url.searchParams.append(
      interpolateString(param.key, variables).trim(),
      interpolateString(param.value, variables)
    )
  }

  const headers: Record<string, string> = {}
  for (const header of enabledRows(request.headers)) {
    setHeader(
      headers,
      interpolateString(header.key, variables).trim(),
      interpolateString(header.value, variables)
    )
  }

  const pluginLog: string[] = []
  let bodyText: string | undefined
  let bodyKind: 'none' | 'text' | 'form-data' = 'none'
  let formData: UndiciFormData | undefined

  switch (request.body.mode) {
    case 'json': {
      bodyText = interpolateString(request.body.raw, variables)
      bodyKind = 'text'
      if (!getHeader(headers, 'Content-Type')) {
        setHeader(headers, 'Content-Type', 'application/json; charset=utf-8')
      }
      break
    }
    case 'text': {
      bodyText = interpolateString(request.body.raw, variables)
      bodyKind = 'text'
      if (!getHeader(headers, 'Content-Type')) {
        setHeader(headers, 'Content-Type', 'text/plain; charset=utf-8')
      }
      break
    }
    case 'form-urlencoded': {
      const params = new URLSearchParams()
      for (const row of enabledRows(request.body.form)) {
        params.append(
          interpolateString(row.key, variables).trim(),
          interpolateString(row.value, variables)
        )
      }
      bodyText = params.toString()
      bodyKind = 'text'
      if (!getHeader(headers, 'Content-Type')) {
        setHeader(headers, 'Content-Type', 'application/x-www-form-urlencoded; charset=utf-8')
      }
      break
    }
    case 'form-data': {
      formData = new UndiciFormData()
      for (const row of enabledRows(request.body.form)) {
        formData.append(
          interpolateString(row.key, variables).trim(),
          interpolateString(row.value, variables)
        )
      }
      bodyKind = 'form-data'
      deleteHeader(headers, 'Content-Type')
      break
    }
    default:
      break
  }

  applyAuth(request, variables, url, headers, pluginLog)

  const context: RequestPluginContext = {
    method: request.method,
    url,
    headers,
    bodyText,
    bodyKind,
    pluginLog
  }

  for (const pluginConfig of request.plugins) {
    if (!pluginConfig.enabled) continue
    const implementation = PLUGIN_IMPLEMENTATIONS[pluginConfig.id]
    if (!implementation) {
      throw new Error(`未知的请求插件：${pluginConfig.id}`)
    }
    const config = interpolateUnknown(pluginConfig.config, variables)
    implementation.beforeSend?.(
      context,
      config && typeof config === 'object' ? (config as Record<string, unknown>) : {}
    )
  }

  if ((context.method === 'GET' || context.method === 'HEAD') && context.bodyKind !== 'none') {
    throw new Error('GET/HEAD 请求不支持请求体，请将 Body 设为 none 或移除请求体加密插件')
  }

  return {
    context,
    formData,
    timeoutMs: Math.min(
      Math.max(positiveNumber(request.settings.timeoutMs, 30_000), 1000),
      300_000
    ),
    rejectUnauthorized: request.settings.rejectUnauthorized !== false,
    proxyUrl: interpolateString(request.settings.proxyUrl, variables).trim()
  }
}

function createDispatcher(prepared: PreparedRequest): Dispatcher {
  const connect = { rejectUnauthorized: prepared.rejectUnauthorized }
  if (!prepared.proxyUrl) {
    return new Agent({ connect })
  }
  const proxyUrl = new URL(prepared.proxyUrl)
  if (proxyUrl.protocol !== 'http:' && proxyUrl.protocol !== 'https:') {
    throw new Error('代理地址仅支持 http:// 或 https://')
  }
  return new ProxyAgent({
    uri: proxyUrl.toString(),
    requestTls: connect,
    proxyTls: connect
  })
}

function makeSnapshot(prepared: PreparedRequest): SentRequestSnapshot {
  const context = prepared.context
  const body =
    context.bodyKind === 'none'
      ? null
      : context.bodyKind === 'form-data'
        ? '[multipart/form-data]'
        : truncate(context.bodyText ?? '')

  return {
    method: context.method,
    url: context.url.toString(),
    headers: Object.entries(context.headers),
    body
  }
}

function errorResult(
  request: RequestConfig,
  prepared: PreparedRequest | null,
  message: string,
  duration: number,
  status = 0,
  statusText = '',
  headers: Array<[string, string]> = [],
  body = '',
  contentType = '',
  size = 0,
  truncated = false
): SendResult {
  const snapshot: SentRequestSnapshot = prepared
    ? makeSnapshot(prepared)
    : {
        method: request.method,
        url: request.url,
        headers: [],
        body: null
      }

  return {
    ok: false,
    status,
    statusText,
    headers,
    body,
    contentType,
    size,
    duration,
    truncated,
    error: message,
    finalUrl: prepared?.context.url.toString() ?? request.url,
    request: snapshot,
    pluginLog: prepared?.context.pluginLog ?? []
  }
}

function isTextualContentType(contentType: string): boolean {
  if (!contentType) return true
  const normalized = contentType.toLowerCase()
  return (
    normalized.startsWith('text/') ||
    normalized.includes('json') ||
    normalized.includes('xml') ||
    normalized.includes('javascript') ||
    normalized.includes('x-www-form-urlencoded') ||
    normalized.includes('graphql') ||
    normalized.includes('yaml') ||
    normalized.includes('csv') ||
    normalized.includes('svg')
  )
}

async function readResponseBody(
  response: Response
): Promise<{ buffer: Buffer; size: number; truncated: boolean }> {
  if (!response.body) {
    return { buffer: Buffer.alloc(0), size: 0, truncated: false }
  }

  const reader = response.body.getReader()
  const chunks: Buffer[] = []
  let size = 0
  let truncated = false

  for (;;) {
    const { done, value } = await reader.read()
    if (done) break
    if (!value) continue

    const remaining = MAX_RESPONSE_BYTES - size
    if (value.byteLength > remaining) {
      chunks.push(Buffer.from(value.subarray(0, remaining)))
      size = MAX_RESPONSE_BYTES
      truncated = true
      void reader.cancel()
      break
    }
    chunks.push(Buffer.from(value))
    size += value.byteLength
  }

  return {
    buffer: Buffer.concat(chunks, size),
    size,
    truncated
  }
}

async function sendPrepared(
  payload: SendPayload,
  prepared: PreparedRequest,
  externalSignal: AbortSignal,
  startedAt: number
): Promise<SendResult> {
  const { context } = prepared
  let dispatcher: Dispatcher | null = null
  let timedOut = false
  const controller = new AbortController()
  const onExternalAbort = (): void => controller.abort()
  const timer = setTimeout(() => {
    timedOut = true
    controller.abort()
  }, prepared.timeoutMs)

  if (externalSignal.aborted) {
    controller.abort()
  } else {
    externalSignal.addEventListener('abort', onExternalAbort, { once: true })
  }

  try {
    dispatcher = createDispatcher(prepared)

    let body: BodyInit | undefined
    if (context.bodyKind === 'form-data') {
      body = prepared.formData
    } else if (context.bodyKind === 'text') {
      body = context.bodyText ?? ''
    }

    const response = await fetch(context.url, {
      method: context.method,
      headers: context.headers,
      body,
      dispatcher,
      redirect: 'follow',
      signal: controller.signal
    })

    const headerEntries = Array.from(response.headers.entries())
    const contentType = response.headers.get('content-type') ?? ''
    const declaredLength = Number(response.headers.get('content-length') ?? 0)
    const { buffer, size, truncated } = await readResponseBody(response)

    let responseBody: string
    if (isTextualContentType(contentType) || size === 0) {
      responseBody = buffer.toString('utf8')
    } else {
      responseBody = `[二进制响应，${size} 字节，当前版本暂不支持预览]`
    }

    let pluginError: string | undefined
    const responseContext: ResponsePluginContext = {
      request: context,
      responseBody,
      status: response.status
    }

    for (const pluginConfig of [...payload.request.plugins].reverse()) {
      if (!pluginConfig.enabled) continue
      const implementation = PLUGIN_IMPLEMENTATIONS[pluginConfig.id]
      if (!implementation?.afterResponse) continue
      try {
        const config = interpolateUnknown(pluginConfig.config, payload.variables)
        responseContext.responseBody = implementation.afterResponse(
          responseContext,
          config && typeof config === 'object' ? (config as Record<string, unknown>) : {}
        )
      } catch (error) {
        pluginError = describeError(error)
        context.pluginLog.push(`响应插件失败：${pluginConfig.id}`)
        break
      }
    }

    return {
      ok: response.ok && !pluginError,
      status: response.status,
      statusText: response.statusText,
      headers: headerEntries,
      body: responseContext.responseBody,
      contentType,
      size,
      duration: performance.now() - startedAt,
      truncated: truncated || (declaredLength > MAX_RESPONSE_BYTES && size >= MAX_RESPONSE_BYTES),
      error: pluginError,
      finalUrl: response.url || context.url.toString(),
      request: makeSnapshot(prepared),
      pluginLog: context.pluginLog
    }
  } catch (error) {
    const message = externalSignal.aborted
      ? '请求已取消'
      : timedOut
        ? `请求超时（${Math.round(prepared.timeoutMs / 1000)} 秒），可在“设置”中调整超时时间`
        : describeError(error)
    return errorResult(
      payload.request,
      prepared,
      message,
      performance.now() - startedAt
    )
  } finally {
    clearTimeout(timer)
    externalSignal.removeEventListener('abort', onExternalAbort)
    if (dispatcher) {
      void dispatcher.close().catch(() => undefined)
    }
  }
}

export async function executeRequest(
  payload: SendPayload,
  signal: AbortSignal
): Promise<SendResult> {
  const startedAt = performance.now()
  let prepared: PreparedRequest | null = null
  try {
    prepared = prepareRequest(payload.request, payload.variables)
    return await sendPrepared(payload, prepared, signal, startedAt)
  } catch (error) {
    return errorResult(
      payload.request,
      prepared,
      describeError(error),
      performance.now() - startedAt
    )
  }
}
