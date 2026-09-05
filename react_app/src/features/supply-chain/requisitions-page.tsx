import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { Button, DataTable, Fact, FactList, FilterTabs, FormCard, FormGrid, Modal, Money, PageHeader, Quantity, StatusChip, TablePagination } from '@/design-system'
import { TextField } from '@/design-system/text-field'
import type { Item } from '@/features/items/items-api'
import type { Supplier } from '@/features/suppliers/suppliers-api'
import type { Warehouse } from '@/features/warehouses/warehouses-api'
import { useSessionStore } from '@/shared/session/session-store'
import { WorkspaceBoundary } from '@/shared/workflows/workspace-boundary'
import { QueryFeedback } from '@/shared/workflows/query-feedback'
import { ConfirmedAction } from '@/shared/workflows/confirmed-action'
import { autoRequisition, createRequisition, getRequisition, listRequisitions, planningRoles, requisitionAction } from './supply-chain-api'
import { PlanningItemName, PlanningItemPicker, PlanningSupplierName, PlanningSupplierPicker, PlanningWarehousePicker, validNumber } from './planning-pickers'

export function RequisitionsPage() { return <WorkspaceBoundary roles={planningRoles}><RequisitionsWorkspace /></WorkspaceBoundary> }
function RequisitionsWorkspace() {
  const orgId = useSessionStore((s) => s.user!.orgId)
  const [page, setPage] = useState(0)
  const [status, setStatus] = useState('')
  const [create, setCreate] = useState(false)
  const [automatic, setAutomatic] = useState(false)
  const [notice, setNotice] = useState('')
  const client = useQueryClient()
  const navigate = useNavigate()
  const query = useQuery({ queryKey: ['supply', orgId, 'requisitions', status, page], queryFn: () => listRequisitions(page, status) })
  return <section className="workspace-page"><PageHeader eyebrow="Supply planning" title="Purchase requisitions" description="Request and approve planned purchases. Approval does not create a purchase order." actions={<><Button variant="secondary" onClick={() => setAutomatic(true)}>Draft from low stock</Button><Button onClick={() => setCreate(true)}>New requisition</Button></>} />
    {notice && <p role="status">{notice}</p>}
    <FilterTabs ariaLabel="Requisition status" activeValue={status} onChange={(value) => { setStatus(value); setPage(0) }} items={[{ value: '', label: 'All' }, ...['DRAFT', 'SUBMITTED', 'APPROVED', 'REJECTED'].map((v) => ({ value: v, label: v }))]} />
    <QueryFeedback query={query}><DataTable caption="Purchase requisitions"><thead><tr><th>Requisition</th><th>Required by</th><th>Source</th><th>Status</th><th className="numeric-cell">Estimated amount</th></tr></thead><tbody>{query.data?.content.map((r) => <tr key={r.id}><td><Link className="table-row-link table-code" to={`/supply-chain/requisitions/${r.id}`}>{r.requisitionNumber}</Link></td><td>{r.requiredByDate ?? '--'}</td><td>{r.source}</td><td><StatusChip status={r.status} /></td><td className="numeric-cell"><Money amount={r.totalAmount} /></td></tr>)}</tbody></DataTable>
      {!query.data?.content.length && <div className="directory-state">No requisitions found.</div>}<TablePagination page={page} totalPages={query.data?.totalPages ?? 0} totalElements={query.data?.totalElements ?? 0} onPageChange={setPage} itemLabel="requisition" /></QueryFeedback>
    {create && <RequisitionEditor onClose={() => setCreate(false)} onDone={(id) => { void client.invalidateQueries({ queryKey: ['supply', orgId] }); if (useSessionStore.getState().user?.orgId === orgId) navigate(`/supply-chain/requisitions/${id}`) }} />}
    {automatic && <ConfirmedAction title="Draft requisition from low stock" description="Create a draft from the backend low-stock scan? Repeated scans can create separate drafts; review existing requisitions first." run={async () => { const result = await autoRequisition(); setNotice(result ? `Created ${result.requisitionNumber}. Review it before submitting.` : 'No eligible low-stock items were found.') }} onClose={() => setAutomatic(false)} onDone={() => { setAutomatic(false); setPage(0); void client.invalidateQueries({ queryKey: ['supply', orgId] }) }} />}
  </section>
}
function RequisitionEditor({ onClose, onDone }: { onClose: () => void; onDone: (id: string) => void }) {
  const [supplier, setSupplier] = useState<Supplier | null>(null)
  const [warehouse, setWarehouse] = useState<Warehouse | null>(null)
  const [date, setDate] = useState('')
  const [notes, setNotes] = useState('')
  const [lines, setLines] = useState<{ key: string; item: Item | null; qty: string; price: string }[]>([{ key: crypto.randomUUID(), item: null, qty: '1', price: '0' }])
  const valid = lines.length > 0 && lines.every((line) => line.item && validNumber(line.qty) && +line.qty > 0 && validNumber(line.price)) && new Set(lines.map((l) => l.item?.id)).size === lines.length
  const save = useMutation({ mutationFn: () => createRequisition({ supplierId: supplier?.id, warehouseId: warehouse?.id, requiredByDate: date || undefined, notes, lines: lines.map((l) => ({ itemId: l.item!.id, requiredQty: +l.qty, estimatedUnitPrice: +l.price })) }), onSuccess: (r) => onDone(r.id) })
  return <Modal isOpen size="lg" title="New purchase requisition" error={save.error?.message} onClose={() => { if (!save.isPending) onClose() }} footer={<><Button variant="secondary" disabled={save.isPending} onClick={onClose}>Cancel</Button><Button disabled={!valid || save.isPending} onClick={() => save.mutate()}>Create draft</Button></>}>
    <FormGrid><PlanningSupplierPicker value={supplier} onChange={setSupplier} /><PlanningWarehousePicker value={warehouse} onChange={setWarehouse} /><TextField label="Required by" type="date" value={date} onChange={(e) => setDate(e.target.value)} /><TextField label="Notes" value={notes} onChange={(e) => setNotes(e.target.value)} /></FormGrid>
    {lines.map((line, index) => <FormCard key={line.key} title={`Line ${index + 1}`} headerAction={<Button variant="ghost" onClick={() => setLines(lines.filter((l) => l.key !== line.key))}>Remove line {index + 1}</Button>}><FormGrid>
      <PlanningItemPicker label={`Item ${index + 1}`} value={line.item} onChange={(item) => setLines(lines.map((l) => l.key === line.key ? { ...l, item, price: String(item?.purchasePrice ?? 0) } : l))} />
      <TextField label={`Quantity ${index + 1}`} type="number" min="0" step="any" value={line.qty} onChange={(e) => setLines(lines.map((l) => l.key === line.key ? { ...l, qty: e.target.value } : l))} />
      <TextField label={`Estimated unit price ${index + 1}`} type="number" min="0" step="any" value={line.price} onChange={(e) => setLines(lines.map((l) => l.key === line.key ? { ...l, price: e.target.value } : l))} />
    </FormGrid></FormCard>)}
    <Button variant="secondary" onClick={() => setLines([...lines, { key: crypto.randomUUID(), item: null, qty: '1', price: '0' }])}>Add line</Button>
    <p className="cell-muted">Select each item once with a positive quantity. Supplier and warehouse are optional. Server-calculated totals are shown after saving.</p>
  </Modal>
}
export function RequisitionDetailPage() {
  const { requisitionId = '' } = useParams()
  return <WorkspaceBoundary roles={planningRoles}><RequisitionDetail key={requisitionId} id={requisitionId} /></WorkspaceBoundary>
}
function RequisitionDetail({ id }: { id: string }) {
  const user = useSessionStore((s) => s.user!)
  const client = useQueryClient()
  const query = useQuery({ queryKey: ['supply', user.orgId, 'requisition', id], queryFn: () => getRequisition(id) })
  const [action, setAction] = useState<'submit' | 'approve' | 'reject' | null>(null)
  const record = query.data
  const approver = ['OWNER', 'ADMIN'].includes(user.role)
  return <section className="workspace-page"><Link to="/supply-chain/requisitions">Back to requisitions</Link><PageHeader eyebrow="Supply planning" title={record?.requisitionNumber ?? 'Requisition'} />
    <QueryFeedback query={query}>{record && <><FormCard title="Requisition details" headerAction={<StatusChip status={record.status} />}><FactList><Fact label="Required by" value={record.requiredByDate} /><Fact label="Supplier" value={record.supplierId ? <PlanningSupplierName id={record.supplierId} /> : 'Not assigned'} /><Fact label="Notes" value={record.notes} /><Fact label="Estimated total" value={<Money amount={record.totalAmount} />} /></FactList>
      {record.status === 'DRAFT' && <Button onClick={() => setAction('submit')}>Submit requisition</Button>}
      {approver && ['DRAFT', 'SUBMITTED'].includes(record.status) && <><Button onClick={() => setAction('approve')}>Approve requisition</Button><Button variant="secondary" onClick={() => setAction('reject')}>Reject requisition</Button></>}
    </FormCard><DataTable caption="Requisition lines"><thead><tr><th>Item</th><th className="numeric-cell">Required quantity</th><th className="numeric-cell">Estimated unit price</th><th className="numeric-cell">Estimated total</th></tr></thead><tbody>{record.lines.map((line) => <tr key={line.id}><td><PlanningItemName id={line.itemId} /></td><td className="numeric-cell"><Quantity value={line.requiredQty} /></td><td className="numeric-cell"><Money amount={line.estimatedUnitPrice} /></td><td className="numeric-cell"><Money amount={line.estimatedLineTotal} /></td></tr>)}</tbody></DataTable>
      <p className="banner">Approval is a planning decision only. The existing API does not provide requisition-to-PO conversion; no duplicate purchase order is created automatically.</p>{record.purchaseOrderId && <Link to={`/purchase-orders/${record.purchaseOrderId}`}>View linked purchase order</Link>}
    </>}</QueryFeedback>
    {action && <ConfirmedAction title={`${action} requisition`} description={`Confirm ${action}? This changes the requisition status, not stock or accounting.`} run={() => requisitionAction(id, action)} onClose={() => setAction(null)} onDone={() => { setAction(null); void client.invalidateQueries({ queryKey: ['supply', user.orgId] }) }} />}
  </section>
}
