import type { ButtonHTMLAttributes, ReactNode } from 'react'
import { cn } from '../lib/utils'

type Variant = 'primary' | 'send' | 'secondary' | 'ghost' | 'danger' | 'soft'
type Size = 'sm' | 'md' | 'icon' | 'icon-sm'

const variants: Record<Variant, string> = {
  primary:
    'bg-accent text-accent-ink shadow-sm hover:brightness-110 active:brightness-95 disabled:opacity-50',
  send:
    'bg-send text-send-ink shadow-sm hover:brightness-105 active:brightness-95 disabled:opacity-50',
  secondary:
    'border border-line bg-panel-2 text-ink hover:border-line-strong hover:bg-elevated disabled:opacity-50',
  ghost:
    'text-muted hover:bg-elevated hover:text-ink disabled:opacity-40 disabled:hover:bg-transparent',
  danger:
    'border border-danger/20 bg-danger/10 text-danger hover:bg-danger/15 disabled:opacity-50',
  soft: 'bg-accent-soft text-accent hover:bg-accent/15 disabled:opacity-50'
}

const sizes: Record<Size, string> = {
  sm: 'h-7 rounded-md px-2.5 text-[12px]',
  md: 'h-9 rounded-lg px-3.5 text-[13px]',
  icon: 'size-9 rounded-lg',
  'icon-sm': 'size-7 rounded-md'
}

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant
  size?: Size
  icon?: ReactNode
}

export function Button({
  variant = 'secondary',
  size = 'md',
  icon,
  className,
  children,
  type = 'button',
  ...props
}: ButtonProps) {
  return (
    <button
      type={type}
      className={cn(
        'inline-flex select-none items-center justify-center gap-1.5 font-medium outline-none transition-all duration-150 focus-visible:ring-2 focus-visible:ring-accent/35',
        variants[variant],
        sizes[size],
        className
      )}
      {...props}
    >
      {icon}
      {children}
    </button>
  )
}

export const inputClass =
  'h-9 w-full min-w-0 rounded-lg border border-line bg-panel-2 px-3 text-[13px] outline-none transition placeholder:text-faint focus:border-accent/50 focus:bg-panel focus:ring-2 focus:ring-accent/10'

export const selectClass =
  'h-9 rounded-lg border border-line bg-panel-2 px-3 text-[13px] outline-none transition focus:border-accent/50 focus:ring-2 focus:ring-accent/10'
