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
      <div className="input-with-icons">
        {leftIcon && (
          <span className="input-with-icons__icon input-with-icons__icon--left">
            {leftIcon}
          </span>
        )}
        <input
          ref={ref}
          className={clsx(
            className,
            leftIcon && 'input-with-icons__input--left',
            rightIcon && 'input-with-icons__input--right',
            isInvalid && 'field-input--error'
          )}
          {...props}
        />
        {rightIcon && (
          <span className="input-with-icons__icon input-with-icons__icon--right">
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
