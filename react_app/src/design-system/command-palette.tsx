import { CornerDownLeft, LogOut, Search, X } from 'lucide-react'
import { useEffect, useRef, useState } from 'react'
import type { NavigationItem } from '@/app/navigation'

type CommandPaletteProps = {
  isOpen: boolean
  navigation: readonly NavigationItem[]
  onNavigate: (to: string) => void
  onOpenChange: (isOpen: boolean) => void
  onSignOut: () => void
}

type Command = {
  id: string
  label: string
  description: string
  icon: NavigationItem['icon']
  run: () => void
}

export function CommandPalette({ isOpen, navigation, onNavigate, onOpenChange, onSignOut }: CommandPaletteProps) {
  const inputRef = useRef<HTMLInputElement>(null)
  const [query, setQuery] = useState('')
  const [activeIndex, setActiveIndex] = useState(0)

  const commands: Command[] = [
    ...navigation.map((item) => ({
      id: item.id,
      label: item.label,
      description: item.description,
      icon: item.icon,
      run: () => onNavigate(item.to),
    })),
    {
      id: 'sign-out',
      label: 'Sign out',
      description: 'End this browser session',
      icon: LogOut,
      run: onSignOut,
    },
  ]
  const normalizedQuery = query.trim().toLocaleLowerCase()
  const matches = commands.filter((command) => {
    if (!normalizedQuery) return true
    return `${command.label} ${command.description}`.toLocaleLowerCase().includes(normalizedQuery)
  })

  function close() {
    onOpenChange(false)
  }

  function run(command: Command) {
    close()
    command.run()
  }

  useEffect(() => {
    function handleShortcut(event: KeyboardEvent) {
      if ((event.ctrlKey || event.metaKey) && event.key.toLocaleLowerCase() === 'k') {
        event.preventDefault()
        onOpenChange(true)
      }
    }

    window.addEventListener('keydown', handleShortcut)
    return () => window.removeEventListener('keydown', handleShortcut)
  }, [onOpenChange])

  useEffect(() => {
    if (!isOpen) return
    setQuery('')
    setActiveIndex(0)
    inputRef.current?.focus()
  }, [isOpen])

  useEffect(() => {
    if (activeIndex >= matches.length) setActiveIndex(0)
  }, [activeIndex, matches.length])

  if (!isOpen) return null

  return (
    <div className="command-palette-backdrop" onMouseDown={(event) => {
      if (event.target === event.currentTarget) close()
    }}>
      <section aria-label="Command palette" aria-modal="true" className="command-palette" role="dialog">
        <div className="command-palette__search">
          <Search aria-hidden="true" size={18} />
          <input
            aria-activedescendant={matches[activeIndex] ? `command-${matches[activeIndex].id}` : undefined}
            aria-controls="command-results"
            aria-expanded="true"
            aria-label="Search commands"
            autoComplete="off"
            onChange={(event) => {
              setQuery(event.target.value)
              setActiveIndex(0)
            }}
            onKeyDown={(event) => {
              if (event.key === 'Escape') {
                event.preventDefault()
                close()
              }
              if (event.key === 'ArrowDown' && matches.length) {
                event.preventDefault()
                setActiveIndex((current) => (current + 1) % matches.length)
              }
              if (event.key === 'ArrowUp' && matches.length) {
                event.preventDefault()
                setActiveIndex((current) => (current - 1 + matches.length) % matches.length)
              }
              if (event.key === 'Enter' && matches[activeIndex]) {
                event.preventDefault()
                run(matches[activeIndex])
              }
            }}
            placeholder="Search commands..."
            ref={inputRef}
            role="combobox"
            value={query}
          />
          <button aria-label="Close command palette" className="command-palette__close" onClick={close} type="button">
            <X aria-hidden="true" size={18} />
          </button>
        </div>
        <div className="command-palette__results" id="command-results" role="listbox">
          {matches.length ? matches.map((command, index) => {
            const Icon = command.icon
            const isActive = activeIndex === index
            return (
              <button
                aria-label={`${command.label}: ${command.description}`}
                aria-selected={isActive}
                className={isActive ? 'command-palette__item command-palette__item--active' : 'command-palette__item'}
                id={`command-${command.id}`}
                key={command.id}
                onClick={() => run(command)}
                onMouseMove={() => setActiveIndex(index)}
                role="option"
                type="button"
              >
                <span className="command-palette__icon"><Icon aria-hidden="true" size={17} /></span>
                <span><strong>{command.label}</strong><small>{command.description}</small></span>
                {isActive && <CornerDownLeft aria-hidden="true" className="command-palette__enter" size={15} />}
              </button>
            )
          }) : (
            <p className="command-palette__empty">No commands match “{query}”.</p>
          )}
        </div>
        <footer className="command-palette__footer"><span><kbd>↑</kbd><kbd>↓</kbd> navigate</span><span><kbd>Enter</kbd> open</span><span><kbd>Esc</kbd> close</span></footer>
      </section>
    </div>
  )
}
