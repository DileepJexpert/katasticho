import { useState, useEffect, useRef, useId, type KeyboardEvent, type ReactNode } from 'react'
import { Search, X, Loader2, Check } from 'lucide-react'
import clsx from 'clsx'
import { Button } from './button'

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
  ariaLabel?: string
  renderEmpty?: (query: string) => ReactNode
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
  ariaLabel = 'Search options',
  renderEmpty,
}: EntityPickerProps<T>) {
  const generatedId = useId()
  const inputId = id || generatedId
  const listboxId = `${inputId}-listbox`

  const [query, setQuery] = useState('')
  const [isOpen, setIsOpen] = useState(false)
  const [isLoading, setIsLoading] = useState(false)
  const [searchError, setSearchError] = useState<string | null>(null)
  const [retrySearch, setRetrySearch] = useState(0)
  const [results, setResults] = useState<T[]>([])
  const [highlightedIndex, setHighlightedIndex] = useState(-1)
  const [currentEntity, setCurrentEntity] = useState<T | null>(selectedEntity || null)

  const containerRef = useRef<HTMLDivElement>(null)
  const inputRef = useRef<HTMLInputElement>(null)
  const debounceTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const searchRequestRef = useRef(0)

  // Sync selectedEntity when prop changes
  useEffect(() => {
    if (!value) {
      setCurrentEntity(null)
    } else if (selectedEntity !== undefined) {
      setCurrentEntity(selectedEntity)
    }
  }, [selectedEntity, value])

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

  // Keep local results responsive while preventing stale remote searches from winning.
  useEffect(() => {
    if (!isOpen) return

    if (debounceTimerRef.current) {
      clearTimeout(debounceTimerRef.current)
    }

    if (options) {
      setSearchError(null)
      const nextResults = filterOptions(options, query, getOptionLabel, getOptionDescription)
      setResults(nextResults)
      setHighlightedIndex((index) => index >= nextResults.length ? -1 : index)
      setIsLoading(false)
      return
    }

    if (onSearch) {
      const requestId = ++searchRequestRef.current
      setSearchError(null)
      setResults([])
      setHighlightedIndex(-1)
      setIsLoading(true)
      debounceTimerRef.current = setTimeout(async () => {
        try {
          const items = await onSearch(query.trim())
          if (requestId === searchRequestRef.current) {
            setResults(items || [])
            setHighlightedIndex(-1)
          }
        } catch (error) {
          if (requestId === searchRequestRef.current) {
            setResults([])
            setSearchError(error instanceof Error ? error.message : 'Records could not be loaded.')
          }
        } finally {
          if (requestId === searchRequestRef.current) setIsLoading(false)
        }
      }, 200)
    } else {
      setResults([])
      setIsLoading(false)
    }

    return () => {
      searchRequestRef.current += 1
      if (debounceTimerRef.current) {
        clearTimeout(debounceTimerRef.current)
      }
    }
  }, [query, isOpen, options, onSearch, getOptionLabel, getOptionDescription, retrySearch])

  function openPicker(highlight: 'first' | 'last' | 'none' = 'none') {
    setIsOpen(true)
    if (!options) return

    const nextResults = filterOptions(options, query, getOptionLabel, getOptionDescription)
    setResults(nextResults)
    setHighlightedIndex(
      highlight === 'first' ? (nextResults.length ? 0 : -1) :
      highlight === 'last' ? nextResults.length - 1 :
      -1,
    )
  }

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
        openPicker('first')
      } else {
        setHighlightedIndex((prev) => (prev < results.length - 1 ? prev + 1 : 0))
      }
    } else if (e.key === 'ArrowUp') {
      e.preventDefault()
      if (!isOpen) {
        openPicker('last')
      } else {
        setHighlightedIndex((prev) => (prev > 0 ? prev - 1 : results.length - 1))
      }
    } else if (e.key === 'Enter') {
      if (isOpen && highlightedIndex >= 0 && results[highlightedIndex]) {
        e.preventDefault()
        handleSelect(results[highlightedIndex])
      }
    } else if (e.key === 'Escape') {
      if (isOpen) { e.preventDefault(); e.stopPropagation() }
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
          isInvalid && 'entity-picker--invalid',
          className
        )}
      >
        <div className="entity-picker__selection">
          <span className="entity-picker__selection-label">{displayLabel}</span>
          {displayDesc && (
            <span className="entity-picker__selection-description">{displayDesc}</span>
          )}
        </div>
        {!disabled && (
          <button
            type="button"
            onClick={handleClear}
            aria-label="Clear selection"
            className="entity-picker__clear"
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
      className={clsx('entity-picker', isInvalid && 'entity-picker--invalid', className)}
    >
      <div className="entity-picker__control">
        <Search aria-hidden="true" className="entity-picker__search-icon" size={14} />
        <input
          ref={inputRef}
          id={inputId}
          type="text"
          role="combobox"
          aria-autocomplete="list"
          aria-activedescendant={isOpen && highlightedIndex >= 0 ? `${listboxId}-option-${highlightedIndex}` : undefined}
          aria-expanded={isOpen}
          aria-controls={listboxId}
          aria-haspopup="listbox"
          aria-label={ariaLabel}
          disabled={disabled}
          placeholder={placeholder}
          value={query}
          onChange={(e) => {
            setQuery(e.target.value)
            if (!isOpen) openPicker()
          }}
          onFocus={() => openPicker()}
          onKeyDown={handleKeyDown}
          className="entity-picker__input"
        />
        {isLoading && (
          <Loader2
            size={14}
            aria-label="Searching"
            className="entity-picker__loader"
          />
        )}
      </div>

      {isOpen && (
        <div
          id={listboxId}
          role={searchError ? undefined : 'listbox'}
          className="entity-picker__options"
        >
          {searchError ? <div className="entity-picker__empty" role="alert"><p>{searchError}</p><Button variant="secondary" onClick={() => setRetrySearch((attempt) => attempt + 1)}>Retry search</Button></div> : results.length === 0 ? (
            renderEmpty && !isLoading ? (
              renderEmpty(query.trim())
            ) : (
              <div className="entity-picker__empty">
                {isLoading ? 'Searching...' : 'No matching records found'}
              </div>
            )
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
                  id={`${listboxId}-option-${idx}`}
                  key={itemId}
                  role="option"
                  aria-selected={isSelected}
                  onClick={() => handleSelect(item)}
                  onMouseEnter={() => setHighlightedIndex(idx)}
                  className={clsx(
                    'entity-picker__option',
                    isHighlighted && 'entity-picker__option--highlighted',
                    isSelected && 'entity-picker__option--selected',
                  )}
                >
                  <div className="entity-picker__option-copy">
                    <div className="entity-picker__option-title-row">
                      <span className="entity-picker__option-label">{itemLabel}</span>
                      {itemBadge && (
                        <span className="entity-picker__option-badge">{itemBadge}</span>
                      )}
                    </div>
                    {itemDesc && (
                      <span className="entity-picker__option-description">{itemDesc}</span>
                    )}
                  </div>
                  {isSelected && (
                    <Check aria-hidden="true" className="entity-picker__selected-icon" size={14} />
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

function filterOptions<T>(
  options: readonly T[],
  query: string,
  getOptionLabel: (item: T) => string,
  getOptionDescription?: (item: T) => string | undefined,
): T[] {
  const normalizedQuery = query.trim().toLowerCase()
  return options.filter((item) => {
    if (!normalizedQuery) return true
    const label = getOptionLabel(item).toLowerCase()
    const description = getOptionDescription?.(item)?.toLowerCase() ?? ''
    return label.includes(normalizedQuery) || description.includes(normalizedQuery)
  }).slice(0, 20)
}
