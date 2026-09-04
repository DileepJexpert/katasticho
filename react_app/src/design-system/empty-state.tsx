import type { ReactNode } from 'react'
import type { LucideIcon } from 'lucide-react'

export interface EmptyStateProps {
  icon?: LucideIcon
  title: string
  description?: ReactNode
  action?: ReactNode
  secondaryAction?: ReactNode
  className?: string
}

export function EmptyState({
  icon: Icon,
  title,
  description,
  action,
  secondaryAction,
  className = '',
}: EmptyStateProps) {
  return (
    <div className={`directory-state ${className}`.trim()} role="status">
      {Icon && <Icon aria-hidden="true" size={28} className="directory-state__icon" />}
      <strong>{title}</strong>
      {description && <p>{description}</p>}
      {(action || secondaryAction) && (
        <div className="directory-state__actions">
          {action}
          {secondaryAction}
        </div>
      )}
    </div>
  )
}
