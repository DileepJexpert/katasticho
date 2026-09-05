import { useState, type FormEvent } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Link, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button, DataTable, DocumentCard, Fact, FactList, FormField, Modal, NumberInput, PageHeader, Quantity, StatusChip, TextAreaInput } from '@/design-system'
import { formatDateTime } from '@/shared/format/format'
import { useInventoryAccess } from '@/features/inventory/inventory-access'
import { BatchAllocationPicker } from '@/features/inventory/batch-allocation-picker'
import { cancelPicklist, completePicklist, getPicklist, startPicklist, updatePicklistLines, type PicklistLine } from './picklists-api'
import { PickProgress } from './pick-progress'

export function PicklistDetailPage() {
  const { picklistId } = useParams()
  const client = useQueryClient()
  const access = useInventoryAccess()
  const [editing, setEditing] = useState<PicklistLine | null>(null)
  const [action, setAction] = useState<'start' | 'complete' | 'cancel' | null>(null)
  const query = useQuery({ queryKey: ['picklists', picklistId], queryFn: () => getPicklist(picklistId!), enabled: Boolean(picklistId) })
  const mutation = useMutation({
    mutationFn: async (next: 'start' | 'complete' | 'cancel') => {
      if (next === 'cancel') await cancelPicklist(picklistId!)
      else if (next === 'start') await startPicklist(picklistId!)
      else await completePicklist(picklistId!)
    },
    onSuccess: () => { setAction(null); void client.invalidateQueries({ queryKey: ['picklists'] }) },
  })
  if (!picklistId) return <section className="workspace-page"><p role="alert">No picklist selected.</p></section>
  if (query.isPending) return <section className="workspace-page"><p role="status">Loading picklist...</p></section>
  if (query.isError || !query.data) return <section className="workspace-page"><p role="alert">{query.error?.message ?? 'Picklist unavailable.'}</p><Button onClick={() => void query.refetch()}>Retry</Button></section>
  const document = query.data
  const pending = document.status === 'PENDING'
  const running = document.status === 'IN_PROGRESS'
  const shortLines = document.lines.filter((line) => Number(line.pickedQuantity) < Number(line.requiredQuantity)).length
  function openAction(next: 'start' | 'complete' | 'cancel') { mutation.reset(); setAction(next) }
  return <section className="workspace-page">
    <Link className="form-back-link" to={appRoutes.picklists}>Back to picklists</Link>
    <PageHeader eyebrow="Inventory / Picking" title={document.picklistNumber} description={document.warehouseName ?? 'Warehouse picking'} actions={<>
      <StatusChip status={document.status} />
      {access.operate && pending && <Button onClick={() => openAction('start')}>Start picking</Button>}
      {access.operate && running && <Button onClick={() => openAction('complete')}>Complete picklist</Button>}
      {access.manage && (pending || running) && <Button variant="destructive" onClick={() => openAction('cancel')}>Cancel picklist</Button>}
    </>} />
    <div className="document-layout"><DocumentCard title="Picklist information"><FactList>
      <Fact label="Sales order" value={<Link to={appRoutes.salesOrderDetail(document.salesOrderId)}>{document.salesOrderNumber ?? 'View order'}</Link>} />
      <Fact label="Warehouse" value={document.warehouseName} /><Fact label="Started" value={formatDateTime(document.startedAt)} /><Fact label="Completed" value={formatDateTime(document.completedAt)} />
    </FactList></DocumentCard><DocumentCard title="Lines with quantity recorded" variant="summary"><PickProgress pickedCount={document.pickedCount} totalCount={document.lineCount} /><p>Line coverage can include partial quantities. Completion does not dispatch stock.</p></DocumentCard></div>
    <DocumentCard title="Pick lines" variant="lines"><DataTable caption="Picklist lines"><thead><tr><th>Item / SKU</th><th className="numeric-cell">Required</th><th className="numeric-cell">Picked</th><th>Batch</th><th>Rack</th><th>Notes</th><th>Action</th></tr></thead><tbody>{document.lines.map((line) => <tr key={line.id}>
      <td><div className="cell-stack"><strong>{line.itemName}</strong><code>{line.sku ?? '--'}</code></div></td><td className="numeric-cell"><Quantity value={line.requiredQuantity} /></td><td className="numeric-cell"><Quantity value={line.pickedQuantity} /></td><td><code>{line.batchNumber ?? '--'}</code></td><td>{line.rackLocationCode ?? '--'}</td><td>{line.notes ?? '--'}</td>
      <td>{access.operate && running && <Button variant="secondary" onClick={() => setEditing(line)}>Update {line.itemName}</Button>}</td>
    </tr>)}</tbody></DataTable></DocumentCard>
    <DocumentCard title="Instructions" variant="notes"><p>{document.notes || 'No instructions.'}</p></DocumentCard>
    {action && <Modal isOpen title={action === 'start' ? 'Start picklist' : action === 'complete' ? 'Complete picklist' : 'Cancel picklist'} onClose={() => { if (!mutation.isPending) setAction(null) }} error={mutation.error?.message} footer={<><Button variant="secondary" disabled={mutation.isPending} onClick={() => setAction(null)}>Back</Button><Button variant={action === 'cancel' ? 'destructive' : 'primary'} loading={mutation.isPending} onClick={() => { if (!mutation.isPending && (action === 'cancel' ? access.manage : access.operate)) mutation.mutate(action) }}>Confirm {action}</Button></>}>
      <p>{action === 'complete' ? 'Finish with the recorded quantities? The API permits partial completion; this does not mean the sales order has shipped.' : action === 'cancel' ? 'Cancel this picking task? This does not cancel its sales order or dispatch stock.' : 'Start this pending picklist so actual picked quantities can be recorded?'}</p>
      {action === 'complete' && <p>{shortLines} line(s) are below their required quantity.</p>}
    </Modal>}
    {editing && <UpdatePickLineModal key={editing.id} line={editing} warehouseId={document.warehouseId} picklistId={document.id} onClose={() => setEditing(null)} onSuccess={() => { setEditing(null); void client.invalidateQueries({ queryKey: ['picklists'] }) }} />}
  </section>
}

