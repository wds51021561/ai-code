import {
  createCipheriv,
  createDecipheriv,
  createHash,
  createHmac,
  randomBytes,
  randomUUID
} from 'node:crypto'
import type { HttpMethod } from '@shared/types'
import { setHeader } from './headers'
import { hasUnresolvedVariables } from './interpolate'

export interface RequestPluginContext {
  method: HttpMethod
  url: URL
  headers: Record<string, string>
  bodyText?: string
  bodyKind: 'none' | 'text' | 'form-data'
  pluginLog: string[]
}

export interface ResponsePluginContext {
  request: RequestPluginContext
  responseBody: string
  status: number
}

export interface RequestPlugin {
  id: string
  beforeSend?: (context: RequestPluginContext, config: Record<string, unknown>) => void
  afterResponse?: (context: ResponsePluginContext, config: Record<string, unknown>) => string
}

function readString(config: Record<string, unknown>, key: string): string {
  const value = config[key]
  return typeof value === 'string' ? value.trim() : ''
}

function readBoolean(config: Record<string, unknown>, key: string, fallback: boolean): boolean {
  const value = config[key]
  if (typeof value === 'boolean') return value
  if (value === 'true') return true
  if (value === 'false') return false
  return fallback
}

function requireSecret(config: Record<string, unknown>, pluginName: string): string {
  const secret = readString(config, 'secret')
  if (!secret) {
    throw new Error(`${pluginName}：请填写 secret`)
  }
  if (hasUnresolvedVariables(secret)) {
    throw new Error(`${pluginName}：secret 中存在未解析的环境变量`)
  }
  return secret
}

function deriveKey(secret: string): Buffer {
  return createHash('sha256').update(secret, 'utf8').digest()
}

interface AesEnvelope {
  alg: 'AES-256-GCM'
  iv: string
  tag: string
  data: string
}

function encryptAesGcm(plaintext: string, secret: string): AesEnvelope {
  const iv = randomBytes(12)
  const cipher = createCipheriv('aes-256-gcm', deriveKey(secret), iv)
  const encrypted = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()])
  return {
    alg: 'AES-256-GCM',
    iv: iv.toString('base64'),
    tag: cipher.getAuthTag().toString('base64'),
    data: encrypted.toString('base64')
  }
}

function decryptAesGcm(envelope: AesEnvelope, secret: string): string {
  const decipher = createDecipheriv(
    'aes-256-gcm',
    deriveKey(secret),
    Buffer.from(envelope.iv, 'base64')
  )
  decipher.setAuthTag(Buffer.from(envelope.tag, 'base64'))
  return Buffer.concat([
    decipher.update(Buffer.from(envelope.data, 'base64')),
    decipher.final()
  ]).toString('utf8')
}

function isAesEnvelope(value: unknown): value is AesEnvelope {
  if (!value || typeof value !== 'object') return false
  const item = value as Record<string, unknown>
  return (
    typeof item.iv === 'string' &&
    typeof item.tag === 'string' &&
    typeof item.data === 'string'
  )
}

const hmacSha256Plugin: RequestPlugin = {
  id: 'hmac-sha256',
  beforeSend(context, config) {
    const secret = requireSecret(config, 'HMAC-SHA256')
    const header = readString(config, 'header') || 'X-Signature'
    const timestampHeader = readString(config, 'timestampHeader') || 'X-Timestamp'
    const nonceHeader = readString(config, 'nonceHeader') || 'X-Nonce'
    const includeQuery = readBoolean(config, 'includeQuery', true)
    const includeBody = readBoolean(config, 'includeBody', true)
    const encoding = readString(config, 'encoding') === 'base64' ? 'base64' : 'hex'
    const prefix = readString(config, 'prefix')

    const timestamp = Date.now().toString()
    const nonce = randomUUID().replaceAll('-', '')
    const path = `${context.url.pathname}${includeQuery ? context.url.search : ''}`
    const canonical = [
      context.method.toUpperCase(),
      path,
      timestamp,
      nonce,
      includeBody ? (context.bodyText ?? '') : ''
    ].join('\n')
    const signature = createHmac('sha256', secret).update(canonical, 'utf8').digest(encoding)

    setHeader(context.headers, timestampHeader, timestamp)
    setHeader(context.headers, nonceHeader, nonce)
    setHeader(context.headers, header, `${prefix}${signature}`)
    context.pluginLog.push(`HMAC-SHA256：签名头 ${header} 已写入`)
  }
}

const aesGcmPlugin: RequestPlugin = {
  id: 'aes-256-gcm',
  beforeSend(context, config) {
    const secret = requireSecret(config, 'AES-256-GCM')
    const shouldEncrypt = readBoolean(config, 'encryptRequest', true)
    if (!shouldEncrypt) return
    if (context.bodyKind === 'form-data') {
      throw new Error('AES-256-GCM：暂不支持加密 multipart/form-data 请求体')
    }

    const headerName = readString(config, 'headerName') || 'X-Payload-Encrypted'
    const envelope = encryptAesGcm(context.bodyText ?? '', secret)
    context.bodyKind = 'text'
    context.bodyText = JSON.stringify(envelope)
    setHeader(context.headers, 'Content-Type', 'application/json; charset=utf-8')
    setHeader(context.headers, headerName, 'AES-256-GCM')
    context.pluginLog.push('AES-256-GCM：请求体已加密')
  },
  afterResponse(context, config) {
    const secret = requireSecret(config, 'AES-256-GCM')
    const shouldDecrypt = readBoolean(config, 'decryptResponse', false)
    if (!shouldDecrypt) return context.responseBody

    let parsed: unknown
    try {
      parsed = JSON.parse(context.responseBody)
    } catch {
      throw new Error('AES-256-GCM：响应体不是 JSON，无法解密')
    }
    if (!isAesEnvelope(parsed)) {
      throw new Error('AES-256-GCM：响应体不是受支持的加密信封')
    }
    const plaintext = decryptAesGcm(parsed, secret)
    context.request.pluginLog.push('AES-256-GCM：响应体已解密')
    return plaintext
  }
}

export const PLUGIN_IMPLEMENTATIONS: Record<string, RequestPlugin> = {
  [hmacSha256Plugin.id]: hmacSha256Plugin,
  [aesGcmPlugin.id]: aesGcmPlugin
}
