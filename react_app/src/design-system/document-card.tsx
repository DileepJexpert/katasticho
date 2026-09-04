import React from 'react'

export interface DocumentCardProps {
  children: React.ReactNode
  title?: string
  headerAction?: React.ReactNode
  variant?: 'default' | 'summary' | 'lines' | 'notes'
  className?: string
  style?: React.CSSProperties
}

export function DocumentCard({
  children,
  title,
  headerAction,
  variant = 'default',
  className = '',
  style,
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
    <section className={`document-card ${variantClass} ${className}`.trim()} style={style}>
      {title && (
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 'var(--space-3)' }}>
          <h2 style={{ margin: 0 }}>{title}</h2>
          {headerAction && <div>{headerAction}</div>}
        </div>
      )}
      {children}
    </section>
  )
}