function UpdatePickLineModal({ line, warehouseId, picklistId, onClose, onSuccess }: { line: PicklistLine; warehouseId: string; picklistId: string; onClose: () => void; onSuccess: () => void }) {
  const access = useInventoryAccess()
  const [quantity, setQuantity] = useState(String(line.pickedQuantity ?? 0))
  const [batchId, setBatchId] = useState<string | undefined>(line.batchId ?? undefined)
  const [notes, setNotes] = useState(line.notes ?? '')
  const valid = quantity.trim() !== '' && Number.isFinite(Number(quantity)) && Number(quantity) >= 0
  const mutation = useMutation({ mutationFn: () => updatePicklistLines(picklistId, { lines: [{ lineId: line.id, pickedQuantity: Number(quantity), batchId, notes }] }), onSuccess })
  function submit(event: FormEvent) { event.preventDefault(); if (valid && !mutation.isPending && access.operate) mutation.mutate() }
  return <Modal isOpen title="Record picked quantity" onClose={() => { if (!mutation.isPending) onClose() }} error={mutation.error?.message} footer={<><Button variant="secondary" disabled={mutation.isPending} onClick={onClose}>Cancel</Button><Button form="pick-line" type="submit" loading={mutation.isPending} disabled={!valid || !access.operate}>Save picked quantity</Button></>}>
    <form id="pick-line" className="create-form-container" onSubmit={submit}>
      <p>{line.itemName}: required <Quantity value={line.requiredQuantity} /></p>
      <FormField label="Picked quantity" required><NumberInput value={quantity} onChange={(event) => setQuantity(event.target.value)} min={0} step="any" required disabled={mutation.isPending} /></FormField>
      <BatchAllocationPicker itemId={line.itemId} value={batchId ?? null} onChange={setBatchId} warehouseId={warehouseId} quantity={Number(quantity)} allowClear={false} instruction="Review the batch actually picked. This API can replace a batch but cannot clear an already saved batch." disabled={mutation.isPending || !valid} />
      {Number(quantity) > Number(line.requiredQuantity) && <p className="cell-muted">Picked quantity exceeds the requirement. Verify the physical count before saving.</p>}
      <FormField label="Notes"><TextAreaInput value={notes} onChange={(event) => setNotes(event.target.value)} disabled={mutation.isPending} /></FormField>
    </form>
  </Modal>
}
