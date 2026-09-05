import { useState, type FormEvent } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Button, DataTable, FormField, FormGrid, Modal, Money, NumberInput, PageHeader, Quantity, StatusChip, TextInput } from '@/design-system'
import { formatDate } from '@/shared/format/format'
import { getItem, type Item } from '@/features/items/items-api'
import { getSupplier, type Supplier } from '@/features/suppliers/suppliers-api'
import { getWarehouse, type Warehouse } from '@/features/warehouses/warehouses-api'
import { useInventoryAccess } from './inventory-access'
import { InventoryItemPicker, InventorySupplierPicker, InventoryWarehousePicker } from './inventory-pickers'
import { getConsignmentStock, getUnsettledConsignmentSales, receiveConsignment, recordConsignmentSale, settleConsignment, type ConsignmentStock, type ConsignmentSettlement } from './consignment-api'

export function ConsignmentsPage() {
  const access = useInventoryAccess()
  const client = useQueryClient()
  const [page, setPage] = useState(0)
  const [receiving, setReceiving] = useState(false)
  const [selling, setSelling] = useState<ConsignmentStock | null>(null)
  const [supplierId, setSupplierId] = useState<string | null>(null)
  const query = useQuery({ queryKey: ['consignments', 'stock'], queryFn: getConsignmentStock })
  const refresh = () => { void client.invalidateQueries({ queryKey: ['consignments'] }) }
  const rows = (query.data ?? []).slice(page * 25, page * 25 + 25)
  return <section className="workspace-page">
    <PageHeader eyebrow="Inventory / Supplier-owned goods" title="Consignment register" description="Track the separate consignment register and its sale settlements."
      actions={<><Button variant="secondary" onClick={refresh}>Refresh</Button>{access.operate && <Button onClick={() => setReceiving(true)}>Receive consignment</Button>}</>} />
    <p className="banner">These endpoints maintain a separate register. They do not post warehouse stock movements, create supplier bills, or record payment.</p>
    {query.isError ? <div role="alert" className="directory-state directory-state--error">{query.error.message}<Button onClick={refresh}>Retry</Button></div> : query.isPending ? <p role="status">Loading consignments...</p> : <>
      <DataTable caption="Consignment stock"><thead><tr><th>Item</th><th>Supplier</th><th>Warehouse</th><th className="numeric-cell">Available quantity</th><th className="numeric-cell">Unit cost</th><th>Date</th><th>Status</th><th>Actions</th></tr></thead><tbody>{rows.map((stock) => <ConsignmentRow key={stock.id} stock={stock} canOperate={access.operate} onSale={() => setSelling(stock)} onSettlements={() => setSupplierId(stock.supplierId)} />)}</tbody></DataTable>
      {!rows.length && <p className="directory-state">No consignment records on this page.</p>}
      <div className="document-actions"><Button variant="secondary" disabled={page === 0} onClick={() => setPage(page - 1)}>Previous</Button><span>Page {page + 1}</span><Button variant="secondary" disabled={(page + 1) * 25 >= query.data.length} onClick={() => setPage(page + 1)}>Next</Button></div>
    </>}
    {receiving && <ReceiveConsignmentModal onClose={() => setReceiving(false)} onSuccess={() => { setReceiving(false); refresh() }} />}
    {selling && <RecordSaleModal stock={selling} onClose={() => setSelling(null)} onSuccess={() => { setSupplierId(selling.supplierId); setSelling(null); refresh() }} />}
    {supplierId && <SettlementModal supplierId={supplierId} onClose={() => setSupplierId(null)} />}
  </section>
}

