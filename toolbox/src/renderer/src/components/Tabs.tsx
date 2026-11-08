import type { ReactNode } from 'react'
import { cn } from '../lib/utils'

export interface TabItem<T extends string> {
  id: T
  label: string
  count?: number
  icon?: ReactNode
}

interface UnderlineTabsProps<T extends string> {
  items: Array<TabItem<T>>
  value: T
  onChange: (value: T) => void
  className?: string
  size?: 'sm' | 'md'
}

export function UnderlineTabs<T extends string>({
  items,
  value,
  onChange,
  className,
  size = 'md'
}: UnderlineTabsProps<T>) {
  return (
    <div
      className={cn(
        'flex items-center gap-1 overflow-x-auto border-b border-line',
        size === 'sm' ? 'px-1' : 'px-3',
        className
      )}
    >
      {items.map((item) => {
        const active = item.id === value
        return (
          <button
            key={item.id}
            type="button"
            onClick={() => onChange(item.id)}
            className={cn(
              'relative flex shrink-0 items-center gap-1.5 font-medium outline-none transition-colors',
              size === 'sm'
                ? 'px-2.5 pb-2 pt-2 text-[11.5px]'
                : 'px-3 pb-2.5 pt-2.5 text-[12px]',
              active ? 'text-ink' : 'text-muted hover:text-ink'
            )}
          >
            {item.icon}
            {item.label}
            {typeof item.count === 'number' && item.count > 0 ? (
              <span
                className={cn(
                  'rounded-full px-1.5 py-px font-mono text-[9px]',
                  active ? 'bg-accent-soft text-accent' : 'bg-panel-2 text-faint'
                )}
              >
                {item.count}
              </span>
            ) : null}
            {active ? (
              <span className="absolute inset-x-2 -bottom-px h-[2px] rounded-full bg-accent" />
            ) : null}
          </button>
        )
      })}
    </div>
  )
}

interface SegmentedTabsProps<T extends string> {
  items: Array<Pick<TabItem<T>, 'id' | 'label'>>
  value: T
  onChange: (value: T) => void
  className?: string
}

export function SegmentedTabs<T extends string>({
  items,
  value,
  onChange,
  className
}: SegmentedTabsProps<T>) {
  return (
    <div
      className={cn(
        'inline-flex items-center gap-0.5 rounded-lg border border-line bg-panel-2 p-0.5',
        className
      )}
    >
      {items.map((item) => {
        const active = item.id === value
        return (
          <button
            key={item.id}
            type="button"
            onClick={() => onChange(item.id)}
            className={cn(
              'rounded-md px-2.5 py-1 text-[11.5px] font-medium outline-none transition-all',
              active
                ? 'bg-elevated text-ink shadow-sm'
                : 'text-muted hover:text-ink'
            )}
          >
            {item.label}
          </button>
        )
      })}
    </div>
  )
}
