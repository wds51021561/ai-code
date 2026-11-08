const VARIABLE_PATTERN = /\{\{\s*([^{}]+?)\s*\}\}/g

export function interpolateString(value: string, variables: Record<string, string>): string {
  return value.replace(VARIABLE_PATTERN, (match, rawKey: string) => {
    const key = rawKey.trim()
    return Object.prototype.hasOwnProperty.call(variables, key) ? variables[key] : match
  })
}

export function interpolateUnknown(value: unknown, variables: Record<string, string>): unknown {
  if (typeof value === 'string') {
    return interpolateString(value, variables)
  }
  if (Array.isArray(value)) {
    return value.map((item) => interpolateUnknown(item, variables))
  }
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value as Record<string, unknown>).map(([key, item]) => [
        key,
        interpolateUnknown(item, variables)
      ])
    )
  }
  return value
}

export function hasUnresolvedVariables(value: string): boolean {
  return /\{\{[^{}]+\}\}/.test(value)
}
