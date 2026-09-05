import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { DataTable, FilterTabs, Money, PageHeader, StatusChip, TablePagination } from '@/design-system'
import { useSessionStore } from '@/shared/session/session-store'
import { WorkspaceBoundary } from '@/shared/workflows/workspace-boundary'
import { QueryFeedback } from '@/shared/workflows/query-feedback'
import { listSupplyReturns, planningRoles } from './supply-chain-api'

export function SupplyReturnsPage() { return <WorkspaceBoundary roles={planningRoles}><Returns /></WorkspaceBoundary> }
function Returns() {
  const orgId = useSessionStore((s) => s.user!.orgId)
  const [page, setPage] = useState(0)
  const [status, setStatus] = useState('')
  const query = useQuery({ queryKey: ['supply', orgId, 'returns', status, page], queryFn: () => listSupplyReturns(page, status) })
  return <section className="workspace-page"><PageHeader eyebrow="Supply planning" title="Return request register" description="Read-only review of existing supply-chain return records." />
    <p className="banner">Return processing is unavailable here: the existing endpoint changes status only and does not move stock, create a credit note or issue a refund. A recorded refund amount is not a payment. Use the verified credit/debit-note workflows instead.</p>
    <FilterTabs ariaLabel="Return status" activeValue={status} onChange={(v) => { setStatus(v); setPage(0) }} items={[{ value: '', label: 'All' }, ...['DRAFT', 'APPROVED', 'PROCESSED', 'CANCELLED'].map((v) => ({ value: v, label: v }))]} />
    <QueryFeedback query={query}><DataTable caption="Return requests"><thead><tr><th>Return</th><th>Type</th><th>Reason</th><th>Status</th><th className="numeric-cell">Recorded amount</th></tr></thead><tbody>{query.data?.content.map((r) => <tr key={r.id}><td className="table-code">{r.returnNumber}</td><td>{r.returnType}</td><td>{r.reasonNotes ?? r.reasonCode ?? '--'}</td><td><StatusChip status={r.status} /></td><td className="numeric-cell"><Money amount={r.totalAmount} /></td></tr>)}</tbody></DataTable>{!query.data?.content.length && <div className="directory-state">No return requests found.</div>}<TablePagination page={page} totalPages={query.data?.totalPages ?? 0} totalElements={query.data?.totalElements ?? 0} onPageChange={setPage} itemLabel="return" /></QueryFeedback>
  </section>
}
