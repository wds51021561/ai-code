import { Check, Plus, Trash2 } from 'lucide-react'
import { useId } from 'react'
import { createEmptyKeyValue } from '@shared/defaults'
import type { KeyValueItem } from '@shared/types'
import { cn } from '../lib/utils'

interface KeyValueEditorProps {
  items: KeyValueItem[]
  onChange: (items: KeyValueItem[]) => void
  keyPlaceholder?: string
  valuePlaceholder?: string
  keySuggestions?: string[]
  addLabel?: string
  className?: string
}

export function KeyValueEditor({
  items,
  onChange,
  keyPlaceholder = 'Key',
  valuePlaceholder = 'Value',
  keySuggestions,
  addLabel = '添加一行',
  className
}: KeyValueEditorProps) {
  const suggestionsId = useId()

  const updateItem = (id: string, patch: Partial<KeyValueItem>): void => {
    const next = items.map((item) => (item.id === id ? { ...item, ...patch } : item))
    const index = next.findIndex((item) => item.id === id)
    const row = next[index]
    if (index === next.length - 1 && row && (row.key || row.value)) {
      next.push(createEmptyKeyValue())
    }
    onChange(next)
  }

  const removeItem = (id: string): void => {
    const next = items.filter((item) => item.id !== id)
    onChange(next.length ? next : [createEmptyKeyValue()])
  }

  const addItem = (): void => {
    onChange([...items, createEmptyKeyValue()])
  }

  return (
    <div className={cn('flex flex-col', className)}>
      {keySuggestions?.length ? (
        <datalist id={suggestionsId}>
          {keySuggestions.map((suggestion) => (
            <option key={suggestion} value={suggestion} />
          ))}
        </datalist>
      ) : null}

      <div className="mb-1 grid grid-cols-[22px_minmax(0,0.9fr)_minmax(0,1.1fr)_26px] items-center gap-1 px-2 text-[10px] font-medium uppercase tracking-wider text-faint">
        <span />
        <span>Key</span>
        <span>Value</span>
        <span />
      </div>

      <div className="flex flex-col">
        {items.map((item) => (
          <div
            key={item.id}
            className="group grid grid-cols-[22px_minmax(0,0.9fr)_minmax(0,1.1fr)_26px] items-center gap-1 rounded-lg border border-transparent px-1 transition-colors hover:border-line hover:bg-panel-2/50 focus-within:border-line focus-within:bg-panel-2/50"
          >
            <button
              type="button"
              role="checkbox"
              aria-checked={item.enabled}
              aria-label={item.enabled ? '禁用此行' : '启用此行'}
              onClick={() => updateItem(item.id, { enabled: !item.enabled })}
              className={cn(
                'flex size-[15px] items-center justify-center rounded border outline-none transition-all focus-visible:ring-2 focus-visible:ring-accent/35',
                item.enabled
                  ? 'border-accent bg-accent text-accent-ink'
                  : 'border-line-strong bg-transparent text-transparent hover:border-muted'
              )}
            >
              <Check size={10} strokeWidth={3.5} />
            </button>

            <input
              value={item.key}
              list={keySuggestions?.length ? suggestionsId : undefined}
              onChange={(event) => updateItem(item.id, { key: event.target.value })}
              placeholder={keyPlaceholder}
              spellCheck={false}
              className={cn(
                'h-8 min-w-0 rounded-md border border-transparent bg-transparent px-2 font-mono text-[12px] outline-none transition placeholder:font-sans placeholder:text-faint focus:border-accent/40 focus:bg-panel focus:ring-2 focus:ring-accent/10',
                !item.enabled && 'text-faint line-through decoration-faint/50'
              )}
            />
            <input
              value={item.value}
              onChange={(event) => updateItem(item.id, { value: event.target.value })}
              placeholder={valuePlaceholder}
              spellCheck={false}
              className={cn(
                'h-8 min-w-0 rounded-md border border-transparent bg-transparent px-2 font-mono text-[12px] outline-none transition placeholder:font-sans placeholder:text-faint focus:border-accent/40 focus:bg-panel focus:ring-2 focus:ring-accent/10',
                !item.enabled && 'text-faint'
              )}
            />
            <button
              type="button"
              aria-label="删除此行"
              onClick={() => removeItem(item.id)}
              className="flex size-7 items-center justify-center rounded-md text-faint opacity-0 outline-none transition hover:bg-danger/10 hover:text-danger focus-visible:opacity-100 focus-visible:ring-2 focus-visible:ring-accent/35 group-hover:opacity-100"
            >
              <Trash2 size={13} />
            </button>
          </div>
        ))}
      </div>

      <button
        type="button"
        onClick={addItem}
        className="mt-2 inline-flex w-fit items-center gap-1 rounded-md px-2 py-1 text-[11.5px] font-medium text-muted outline-none transition hover:bg-panel-2 hover:text-ink focus-visible:ring-2 focus-visible:ring-accent/35"
      >
        <Plus size={13} />
        {addLabel}
      </button>
    </div>
  )
}
