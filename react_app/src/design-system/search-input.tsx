import { forwardRef } from 'react'
import { Search, X } from 'lucide-react'

export interface SearchInputProps {
  value: string
  onChange: (value: string) => void
  onClear?: () => void
  placeholder?: string
  ariaLabel?: string
  className?: string
  id?: string
  name?: string
  autoFocus?: boolean
  disabled?: boolean
}

export const SearchInput = forwardRef<HTMLInputElement, SearchInputProps>(function SearchInput(
  {
    value,
    onChange,
    onClear,
    placeholder = 'Search...',
    ariaLabel = 'Search directory',
    className = '',
    id,
    name,
    autoFocus,
    disabled = false,
  },
  ref,
) {
  return (
    <label className={`directory-search ${className}`.trim()}>
      <Search aria-hidden="true" size={18} />
      <span className="sr-only">{ariaLabel}</span>
      <input
        aria-label={ariaLabel}
        autoFocus={autoFocus}
        disabled={disabled}
        id={id}
        name={name}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        ref={ref}
        type="search"
        value={value}
      />
      {Boolean(value && onClear) && (
        <button
          aria-label="Clear search"
          className="search-clear-button"
          onClick={(e) => {
            e.preventDefault()
            onClear?.()
          }}
          style={{
            background: 'none',
            border: 'none',
            cursor: 'pointer',
            padding: 0,
            display: 'flex',
            alignItems: 'center',
            color: 'var(--text-muted)',
          }}
          type="button"
        >
          <X aria-hidden="true" size={14} />
        </button>
      )}
    </label>
  )
})
