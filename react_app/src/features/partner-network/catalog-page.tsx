import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Button, EntityPicker, FormField, FormGrid, Modal, Money, PageHeader, Quantity, SelectInput, StatusChip } from '@/design-system'
import { TextField } from '@/design-system/text-field'
import { listItems, type Item } from '@/features/items/items-api'
import { useSessionStore } from '@/shared/session/session-store'
import { WorkspaceBoundary } from '@/shared/workflows/workspace-boundary'
import { ConfirmedAction } from '@/shared/workflows/confirmed-action'
import { QueryFeedback } from '@/shared/workflows/query-feedback'
import { LocalDirectory } from '@/shared/workflows/local-directory'
import { listCatalog, listPartners, searchSupplierCatalog, publishCatalogItem, unpublishCatalogItem, networkRoles, networkWriteBlockers, type CatalogItem, type CatalogRequest } from './partner-network-api'

export function CatalogPage({ supplier = false }: { supplier?: boolean }) {
  return <WorkspaceBoundary roles={networkRoles}><CatalogWorkspace key={String(supplier)} supplier={supplier} /></WorkspaceBoundary>
}
function CatalogWorkspace({ supplier }: { supplier: boolean }) {
  const orgId = useSessionStore((s) => s.user!.orgId)
  const [search, setSearch] = useState('')
  const [applied, setApplied] = useState('')
  const [editing, setEditing] = useState<CatalogItem | 'new' | null>(null)
  const [removing, setRemoving] = useState<CatalogItem | null>(null)
  const client = useQueryClient()
  const query = useQuery({ queryKey: ['network', orgId, supplier ? 'supplier-catalog' : 'catalog', applied], queryFn: () => supplier ? searchSupplierCatalog(applied) : listCatalog() })
  const partners = useQuery({ queryKey: ['network', orgId, 'partners'], queryFn: listPartners, enabled: supplier })
  const refresh = () => { setEditing(null); setRemoving(null); void client.invalidateQueries({ queryKey: ['network', orgId] }) }
  return <section className="workspace-page">
    <PageHeader eyebrow="Partner network" title={supplier ? 'Supplier catalog' : 'Published catalog'} description={supplier ? 'Products published by your approved seller organisations.' : 'Maintain catalog metadata shared with approved trading partners.'} actions={!supplier && <Button onClick={() => setEditing('new')}>Publish item</Button>} />
    {supplier && <><p className="banner">{networkWriteBlockers.order}</p><form onSubmit={(e) => { e.preventDefault(); setApplied(search.trim()) }}><FormGrid><TextField label="Search supplier products" value={search} onChange={(e) => setSearch(e.target.value)} /><Button type="submit">Search suppliers</Button></FormGrid></form>{partners.isError && <p role="alert">Supplier names could not be loaded: {partners.error.message}</p>}</>}
    <QueryFeedback query={query}><LocalDirectory rows={query.data ?? []} caption="Catalog items" searchText={(c) => `${c.displayName} ${c.publishedSku ?? ''} ${c.manufacturer ?? ''}`}
      header={<tr><th>Product</th>{supplier && <th>Seller</th>}<th>SKU</th><th>Availability</th><th className="numeric-cell">Minimum order</th><th className="numeric-cell">MRP</th><th className="numeric-cell">Trade price</th>{!supplier && <th>Actions</th>}</tr>}
      renderRow={(c) => <tr key={c.id}><td>{c.displayName}</td>{supplier && <td>{partners.data?.find((p) => p.sellerOrgId === c.sellerOrgId)?.sellerOrgName ?? 'Seller name unavailable'}</td>}<td className="table-code">{c.publishedSku || '--'}</td><td><StatusChip status={c.isActive ? c.availabilityStatus : 'INACTIVE'} /></td><td className="numeric-cell"><Quantity value={c.minOrderQty} /></td><td className="numeric-cell"><Money amount={c.publishedMrp} /></td><td className="numeric-cell"><Money amount={c.publishedPtr} /></td>{!supplier && <td><Button variant="ghost" onClick={() => setEditing(c)}>Edit {c.displayName}</Button>{c.isActive && <Button variant="ghost" onClick={() => setRemoving(c)}>Unpublish {c.displayName}</Button>}</td>}</tr>} /></QueryFeedback>
    {editing && <CatalogEditor entry={editing} onClose={() => setEditing(null)} onDone={refresh} />}
    {removing && <ConfirmedAction title="Unpublish product" description={`Remove ${removing.displayName} from supplier search? Existing orders are retained.`} run={() => unpublishCatalogItem(removing.id)} onClose={() => setRemoving(null)} onDone={refresh} />}
  </section>
}
function CatalogEditor({ entry, onClose, onDone }: { entry: CatalogItem | 'new'; onClose: () => void; onDone: () => void }) {
  const [item, setItem] = useState<Item | null>(null)
  const [draft, setDraft] = useState<CatalogRequest>(() => entry === 'new' ? { itemId: '', drugMasterId: null, displayName: '', publishedSku: '', hsnCode: '', manufacturer: '', packSize: '', category: '', description: '', publishedMrp: 0, publishedPtr: 0, minOrderQty: 1, availabilityStatus: 'AVAILABLE' } : { itemId: entry.itemId, drugMasterId: entry.drugMasterId, displayName: entry.displayName, publishedSku: entry.publishedSku, hsnCode: entry.hsnCode, manufacturer: entry.manufacturer, packSize: entry.packSize, category: entry.category, description: entry.description, publishedMrp: entry.publishedMrp, publishedPtr: entry.publishedPtr, minOrderQty: entry.minOrderQty, availabilityStatus: entry.availabilityStatus })
  const save = useMutation({ mutationFn: () => publishCatalogItem(draft), onSuccess: onDone })
  const valid = !!draft.itemId && !!draft.displayName.trim() && [draft.publishedMrp, draft.publishedPtr].every((n) => n !== null && String(n).trim() !== '' && Number.isFinite(+n) && +n >= 0) && draft.minOrderQty !== null && Number.isFinite(+draft.minOrderQty) && +draft.minOrderQty > 0
  return <Modal isOpen title={entry === 'new' ? 'Publish catalog item' : 'Update catalog item'} error={save.error?.message} onClose={() => { if (!save.isPending) onClose() }} footer={<><Button variant="secondary" disabled={save.isPending} onClick={onClose}>Cancel</Button><Button disabled={!valid || save.isPending} onClick={() => save.mutate()}>Publish</Button></>}>
    <p>Publishing makes this metadata visible to approved buyers. Updating an inactive entry publishes it again.</p>
    <FormGrid>
      {entry === 'new' && <EntityPicker<Item> ariaLabel="Catalog product" value={item?.id ?? null} selectedEntity={item} onSearch={async (search) => (await listItems({ search, activeOnly: true })).content} getOptionId={(i) => i.id} getOptionLabel={(i) => i.name} getOptionDescription={(i) => i.sku ?? ''} onChange={(_id, i) => { setItem(i ?? null); setDraft({ ...draft, itemId: i?.id ?? '', displayName: i?.name ?? '', publishedSku: i?.sku ?? '', hsnCode: i?.hsnCode ?? '', manufacturer: i?.manufacturer ?? '', category: i?.category ?? '', packSize: i?.packSize ?? '', publishedMrp: i?.mrp ?? 0, publishedPtr: i?.salePrice ?? 0 }) }} />}
      <TextField label="Display name" value={draft.displayName} required onChange={(e) => setDraft({ ...draft, displayName: e.target.value })} />
      {(['publishedSku', 'hsnCode', 'manufacturer', 'packSize', 'category', 'description'] as const).map((field) => <TextField key={field} label={{ publishedSku: 'Published SKU', hsnCode: 'HSN', manufacturer: 'Manufacturer', packSize: 'Pack size', category: 'Category', description: 'Description' }[field]} value={draft[field] ?? ''} onChange={(e) => setDraft({ ...draft, [field]: e.target.value })} />)}
      {(['publishedMrp', 'publishedPtr', 'minOrderQty'] as const).map((field) => <TextField key={field} label={{ publishedMrp: 'MRP', publishedPtr: 'Trade price', minOrderQty: 'Minimum order quantity' }[field]} type="number" min="0" step="any" value={draft[field] ?? ''} onChange={(e) => setDraft({ ...draft, [field]: e.target.value })} />)}
      <FormField label="Availability"><SelectInput value={draft.availabilityStatus} onChange={(e) => setDraft({ ...draft, availabilityStatus: e.target.value })}>{[...new Set(['AVAILABLE', 'LIMITED', 'OUT_OF_STOCK', 'ON_ORDER', draft.availabilityStatus])].map((v) => <option key={v}>{v}</option>)}</SelectInput></FormField>
    </FormGrid>
  </Modal>
}
