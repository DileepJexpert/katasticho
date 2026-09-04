import { forwardRef, type InputHTMLAttributes } from 'react'
import clsx from 'clsx'

export interface NumberInputProps extends Omit<InputHTMLAttributes<HTMLInputElement>, 'type'> {
  currencyPrefix?: boolean | string
  unitSuffix?: string
  isInvalid?: boolean
}

export const NumberInput = forwardRef<HTMLInputElement, NumberInputProps>(function NumberInput(
  { currencyPrefix, unitSuffix, isInvalid, className, style, ...props },
  ref
) {
  const prefix = typeof currencyPrefix === 'string' ? currencyPrefix : currencyPrefix ? '₹' : null

  if (prefix || unitSuffix) {
    return (
      <div className="number-input-wrap">
        {prefix && (
          <span className="number-input-prefix">
            {prefix}
          </span>
        )}
        <input
          ref={ref}
          type="number"
          className={clsx(
            'number-input',
            prefix && 'number-input--prefix',
            unitSuffix && 'number-input--suffix',
            className,
            isInvalid && 'field-input--error'
          )}
          style={style}
          {...props}
        />
        {unitSuffix && (
          <span className="number-input-suffix">
            {unitSuffix}
          </span>
        )}
      </div>
    )
  }

  return (
    <input
      ref={ref}
      type="number"
      className={clsx('number-input', className, isInvalid && 'field-input--error')}
      style={style}
      {...props}
    />
  )
})
