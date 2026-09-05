import { useState } from 'react'
import { useMutation, useQuery } from '@tanstack/react-query'
import { useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button, CheckboxInput, DataTable, DirectoryToolbar, FormField, Modal, Money, NumberInput, PageHeader, Quantity, SearchInput, StatusChip, TextInput } from '@/design-system'
import { getItem, getShortbook, type ShortbookItem } from '@/features/items/items-api'
import { createPurchaseOrder, type CreatePurchaseOrderRequest } from '@/features/purchase-orders/purchase-orders-api'
import type { Supplier } from '@/features/suppliers/suppliers-api'
import type { Warehouse } from '@/features/warehouses/warehouses-api'
import { useInventoryAccess } from './inventory-access'
import { InventorySupplierPicker, InventoryWarehousePicker } from './inventory-pickers'

export function ShortbookPage() {
  const navigate = useNavigate()
  const access = useInventoryAccess()
  const [ids, setIds] = useState<string[]>([])
  const [search, setSearch] = useState('')
  const [draftRows, setDraftRows] = useState<ShortbookItem[] | null>(null)
  const query = useQuery({ queryKey: ['shortbook'], queryFn: getShortbook })
  const items = query.data ?? []
  const selected = items.filter((item) => ids.includes(item.itemId))
  const rows = items.filter((item) => (item.itemName + ' ' + item.sku).toLowerCase().includes(search.toLowerCase()))
  return <section className="workspace-page">
    <PageHeader eyebrow="Inventory / Replenishment" title="Shortbook" description="Server-calculated replenishment suggestions from low stock and outstanding backorders."
      actions={<><Button variant="secondary" onClick={() => void query.refetch()}>Refresh</Button>{access.manage && <Button disabled={!selected.length || query.isError || query.isFetching} onClick={() => setDraftRows(selected)}>Create draft PO ({selected.length})</Button>}</>} />
    <section className="list-panel"><DirectoryToolbar><SearchInput ariaLabel="Search shortbook" value={search} onChange={setSearch} placeholder="Search item or SKU" /><span>{items.length} replenishment suggestions</span></DirectoryToolbar>
      {query.isError ? <div className="directory-state directory-state--error" role="alert">{query.error.message}<Button onClick={() => void query.refetch()}>Retry</Button></div> : query.isPending ? <div className="directory-state" role="status">Loading shortbook...</div> : <>
        <DataTable caption="Replenishment suggestions"><thead><tr><th>Select</th><th>Item / SKU</th><th className="numeric-cell">On hand</th><th className="numeric-cell">Reorder level</th><th className="numeric-cell">Backordered</th><th className="numeric-cell">Suggested order</th><th>Reason</th></tr></thead><tbody>{rows.map((item) => <tr key={item.itemId}>
          <td><CheckboxInput aria-label={'Select ' + item.itemName} disabled={!access.manage} checked={ids.includes(item.itemId)} onChange={(event) => setIds((current) => event.target.checked ? [...current, item.itemId] : current.filter((id) => id !== item.itemId))} /></td>
          <td><div className="cell-stack"><strong>{item.itemName}</strong><code>{item.sku ?? '--'}</code></div></td><td className="numeric-cell"><Quantity value={item.currentStock} /></td><td className="numeric-cell"><Quantity value={item.reorderLevel} /></td><td className="numeric-cell"><Quantity value={item.backordered} /></td><td className="numeric-cell"><Quantity value={item.suggestOrderQty} /></td><td><StatusChip status={item.reason} /></td>
        </tr>)}</tbody></DataTable>
        {!rows.length && <div className="directory-state">{search ? 'No matching suggestions.' : 'The server returned no replenishment suggestions.'}</div>}
      </>}
    </section>
    {draftRows && <ShortbookPoModal items={draftRows} onClose={() => setDraftRows(null)} onSuccess={(id) => { setDraftRows(null); setIds([]); navigate(appRoutes.purchaseOrderDetail(id)) }} />}
  </section>
}

