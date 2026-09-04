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
      <div className="form-checkbox-body">
        {displayLabel && <span>{displayLabel}</span>}
        {description && (
          <span className="form-checkbox-description">
            {description}
          </span>
        )}
      </div>
    </label>
  )
})
