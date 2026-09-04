import { forwardRef, type SelectHTMLAttributes } from 'react'
import clsx from 'clsx'

export interface SelectOption {
  value: string | number
  label: string
  disabled?: boolean
}

export interface SelectInputProps extends SelectHTMLAttributes<HTMLSelectElement> {
  options?: readonly SelectOption[]
  placeholderOption?: string
  isInvalid?: boolean
}

export const SelectInput = forwardRef<HTMLSelectElement, SelectInputProps>(function SelectInput(
  { options, placeholderOption, isInvalid, children, className, ...props },
  ref
) {
  return (
    <select
      ref={ref}
      className={clsx(className, isInvalid && 'field-input--error')}
      {...props}
    >
      {placeholderOption && <option value="">{placeholderOption}</option>}
      {options
        ? options.map((opt) => (
            <option key={opt.value} value={opt.value} disabled={opt.disabled}>
              {opt.label}
            </option>
          ))
        : children}
    </select>
  )
})
