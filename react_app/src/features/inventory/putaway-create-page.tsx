import { useState, type FormEvent } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useNavigate, useSearchParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button, DataTable, FormField, FormGrid, NumberInput, PageHeader, TextAreaInput, TextInput } from '@/design-system'
import type { Item } from '@/features/items/items-api'
import { getStockReceipt, type StockReceipt } from '@/features/stock-receipts/stock-receipts-api'
import { listWarehouses, type Warehouse } from '@/features/warehouses/warehouses-api'
import { useInventoryAccess } from './inventory-access'
import { InventoryItemPicker, InventoryWarehousePicker } from './inventory-pickers'
import { createPutawayTask } from './putaway-api'
import { RackPicker } from './rack-locations-page'

type DraftLine = { key: string; itemId: string; name: string; unit: string | null; quantity: string; maximum?: number; batchNumber: string; suggestedRackId: string | null }

export function PutawayCreatePage() {
  const access = useInventoryAccess()
  const [params] = useSearchParams()
  const receiptId = params.get('receiptId')
  const receipt = useQuery({ queryKey: ['stock-receipts', receiptId], queryFn: () => getStockReceipt(receiptId!), enabled: Boolean(receiptId) && access.operate })
  if (!access.operate) return <p>Your role cannot create putaway tasks.</p>
  if (receiptId && receipt.isError) return <div role="alert">{receipt.error.message}<Button onClick={() => void receipt.refetch()}>Retry source receipt</Button></div>
  if (receiptId && !receipt.data) return <p role="status">Loading source receipt...</p>
  if (receipt.data && receipt.data.status !== 'RECEIVED') return <p role="alert">Only a received goods receipt can be used as a putaway source.</p>
  return <PutawayCreateForm key={receiptId ?? 'standalone'} receipt={receipt.data} />
}

