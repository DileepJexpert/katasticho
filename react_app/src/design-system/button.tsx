import { LoaderCircle } from 'lucide-react'
import { forwardRef, type ButtonHTMLAttributes, type ReactNode } from 'react'
import clsx from 'clsx'

type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: 'primary' | 'secondary' | 'ghost' | 'destructive'
  loading?: boolean
  children: ReactNode
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(function Button(
  { children, className, disabled, loading = false, type = 'button', variant = 'primary', ...props },
  ref,
) {
  return (
    <button
      {...props}
      className={clsx('button', `button--${variant}`, className)}
      disabled={disabled || loading}
      ref={ref}
      type={type}
    >
      {loading && <LoaderCircle className="button-spinner" size={16} aria-hidden="true" />}
      {children}
    </button>
  )
})
