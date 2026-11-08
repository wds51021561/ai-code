import { X } from 'lucide-react'
import { useEffect, useId, useRef, type ReactNode } from 'react'
import { createPortal } from 'react-dom'
import { cn } from '../lib/utils'
import { Button } from './Button'

interface ModalProps {
  open: boolean
  onClose: () => void
  title: string
  description?: string
  children: ReactNode
  footer?: ReactNode
  width?: 'sm' | 'md' | 'lg' | 'xl'
  noPadding?: boolean
}

const widths = {
  sm: 'max-w-md',
  md: 'max-w-2xl',
  lg: 'max-w-4xl',
  xl: 'max-w-6xl'
}

export function Modal({
  open,
  onClose,
  title,
  description,
  children,
  footer,
  width = 'md',
  noPadding = false
}: ModalProps) {
  const titleId = useId()
  const panelRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!open) return
    const onKeyDown = (event: KeyboardEvent): void => {
      if (event.key !== 'Escape') return
      const dialogs = Array.from(document.querySelectorAll('[role="dialog"]'))
      if (dialogs.at(-1) !== panelRef.current) return
      onClose()
    }
    window.addEventListener('keydown', onKeyDown)
    const timer = window.setTimeout(() => panelRef.current?.focus(), 20)
    return () => {
      window.removeEventListener('keydown', onKeyDown)
      window.clearTimeout(timer)
    }
  }, [open, onClose])

  if (!open) return null

  return createPortal(
    <div className="fixed inset-0 z-50 flex animate-fade-in items-center justify-center p-5">
      <button
        type="button"
        aria-label="关闭"
        className="absolute inset-0 cursor-default bg-[var(--overlay)] backdrop-blur-[2px]"
        onClick={onClose}
      />
      <div
        ref={panelRef}
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        tabIndex={-1}
        className={cn(
          'relative flex max-h-[88vh] w-full animate-pop-in flex-col overflow-hidden rounded-2xl border border-line bg-panel shadow-[var(--shadow)] outline-none',
          widths[width]
        )}
      >
        <div className="flex items-start justify-between gap-4 border-b border-line px-5 py-4">
          <div className="min-w-0">
            <h2 id={titleId} className="text-[15px] font-semibold text-ink">
              {title}
            </h2>
            {description ? (
              <p className="mt-1 text-[12px] leading-5 text-muted">{description}</p>
            ) : null}
          </div>
          <Button
            variant="ghost"
            size="icon-sm"
            aria-label="关闭"
            onClick={onClose}
            className="-mr-1 -mt-1 shrink-0"
          >
            <X size={16} />
          </Button>
        </div>

        <div className={cn('min-h-0 flex-1 overflow-auto', noPadding ? '' : 'p-5')}>{children}</div>

        {footer ? (
          <div className="flex items-center justify-end gap-2 border-t border-line bg-panel-2/60 px-5 py-3.5">
            {footer}
          </div>
        ) : null}
      </div>
    </div>,
    document.body
  )
}
