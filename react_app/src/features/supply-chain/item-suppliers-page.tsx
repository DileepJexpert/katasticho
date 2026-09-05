import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Button, CheckboxInput, FormGrid, Modal, Money, PageHeader, Quantity } from '@/design-system'
import { TextField } from '@/design-system/text-field'
import type { Item } from '@/features/items/items-api'
import type { Supplier } from '@/features/suppliers/suppliers-api'
import { useSessionStore } from '@/shared/session/session-store'
import { WorkspaceBoundary } from '@/shared/workflows/workspace-boundary'
import { QueryFeedback } from '@/shared/workflows/query-feedback'
import { ConfirmedAction } from '@/shared/workflows/confirmed-action'
import { LocalDirectory } from '@/shared/workflows/local-directory'
import { addItemSupplier, listItemSuppliers, planningRoles, removeItemSupplier, setPreferredSupplier, type ItemSupplier } from './supply-chain-api'
import { PlanningItemPicker, PlanningSupplierName, PlanningSupplierPicker, validNumber } from './planning-pickers'

export function ItemSuppliersPage() { return <WorkspaceBoundary roles={planningRoles}><ItemSuppliers /></WorkspaceBoundary> }
function ItemSuppliers() {
  const [item, setItem] = useState<Item | null>(null)
  return <section className="workspace-page"><PageHeader eyebrow="Supply planning" title="Item suppliers" description="Maintain supplier-specific ordering quantities, lead times and price references." /><PlanningItemPicker value={item} onChange={setItem} />{item ? <Mappings key={item.id} item={item} /> : <div className="directory-state">Select an item to view its suppliers.</div>}</section>
}
function Mappings({ item }: { item: Item }) {
  const orgId = useSessionStore((s) => s.user!.orgId)
  const client = useQueryClient()
  const [create, setCreate] = useState(false)
  const [action, setAction] = useState<{ row: ItemSupplier; remove: boolean } | null>(null)
  const query = useQuery({ queryKey: ['supply', orgId, 'item-suppliers', item.id], queryFn: () => listItemSuppliers(item.id) })
  const refresh = () => { setCreate(false); setAction(null); void client.invalidateQueries({ queryKey: ['supply', orgId] }) }
  return <><Button onClick={() => setCreate(true)}>Add supplier mapping</Button><QueryFeedback query={query}><LocalDirectory rows={query.data ?? []} caption="Supplier mappings" searchText={(m) => `${m.supplierSku ?? ''} ${m.preferred ? 'preferred' : ''}`} header={<tr><th>Supplier</th><th>Supplier SKU</th><th>Lead days</th><th className="numeric-cell">Minimum order</th><th className="numeric-cell">Unit price</th><th>Preferred</th><th>Actions</th></tr>} renderRow={(m) => <tr key={m.id}><td><PlanningSupplierName id={m.supplierId} /></td><td className="table-code">{m.supplierSku ?? '--'}</td><td>{m.leadTimeDays}</td><td className="numeric-cell"><Quantity value={m.minOrderQty} /></td><td className="numeric-cell"><Money amount={m.unitPrice} /></td><td>{m.preferred ? 'Yes' : 'No'}</td><td>{!m.preferred && <Button variant="ghost" onClick={() => setAction({ row: m, remove: false })}>Set preferred</Button>}<Button variant="ghost" onClick={() => setAction({ row: m, remove: true })}>Remove mapping</Button></td></tr>} /></QueryFeedback>
    {create && <MappingEditor item={item} onClose={() => setCreate(false)} onDone={refresh} />}
    {action && <ConfirmedAction title={action.remove ? 'Remove supplier mapping' : 'Set preferred supplier'} description={action.remove ? 'Remove this supplier from the item? Existing purchase documents are retained.' : 'Replace the current preferred supplier for this item?'} destructive={action.remove} run={() => action.remove ? removeItemSupplier(action.row.id) : setPreferredSupplier(item.id, action.row.supplierId)} onClose={() => setAction(null)} onDone={refresh} />}
  </>
}
function MappingEditor({ item, onClose, onDone }: { item: Item; onClose: () => void; onDone: () => void }) {
  const [supplier, setSupplier] = useState<Supplier | null>(null)
  const [days, setDays] = useState('7')
  const [qty, setQty] = useState('1')
  const [price, setPrice] = useState(String(item.purchasePrice ?? 0))
  const [sku, setSku] = useState('')
  const [preferred, setPreferred] = useState(false)
  const valid = supplier && validNumber(days) && Number.isInteger(+days) && validNumber(qty) && +qty > 0 && validNumber(price)
  const save = useMutation({ mutationFn: () => addItemSupplier({ itemId: item.id, supplierId: supplier!.id, leadTimeDays: +days, minOrderQty: +qty, unitPrice: +price, supplierSku: sku, preferred }), onSuccess: onDone })
  return <Modal isOpen title={`Add supplier for ${item.name}`} error={save.error?.message} onClose={() => { if (!save.isPending) onClose() }} footer={<><Button variant="secondary" disabled={save.isPending} onClick={onClose}>Cancel</Button><Button disabled={!valid || save.isPending} onClick={() => save.mutate()}>Save mapping</Button></>}><FormGrid><PlanningSupplierPicker value={supplier} onChange={setSupplier} /><TextField label="Lead time days" type="number" min="0" step="1" value={days} onChange={(e) => setDays(e.target.value)} /><TextField label="Minimum order quantity" type="number" min="0" step="any" value={qty} onChange={(e) => setQty(e.target.value)} /><TextField label="Unit price" type="number" min="0" step="any" value={price} onChange={(e) => setPrice(e.target.value)} /><TextField label="Supplier SKU" value={sku} onChange={(e) => setSku(e.target.value)} /><CheckboxInput label="Set as preferred supplier" checked={preferred} onChange={(e) => setPreferred(e.target.checked)} /></FormGrid></Modal>
}
