import { type HTMLAttributes, type ReactNode } from 'react'
import clsx from 'clsx'

export interface FormCardProps extends HTMLAttributes<HTMLDivElement> {
  stepNumber?: number | string
  title: string
  description?: string
  headerAction?: ReactNode
  children: ReactNode
}

export function FormCard({
  stepNumber,
  title,
  description,
  headerAction,
  children,
  className,
  ...props
}: FormCardProps) {
  return (
    <div className={clsx('form-card', className)} {...props}>
      <div className="form-card-header">
        <div>
          <h2 className="form-card-title">
            {stepNumber ? `${stepNumber}. ` : ''}{title}
          </h2>
          {description && <p className="form-card-description">{description}</p>}
        </div>
        {headerAction && <div>{headerAction}</div>}
      </div>
      {children}
    </div>
  )
}
