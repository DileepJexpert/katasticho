import type { ReactNode } from 'react'
import { Button } from '@/design-system'

export function QueryFeedback({ query, children }: {
  query: { isPending: boolean; isError: boolean; error: Error | null; refetch: () => unknown }; children: ReactNode
}) {
  if (query.isPending) return <div className="directory-state" role="status">Loading records...</div>
  if (query.isError) return <div className="directory-state directory-state--error" role="alert">{query.error?.message ?? 'Unable to load records.'}<Button variant="secondary" onClick={() => query.refetch()}>Retry</Button></div>
  return children
}
