import type { ReactNode } from 'react'

export interface DocumentCardProps {
  children: ReactNode
  title?: string
  headerAction?: ReactNode
  variant?: 'default' | 'summary' | 'lines' | 'notes'
  className?: string
}

export function DocumentCard({
  children,
  title,
  headerAction,
  variant = 'default',
  className = '',
}: DocumentCardProps) {
  const variantClass =
    variant === 'summary'
      ? 'document-card--summary'
      : variant === 'lines'
        ? 'document-card--lines'
        : variant === 'notes'
          ? 'document-card--notes'
          : ''

  return (
    <section className={`document-card ${variantClass} ${className}`.trim()}>
      {title && (
        <div className="document-card__header">
          <h2>{title}</h2>
          {headerAction && <div className="document-card__header-action">{headerAction}</div>}
        </div>
      )}
      {children}
    </section>
  )
}
