import { useRef, useState, type FormEvent, type RefObject } from 'react'
import { useMutation, useQuery } from '@tanstack/react-query'
import { Button, CheckboxInput, DataTable, EntityPicker, FormField, Modal, NumberInput, Quantity, SelectInput, TextAreaInput } from '@/design-system'
import { getSalesOrder, listSalesOrders, type SalesOrder } from '@/features/sales-orders/sales-orders-api'
import { listWarehouses, type Warehouse } from '@/features/warehouses/warehouses-api'
import { useInventoryAccess } from '@/features/inventory/inventory-access'
import { createPicklist } from './picklists-api'

export function pickableQuantity(line: SalesOrder['lines'][number]) {
  return Math.max(0, Number(line.quantity) - Number(line.quantityShipped) - Number(line.quantityBackordered))
}

export function CreatePicklistModal({ onClose, onSuccess }: { onClose: () => void; onSuccess: (id: string) => void }) {
  const [status, setStatus] = useState('CONFIRMED')
  const [page, setPage] = useState(0)
  const [orderId, setOrderId] = useState<string | null>(null)
  const saving = useRef(false)
  const orders = useQuery({ queryKey: ['sales-orders', 'picklist-source', status, page], queryFn: () => listSalesOrders({ status, page }), enabled: !orderId })
  const order = useQuery({ queryKey: ['sales-orders', orderId, 'picklist-source'], queryFn: () => getSalesOrder(orderId!), enabled: Boolean(orderId) })
  return <Modal isOpen size="xl" title="Create picklist" description="Choose an eligible order and the quantities to pick. Picking does not dispatch stock." onClose={() => { if (!saving.current) onClose() }}>
    {!orderId ? <div className="create-form-container">
      <FormField label="Sales order status"><SelectInput value={status} onChange={(event) => { setStatus(event.target.value); setPage(0) }} options={['CONFIRMED', 'PARTIALLY_SHIPPED', 'BACKORDER'].map((value) => ({ value, label: value.replaceAll('_', ' ') }))} /></FormField>
      {orders.isError ? <div role="alert">{orders.error.message}<Button variant="secondary" onClick={() => void orders.refetch()}>Retry orders</Button></div> : orders.isPending ? <p role="status">Loading orders...</p> : <>
        <DataTable caption="Eligible sales orders"><thead><tr><th>Order</th><th>Customer</th><th>Warehouse</th><th>Action</th></tr></thead><tbody>{orders.data.content.map((entry) => <tr key={entry.id}><td><code>{entry.salesOrderNumber}</code></td><td>{entry.contactName}</td><td>{entry.warehouseName ?? '--'}</td><td><Button variant="secondary" onClick={() => setOrderId(entry.id)}>Choose {entry.salesOrderNumber}</Button></td></tr>)}</tbody></DataTable>
        {!orders.data.content.length && <p>No orders in this status.</p>}
        <div className="document-actions"><Button variant="secondary" disabled={page === 0} onClick={() => setPage(page - 1)}>Previous orders</Button><span>Page {page + 1} of {Math.max(1, orders.data.totalPages)}</span><Button variant="secondary" disabled={orders.data.last} onClick={() => setPage(page + 1)}>Next orders</Button></div>
      </>}
    </div> : order.isError ? <div role="alert">{order.error.message}<Button onClick={() => void order.refetch()}>Retry order</Button><Button variant="secondary" onClick={() => setOrderId(null)}>Choose another order</Button></div> : !order.data ? <p role="status">Loading order lines...</p> : <PicklistCreateForm key={order.data.id} order={order.data} saving={saving} onBack={() => setOrderId(null)} onSuccess={onSuccess} />}
  </Modal>
}

