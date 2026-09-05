import { useQuery } from '@tanstack/react-query'
import { Money, PageHeader, Quantity } from '@/design-system'
import { useSessionStore } from '@/shared/session/session-store'
import { WorkspaceBoundary } from '@/shared/workflows/workspace-boundary'
import { QueryFeedback } from '@/shared/workflows/query-feedback'
import { LocalDirectory } from '@/shared/workflows/local-directory'
import { listSupplierRankings, planningRoles } from './supply-chain-api'

export function SupplierPerformancePage() { return <WorkspaceBoundary roles={planningRoles}><Performance /></WorkspaceBoundary> }
function Performance() {
  const orgId = useSessionStore((s) => s.user!.orgId)
  const query = useQuery({ queryKey: ['supply', orgId, 'performance'], queryFn: listSupplierRankings })
  return <section className="workspace-page"><PageHeader eyebrow="Supply planning" title="Supplier performance history" description="Review recorded supplier scores by period; these are not live delivery measurements." /><p className="banner">Recalculation is not exposed until the backend purchase-order/GRN query contract is verified. The stored overall score currently represents the quality rate, not an on-time delivery score.</p>
    <QueryFeedback query={query}><LocalDirectory rows={query.data ?? []} caption="Supplier performance" searchText={(p) => `${p.supplierName ?? ''} ${p.periodStart} ${p.periodEnd}`} header={<tr><th>Supplier</th><th>Period</th><th>Orders</th><th className="numeric-cell">Ordered</th><th className="numeric-cell">Received</th><th className="numeric-cell">Quality (%)</th><th className="numeric-cell">Recorded amount</th></tr>} renderRow={(p) => <tr key={p.id}><td>{p.supplierName ?? 'Supplier name unavailable'}</td><td>{p.periodStart} to {p.periodEnd}</td><td>{p.totalOrders}</td><td className="numeric-cell"><Quantity value={p.totalQtyOrdered} /></td><td className="numeric-cell"><Quantity value={p.totalQtyReceived} /></td><td className="numeric-cell"><Quantity value={p.qualityRate} /></td><td className="numeric-cell"><Money amount={p.totalAmount} /></td></tr>} /></QueryFeedback>
  </section>
}
