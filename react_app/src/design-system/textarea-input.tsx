import { forwardRef, type TextareaHTMLAttributes } from 'react'
import clsx from 'clsx'

export interface TextAreaInputProps extends TextareaHTMLAttributes<HTMLTextAreaElement> {
  isInvalid?: boolean
}

export const TextAreaInput = forwardRef<HTMLTextAreaElement, TextAreaInputProps>(function TextAreaInput(
  { isInvalid, className, ...props },
  ref
) {
  return (
    <textarea
      ref={ref}
      className={clsx(className, isInvalid && 'field-input--error')}
      {...props}
    />
  )
})
