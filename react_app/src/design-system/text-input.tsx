import { forwardRef, type InputHTMLAttributes, type ReactNode } from 'react'
import clsx from 'clsx'

export interface TextInputProps extends InputHTMLAttributes<HTMLInputElement> {
  leftIcon?: ReactNode
  rightIcon?: ReactNode
  isInvalid?: boolean
}

export const TextInput = forwardRef<HTMLInputElement, TextInputProps>(function TextInput(
  { leftIcon, rightIcon, isInvalid, className, ...props },
  ref
) {
  if (leftIcon || rightIcon) {
    return (
      <div className="input-with-icons" style={{ position: 'relative', display: 'flex', alignItems: 'center', width: '100%' }}>
        {leftIcon && (
          <span style={{ position: 'absolute', left: '10px', display: 'flex', alignItems: 'center', pointerEvents: 'none', color: 'var(--text-muted)' }}>
            {leftIcon}
          </span>
        )}
        <input
          ref={ref}
          className={clsx(className, isInvalid && 'field-input--error')}
          style={{
            paddingLeft: leftIcon ? '34px' : undefined,
            paddingRight: rightIcon ? '34px' : undefined,
          }}
          {...props}
        />
        {rightIcon && (
          <span style={{ position: 'absolute', right: '10px', display: 'flex', alignItems: 'center', pointerEvents: 'none', color: 'var(--text-muted)' }}>
            {rightIcon}
          </span>
        )}
      </div>
    )
  }

  return (
    <input
      ref={ref}
      className={clsx(className, isInvalid && 'field-input--error')}
      {...props}
    />
  )
})
