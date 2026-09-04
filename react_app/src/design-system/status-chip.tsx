import clsx from 'clsx'

type StatusTone = 'positive' | 'negative' | 'warning' | 'info' | 'neutral'

const statusTone = (status: string): StatusTone => {
  const normalized = status.toLowerCase()
  if (/negative stock|overdue|failed|rejected|error|void|cancelled/.test(normalized)) return 'negative'
  if (/low stock|out of stock|reorder|pending|due|partial|draft|backorder|wave|in progress/.test(normalized)) return 'warning'
  if (/paid|received|reconciled|approved|active|connected|posted|confirmed|shipped|invoiced|completed|fully picked|in stock/.test(normalized)) return 'positive'
  if (/sent|info/.test(normalized)) return 'info'
  return 'neutral'
}

export function StatusChip({ status, children }: { status: string; children?: React.ReactNode }) {
  return <span className={clsx('status-chip', `status-chip--${statusTone(status)}`)}>{children ?? status}</span>
}
