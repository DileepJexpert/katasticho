import { useState, type FormEvent } from 'react'
import { useMutation, useQueries, useQuery, useQueryClient } from '@tanstack/react-query'
import { Link, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button, DataTable, DocumentCard, FormField, Modal, PageHeader, Quantity, StatusChip } from '@/design-system'
import { getItem } from '@/features/items/items-api'
import { listRackLocations } from '@/features/pharmacy/pharmacy-api'
import { listWarehouses } from '@/features/warehouses/warehouses-api'
import { formatDateTime } from '@/shared/format/format'
import { useInventoryAccess } from './inventory-access'
import { cancelPutawayTask, confirmPutawayLine, getPutawayTask, type PutawayLine, type PutawayTask } from './putaway-api'
import { RackPicker } from './rack-locations-page'

export function PutawayDetailPage() {
  const access = useInventoryAccess()
  const { taskId } = useParams()
  const query = useQuery({ queryKey: ['putaway-tasks', 'detail', taskId], queryFn: () => getPutawayTask(taskId!), enabled: Boolean(taskId) && access.operate })
  if (!access.operate) return <p>Your role cannot access putaway tasks.</p>
  if (!taskId || query.isError) return <div role="alert">{query.error?.message ?? 'Putaway task not found.'}<Button onClick={() => void query.refetch()}>Retry task</Button></div>
  if (!query.data) return <p role="status">Loading putaway task...</p>
  return <PutawayDetail key={taskId} task={query.data} />
}

