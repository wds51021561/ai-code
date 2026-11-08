import { Check, Eye, EyeOff, Plus, ShieldCheck, ShieldOff, Trash2 } from 'lucide-react'
import { useId, useState } from 'react'
import { createEmptyVariable } from '@shared/defaults'
import type { Variable } from '@shared/types'
import { cn } from '../lib/utils'

interface VariableEditorProps {
  variables: Variable[]
  onChange: (variables: Variable[]) => void
}

const keySuggestions = [
  'baseUrl',
  'apiToken',
  'signSecret',
  'cryptoKey',
  'accessKey',
  'userId',
  'tenantId'
]

export function VariableEditor({ variables, onChange }: VariableEditorProps) {
  const suggestionsId = useId()
  const [revealed, setRevealed] = useState<Set<string>>(() => new Set())

  const toggleReveal = (id: string): void => {
    setRevealed((current) => {
      const next = new Set(current)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }

  const updateItem = (id: string, patch: Partial<Variable>): void => {
    const next = variables.map((item) => (item.id === id ? { ...item, ...patch } : item))
    const index = next.findIndex((item) => item.id === id)
    const row = next[index]
    if (index === next.length - 1 && row && (row.key || row.value)) {
      next.push(createEmptyVariable())
    }
    onChange(next)
  }

  const removeItem = (id: string): void => {
    const next = variables.filter((item) => item.id !== id)
    onChange(next.length ? next : [createEmptyVariable()])
  }

  return (
    <div className="flex flex-col">
      <datalist id={suggestionsId}>
        {keySuggestions.map((suggestion) => (
          <option key={suggestion} value={suggestion} />
        ))}
      </datalist>

      <div className="mb-1 grid grid-cols-[22px_minmax(0,0.75fr)_minmax(0,1.25fr)_30px_26px] items-center gap-1 px-2 text-[10px] font-medium uppercase tracking-wider text-faint">
        <span />
        <span>变量名</span>
        <span>值</span>
        <span className="text-center">敏感</span>
        <span />
      </div>

      <div className="flex flex-col">
        {variables.map((item) => {
          const isRevealed = revealed.has(item.id)
          return (
            <div
              key={item.id}
              className="group grid grid-cols-[22px_minmax(0,0.75fr)_minmax(0,1.25fr)_30px_26px] items-center gap-1 rounded-lg border border-transparent px-1 transition-colors hover:border-line hover:bg-panel-2/60 focus-within:border-line focus-within:bg-panel-2/60"
            >
              <button
                type="button"
                role="checkbox"
                aria-checked={item.enabled}
                aria-label={item.enabled ? '禁用变量' : '启用变量'}
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
                list={suggestionsId}
                onChange={(event) => updateItem(item.id, { key: event.target.value })}
                placeholder="变量名"
                spellCheck={false}
                className={cn(
                  'h-8 min-w-0 rounded-md border border-transparent bg-transparent px-2 font-mono text-[12px] outline-none transition placeholder:font-sans placeholder:text-faint focus:border-accent/40 focus:bg-panel focus:ring-2 focus:ring-accent/10',
                  !item.enabled && 'text-faint line-through decoration-faint/50'
                )}
              />

              <div className="relative min-w-0">
                <input
                  value={item.value}
                  type={item.secret && !isRevealed ? 'password' : 'text'}
                  onChange={(event) => updateItem(item.id, { value: event.target.value })}
                  placeholder={item.secret ? '敏感值' : '变量值'}
                  spellCheck={false}
                  className={cn(
                    'h-8 w-full min-w-0 rounded-md border border-transparent bg-transparent px-2 pr-8 font-mono text-[12px] outline-none transition placeholder:font-sans placeholder:text-faint focus:border-accent/40 focus:bg-panel focus:ring-2 focus:ring-accent/10',
                    !item.enabled && 'text-faint'
                  )}
                />
                {item.secret ? (
                  <button
                    type="button"
                    aria-label={isRevealed ? '隐藏变量值' : '显示变量值'}
                    onClick={() => toggleReveal(item.id)}
                    className="absolute right-1 top-1/2 flex size-6 -translate-y-1/2 items-center justify-center rounded text-faint outline-none transition hover:bg-panel-2 hover:text-ink focus-visible:ring-2 focus-visible:ring-accent/35"
                  >
                    {isRevealed ? <EyeOff size={12} /> : <Eye size={12} />}
                  </button>
                ) : null}
              </div>

              <button
                type="button"
                aria-label={item.secret ? '取消敏感标记' : '标记为敏感'}
                title={item.secret ? '取消敏感标记' : '标记为敏感'}
                onClick={() => updateItem(item.id, { secret: !item.secret })}
                className={cn(
                  'mx-auto flex size-7 items-center justify-center rounded-md outline-none transition focus-visible:ring-2 focus-visible:ring-accent/35',
                  item.secret
                    ? 'text-accent hover:bg-accent-soft'
                    : 'text-faint hover:bg-panel-2 hover:text-ink'
                )}
              >
                {item.secret ? <ShieldCheck size={13} /> : <ShieldOff size={13} />}
              </button>

              <button
                type="button"
                aria-label="删除变量"
                onClick={() => removeItem(item.id)}
                className="flex size-7 items-center justify-center rounded-md text-faint opacity-0 outline-none transition hover:bg-danger/10 hover:text-danger focus-visible:opacity-100 focus-visible:ring-2 focus-visible:ring-accent/35 group-hover:opacity-100"
              >
                <Trash2 size={13} />
              </button>
            </div>
          )
        })}
      </div>

      <button
        type="button"
        onClick={() => onChange([...variables, createEmptyVariable()])}
        className="mt-2 inline-flex w-fit items-center gap-1 rounded-md px-2 py-1 text-[11.5px] font-medium text-muted outline-none transition hover:bg-panel-2 hover:text-ink focus-visible:ring-2 focus-visible:ring-accent/35"
      >
        <Plus size={13} />
        添加变量
      </button>
    </div>
  )
}
