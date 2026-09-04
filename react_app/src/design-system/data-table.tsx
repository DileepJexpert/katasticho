import type { ComponentProps, ReactNode } from 'react'
import clsx from 'clsx'

type DataTableProps = ComponentProps<'table'> & {
  caption: string
  children: ReactNode
  scrollLabel?: string
}

export function DataTable({ caption, children, className, scrollLabel, ...props }: DataTableProps) {
  return (
    <div
      aria-label={scrollLabel ?? `${caption} table. Scroll horizontally to view all columns.`}
      className="data-table-scroll"
      role="region"
      tabIndex={0}
    >
      <table {...props} className={clsx('data-table', className)}>
        <caption className="sr-only">{caption}</caption>
        {children}
      </table>
    </div>
  )
}
