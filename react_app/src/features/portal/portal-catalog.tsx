import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Button, DataTable, DirectoryToolbar, FormCard, FormGrid, Modal, Money as DesignMoney, Quantity, SearchInput, StatusChip, TablePagination } from '@/design-system'
import { TextField } from '@/design-system/text-field'
import { QueryFeedback } from '@/shared/workflows/query-feedback'
import type { PortalApi, PortalItem, PortalOrderResult } from './portal-api'

function Money({ amount }: { amount: number | string | null | undefined }) {
  return <DesignMoney amount={amount} showCurrency={false} />
}

export function PortalCatalogPage({ api }: { api: PortalApi }) {
  const client = useQueryClient()
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(0)
  const [frequent, setFrequent] = useState(false)
  const [cart, setCart] = useState<{ item: PortalItem; quantity: string }[]>([])
  const [notes, setNotes] = useState('')
  const [reference, setReference] = useState('')
  const [date, setDate] = useState('')
  const [confirm, setConfirm] = useState(false)
  const [result, setResult] = useState<PortalOrderResult | null>(null)
  const catalog = useQuery({ queryKey: ['catalog', search, page], queryFn: () => api.catalog(search, page), enabled: !frequent })
  const favourites = useQuery({ queryKey: ['frequent-items'], queryFn: api.frequentItems, enabled: frequent })
  const save = useMutation({ mutationFn: () => api.placeOrder({ lines: cart.map(({ item, quantity }) => ({ itemId: item.id, quantity: Number(quantity) })), notes, referenceNumber: reference, ...(date ? { expectedShipmentDate: date } : {}) }), retry: false, onSuccess: (order) => { setResult(order); setCart([]); setNotes(''); setReference(''); setDate(''); setConfirm(false); void client.invalidateQueries({ queryKey: ['orders'] }); void client.invalidateQueries({ queryKey: ['frequent-items'] }) } })
  const valid = cart.length > 0 && cart.every((line) => line.quantity.trim() && Number.isFinite(Number(line.quantity)) && Number(line.quantity) > 0)
  const items = frequent ? favourites.data ?? [] : catalog.data?.items ?? []
  const query = frequent ? favourites : catalog
  function add(item: PortalItem) { if (!cart.some((line) => line.item.id === item.id)) setCart([...cart, { item, quantity: '1' }]) }
  return <><p className="banner">Prices shown are indicative for one unit. The server applies quantity pricing, schemes and tax when saving. Amounts omit a currency symbol because the portal API does not return the organisation currency. An order is not a payment, stock reservation or dispatch confirmation.</p>
    {result && <FormCard title={`Order saved: ${result.salesorderNumber}`}><StatusChip status={result.status} /><p>Server-confirmed order total: <Money amount={result.total} /></p></FormCard>}
    <DirectoryToolbar actions={<Button variant="secondary" onClick={() => setFrequent(!frequent)}>{frequent ? 'Browse catalog' : 'Frequently ordered'}</Button>}>{!frequent && <SearchInput ariaLabel="Search portal products" value={search} onChange={(value) => { setSearch(value); setPage(0) }} onClear={() => { setSearch(''); setPage(0) }} />}</DirectoryToolbar>
    <QueryFeedback query={query}><DataTable caption={frequent ? 'Frequently ordered products' : 'Product catalog'}><thead><tr><th>Product</th><th>Unit</th><th className="numeric-cell">Indicative price</th><th>Availability</th><th>Scheme</th><th>Action</th></tr></thead><tbody>{items.map((item) => <tr key={item.id}><td>{item.name}<div className="table-code">{item.sku}</div></td><td>{item.unitOfMeasure}</td><td className="numeric-cell"><Money amount={item.salePrice} /></td><td>{item.inStock ? 'Available' : 'Unavailable'}</td><td>{item.schemeDescription ?? '--'}</td><td><Button variant="secondary" disabled={save.isPending || cart.some((line) => line.item.id === item.id)} onClick={() => add(item)}>Add {item.name}</Button></td></tr>)}</tbody></DataTable>{!items.length && <p>No products found.</p>}{!frequent && catalog.data && <TablePagination page={page} totalPages={catalog.data.totalPages} totalElements={catalog.data.totalElements} onPageChange={setPage} itemLabel="product" filterDescription="in your portal catalog" />}</QueryFeedback>
    <FormCard title={`Order request (${cart.length} lines)`}><DataTable caption="Order request lines"><thead><tr><th>Product</th><th>Quantity</th><th>Action</th></tr></thead><tbody>{cart.map((line) => <tr key={line.item.id}><td>{line.item.name}</td><td><TextField label={`Quantity for ${line.item.name}`} type="number" min="0" step="any" value={line.quantity} disabled={save.isPending} onChange={(e) => setCart(cart.map((entry) => entry.item.id === line.item.id ? { ...entry, quantity: e.target.value } : entry))} /></td><td><Button variant="ghost" disabled={save.isPending} onClick={() => setCart(cart.filter((entry) => entry.item.id !== line.item.id))}>Remove {line.item.name}</Button></td></tr>)}</tbody></DataTable><FormGrid><TextField label="Your reference" value={reference} disabled={save.isPending} onChange={(e) => setReference(e.target.value)} /><TextField label="Requested shipment date" type="date" value={date} disabled={save.isPending} onChange={(e) => setDate(e.target.value)} /><TextField label="Order notes" value={notes} disabled={save.isPending} onChange={(e) => setNotes(e.target.value)} /></FormGrid><Button disabled={!valid || save.isPending} onClick={() => { save.reset(); setConfirm(true) }}>Review order request</Button></FormCard>
    {confirm && <Modal isOpen title="Submit order request" onClose={() => { if (!save.isPending) setConfirm(false) }} error={save.error?.message} footer={<><Button variant="secondary" disabled={save.isPending} onClick={() => setConfirm(false)}>Cancel</Button><Button disabled={!valid || save.isPending || save.isError} loading={save.isPending} onClick={() => save.mutate()}>Submit order once</Button></>}><p>The supplier's server determines the final price and order status.</p>{cart.map((line) => <p key={line.item.id}>{line.item.name}: <Quantity value={line.quantity} /> {line.item.unitOfMeasure}</p>)}{save.isError && <p role="alert">Do not submit again until you check Orders. A lost response may mean the order was already saved. Close this dialog and check the order history first.</p>}</Modal>}
  </>
}
