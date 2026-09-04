import {
  cloneElement,
  forwardRef,
  isValidElement,
  useId,
  type HTMLAttributes,
  type ReactElement,
  type ReactNode,
} from 'react'
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
  const autoId = useId()
  const inputId = htmlFor || autoId

  const renderedChild =
    isValidElement(children) &&
    typeof children.type !== 'string' &&
    !('id' in (children.props as object) && Boolean((children.props as { id?: string }).id))
      ? cloneElement(children as ReactElement<{ id?: string }>, { id: inputId })
      : children

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
      <div className="field-label-row">
        <label htmlFor={inputId}>
          <span>{label}</span>
          {required && <span className="field-required-mark">*</span>}
          {optional && <span className="field-optional-tag">(optional)</span>}
        </label>
        {tooltip && (
          <span className="field-tooltip" title={tooltip}>
            ℹ
          </span>
        )}
      </div>
      {renderedChild}
      {error ? (
        <small className="field-error" role="alert">
          {error}
        </small>
      ) : hint ? (
        <small className="field-hint">
          {hint}
        </small>
      ) : null}
    </div>
  )
})