function ShortbookPoModal({ items, onClose, onSuccess }: { items: ShortbookItem[]; onClose: () => void; onSuccess: (id: string) => void }) {
  const access = useInventoryAccess()
  const [supplier, setSupplier] = useState<Supplier | null>(null)
  const [warehouse, setWarehouse] = useState<Warehouse | null>(null)
  const [date, setDate] = useState(() => { const now = new Date(); return new Date(now.getTime() - now.getTimezoneOffset() * 60000).toISOString().slice(0, 10) })
  const [quantities, setQuantities] = useState(() => Object.fromEntries(items.map((item) => [item.itemId, String(item.suggestOrderQty ?? '')])))
  const details = useQuery({ queryKey: ['shortbook', 'purchase-details', items.map((item) => item.itemId)], queryFn: () => Promise.all(items.map((item) => getItem(item.itemId))) })
  const mutation = useMutation({ mutationFn: (request: CreatePurchaseOrderRequest) => createPurchaseOrder(request), onSuccess: (created) => onSuccess(created.id) })
  const ratesValid = details.isSuccess && details.data.every((item) => item.purchasePrice !== null && String(item.purchasePrice).trim() !== '' && Number.isFinite(Number(item.purchasePrice)) && Number(item.purchasePrice) >= 0)
  const valid = Boolean(access.manage && supplier && warehouse && date && ratesValid && details.isSuccess && details.data.every((item) => item.active) && items.every((item) => quantities[item.itemId]?.trim() && Number.isFinite(Number(quantities[item.itemId])) && Number(quantities[item.itemId]) > 0))
  function submit() {
    if (!valid || mutation.isPending || !supplier || !warehouse || !details.data) return
    mutation.mutate({ supplierId: supplier.id, warehouseId: warehouse.id, orderDate: date, notes: 'Draft replenishment order from Shortbook.',
      lines: details.data.map((item) => ({ itemId: item.id, quantity: Number(quantities[item.id]), unitPrice: Number(item.purchasePrice), description: item.name, taxGroupId: item.defaultTaxGroupId ?? undefined })) })
  }
  return <Modal isOpen size="lg" title="Create replenishment PO" onClose={() => { if (!mutation.isPending) onClose() }} error={mutation.error?.message ?? details.error?.message}
    footer={<><Button variant="secondary" disabled={mutation.isPending} onClick={onClose}>Cancel</Button><Button loading={mutation.isPending} disabled={!valid} onClick={submit}>Create draft PO</Button></>}>
    <div className="create-form-container">
      <FormField label="Supplier" required><InventorySupplierPicker value={supplier} onChange={setSupplier} disabled={mutation.isPending} /></FormField>
      <FormField label="Warehouse" required><InventoryWarehousePicker value={warehouse} onChange={setWarehouse} disabled={mutation.isPending} /></FormField>
      <FormField label="Order date" required><TextInput type="date" value={date} onChange={(event) => setDate(event.target.value)} disabled={mutation.isPending} /></FormField>
      <p className="cell-muted">Suggested quantities come from Shortbook. Rates and tax groups are loaded from the item master; the server calculates document totals.</p>
      {details.isSuccess && !ratesValid && <p role="alert">A selected item has no valid purchase rate. Update its item master and reload the details before creating this order.</p>}
      {details.isPending ? <p role="status">Loading purchase rates...</p> : <DataTable caption="Replenishment order lines"><thead><tr><th>Item</th><th className="numeric-cell">Quantity</th><th className="numeric-cell">Purchase rate</th></tr></thead><tbody>{items.map((item) => {
        const detail = details.data?.find((entry) => entry.id === item.itemId)
        return <tr key={item.itemId}><td>{item.itemName}{detail && !detail.active && <span> (Inactive)</span>}</td><td><NumberInput aria-label={'Order quantity for ' + item.itemName} value={quantities[item.itemId] ?? ''} min={0} step="any" disabled={mutation.isPending} onChange={(event) => setQuantities((current) => ({ ...current, [item.itemId]: event.target.value }))} /></td><td className="numeric-cell">{detail ? <Money amount={detail.purchasePrice} /> : '--'}</td></tr>
      })}</tbody></DataTable>}
      {(details.isError || (details.isSuccess && !ratesValid)) && <Button variant="secondary" onClick={() => void details.refetch()}>Reload item details</Button>}
    </div>
  </Modal>
}