function PicklistCreateForm({ order, saving, onBack, onSuccess }: { order: SalesOrder; saving: RefObject<boolean>; onBack: () => void; onSuccess: (id: string) => void }) {
  const access = useInventoryAccess()
  const warehouses = useQuery({ queryKey: ['warehouses'], queryFn: listWarehouses })
  const [warehouseId, setWarehouseId] = useState<string | null>(order.warehouseId ?? null)
  const [notes, setNotes] = useState('')
  const [error, setError] = useState('')
  const [lines, setLines] = useState(() => order.lines.filter((line) => line.itemId && pickableQuantity(line) > 0).map((line) => ({ ...line, included: true, requiredQuantity: String(pickableQuantity(line)) })))
  const warehouse = warehouses.data?.find((entry) => entry.id === warehouseId && entry.active)
  const save = useMutation({ mutationFn: createPicklist, onSuccess: (created) => onSuccess(created.id), onSettled: () => { saving.current = false } })
  function submit(event: FormEvent) {
    event.preventDefault()
    if (save.isPending || saving.current || !access.operate) return
    const selected = lines.filter((line) => line.included)
    if (!warehouse || !selected.length || selected.some((line) => !line.requiredQuantity.trim() || !Number.isFinite(Number(line.requiredQuantity)) || Number(line.requiredQuantity) <= 0 || Number(line.requiredQuantity) > pickableQuantity(line))) {
      setError('Choose an active warehouse and at least one line with a positive quantity no greater than its shippable balance.'); return
    }
    if (!['CONFIRMED', 'PARTIALLY_SHIPPED', 'BACKORDER'].includes(order.status)) { setError('This order is no longer eligible. Reload it before creating a picklist.'); return }
    setError('')
    saving.current = true
    save.mutate({ salesOrderId: order.id, warehouseId: warehouse.id, notes: notes.trim() || undefined, lines: selected.map((line) => ({ salesOrderLineId: line.id, requiredQuantity: Number(line.requiredQuantity) })) })
  }
  return <form className="create-form-container" onSubmit={submit}>
    <p><code>{order.salesOrderNumber}</code> / {order.contactName}</p>
    {(error || save.isError || warehouses.isError) && <div className="banner banner--error" role="alert">{error || save.error?.message || warehouses.error?.message}</div>}
    {warehouses.isError && <Button variant="secondary" onClick={() => void warehouses.refetch()}>Retry warehouses</Button>}
    <FormField label="Warehouse" required><EntityPicker<Warehouse> ariaLabel="Select picklist warehouse" value={warehouse?.id ?? null} selectedEntity={warehouse} onChange={setWarehouseId} options={(warehouses.data ?? []).filter((entry) => entry.active)} getOptionId={(entry) => entry.id} getOptionLabel={(entry) => entry.name} getOptionDescription={(entry) => entry.code} disabled={save.isPending} /></FormField>
    <DataTable caption="Shippable picklist lines"><thead><tr><th>Include</th><th>Item</th><th className="numeric-cell">Shippable</th><th className="numeric-cell">Quantity to pick</th></tr></thead><tbody>{lines.map((line) => <tr key={line.id}>
      <td><CheckboxInput aria-label={`Include ${line.itemName ?? line.description}`} checked={line.included} disabled={save.isPending} onChange={(event) => setLines((current) => current.map((entry) => entry.id === line.id ? { ...entry, included: event.target.checked } : entry))} /></td>
      <td>{line.itemName ?? line.description}</td><td className="numeric-cell"><Quantity value={pickableQuantity(line)} unit={line.unit} /></td>
      <td><NumberInput aria-label={`Pick quantity for ${line.itemName ?? line.description}`} value={line.requiredQuantity} min={0} max={pickableQuantity(line)} step="any" disabled={!line.included || save.isPending} onChange={(event) => setLines((current) => current.map((entry) => entry.id === line.id ? { ...entry, requiredQuantity: event.target.value } : entry))} /></td>
    </tr>)}</tbody></DataTable>
    {!lines.length && <p>No item lines have a shippable balance.</p>}
    <FormField label="Picking instructions"><TextAreaInput value={notes} onChange={(event) => setNotes(event.target.value)} disabled={save.isPending} /></FormField>
    <div className="document-actions"><Button variant="secondary" disabled={save.isPending} onClick={onBack}>Choose another order</Button><Button type="submit" loading={save.isPending} disabled={!access.operate || !warehouse || !lines.some((line) => line.included)}>Create picklist</Button></div>
  </form>
}
