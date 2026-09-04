import React from 'react'

export interface FactListProps {
  children: React.ReactNode
  columns?: 1 | 2 | 3 | 4
  className?: string
  style?: React.CSSProperties
}

export function FactList({
  children,
  columns = 2,
  className = '',
  style,
}: FactListProps) {
  const colClass = columns === 3 ? 'form-grid--3col' : columns === 4 ? 'form-grid--4col' : ''
  return (
    <dl
      className={`document-facts ${colClass} ${className}`.trim()}
      style={style}
    >
      {children}
    </dl>
  )
}

export interface FactProps {
  label: string
  value?: React.ReactNode
  mono?: boolean
  className?: string
}

export function Fact({ label, value, mono = false, className = '' }: FactProps) {
  return (
    <div className={className}>
      <dt>{label}</dt>
      <dd style={mono ? { fontFamily: 'var(--font-mono)' } : undefined}>
        {value !== undefined && value !== null && value !== '' ? value : '--'}
      </dd>
    </div>
  )
}
