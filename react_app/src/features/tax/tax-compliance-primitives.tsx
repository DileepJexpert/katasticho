import { type ReactNode } from 'react'
import clsx from 'clsx'

export interface ComplianceMetricProps {
  label: string
  value: ReactNode
  tone?: 'default' | 'brand' | 'positive'
}

export function ComplianceMetric({ label, value, tone = 'default' }: ComplianceMetricProps) {
  return (
    <div className="compliance-metric">
      <span className="compliance-metric__label">{label}</span>
      <strong className={clsx('compliance-metric__value', `compliance-metric__value--${tone}`)}>
        {value}
      </strong>
    </div>
  )
}

export function ComplianceMetricGrid({ children }: { children: ReactNode }) {
  return <div className="compliance-metric-grid">{children}</div>
}

export function CompliancePanel({ children, className }: { children: ReactNode; className?: string }) {
  return <div className={clsx('compliance-panel', className)}>{children}</div>
}

export function CompliancePeriodToolbar({
  controls,
  actions,
}: {
  controls: ReactNode
  actions?: ReactNode
}) {
  return (
    <div className="compliance-period-toolbar">
      <div className="compliance-period-toolbar__controls">{controls}</div>
      {actions && <div className="table-actions">{actions}</div>}
    </div>
  )
}
