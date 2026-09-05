import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Button, DataTable, DocumentCard, TablePagination } from '@/design-system'
import { apiFetch } from '@/api/client/api-client'
import { useSessionStore } from '@/shared/session/session-store'
import { formatDateTime } from '@/shared/format/format'

export type EstimateComment = { id: string; commentText: string; system: boolean; createdByName: string | null; createdAt: string }
type CommentPage = { content: EstimateComment[]; totalElements: number; totalPages: number; number: number }

export function EstimateActivity({ estimateId }: { estimateId: string }) {
  const orgId = useSessionStore((state) => state.user?.orgId)
  const [page, setPage] = useState(0)
  const query = useQuery({ queryKey: ['estimate-comments', orgId, estimateId, page], queryFn: () => apiFetch<CommentPage>(`/api/v1/comments/ESTIMATE/${encodeURIComponent(estimateId)}?page=${page}&size=20`), enabled: Boolean(orgId && estimateId) })
  return <DocumentCard title="Activity and comments">
    {query.isPending ? <p role="status">Loading activity...</p> : query.isError ? <div role="alert">{query.error.message}<Button variant="secondary" onClick={() => void query.refetch()}>Retry activity</Button></div> : <>
      <DataTable caption="Estimate activity"><thead><tr><th>When</th><th>Author</th><th>Event / comment</th></tr></thead><tbody>{query.data.content.map((entry) => <tr key={entry.id}><td>{formatDateTime(entry.createdAt)}</td><td>{entry.system ? 'System' : entry.createdByName || 'Team member'}</td><td>{entry.commentText}</td></tr>)}</tbody></DataTable>
      {!query.data.content.length && <p className="cell-muted">No recorded activity on this page.</p>}
      <TablePagination page={page} totalPages={query.data.totalPages} totalElements={query.data.totalElements} itemLabel="event" filterDescription="for this estimate" onPageChange={setPage} />
    </>}
  </DocumentCard>
}
