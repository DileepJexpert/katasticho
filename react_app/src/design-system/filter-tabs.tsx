export interface FilterTabOption<T extends string = string> {
  value: T
  label: string
  count?: number
}

export interface FilterTabsProps<T extends string = string> {
  items: readonly FilterTabOption<T>[]
  activeValue: T
  onChange: (value: T) => void
  ariaLabel?: string
  className?: string
}

export function FilterTabs<T extends string = string>({
  items,
  activeValue,
  onChange,
  ariaLabel = 'Filter by status',
  className = '',
}: FilterTabsProps<T>) {
  return (
    <div aria-label={ariaLabel} className={`role-tabs ${className}`.trim()} role="tablist">
      {items.map((option) => {
        const isActive = activeValue === option.value
        return (
          <button
            aria-selected={isActive}
            className={isActive ? 'role-tab role-tab--active' : 'role-tab'}
            key={option.value}
            onClick={() => onChange(option.value)}
            role="tab"
            type="button"
          >
            <span>{option.label}</span>
            {option.count !== undefined && <span>({option.count})</span>}
          </button>
        )
      })}
    </div>
  )
}
