import type { HttpMethod } from '@shared/types'
import { cn, methodColorVar, statusColorVar } from '../lib/utils'

export function MethodBadge({
  method,
  className
}: {
  method: HttpMethod
  className?: string
}) {
  const color = methodColorVar(method)
  return (
    <span
      className={cn(
        'inline-flex min-w-[50px] items-center justify-center rounded-md px-1.5 py-0.5 font-mono text-[9.5px] font-bold tracking-wide',
        className
      )}
      style={{
        color,
        backgroundColor: `color-mix(in srgb, ${color} 12%, transparent)`,
        border: `1px solid color-mix(in srgb, ${color} 22%, transparent)`
      }}
    >
      {method}
    </span>
  )
}

export function StatusBadge({
  status,
  className
}: {
  status: number
  className?: string
}) {
  const color = statusColorVar(status)
  return (
    <span
      className={cn(
        'inline-flex items-center gap-1.5 rounded-md px-2 py-0.5 font-mono text-[10.5px] font-semibold',
        className
      )}
      style={{
        color,
        backgroundColor: `color-mix(in srgb, ${color} 12%, transparent)`,
        border: `1px solid color-mix(in srgb, ${color} 22%, transparent)`
      }}
    >
      <span className="size-1.5 rounded-full" style={{ backgroundColor: color }} />
      {status || 'ERR'}
    </span>
  )
}
