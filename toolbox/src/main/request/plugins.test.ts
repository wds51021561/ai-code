import { createHmac } from 'node:crypto'
import { describe, expect, it } from 'vitest'
import { PLUGIN_IMPLEMENTATIONS, type RequestPluginContext } from './plugins'

function createContext(body: string): RequestPluginContext {
  return {
    method: 'POST',
    url: new URL('https://api.example.com/v1/users?page=2'),
    headers: {},
    bodyText: body,
    bodyKind: 'text',
    pluginLog: []
  }
}

describe('hmac-sha256 plugin', () => {
  const plugin = PLUGIN_IMPLEMENTATIONS['hmac-sha256']

  it('writes matching timestamp, nonce and signature headers', () => {
    const context = createContext('{"name":"demo"}')
    plugin.beforeSend?.(context, {
      secret: 'top-secret',
      header: 'X-Signature',
      timestampHeader: 'X-Timestamp',
      nonceHeader: 'X-Nonce',
      includeQuery: true,
      includeBody: true,
      encoding: 'hex',
      prefix: ''
    })

    const timestamp = context.headers['X-Timestamp']
    const nonce = context.headers['X-Nonce']
    const canonical = [
      'POST',
      '/v1/users?page=2',
      timestamp,
      nonce,
      '{"name":"demo"}'
    ].join('\n')
    const expected = createHmac('sha256', 'top-secret').update(canonical).digest('hex')

    expect(timestamp).toBeTruthy()
    expect(nonce).toHaveLength(32)
    expect(context.headers['X-Signature']).toBe(expected)
    expect(context.pluginLog).toContain('HMAC-SHA256：签名头 X-Signature 已写入')
  })

  it('rejects missing or unresolved secrets', () => {
    expect(() => plugin.beforeSend?.(createContext(''), {})).toThrow('请填写 secret')
    expect(() =>
      plugin.beforeSend?.(createContext(''), { secret: '{{missing}}' })
    ).toThrow('未解析的环境变量')
  })
})

describe('aes-256-gcm plugin', () => {
  const plugin = PLUGIN_IMPLEMENTATIONS['aes-256-gcm']

  it('encrypts a request and decrypts the response envelope', () => {
    const context = createContext('{"hello":"world"}')
    const config = {
      secret: 'aes-secret',
      encryptRequest: true,
      decryptResponse: true,
      headerName: 'X-Payload-Encrypted'
    }

    plugin.beforeSend?.(context, config)

    expect(context.bodyKind).toBe('text')
    expect(context.headers['Content-Type']).toBe('application/json; charset=utf-8')
    expect(context.headers['X-Payload-Encrypted']).toBe('AES-256-GCM')
    const envelope = context.bodyText ?? ''
    expect(JSON.parse(envelope).alg).toBe('AES-256-GCM')

    const decrypted = plugin.afterResponse?.(
      { request: context, responseBody: envelope, status: 200 },
      config
    )
    expect(decrypted).toBe('{"hello":"world"}')
    expect(context.pluginLog).toContain('AES-256-GCM：请求体已加密')
    expect(context.pluginLog).toContain('AES-256-GCM：响应体已解密')
  })

  it('rejects multipart bodies and invalid response envelopes', () => {
    const context = createContext('')
    context.bodyKind = 'form-data'
    expect(() =>
      plugin.beforeSend?.(context, { secret: 'aes-secret', encryptRequest: true })
    ).toThrow('multipart/form-data')

    const responseContext = {
      request: createContext(''),
      responseBody: 'not-json',
      status: 200
    }
    expect(() =>
      plugin.afterResponse?.(responseContext, { secret: 'aes-secret', decryptResponse: true })
    ).toThrow('响应体不是 JSON')
  })
})
