import { json } from '@codemirror/lang-json'
import { HighlightStyle, syntaxHighlighting } from '@codemirror/language'
import type { Extension } from '@codemirror/state'
import { EditorView } from '@codemirror/view'
import { tags } from '@lezer/highlight'
import CodeMirror from '@uiw/react-codemirror'
import { useMemo } from 'react'
import { useAppStore } from '../store/useAppStore'
import { cn } from '../lib/utils'

const highlightStyle = HighlightStyle.define([
  { tag: tags.comment, color: 'var(--faint)', fontStyle: 'italic' },
  { tag: [tags.propertyName, tags.attributeName], color: 'var(--code-key)' },
  { tag: [tags.string, tags.special(tags.string)], color: 'var(--code-string)' },
  { tag: [tags.number, tags.integer, tags.float], color: 'var(--code-number)' },
  { tag: [tags.bool, tags.atom], color: 'var(--code-bool)' },
  { tag: tags.null, color: 'var(--code-null)' },
  { tag: [tags.punctuation, tags.bracket, tags.separator], color: 'var(--code-punct)' },
  { tag: tags.invalid, color: 'var(--danger)' },
  { tag: [tags.keyword, tags.operator], color: 'var(--code-bool)' }
])

function createTheme(dark: boolean): Extension {
  return EditorView.theme(
    {
      '&': {
        backgroundColor: 'transparent',
        color: 'var(--ink)',
        fontSize: '12.5px',
        height: '100%'
      },
      '&.cm-focused': { outline: 'none' },
      '.cm-scroller': {
        fontFamily: 'var(--font-mono)',
        lineHeight: '1.65',
        overflow: 'auto'
      },
      '.cm-content': {
        padding: '10px 0',
        caretColor: 'var(--accent)'
      },
      '.cm-line': { padding: '0 14px 0 6px' },
      '.cm-gutters': {
        backgroundColor: 'transparent',
        color: 'var(--faint)',
        border: 'none',
        paddingLeft: '8px'
      },
      '.cm-lineNumbers .cm-gutterElement': {
        padding: '0 8px 0 4px',
        minWidth: '32px'
      },
      '.cm-activeLine': {
        backgroundColor: 'color-mix(in srgb, var(--ink) 4%, transparent)'
      },
      '.cm-activeLineGutter': { backgroundColor: 'transparent' },
      '.cm-selectionBackground, ::selection': {
        backgroundColor: 'color-mix(in srgb, var(--accent) 24%, transparent) !important'
      },
      '&.cm-focused .cm-selectionBackground': {
        backgroundColor: 'color-mix(in srgb, var(--accent) 24%, transparent) !important'
      },
      '.cm-cursor, .cm-dropCursor': { borderLeftColor: 'var(--accent)' },
      '.cm-foldPlaceholder': {
        backgroundColor: 'var(--panel-2)',
        border: '1px solid var(--line)',
        color: 'var(--muted)'
      },
      '.cm-tooltip': {
        backgroundColor: 'var(--elevated)',
        border: '1px solid var(--line)',
        borderRadius: '8px'
      },
      '.cm-panels': {
        backgroundColor: 'var(--panel-2)',
        color: 'var(--ink)'
      }
    },
    { dark }
  )
}

interface CodeEditorProps {
  value: string
  onChange?: (value: string) => void
  language?: 'json' | 'text'
  readOnly?: boolean
  placeholder?: string
  className?: string
}

export function CodeEditor({
  value,
  onChange,
  language = 'text',
  readOnly = false,
  placeholder,
  className
}: CodeEditorProps) {
  const theme = useAppStore((state) => state.workspace.theme)

  const extensions = useMemo(() => {
    const list: Extension[] = [
      createTheme(theme === 'dark'),
      syntaxHighlighting(highlightStyle),
      EditorView.lineWrapping
    ]
    if (language === 'json') {
      list.push(json())
    }
    return list
  }, [language, theme])

  return (
    <CodeMirror
      value={value}
      height="100%"
      theme="none"
      readOnly={readOnly}
      editable={!readOnly}
      extensions={extensions}
      onChange={(next) => onChange?.(next)}
      placeholder={placeholder}
      className={cn('h-full overflow-hidden', className)}
      basicSetup={{
        lineNumbers: true,
        foldGutter: false,
        highlightActiveLine: !readOnly,
        highlightActiveLineGutter: false,
        autocompletion: !readOnly,
        closeBrackets: true,
        bracketMatching: true,
        highlightSelectionMatches: false
      }}
    />
  )
}
