import { forwardRef, type InputHTMLAttributes, type ReactNode } from 'react'
import clsx from 'clsx'

export interface CheckboxInputProps extends Omit<InputHTMLAttributes<HTMLInputElement>, 'type'> {
  label?: ReactNode
  title?: string
  description?: ReactNode
}

export const CheckboxInput = forwardRef<HTMLInputElement, CheckboxInputProps>(function CheckboxInput(
  { label, title, description, className, style, ...props },
  ref
) {
  const displayLabel = label ?? title
  return (
    <label className={clsx('form-checkbox-label', className)} style={style}>
      <input ref={ref} type="checkbox" {...props} />
      <div style={{ display: 'flex', flexDirection: 'column', gap: '2px' }}>
        {displayLabel && <span>{displayLabel}</span>}
        {description && (
          <span style={{ fontSize: 'var(--text-xs)', color: 'var(--text-secondary)', fontWeight: 'var(--fw-regular)' }}>
            {description}
          </span>
        )}
      </div>
    </label>
  )
})
