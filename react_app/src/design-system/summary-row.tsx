import React from 'react'

export interface SummaryRowProps {
  label: string
  value: React.ReactNode
  isTotal?: boolean
  className?: string
  style?: React.CSSProperties
}

export function SummaryRow({
  label,
  value,
  isTotal = false,
  className = '',
  style,
}: SummaryRowProps) {
  return (
    <div
      className={`progress-row ${isTotal ? 'progress-row--total' : ''} ${className}`.trim()}
      style={style}
    >
      <span>{label}</span>
      {isTotal ? <strong>{value}</strong> : <div>{value}</div>}
    </div>
  )
}
