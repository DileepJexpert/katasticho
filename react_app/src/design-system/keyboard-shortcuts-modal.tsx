import { useEffect } from 'react'
import { Button } from './button'
import { Modal } from './modal'

export interface KeyboardShortcutsModalProps {
  isOpen: boolean
  onClose: () => void
  onOpen?: () => void
}

interface ShortcutItem {
  keys: string[]
  description: string
}

interface ShortcutCategory {
  title: string
  items: ShortcutItem[]
}

const SHORTCUT_CATEGORIES: ShortcutCategory[] = [
  {
    title: 'Navigation & Search',
    items: [
      { keys: ['Ctrl', 'K'], description: 'Open command palette / quick jump' },
      { keys: ['?'], description: 'Open keyboard shortcuts helper' },
      { keys: ['F1'], description: 'Alternative shortcuts helper' },
      { keys: ['Esc'], description: 'Close modal, menu, or clear search' },
    ],
  },
  {
    title: 'Forms & Dialogs',
    items: [
      { keys: ['Tab'], description: 'Focus next input or interactive element' },
      { keys: ['Shift', 'Tab'], description: 'Focus previous input or element' },
      { keys: ['Enter'], description: 'Submit modal form or activate row' },
      { keys: ['Space'], description: 'Toggle checkbox or open select' },
    ],
  },
  {
    title: 'Tables & Registers',
    items: [
      { keys: ['Tab'], description: 'Focus horizontal scrolling table area' },
      { keys: ['←', '→'], description: 'Scroll wide tabular columns horizontally' },
      { keys: ['Home', 'End'], description: 'Jump to start or end of table view' },
    ],
  },
]

export function KeyboardShortcutsModal({
  isOpen,
  onClose,
  onOpen,
}: KeyboardShortcutsModalProps) {
  useEffect(() => {
    function handleKeyDown(event: KeyboardEvent) {
      const target = event.target as HTMLElement | null
      const isInput =
        target?.tagName === 'INPUT' ||
        target?.tagName === 'TEXTAREA' ||
        target?.tagName === 'SELECT' ||
        Boolean(target?.isContentEditable)

      if (isInput) return

      if (event.key === '?' || (event.key === '/' && event.shiftKey) || event.key === 'F1') {
        event.preventDefault()
        if (isOpen) {
          onClose()
        } else if (onOpen) {
          onOpen()
        }
      }
    }

    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [isOpen, onClose, onOpen])

  return (
    <Modal
      footer={
        <Button onClick={onClose} variant="secondary">
          Close
        </Button>
      }
      isOpen={isOpen}
      onClose={onClose}
      size="md"
      title="Keyboard shortcuts"
      description="Quickly navigate, search, and perform common ERP actions with your keyboard."
    >
      <div className="shortcuts-grid">
        {SHORTCUT_CATEGORIES.map((category) => (
          <section
            aria-labelledby={`shortcuts-${category.title.toLowerCase().replace(/[^a-z0-9]/g, '-')}`}
            className="shortcuts-category"
            key={category.title}
          >
            <span
              className="shortcuts-category__title"
              id={`shortcuts-${category.title.toLowerCase().replace(/[^a-z0-9]/g, '-')}`}
            >
              {category.title}
            </span>
            <div className="shortcuts-list">
              {category.items.map((item) => (
                <div className="shortcut-row" key={item.description}>
                  <span className="shortcut-row__description">{item.description}</span>
                  <div className="shortcut-keys">
                    {item.keys.map((key) => (
                      <kbd className="shortcut-kbd" key={key}>
                        {key}
                      </kbd>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          </section>
        ))}
      </div>
    </Modal>
  )
}
