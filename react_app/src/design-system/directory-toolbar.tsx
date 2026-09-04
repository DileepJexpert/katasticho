import type { ReactNode } from 'react'

export interface DirectoryToolbarProps {
  children?: ReactNode
  stacked?: boolean
  className?: string
  actions?: ReactNode
  ariaLabel?: string
}

export function DirectoryToolbar({
  children,
  stacked = false,
  className = '',
  actions,
  ariaLabel = 'Directory filters and controls',
}: DirectoryToolbarProps) {
  const baseClass = stacked ? 'list-toolbar list-toolbar--stacked' : 'list-toolbar'
  const combinedClass = className ? `${baseClass} ${className}` : baseClass

  return (
    <div aria-label={ariaLabel} className={combinedClass} role="region">
      {children}
      {actions && <div className="directory-toolbar-actions">{actions}</div>}
    </div>
  )
}
