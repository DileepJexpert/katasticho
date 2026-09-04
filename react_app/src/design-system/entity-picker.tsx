import { useState, useEffect, useRef, useId, type KeyboardEvent } from 'react'
import { Search, X, Loader2, Check } from 'lucide-react'
import clsx from 'clsx'

export interface EntityPickerProps<T> {
  value: string | null
  onChange: (id: string | null, entity?: T | null) => void
  onSearch?: (query: string) => Promise<T[]>
  options?: T[]
  getOptionId: (item: T) => string
  getOptionLabel: (item: T) => string
  getOptionDescription?: (item: T) => string | undefined
  getOptionBadge?: (item: T) => string | undefined
  placeholder?: string
  disabled?: boolean
  isInvalid?: boolean
  selectedEntity?: T | null
  selectedLabel?: string | null
  className?: string
  id?: string
}

export function EntityPicker<T>({
  value,
  onChange,
  onSearch,
  options,
  getOptionId,
  getOptionLabel,
  getOptionDescription,
  getOptionBadge,
  placeholder = 'Search to select...',
  disabled = false,
  isInvalid = false,
  selectedEntity,
  selectedLabel,
  className,
  id,
}: EntityPickerProps<T>) {
  const generatedId = useId()
  const inputId = id || generatedId
  const listboxId = `${inputId}-listbox`

  const [query, setQuery] = useState('')
  const [isOpen, setIsOpen] = useState(false)
  const [isLoading, setIsLoading] = useState(false)
  const [results, setResults] = useState<T[]>([])
  const [highlightedIndex, setHighlightedIndex] = useState(-1)
  const [currentEntity, setCurrentEntity] = useState<T | null>(selectedEntity || null)

  const containerRef = useRef<HTMLDivElement>(null)
  const inputRef = useRef<HTMLInputElement>(null)
  const debounceTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  // Sync selectedEntity when prop changes
  useEffect(() => {
    if (selectedEntity !== undefined) {
      setCurrentEntity(selectedEntity)
    }
  }, [selectedEntity])

  // Close dropdown on outside click
  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (containerRef.current && !containerRef.current.contains(e.target as Node)) {
        setIsOpen(false)
      }
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])

  // Execute search
  useEffect(() => {
    if (!isOpen) return

    if (debounceTimerRef.current) {
      clearTimeout(debounceTimerRef.current)
    }

    if (options) {
      const q = query.trim().toLowerCase()
      if (!q) {
        setResults(options.slice(0, 20))
      } else {
        setResults(
          options.filter((item) => {
            const label = getOptionLabel(item).toLowerCase()
            const desc = getOptionDescription ? getOptionDescription(item)?.toLowerCase() : ''
            return label.includes(q) || (desc && desc.includes(q))
          }).slice(0, 20)
        )
      }
      setHighlightedIndex(-1)
      return
    }

    if (onSearch) {
      debounceTimerRef.current = setTimeout(async () => {
        setIsLoading(true)
        try {
          const items = await onSearch(query.trim())
          setResults(items || [])
          setHighlightedIndex(-1)
        } catch {
          setResults([])
        } finally {
          setIsLoading(false)
        }
      }, 200)
    }

    return () => {
      if (debounceTimerRef.current) {
        clearTimeout(debounceTimerRef.current)
      }
    }
  }, [query, isOpen, options, onSearch, getOptionLabel, getOptionDescription])

  function handleSelect(item: T) {
    const idVal = getOptionId(item)
    setCurrentEntity(item)
    onChange(idVal, item)
    setIsOpen(false)
    setQuery('')
  }

  function handleClear() {
    setCurrentEntity(null)
    onChange(null, null)
    setQuery('')
    setTimeout(() => inputRef.current?.focus(), 0)
  }

  function handleKeyDown(e: KeyboardEvent<HTMLInputElement>) {
    if (e.key === 'ArrowDown') {
      e.preventDefault()
      if (!isOpen) {
        setIsOpen(true)
      } else {
        setHighlightedIndex((prev) => (prev < results.length - 1 ? prev + 1 : 0))
      }
    } else if (e.key === 'ArrowUp') {
      e.preventDefault()
      if (!isOpen) {
        setIsOpen(true)
      } else {
        setHighlightedIndex((prev) => (prev > 0 ? prev - 1 : results.length - 1))
      }
    } else if (e.key === 'Enter') {
      if (isOpen && highlightedIndex >= 0 && results[highlightedIndex]) {
        e.preventDefault()
        handleSelect(results[highlightedIndex])
      }
    } else if (e.key === 'Escape') {
      setIsOpen(false)
    }
  }

  const displayLabel = selectedLabel || (currentEntity ? getOptionLabel(currentEntity) : null)
  const displayDesc = currentEntity && getOptionDescription ? getOptionDescription(currentEntity) : null

  // If a value is selected, render the selected token
  if (value && displayLabel) {
    return (
      <div
        ref={containerRef}
        className={clsx(
          'entity-picker entity-picker--selected',
          isInvalid && 'field-input--error',
          className
        )}
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          minHeight: 'var(--control-h, 36px)',
          padding: '0 10px',
          border: '1px solid var(--color-border)',
          borderRadius: 'var(--radius-sm, 6px)',
          background: 'var(--color-surface)',
          gap: '8px',
        }}
      >
        <div style={{ display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
          <span style={{ fontSize: '13px', fontWeight: 600, color: 'var(--color-text-primary)' }}>
            {displayLabel}
          </span>
          {displayDesc && (
            <span style={{ fontSize: '11px', color: 'var(--color-text-muted)' }}>
              {displayDesc}
            </span>
          )}
        </div>
        {!disabled && (
          <button
            type="button"
            onClick={handleClear}
            aria-label="Clear selection"
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              justifyContent: 'center',
              width: 22,
              height: 22,
              border: 'none',
              background: 'transparent',
              borderRadius: 'var(--radius-full)',
              color: 'var(--color-text-muted)',
              cursor: 'pointer',
              padding: 0,
            }}
          >
            <X size={14} />
          </button>
        )}
      </div>
    )
  }

  return (
    <div
      ref={containerRef}
      className={clsx('entity-picker', isInvalid && 'field-input--error', className)}
      style={{ position: 'relative', width: '100%' }}
    >
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          minHeight: 'var(--control-h, 36px)',
          border: '1px solid var(--color-border)',
          borderRadius: 'var(--radius-sm, 6px)',
          background: disabled ? 'var(--color-surface-subtle)' : 'var(--color-surface)',
          padding: '0 10px',
          gap: '8px',
        }}
      >
        <Search size={14} style={{ color: 'var(--color-text-muted)', flexShrink: 0 }} />
        <input
          ref={inputRef}
          id={inputId}
          type="text"
          role="combobox"
          aria-autocomplete="list"
          aria-expanded={isOpen}
          aria-controls={listboxId}
          disabled={disabled}
          placeholder={placeholder}
          value={query}
          onChange={(e) => {
            setQuery(e.target.value)
            if (!isOpen) setIsOpen(true)
          }}
          onFocus={() => setIsOpen(true)}
          onKeyDown={handleKeyDown}
          style={{
            flex: 1,
            border: 'none',
            background: 'transparent',
            outline: 'none',
            fontSize: '13px',
            color: 'var(--color-text-primary)',
            padding: 0,
          }}
        />
        {isLoading && (
          <Loader2
            size={14}
            className="spin"
            style={{ color: 'var(--color-text-muted)', flexShrink: 0 }}
          />
        )}
      </div>

      {isOpen && (
        <div
          id={listboxId}
          role="listbox"
          style={{
            position: 'absolute',
            top: 'calc(100% + 4px)',
            left: 0,
            right: 0,
            zIndex: 100,
            background: 'var(--color-surface)',
            border: '1px solid var(--color-border)',
            borderRadius: 'var(--radius-md, 8px)',
            boxShadow: 'var(--shadow-md, 0 4px 12px rgba(0,0,0,0.1))',
            maxHeight: 220,
            overflowY: 'auto',
            padding: '4px',
          }}
        >
          {results.length === 0 ? (
            <div
              style={{
                padding: '10px 12px',
                fontSize: '12px',
                color: 'var(--color-text-muted)',
                textAlign: 'center',
              }}
            >
              {isLoading ? 'Searching...' : 'No matching records found'}
            </div>
          ) : (
            results.map((item, idx) => {
              const itemId = getOptionId(item)
              const itemLabel = getOptionLabel(item)
              const itemDesc = getOptionDescription ? getOptionDescription(item) : null
              const itemBadge = getOptionBadge ? getOptionBadge(item) : null
              const isSelected = value === itemId
              const isHighlighted = highlightedIndex === idx

              return (
                <div
                  key={itemId}
                  role="option"
                  aria-selected={isSelected}
                  onClick={() => handleSelect(item)}
                  onMouseEnter={() => setHighlightedIndex(idx)}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    padding: '8px 10px',
                    borderRadius: 'var(--radius-sm, 4px)',
                    cursor: 'pointer',
                    background: isHighlighted
                      ? 'var(--color-surface-subtle)'
                      : isSelected
                      ? 'rgba(15, 133, 118, 0.08)'
                      : 'transparent',
                  }}
                >
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '2px' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                      <span
                        style={{
                          fontSize: '13px',
                          fontWeight: isSelected ? 600 : 500,
                          color: isSelected ? 'var(--color-primary)' : 'var(--color-text-primary)',
                        }}
                      >
                        {itemLabel}
                      </span>
                      {itemBadge && (
                        <span
                          style={{
                            fontSize: '10px',
                            fontWeight: 600,
                            padding: '1px 5px',
                            borderRadius: '3px',
                            background: 'var(--color-surface-subtle)',
                            color: 'var(--color-text-muted)',
                            border: '1px solid var(--color-border)',
                          }}
                        >
                          {itemBadge}
                        </span>
                      )}
                    </div>
                    {itemDesc && (
                      <span style={{ fontSize: '11px', color: 'var(--color-text-muted)' }}>
                        {itemDesc}
                      </span>
                    )}
                  </div>
                  {isSelected && (
                    <Check size={14} style={{ color: 'var(--color-primary)' }} />
                  )}
                </div>
              )
            })
          )}
        </div>
      )}
    </div>
  )
}
