import { forwardRef, type InputHTMLAttributes } from 'react'
import clsx from 'clsx'

type TextFieldProps = InputHTMLAttributes<HTMLInputElement> & {
  label: string
  error?: string
  hint?: string
}

export const TextField = forwardRef<HTMLInputElement, TextFieldProps>(function TextField(
  { className, error, hint, id, label, ...props },
  ref,
) {
  const fieldId = id ?? props.name
  return (
    <label className="field" htmlFor={fieldId}>
      <span>{label}</span>
      <input {...props} aria-invalid={Boolean(error)} className={clsx({ 'field-input--error': error }, className)} id={fieldId} ref={ref} />
      {error ? <small className="field-error">{error}</small> : hint ? <small className="field-hint">{hint}</small> : null}
    </label>
  )
})
