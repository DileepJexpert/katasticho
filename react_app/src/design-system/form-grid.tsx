import { type HTMLAttributes, type ReactNode } from 'react'
import clsx from 'clsx'

export interface FormGridProps extends HTMLAttributes<HTMLDivElement> {
  columns?: 1 | 2 | 3 | 4 | 'auto'
  children: ReactNode
}

export function FormGrid({ columns = 2, children, className, ...props }: FormGridProps) {
  const colClass =
    columns === 1
      ? 'form-grid'
      : columns === 2
      ? 'form-grid--2col'
      : columns === 3
      ? 'form-grid--3col'
      : columns === 4
      ? 'form-grid--4col'
      : 'form-grid--auto'

  return (
    <div className={clsx(colClass, className)} {...props}>
      {children}
    </div>
  )
}
