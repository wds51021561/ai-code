import { describe, expect, it } from 'vitest'
import { hasUnresolvedVariables, interpolateString, interpolateUnknown } from './interpolate'

describe('interpolateString', () => {
  const variables = {
    baseUrl: 'https://api.example.com',
    token: 'secret-token',
    'user.id': '42'
  }

  it('replaces variables including dotted names and whitespace', () => {
    expect(interpolateString('{{baseUrl}}/users/{{ user.id }}', variables)).toBe(
      'https://api.example.com/users/42'
    )
  })

  it('leaves unknown variables untouched', () => {
    expect(interpolateString('{{baseUrl}}/{{missing}}', variables)).toBe(
      'https://api.example.com/{{missing}}'
    )
  })

  it('interpolates nested values', () => {
    expect(
      interpolateUnknown(
        {
          url: '{{baseUrl}}/login',
          headers: ['Bearer {{token}}'],
          retry: 2
        },
        variables
      )
    ).toEqual({
      url: 'https://api.example.com/login',
      headers: ['Bearer secret-token'],
      retry: 2
    })
  })
})

describe('hasUnresolvedVariables', () => {
  it('detects remaining placeholders', () => {
    expect(hasUnresolvedVariables('{{baseUrl}}/users')).toBe(true)
    expect(hasUnresolvedVariables('https://api.example.com/users')).toBe(false)
  })
})
