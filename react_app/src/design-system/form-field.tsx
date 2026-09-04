import { forwardRef, type HTMLAttributes, type ReactNode } from 'react'
import clsx from 'clsx'

export interface FormFieldProps extends HTMLAttributes<HTMLDivElement> {
  label: string
  htmlFor?: string
  required?: boolean
  optional?: boolean
  error?: string
  hint?: string
  tooltip?: string
  span?: 1 | 2 | 3 | 4 | 'full'
  children: ReactNode
}

export const FormField = forwardRef<HTMLDivElement, FormFieldProps>(function FormField(
  { label, htmlFor, required, optional, error, hint, tooltip, span, children, className, ...props },
  ref
) {
  return (
    <div
      ref={ref}
      className={clsx(
        'field-group',
        span === 2 && 'field-group--span-2',
        span === 3 && 'field-group--span-3',
        span === 'full' && 'field-group--span-full',
        className
      )}
      {...props}
    >
      <div className="field-label-row" style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <label htmlFor={htmlFor} style={{ display: 'inline-flex', alignItems: 'center', gap: '4px', cursor: htmlFor ? 'pointer' : 'default' }}>
          <span>{label}</span>
          {required && <span style={{ color: 'var(--neg-text)', fontWeight: 'var(--fw-semibold)' }}>*</span>}
          {optional && <span style={{ color: 'var(--text-muted)', fontSize: '11px' }}>(optional)</span>}
        </label>
        {tooltip && (
          <span className="field-tooltip" style={{ cursor: 'help', color: 'var(--text-muted)', fontSize: '12px' }} title={tooltip}>
            ℹ
          </span>
        )}
      </div>
      {children}
      {error ? (
        <small className="field-error" role="alert" style={{ color: 'var(--neg-text)', fontSize: 'var(--text-xs)' }}>
          {error}
        </small>
      ) : hint ? (
        <small className="field-hint" style={{ color: 'var(--text-muted)', fontSize: 'var(--text-xs)' }}>
          {hint}
        </small>
      ) : null}
    </div>
  )
})
