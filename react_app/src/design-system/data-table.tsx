import type { ComponentProps, ReactNode } from 'react'
import clsx from 'clsx'

type DataTableProps = ComponentProps<'table'> & {
  caption: string
  children: ReactNode
}

export function DataTable({ caption, children, className, ...props }: DataTableProps) {
  return (
    <div className="data-table-scroll">
      <table {...props} className={clsx('data-table', className)}>
        <caption className="sr-only">{caption}</caption>
        {children}
      </table>
    </div>
  )
}