function PutawayDetail({ task }: { task: PutawayTask }) {
  const access = useInventoryAccess()
  const client = useQueryClient()
  const [page, setPage] = useState(0)
  const [action, setAction] = useState<PutawayLine | 'cancel' | null>(null)
  const [rackId, setRackId] = useState<string | null>(null)
  const [error, setError] = useState('')
  const warehouses = useQuery({ queryKey: ['warehouses'], queryFn: listWarehouses })
  const racks = useQuery({ queryKey: ['pharmacy-racks', task.warehouseId], queryFn: () => listRackLocations(task.warehouseId) })
  const pages = Math.max(1, Math.ceil(task.lines.length / 25))
  const currentPage = Math.min(page, pages - 1)
  const visible = task.lines.slice(currentPage * 25, currentPage * 25 + 25)
  const itemIds = [...new Set(visible.map((line) => line.itemId))]
  const items = useQueries({ queries: itemIds.map((id) => ({ queryKey: ['items', id], queryFn: () => getItem(id) })) })
  const itemName = (id: string) => items[itemIds.indexOf(id)]?.data?.name ?? id
  const rackName = (id: string | null) => id ? racks.data?.find((rack) => rack.id === id)?.code ?? id : '--'
  const open = ['PENDING', 'IN_PROGRESS'].includes(task.status)
  const save = useMutation({
    mutationFn: async (command: { kind: 'cancel' } | { kind: 'confirm'; lineId: string; rackId: string }) => {
      const current = await getPutawayTask(task.id)
      if (!['PENDING', 'IN_PROGRESS'].includes(current.status)) throw new Error('The task is no longer open. Reload before acting.')
      if (command.kind === 'confirm' && !current.lines.some((line) => line.id === command.lineId && line.status === 'PENDING')) throw new Error('This line is no longer pending.')
      return command.kind === 'cancel' ? cancelPutawayTask(task.id) : confirmPutawayLine(task.id, command.lineId, command.rackId)
    },
    onSuccess: (updated) => {
      client.setQueryData(['putaway-tasks', 'detail', task.id], updated)
      void client.invalidateQueries({ queryKey: ['putaway-tasks'] })
      void client.invalidateQueries({ queryKey: ['items'] })
      setAction(null)
    },
  })
  function chooseAction(next: PutawayLine | 'cancel') {
    setError(''); save.reset(); setAction(next)
    setRackId(next === 'cancel' ? null : next.suggestedRackId)
  }
  function confirm(event: FormEvent) {
    event.preventDefault()
    if (!access.operate || !open || save.isPending || !action) return
    if (action === 'cancel') { save.mutate({ kind: 'cancel' }); return }
    if (racks.isError || !racks.data?.some((rack) => rack.id === rackId && rack.active && rack.warehouseId === task.warehouseId)) { setError('Choose an active rack in this task warehouse.'); return }
    setError(''); save.mutate({ kind: 'confirm', lineId: action.id, rackId: rackId! })
  }
  return <section className="workspace-page">
    <PageHeader eyebrow="Inventory / Storage" title={task.taskNumber} description={`${warehouses.data?.find((warehouse) => warehouse.id === task.warehouseId)?.name ?? task.warehouseId} / ${task.sourceLocation ?? '--'}`}
      actions={<><StatusChip status={task.status} /><Link className="button button--secondary" to={appRoutes.putawayTasks}>Back to tasks</Link>{open && <Button variant="destructive" onClick={() => chooseAction('cancel')}>Cancel task</Button>}</>} />
    <DocumentCard title="Placement record">
      <p>Confirmation records the actual rack and can set an empty item default rack. It does not move or value stock, replace an existing default, or maintain quantity-per-rack balances.</p>
      {task.goodsReceiptId && <Link to={appRoutes.stockReceiptDetail(task.goodsReceiptId)}>View source goods receipt</Link>}
      {task.assignedTo && <p>Assigned user: <code>{task.assignedTo}</code></p>}
      {task.notes && <p>{task.notes}</p>}
      {(items.some((item) => item.isError) || racks.isError || warehouses.isError) && <p role="alert">Some master labels could not be loaded; identifiers are shown instead.</p>}
      <DataTable caption="Putaway lines"><thead><tr><th>Item / batch</th><th className="numeric-cell">Quantity</th><th>Suggested rack</th><th>Confirmed rack</th><th>Status / confirmed</th><th>Action</th></tr></thead>
        <tbody>{visible.map((line) => <tr key={line.id}>
          <td><div className="cell-stack"><span>{itemName(line.itemId)}</span><code>{line.batchNumber ?? '--'}</code></div></td>
          <td className="numeric-cell"><Quantity value={line.quantity} /></td><td><code>{rackName(line.suggestedRackId)}</code></td><td><code>{rackName(line.confirmedRackId)}</code></td>
          <td><div className="cell-stack"><StatusChip status={line.status} /><span>{line.confirmedAt ? formatDateTime(line.confirmedAt) : '--'}</span></div></td>
          <td>{open && line.status === 'PENDING' && <Button variant="secondary" onClick={() => chooseAction(line)}>Confirm {itemName(line.itemId)}</Button>}</td>
        </tr>)}</tbody>
      </DataTable>
      <div className="document-actions"><Button variant="secondary" disabled={currentPage === 0} onClick={() => setPage(currentPage - 1)}>Previous lines</Button><span>Page {currentPage + 1} of {pages}</span><Button variant="secondary" disabled={currentPage + 1 >= pages} onClick={() => setPage(currentPage + 1)}>Next lines</Button></div>
    </DocumentCard>
    {action && <Modal isOpen title={action === 'cancel' ? 'Cancel putaway task' : 'Confirm rack placement'} error={error || save.error?.message} onClose={() => { if (!save.isPending) setAction(null) }}>
      <form onSubmit={confirm} className="create-form-container">
        {action === 'cancel' ? <p>Cancel the remaining work? Existing confirmations and any item default rack already set are not reversed.</p> : <><p>{itemName(action.itemId)}: <Quantity value={action.quantity} />. Confirm only after physical placement.</p><FormField label="Actual rack" required><RackPicker warehouseId={task.warehouseId} value={rackId} onChange={setRackId} disabled={save.isPending} /></FormField></>}
        <div className="document-actions"><Button variant="secondary" disabled={save.isPending} onClick={() => setAction(null)}>Keep unchanged</Button><Button type="submit" loading={save.isPending} variant={action === 'cancel' ? 'destructive' : 'primary'}>{action === 'cancel' ? 'Confirm cancellation' : 'Record placement'}</Button></div>
      </form>
    </Modal>}
  </section>
}
