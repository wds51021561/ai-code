import type { HttpMethod, KeyValueItem, RequestConfig, Workspace } from '@shared/types'
import { makeId } from '@shared/defaults'

export function cn(...parts: Array<string | false | null | undefined>): string {
  return parts.filter(Boolean).join(' ')
}

export function formatBytes(bytes: number): string {
  if (!Number.isFinite(bytes) || bytes <= 0) return '0 B'
  const units = ['B', 'KB', 'MB', 'GB']
  const index = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1)
  const value = bytes / 1024 ** index
  return `${value >= 100 || index === 0 ? value.toFixed(0) : value.toFixed(1)} ${units[index]}`
}

export function formatDuration(milliseconds: number): string {
  if (!Number.isFinite(milliseconds)) return '-'
  if (milliseconds < 1000) return `${Math.round(milliseconds)} ms`
  return `${(milliseconds / 1000).toFixed(2)} s`
}

export function formatRelativeTime(timestamp: number): string {
  const delta = Date.now() - timestamp
  if (delta < 60_000) return '刚刚'
  if (delta < 3_600_000) return `${Math.floor(delta / 60_000)} 分钟前`
  if (delta < 86_400_000) return `${Math.floor(delta / 3_600_000)} 小时前`
  if (delta < 172_800_000) return '昨天'
  return new Intl.DateTimeFormat('zh-CN', {
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit'
  }).format(new Date(timestamp))
}

export function methodColorVar(method: HttpMethod): string {
  const map: Record<HttpMethod, string> = {
    GET: 'var(--method-get)',
    POST: 'var(--method-post)',
    PUT: 'var(--method-put)',
    PATCH: 'var(--method-patch)',
    DELETE: 'var(--method-delete)',
    HEAD: 'var(--method-other)',
    OPTIONS: 'var(--method-other)'
  }
  return map[method]
}

export function statusColorVar(status: number): string {
  if (!status) return 'var(--danger)'
  if (status < 300) return 'var(--success)'
  if (status < 400) return 'var(--warning)'
  if (status < 500) return 'var(--warning)'
  return 'var(--danger)'
}

export function prettyJson(raw: string): { text: string; isJson: boolean } {
  const value = raw.trim()
  if (!value) return { text: '', isJson: false }
  try {
    const parsed: unknown = JSON.parse(value)
    return { text: JSON.stringify(parsed, null, 2), isJson: true }
  } catch {
    return { text: raw, isJson: false }
  }
}

export function requestDisplayUrl(request: RequestConfig): string {
  return request.url || '未填写 URL'
}

export function suggestedRequestName(request: RequestConfig): string {
  try {
    let safeUrl = request.url.replace(/\{\{[^{}]+\}\}/g, 'variable')
    if (!/^[a-z][a-z\d+.-]*:\/\//i.test(safeUrl)) {
      safeUrl = `https://${safeUrl.replace(/^\/+/, '')}`
    }
    const url = new URL(safeUrl)
    const segments = url.pathname.split('/').filter(Boolean)
    const last = segments.at(-1)
    if (last && /^\d+$/.test(last) && segments.length > 1) {
      return `${segments.at(-2)}/${last}`
    }
    return last ? decodeURIComponent(last) : url.hostname
  } catch {
    return request.url.trim() || `${request.method} 请求`
  }
}

export function extractUrlQuery(url: string): { url: string; params: KeyValueItem[] } | null {
  const questionIndex = url.indexOf('?')
  if (questionIndex < 0) return null

  const hashIndex = url.indexOf('#')
  const queryEnd = hashIndex > questionIndex ? hashIndex : url.length
  const query = url.slice(questionIndex + 1, queryEnd)
  if (!query) return null

  const search = new URLSearchParams(query)
  if (Array.from(search.keys()).length === 0) return null

  return {
    url: url.slice(0, questionIndex) + (hashIndex > questionIndex ? url.slice(hashIndex) : ''),
    params: Array.from(search.entries()).map(([key, value]) => ({
      id: makeId('kv'),
      enabled: true,
      key,
      value
    }))
  }
}

export function resolveVariables(workspace: Workspace): Record<string, string> {
  const variables: Record<string, string> = {}
  for (const variable of workspace.globalVariables) {
    if (variable.enabled && variable.key.trim()) {
      variables[variable.key.trim()] = variable.value
    }
  }
  const environment = workspace.environments.find((item) => item.id === workspace.activeEnvId)
  if (environment) {
    for (const variable of environment.variables) {
      if (variable.enabled && variable.key.trim()) {
        variables[variable.key.trim()] = variable.value
      }
    }
  }
  return variables
}

export async function copyText(text: string): Promise<void> {
  try {
    await navigator.clipboard.writeText(text)
    return
  } catch {
    const textarea = document.createElement('textarea')
    textarea.value = text
    textarea.style.position = 'fixed'
    textarea.style.opacity = '0'
    document.body.appendChild(textarea)
    textarea.select()
    document.execCommand('copy')
    textarea.remove()
  }
}
