import { useEffect, useRef, useState } from 'react'
import { Button, inputClass } from './Button'
import { Modal } from './Modal'

interface SaveRequestDialogProps {
  open: boolean
  initialName: string
  updating: boolean
  onCancel: () => void
  onSave: (name: string) => void
}

export function SaveRequestDialog({
  open,
  initialName,
  updating,
  onCancel,
  onSave
}: SaveRequestDialogProps) {
  const [name, setName] = useState(initialName)
  const inputRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    if (!open) return
    setName(initialName)
    const timer = window.setTimeout(() => {
      inputRef.current?.focus()
      inputRef.current?.select()
    }, 40)
    return () => window.clearTimeout(timer)
  }, [open, initialName])

  const submit = (): void => {
    const trimmed = name.trim()
    if (!trimmed) return
    onSave(trimmed)
  }

  return (
    <Modal
      open={open}
      onClose={onCancel}
      title={updating ? '更新收藏' : '保存请求'}
      description={
        updating
          ? '将覆盖当前收藏的请求内容，名称也可以一并修改。'
          : '保存到左侧收藏列表，方便下次快速打开。'
      }
      width="sm"
      footer={
        <>
          <Button variant="ghost" onClick={onCancel}>
            取消
          </Button>
          <Button variant="primary" onClick={submit} disabled={!name.trim()}>
            {updating ? '更新' : '保存'}
          </Button>
        </>
      }
    >
      <label className="mb-1.5 block text-[11px] font-medium text-muted">请求名称</label>
      <input
        ref={inputRef}
        value={name}
        onChange={(event) => setName(event.target.value)}
        onKeyDown={(event) => {
          if (event.key === 'Enter') {
            event.preventDefault()
            submit()
          }
        }}
        placeholder="例如：获取用户详情"
        className={inputClass}
      />
    </Modal>
  )
}
