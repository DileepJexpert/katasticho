import { useState } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { Button, DataTable, FilterTabs, PageHeader, StatusChip, TablePagination } from '@/design-system'
import { useSessionStore } from '@/shared/session/session-store'
import { WorkspaceBoundary } from '@/shared/workflows/workspace-boundary'
import { QueryFeedback } from '@/shared/workflows/query-feedback'
import { ConfirmedAction } from '@/shared/workflows/confirmed-action'
import { listSupplyAlerts, planningRoles, resolveSupplyAlert, scanSupplyAlerts, type SupplyAlert } from './supply-chain-api'

export function SupplyAlertsPage() { return <WorkspaceBoundary roles={planningRoles}><Alerts /></WorkspaceBoundary> }
function Alerts() {
  const orgId = useSessionStore((s) => s.user!.orgId)
  const client = useQueryClient()
  const [status, setStatus] = useState('OPEN')
  const [page, setPage] = useState(0)
  const [action, setAction] = useState<SupplyAlert | 'scan' | null>(null)
  const query = useQuery({ queryKey: ['supply', orgId, 'alerts', status, page], queryFn: () => listSupplyAlerts(page, status) })
  return <section className="workspace-page"><PageHeader eyebrow="Supply planning" title="Supply alerts" description="Review signals and acknowledge resolved issues. Resolving an alert does not replenish stock." actions={<Button onClick={() => setAction('scan')}>Scan for alerts</Button>} />
    <FilterTabs ariaLabel="Alert status" activeValue={status} onChange={(v) => { setStatus(v); setPage(0) }} items={[{ value: 'OPEN', label: 'Open' }, { value: 'RESOLVED', label: 'Resolved' }, { value: '', label: 'All' }]} />
    <QueryFeedback query={query}><DataTable caption="Supply alerts"><thead><tr><th>Alert</th><th>Details</th><th>Severity</th><th>Status</th><th>Action</th></tr></thead><tbody>{query.data?.content.map((a) => <tr key={a.id}><td>{a.title}</td><td>{a.description}</td><td><StatusChip status={a.severity} /></td><td><StatusChip status={a.status} /></td><td>{a.status === 'OPEN' && <Button variant="ghost" onClick={() => setAction(a)}>Resolve {a.title}</Button>}</td></tr>)}</tbody></DataTable>{!query.data?.content.length && <div className="directory-state">No alerts found.</div>}<TablePagination page={page} totalPages={query.data?.totalPages ?? 0} totalElements={query.data?.totalElements ?? 0} onPageChange={setPage} itemLabel="alert" /></QueryFeedback>
    {action && <ConfirmedAction title={action === 'scan' ? 'Scan supply alerts' : 'Resolve alert'} description={action === 'scan' ? 'Run an organisation-wide scan? The existing scan may create new alert records each time.' : `Mark ${action.title} resolved? Verify the underlying issue first.`} run={() => action === 'scan' ? scanSupplyAlerts() : resolveSupplyAlert(action.id)} onClose={() => setAction(null)} onDone={() => { setAction(null); void client.invalidateQueries({ queryKey: ['supply', orgId] }) }} />}
  </section>
}
