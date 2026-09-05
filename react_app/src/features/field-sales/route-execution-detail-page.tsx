import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Link, useParams } from 'react-router-dom'
import { Button, Fact, FactList, FormCard, FormField, Modal, Money, PageHeader, Quantity, SelectInput, StatusChip } from '@/design-system'
import { TextField } from '@/design-system/text-field'
import { getContact } from '@/features/contacts/contacts-api'
import { useSessionStore } from '@/shared/session/session-store'
import { ConfirmedAction } from '@/shared/workflows/confirmed-action'
import { LocalDirectory } from '@/shared/workflows/local-directory'
import { QueryFeedback } from '@/shared/workflows/query-feedback'
import { WorkspaceBoundary } from '@/shared/workflows/workspace-boundary'
import { checkInVisit, checkOutVisit, completeRoute, getExecution, getExecutionVisits, getRoute, recordVisitCollection, recordVisitOrder, skipVisit, startRoute, type FieldVisit } from './field-sales-api'
import { captureVisitLocation } from './visit-location'

export function RouteExecutionDetailPage() {
  const { executionId = '' } = useParams()
  return <WorkspaceBoundary roles={['OWNER', 'ADMIN', 'OPERATOR']}><ExecutionDetail key={executionId} id={executionId} /></WorkspaceBoundary>
}
function ExecutionDetail({ id }: { id: string }) {
  const user = useSessionStore((s) => s.user!)
  const client = useQueryClient()
  const execution = useQuery({ queryKey: ['field-sales', user.orgId, 'execution', id], queryFn: () => getExecution(id) })
  const visits = useQuery({ queryKey: ['field-sales', user.orgId, 'visits', id], queryFn: () => getExecutionVisits(id) })
  const route = useQuery({ queryKey: ['field-route', user.orgId, execution.data?.routeId], queryFn: () => getRoute(execution.data!.routeId), enabled: !!execution.data?.routeId })
  const [lifecycle, setLifecycle] = useState<'start' | 'complete' | null>(null)
  const [action, setAction] = useState<{ type: 'order' | 'collection' | 'skip'; visit: FieldVisit } | null>(null)
  const refresh = () => { void client.invalidateQueries({ queryKey: ['field-sales'] }) }
  const gps = useMutation({ mutationFn: async ({ visitId, checkOut }: { visitId: string; checkOut: boolean }) => {
    const position = await captureVisitLocation()
    const current = useSessionStore.getState().user
    if (current?.id !== user.id || current.orgId !== user.orgId) throw new Error('The workspace changed. No visit action was sent.')
    return checkOut ? checkOutVisit(visitId, undefined, position.latitude, position.longitude) : checkInVisit(visitId, position.latitude, position.longitude)
  }, onSuccess: refresh })
  const run = execution.data
  const assigned = run?.salespersonId === user.id
  const canRun = assigned || ['OWNER', 'ADMIN'].includes(user.role)
  return <section className="workspace-page"><Link to="/field-sales/executions">Back to route executions</Link><PageHeader eyebrow="Field sales" title={route.data?.name ?? 'Route execution'} description={run?.executionDate} />
    <QueryFeedback query={execution}>{run && <FormCard title="Execution summary" headerAction={<StatusChip status={run.status} />}><FactList><Fact label="Planned visits" value={run.plannedVisits ?? 0} /><Fact label="Completed visits" value={run.completedVisits ?? 0} /><Fact label="Order value" value={<Money amount={run.totalOrdersValue ?? 0} />} /><Fact label="Collections" value={<Money amount={run.totalCollections ?? 0} />} /><Fact label="Audit notes" value={run.notes} /></FactList><div className="document-actions">{canRun && run.status === 'PLANNED' && <Button onClick={() => setLifecycle('start')}>Start field run</Button>}{canRun && run.status === 'IN_PROGRESS' && <Button variant="secondary" onClick={() => setLifecycle('complete')}>Complete route run</Button>}{canRun && run.status === 'COMPLETED' && <Link to={`/field-sales/day-close?executionId=${encodeURIComponent(id)}`}>Open day close</Link>}</div>{!assigned && <p>Visit actions are available only to the assigned salesperson, including when signed in as an administrator.</p>}</FormCard>}</QueryFeedback>
    {gps.error && <p role="alert" className="form-error">{gps.error.message}</p>}
    <p>Check-in and check-out request your current device location. No default or fabricated coordinates are sent.</p>
    <QueryFeedback query={visits}><LocalDirectory rows={visits.data ?? []} caption="Customer stops" searchText={(visit) => `${visit.contactName ?? ''} ${visit.status} ${visit.sequenceNumber ?? ''}`} header={<tr><th>Sequence</th><th>Customer</th><th>Status</th><th>Location check</th><th className="numeric-cell">Order value</th><th className="numeric-cell">Collection</th><th>Actions</th></tr>} renderRow={(visit) => <tr key={visit.id}><td>{visit.sequenceNumber ?? '--'}</td><td><VisitContactName id={visit.contactId} /></td><td><StatusChip status={visit.status} /></td><td>{visit.geoVerified == null ? '--' : visit.geoVerified ? 'Within geofence' : <>Outside geofence: <Quantity value={visit.geoDistanceM ?? 0} /> m</>}</td><td className="numeric-cell"><Money amount={visit.orderValue ?? 0} /></td><td className="numeric-cell"><Money amount={visit.collectionAmount ?? 0} /></td><td>{assigned && run?.status === 'IN_PROGRESS' && <div className="table-actions">{visit.status === 'PLANNED' && <><Button variant="secondary" disabled={gps.isPending} onClick={() => gps.mutate({ visitId: visit.id, checkOut: false })}>Check in</Button><Button variant="ghost" onClick={() => setAction({ type: 'skip', visit })}>Skip</Button></>}{visit.status === 'IN_PROGRESS' && <><Button variant="secondary" onClick={() => setAction({ type: 'order', visit })}>Record order value</Button><Button variant="secondary" disabled={!!visit.customerReceiptId} onClick={() => setAction({ type: 'collection', visit })}>{visit.customerReceiptId ? 'Receipt recorded' : 'Record collection'}</Button><Button disabled={gps.isPending} onClick={() => gps.mutate({ visitId: visit.id, checkOut: true })}>Check out</Button></>}</div>}</td></tr>} /></QueryFeedback>
    {lifecycle && <ConfirmedAction title={lifecycle === 'start' ? 'Start route' : 'Complete route'} description={lifecycle === 'start' ? 'Start this planned route execution?' : 'Complete this route after finishing or skipping every customer stop?'} run={() => lifecycle === 'start' ? startRoute(id) : completeRoute(id)} onClose={() => setLifecycle(null)} onDone={() => { setLifecycle(null); refresh() }} />}
    {action && <VisitAction key={`${action.visit.id}:${action.type}`} type={action.type} visit={action.visit} onClose={() => setAction(null)} onDone={() => { setAction(null); refresh() }} />}
  </section>
}
function VisitContactName({ id }: { id: string }) {
  const orgId = useSessionStore((s) => s.user!.orgId)
  const query = useQuery({ queryKey: ['visit-contact', orgId, id], queryFn: () => getContact(id) })
  return <span>{query.data?.displayName ?? (query.isError ? 'Customer unavailable' : 'Loading customer...')}</span>
}
function VisitAction({ type, visit, onClose, onDone }: { type: 'order' | 'collection' | 'skip'; visit: FieldVisit; onClose: () => void; onDone: () => void }) {
  const [amount, setAmount] = useState(type === 'order' ? String(visit.orderValue ?? '') : '')
  const [mode, setMode] = useState('CASH')
  const [text, setText] = useState('')
  const valid = type === 'skip' ? !!text.trim() : amount.trim() !== '' && Number.isFinite(Number(amount)) && Number(amount) > 0
  const save = useMutation({ mutationFn: () => type === 'skip' ? skipVisit(visit.id, text.trim()) : type === 'order' ? recordVisitOrder(visit.id, undefined, Number(amount)) : recordVisitCollection(visit.id, Number(amount), mode, text.trim() || undefined), onSuccess: onDone, retry: false })
  const title = type === 'skip' ? 'Skip visit' : type === 'order' ? 'Record visit order value' : 'Record customer collection'
  return <Modal isOpen title={title} onClose={() => { if (!save.isPending) onClose() }} error={save.error?.message} footer={<><Button variant="secondary" disabled={save.isPending} onClick={onClose}>Cancel</Button><Button disabled={!valid || save.isPending} loading={save.isPending} onClick={() => save.mutate()}>Confirm {type}</Button></>}><VisitContactName id={visit.contactId} />{type === 'order' && <p>This updates the visit's recorded order value; it does not create a sales order or invoice. Existing document links are preserved. Use Sales Orders for a real order.</p>}{type === 'collection' && <p>This creates a real customer receipt. The backend allocates it oldest-invoice-first and treats any remainder as advance. One receipt is supported per visit; repeated requests return that existing receipt.</p>}{type !== 'skip' && <TextField label="Amount" type="number" min="0" step="any" value={amount} onChange={(e) => setAmount(e.target.value)} />}{type === 'collection' && <FormField label="Payment method"><SelectInput value={mode} onChange={(e) => setMode(e.target.value)}>{['CASH', 'UPI', 'CHEQUE', 'NEFT'].map((value) => <option key={value}>{value}</option>)}</SelectInput></FormField>}{type !== 'order' && <TextField label={type === 'skip' ? 'Reason' : 'Reference number'} required={type === 'skip'} value={text} onChange={(e) => setText(e.target.value)} />}</Modal>
}