function PutawayCreateForm({ receipt }: { receipt?: StockReceipt }) {
  const access = useInventoryAccess()
  const navigate = useNavigate()
  const client = useQueryClient()
  const warehouses = useQuery({ queryKey: ['warehouses'], queryFn: listWarehouses })
  const [warehouse, setWarehouse] = useState<Warehouse | null>(null)
  const warehouseId = receipt?.warehouseId ?? warehouse?.id ?? ''
  const activeWarehouse = warehouses.data?.find((entry) => entry.id === warehouseId && entry.active)
  const [source, setSource] = useState('RECEIVING_DOCK')
  const [notes, setNotes] = useState('')
  const [error, setError] = useState('')
  const [lines, setLines] = useState<DraftLine[]>(() => (receipt?.lines ?? []).filter((line) => line.itemId && Number(line.quantity) > 0).map((line) => ({ key: line.id, itemId: line.itemId, name: line.itemName ?? line.description ?? line.itemSku ?? line.itemId, unit: line.unitOfMeasure, quantity: String(line.quantity), maximum: Number(line.quantity), batchNumber: line.batchNumber ?? '', suggestedRackId: null })))
  const save = useMutation({ mutationFn: createPutawayTask, onSuccess: (task) => { void client.invalidateQueries({ queryKey: ['putaway-tasks'] }); navigate(appRoutes.putawayDetail(task.id)) } })
  function addItem(item: Item | null) {
    if (!item) return
    if (!item.trackInventory) { setError('Choose an inventory-tracked item.'); return }
    setLines((current) => [...current, { key: crypto.randomUUID(), itemId: item.id, name: item.name, unit: item.unitOfMeasure, quantity: '1', batchNumber: '', suggestedRackId: null }])
    setError('')
  }
  function editLine(key: string, change: Partial<DraftLine>) { setLines((current) => current.map((line) => line.key === key ? { ...line, ...change } : line)) }
  function submit(event: FormEvent) {
    event.preventDefault()
    if (save.isPending || !access.operate) return
    if (!activeWarehouse || !source.trim() || !lines.length || lines.some((line) => !line.quantity.trim() || !Number.isFinite(Number(line.quantity)) || Number(line.quantity) <= 0 || (line.maximum !== undefined && Number(line.quantity) > line.maximum))) {
      setError('Choose an active warehouse, a source and positive quantities within the source receipt, where linked.'); return
    }
    setError('')
    save.mutate({ goodsReceiptId: receipt?.id, warehouseId, sourceLocation: source.trim(), notes: notes.trim() || undefined, lines: lines.map((line) => ({ itemId: line.itemId, quantity: Number(line.quantity), batchNumber: line.batchNumber.trim() || undefined, suggestedRackId: line.suggestedRackId ?? undefined })) })
  }
  return <section className="workspace-page">
    <PageHeader eyebrow="Inventory / Storage" title="New putaway task" description={receipt ? `Source receipt ${receipt.receiptNumber}. Review physical placement before recording.` : 'Create a physical-placement checklist. This is not a goods receipt or stock transfer.'} />
    <form onSubmit={submit} className="create-form-container">
      {(error || save.isError || warehouses.isError) && <div role="alert" className="banner banner--error">{error || save.error?.message || warehouses.error?.message}</div>}
      {warehouses.isError && <Button variant="secondary" onClick={() => void warehouses.refetch()}>Retry warehouses</Button>}
      <FormGrid columns={2}>
        <FormField label="Warehouse" required>{receipt ? <TextInput readOnly value={receipt.warehouseName} /> : <InventoryWarehousePicker value={warehouse} disabled={save.isPending} onChange={(selected) => { setWarehouse(selected); setLines((current) => current.map((line) => ({ ...line, suggestedRackId: null }))) }} />}</FormField>
        <FormField label="Source location" required><TextInput required maxLength={100} value={source} disabled={save.isPending} onChange={(event) => setSource(event.target.value)} /></FormField>
      </FormGrid>
      {!receipt && <FormField label="Add item"><InventoryItemPicker value={null} onChange={addItem} disabled={save.isPending} /></FormField>}
      <DataTable caption="Putaway quantities and suggested racks"><thead><tr><th>Item</th><th>Batch reference</th><th className="numeric-cell">Quantity</th><th>Suggested rack</th><th>Action</th></tr></thead>
        <tbody>{lines.map((line) => <tr key={line.key}>
          <td>{line.name}<span className="cell-muted"> {line.unit}</span></td>
          <td><TextInput aria-label={`Batch for ${line.name}`} maxLength={100} value={line.batchNumber} readOnly={Boolean(receipt)} disabled={save.isPending} onChange={(event) => editLine(line.key, { batchNumber: event.target.value })} /></td>
          <td><NumberInput aria-label={`Quantity for ${line.name}`} min={0} step="any" max={line.maximum} value={line.quantity} disabled={save.isPending} onChange={(event) => editLine(line.key, { quantity: event.target.value })} /></td>
          <td><RackPicker label={`Suggested rack for ${line.name}`} warehouseId={warehouseId} value={line.suggestedRackId} onChange={(suggestedRackId) => editLine(line.key, { suggestedRackId })} disabled={save.isPending} /></td>
          <td><Button variant="ghost" disabled={save.isPending} onClick={() => setLines((current) => current.filter((entry) => entry.key !== line.key))}>Remove {line.name}</Button></td>
        </tr>)}</tbody>
      </DataTable>
      {!lines.length && <p>Add at least one placement line.</p>}
      <FormField label="Notes"><TextAreaInput value={notes} disabled={save.isPending} rows={2} onChange={(event) => setNotes(event.target.value)} /></FormField>
      <p className="cell-muted">The service does not enforce cumulative receipt-to-putaway quantities or hold bin stock. Avoid duplicate tasks for the same physical goods. Confirmation can set an empty item default rack; it never overwrites an existing one.</p>
      <div className="document-actions"><Button variant="secondary" disabled={save.isPending} onClick={() => navigate(appRoutes.putawayTasks)}>Cancel</Button><Button type="submit" loading={save.isPending} disabled={!activeWarehouse || !lines.length}>Create putaway task</Button></div>
    </form>
  </section>
}