function ConsignmentRow({ stock, canOperate, onSale, onSettlements }: { stock: ConsignmentStock; canOperate: boolean; onSale: () => void; onSettlements: () => void }) {
  const item = useQuery({ queryKey: ['items', stock.itemId, 'consignment-label'], queryFn: () => getItem(stock.itemId) })
  const supplier = useQuery({ queryKey: ['suppliers', stock.supplierId], queryFn: () => getSupplier(stock.supplierId) })
  const warehouse = useQuery({ queryKey: ['warehouses', stock.warehouseId], queryFn: () => getWarehouse(stock.warehouseId) })
  return <tr><td><div className="cell-stack"><strong>{item.data?.name ?? (item.isError ? 'Item unavailable' : 'Loading item...')}</strong><code>{item.data?.sku ?? stock.itemId}</code></div></td>
    <td>{supplier.data?.name ?? stock.supplierId}</td><td>{warehouse.data?.name ?? stock.warehouseId}</td><td className="numeric-cell"><Quantity value={stock.quantity} /></td><td className="numeric-cell"><Money amount={stock.unitCost} /></td><td>{formatDate(stock.consignmentDate)}</td><td><StatusChip status={stock.status} /></td>
    <td><div className="document-actions">{canOperate && stock.status === 'ACTIVE' && <Button variant="secondary" disabled={Number(stock.quantity) <= 0} onClick={onSale}>Record sale</Button>}<Button variant="secondary" onClick={onSettlements}>Supplier settlements</Button></div></td></tr>
}

function ReceiveConsignmentModal({ onClose, onSuccess }: { onClose: () => void; onSuccess: () => void }) {
  const access = useInventoryAccess()
  const [item, setItem] = useState<Item | null>(null)
  const [supplier, setSupplier] = useState<Supplier | null>(null)
  const [warehouse, setWarehouse] = useState<Warehouse | null>(null)
  const [quantity, setQuantity] = useState('')
  const [cost, setCost] = useState('')
  const [reference, setReference] = useState('')
  const [date, setDate] = useState(() => { const now = new Date(); return new Date(now.getTime() - now.getTimezoneOffset() * 60000).toISOString().slice(0, 10) })
  const valid = Boolean(item && supplier && warehouse && quantity.trim() && cost.trim() && Number.isFinite(Number(quantity)) && Number(quantity) > 0 && Number.isFinite(Number(cost)) && Number(cost) >= 0)
  const mutation = useMutation({ mutationFn: () => receiveConsignment({ itemId: item!.id, supplierId: supplier!.id, warehouseId: warehouse!.id, quantity: Number(quantity), unitCost: Number(cost), consignmentDate: date || undefined, agreementRef: reference.trim() || undefined }), onSuccess })
  function submit(event: FormEvent) { event.preventDefault(); if (valid && access.operate && !mutation.isPending) mutation.mutate() }
  return <Modal isOpen title="Receive consignment" onClose={() => { if (!mutation.isPending) onClose() }} error={mutation.error?.message} footer={<><Button variant="secondary" disabled={mutation.isPending} onClick={onClose}>Cancel</Button><Button form="consignment-receive" type="submit" disabled={!valid || !access.operate} loading={mutation.isPending}>Record receipt</Button></>}>
    <form id="consignment-receive" className="create-form-container" onSubmit={submit}>
      <FormField label="Item" required><InventoryItemPicker value={item} onChange={setItem} disabled={mutation.isPending} /></FormField>
      <FormField label="Supplier" required><InventorySupplierPicker value={supplier} onChange={setSupplier} disabled={mutation.isPending} /></FormField>
      <FormField label="Warehouse" required><InventoryWarehousePicker value={warehouse} onChange={setWarehouse} disabled={mutation.isPending} /></FormField>
      <FormGrid columns={2}><FormField label="Quantity" required><NumberInput value={quantity} onChange={(event) => setQuantity(event.target.value)} min={0} step="any" required disabled={mutation.isPending} /></FormField><FormField label="Agreed unit cost" required><NumberInput value={cost} onChange={(event) => setCost(event.target.value)} min={0} step="any" required disabled={mutation.isPending} /></FormField></FormGrid>
      <FormField label="Agreement reference"><TextInput value={reference} maxLength={50} onChange={(event) => setReference(event.target.value)} disabled={mutation.isPending} /></FormField>
      <FormField label="Consignment date"><TextInput type="date" value={date} onChange={(event) => setDate(event.target.value)} disabled={mutation.isPending} /></FormField>
      <p>This updates the consignment register only, not the stock ledger.</p>
    </form>
  </Modal>
}

