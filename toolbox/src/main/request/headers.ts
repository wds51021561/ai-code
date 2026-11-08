export function setHeader(headers: Record<string, string>, name: string, value: string): void {
  const lower = name.toLowerCase()
  for (const key of Object.keys(headers)) {
    if (key.toLowerCase() === lower) {
      delete headers[key]
    }
  }
  headers[name] = value
}

export function getHeader(headers: Record<string, string>, name: string): string | undefined {
  const lower = name.toLowerCase()
  const key = Object.keys(headers).find((item) => item.toLowerCase() === lower)
  return key ? headers[key] : undefined
}

export function deleteHeader(headers: Record<string, string>, name: string): void {
  const lower = name.toLowerCase()
  for (const key of Object.keys(headers)) {
    if (key.toLowerCase() === lower) {
      delete headers[key]
    }
  }
}
