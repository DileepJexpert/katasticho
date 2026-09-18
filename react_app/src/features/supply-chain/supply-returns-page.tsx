import { useState } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { Button, DataTable, FilterTabs, Money, PageHeader, StatusChip, TablePagination } from '@/design-system'
import { useSessionStore } from '@/shared/session/session-store'
import { WorkspaceBoundary } from '@/shared/workflows/workspace-boundary'
import { QueryFeedback } from '@/shared/workflows/query-feedback'
import { ConfirmedAction } from '@/shared/workflows/confirmed-action'
import { listSupplyReturns, planningRoles, returnAction, type SupplyReturn } from './supply-chain-api'

export function SupplyReturnsPage() { return <WorkspaceBoundary roles={planningRoles}><Returns /></WorkspaceBoundary> }

function Returns() {
  const user = useSessionStore((s) => s.user!)
  const orgId = user.orgId
  const isOwnerOrAdmin = user.role === 'OWNER' || user.role === 'ADMIN'
  const client = useQueryClient()
  const [page, setPage] = useState(0)
  const [status, setStatus] = useState('')
  const [action, setAction] = useState<{ ret: SupplyReturn; type: 'approve' | 'process' | 'cancel' } | null>(null)
  const query = useQuery({ queryKey: ['supply', orgId, 'returns', status, page], queryFn: () => listSupplyReturns(page, status) })

  return <section className="workspace-page">
    <PageHeader eyebrow="Supply planning" title="Return request register" description="Review and manage supply-chain return orders." />
    <p className="banner">Supply returns track return requests and lifecycle status. Physical stock movements and financial settlements should be coordinated with inventory adjustments and debit notes. A recorded refund amount is not a payment.</p>
    <FilterTabs ariaLabel="Return status" activeValue={status} onChange={(v) => { setStatus(v); setPage(0) }} items={[{ value: '', label: 'All' }, ...['DRAFT', 'APPROVED', 'PROCESSED', 'CANCELLED'].map((v) => ({ value: v, label: v }))]} />
    <QueryFeedback query={query}><DataTable caption="Return requests"><thead><tr><th>Return</th><th>Type</th><th>Reason</th><th>Status</th><th className="numeric-cell">Recorded amount</th><th>Actions</th></tr></thead><tbody>{query.data?.content.map((r) => <tr key={r.id}><td className="table-code">{r.returnNumber}</td><td>{r.returnType}</td><td>{r.reasonNotes ?? r.reasonCode ?? '--'}</td><td><StatusChip status={r.status} /></td><td className="numeric-cell"><Money amount={r.totalAmount} /></td><td>
      {r.status === 'DRAFT' && (
        <>
          {isOwnerOrAdmin && <Button variant="ghost" onClick={() => setAction({ ret: r, type: 'approve' })}>Approve</Button>}
          <Button variant="ghost" onClick={() => setAction({ ret: r, type: 'cancel' })}>Cancel</Button>
        </>
      )}
      {r.status === 'APPROVED' && (
        <>
          <Button variant="ghost" onClick={() => setAction({ ret: r, type: 'process' })}>Process</Button>
          <Button variant="ghost" onClick={() => setAction({ ret: r, type: 'cancel' })}>Cancel</Button>
        </>
      )}
    </td></tr>)}</tbody></DataTable>{!query.data?.content.length && <div className="directory-state">No return requests found.</div>}<TablePagination page={page} totalPages={query.data?.totalPages ?? 0} totalElements={query.data?.totalElements ?? 0} onPageChange={setPage} itemLabel="return" /></QueryFeedback>
    {action && (
      <ConfirmedAction
        title={`${action.type.charAt(0).toUpperCase() + action.type.slice(1)} return ${action.ret.returnNumber}`}
        description={`Are you sure you want to ${action.type} return request ${action.ret.returnNumber}?`}
        destructive={action.type === 'cancel'}
        run={() => returnAction(action.ret.id, action.type)}
        onClose={() => setAction(null)}
        onDone={() => {
          setAction(null)
          void client.invalidateQueries({ queryKey: ['supply', orgId, 'returns'] })
        }}
      />
    )}
  </section>
}