function RecordSaleModal({ stock, onClose, onSuccess }: { stock: ConsignmentStock; onClose: () => void; onSuccess: () => void }) {
  const access = useInventoryAccess()
  const [quantity, setQuantity] = useState('')
  const valid = quantity.trim() !== '' && Number.isFinite(Number(quantity)) && Number(quantity) > 0 && Number(quantity) <= Number(stock.quantity)
  const mutation = useMutation({ mutationFn: () => recordConsignmentSale({ consignmentStockId: stock.id, quantitySold: Number(quantity) }), onSuccess })
  return <Modal isOpen title="Record consignment sale" onClose={() => { if (!mutation.isPending) onClose() }} error={mutation.error?.message} footer={<><Button variant="secondary" disabled={mutation.isPending} onClick={onClose}>Cancel</Button><Button loading={mutation.isPending} disabled={!valid || !access.operate} onClick={() => { if (valid && !mutation.isPending && access.operate) mutation.mutate() }}>Confirm sale</Button></>}>
    <div className="create-form-container"><p>Available: <Quantity value={stock.quantity} />. This reduces the consignment register and creates a DRAFT settlement. No supplier bill or sales invoice is created.</p><FormField label="Quantity sold" required><NumberInput value={quantity} onChange={(event) => setQuantity(event.target.value)} min={0} max={Number(stock.quantity)} step="any" disabled={mutation.isPending} /></FormField></div>
  </Modal>
}

function SettlementModal({ supplierId, onClose }: { supplierId: string; onClose: () => void }) {
  const access = useInventoryAccess()
  const client = useQueryClient()
  const [confirm, setConfirm] = useState<ConsignmentSettlement | null>(null)
  const query = useQuery({ queryKey: ['consignments', 'unsettled', supplierId], queryFn: () => getUnsettledConsignmentSales(supplierId) })
  const mutation = useMutation({ mutationFn: (id: string) => settleConsignment(id), onSuccess: () => { setConfirm(null); void client.invalidateQueries({ queryKey: ['consignments'] }) } })
  return <Modal isOpen size="lg" title="Supplier settlements" onClose={() => { if (!mutation.isPending) onClose() }} error={mutation.error?.message ?? query.error?.message} footer={<Button variant="secondary" disabled={mutation.isPending} onClick={onClose}>Close</Button>}>
    <p>Mark a settlement only after the supplier payable has been handled separately. This action changes settlement status only; it does not pay the supplier.</p>
    {query.isPending ? <p role="status">Loading settlements...</p> : query.isError ? <Button onClick={() => void query.refetch()}>Retry settlements</Button> : <DataTable caption="Draft consignment settlements"><thead><tr><th>Settlement</th><th className="numeric-cell">Quantity sold</th><th className="numeric-cell">Amount</th><th>Action</th></tr></thead><tbody>{query.data.map((entry) => <tr key={entry.id}><td><code>{entry.settlementNumber}</code></td><td className="numeric-cell"><Quantity value={entry.quantitySold} /></td><td className="numeric-cell"><Money amount={entry.totalAmount} /></td><td>{access.manage && <Button variant="secondary" disabled={mutation.isPending} onClick={() => { mutation.reset(); setConfirm(entry) }}>Mark settled</Button>}</td></tr>)}</tbody></DataTable>}
    {query.isSuccess && !query.data.length && <p>No draft settlements for this supplier.</p>}
    {confirm && <div className="create-form-container"><p>Confirm settlement <code>{confirm.settlementNumber}</code> for <Money amount={confirm.totalAmount} />?</p><div className="document-actions"><Button variant="secondary" disabled={mutation.isPending} onClick={() => setConfirm(null)}>Back</Button><Button loading={mutation.isPending} onClick={() => { if (access.manage && !mutation.isPending) mutation.mutate(confirm.id) }}>Confirm settlement</Button></div></div>}
  </Modal>
}
