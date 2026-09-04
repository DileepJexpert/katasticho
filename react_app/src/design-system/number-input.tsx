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
      <div style={{ position: 'relative', display: 'flex', alignItems: 'center', width: '100%' }}>
        {prefix && (
          <span style={{ position: 'absolute', left: '10px', color: 'var(--text-secondary)', fontSize: 'var(--text-sm)', fontWeight: 'var(--fw-medium)', pointerEvents: 'none' }}>
            {prefix}
          </span>
        )}
        <input
          ref={ref}
          type="number"
          className={clsx(className, isInvalid && 'field-input--error')}
          style={{
            paddingLeft: prefix ? '26px' : undefined,
            paddingRight: unitSuffix ? '44px' : undefined,
            textAlign: 'right',
            fontVariantNumeric: 'tabular-nums',
            ...style,
          }}
          {...props}
        />
        {unitSuffix && (
          <span style={{ position: 'absolute', right: '10px', color: 'var(--text-muted)', fontSize: 'var(--text-xs)', pointerEvents: 'none' }}>
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
      className={clsx(className, isInvalid && 'field-input--error')}
      style={{ textAlign: 'right', fontVariantNumeric: 'tabular-nums', ...style }}
      {...props}
    />
  )
})
