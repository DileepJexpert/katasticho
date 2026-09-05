import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { useSearchParams } from 'react-router-dom'
import { Button, DataTable, DirectoryToolbar, FormField, PageHeader, SearchInput, SelectInput, StatusChip } from '@/design-system'
import { getItem, type Item } from '@/features/items/items-api'
import { listWarehouses } from '@/features/warehouses/warehouses-api'
import { formatDateTime } from '@/shared/format/format'
import { InventoryItemPicker } from './inventory-pickers'
import { listAvailableSerials, listSerialNumbers } from './serial-numbers-api'

export function SerialNumbersPage() {
  const [params] = useSearchParams()
  return <SerialNumbersWorkspace key={params.get('itemId') ?? ''} />
}

function SerialNumbersWorkspace() {
  const [params, setParams] = useSearchParams()
  const itemId = params.get('itemId') ?? ''
  const [selectedItem, setSelectedItem] = useState<Item | null>(null)
  const [mode, setMode] = useState('all')
  const [warehouseId, setWarehouseId] = useState('')
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(0)
  const item = useQuery({ queryKey: ['items', itemId], queryFn: () => getItem(itemId), enabled: Boolean(itemId) })
  const warehouses = useQuery({ queryKey: ['warehouses'], queryFn: listWarehouses })
  const records = useQuery({ queryKey: ['serial-numbers', itemId, page], queryFn: () => listSerialNumbers(itemId, page), enabled: Boolean(itemId) && mode === 'all' })
  const available = useQuery({ queryKey: ['serial-numbers', 'available', itemId, warehouseId], queryFn: () => listAvailableSerials(itemId, warehouseId || undefined), enabled: Boolean(itemId) && mode === 'available' })
  const query = mode === 'all' ? records : available
  const allRows = mode === 'all' ? records.data?.content ?? [] : available.data ?? []
  const filtered = allRows.filter((record) => record.serial.toLowerCase().includes(search.trim().toLowerCase()))
  const pages = mode === 'all' ? Math.max(1, records.data?.totalPages ?? 1) : Math.max(1, Math.ceil(filtered.length / 25))
  const currentPage = mode === 'all' ? page : Math.min(page, pages - 1)
  const visible = mode === 'all' ? filtered : filtered.slice(currentPage * 25, currentPage * 25 + 25)
  function changeItem(value: Item | null) {
    setSelectedItem(value); setPage(0); setSearch('')
    const next = new URLSearchParams(params)
    if (value) next.set('itemId', value.id); else next.delete('itemId')
    setParams(next)
  }
  return <section className="workspace-page">
    <PageHeader eyebrow="Inventory / Traceability" title="Serial numbers" description="Review the serial register by item, availability and warehouse. Serial status is not an inventory balance." />
    <FormField label="Item"><InventoryItemPicker value={item.data ?? (selectedItem?.id === itemId ? selectedItem : null)} onChange={changeItem} includeInactive /></FormField>
    {item.isError && <div role="alert">{item.error.message}<Button variant="secondary" onClick={() => void item.refetch()}>Retry item</Button></div>}
    <p className="cell-muted">Read-only review. Receiving, sale assignment, damage and returns need a separately reviewed document/stock integration. An empty register does not prove whether serial tracking is enabled.</p>
    {!itemId ? <p>Select an item to review its serial history.</p> : <section className="list-panel">
      <DirectoryToolbar ariaLabel="Filter serial register">
        <SelectInput aria-label="Serial view" value={mode} onChange={(event) => { setMode(event.target.value); setPage(0); setSearch('') }} options={[{ value: 'all', label: 'All serial history' }, { value: 'available', label: 'Available in stock' }]} />
        {mode === 'available' && <SelectInput aria-label="Serial warehouse" value={warehouseId} onChange={(event) => { setWarehouseId(event.target.value); setPage(0) }} placeholderOption="All warehouses" options={(warehouses.data ?? []).map((warehouse) => ({ value: warehouse.id, label: warehouse.name }))} />}
        <SearchInput value={search} onChange={(value) => { setSearch(value); if (mode === 'available') setPage(0) }} onClear={() => setSearch('')} placeholder={mode === 'all' ? 'Find serial on this page' : 'Find available serial'} />
      </DirectoryToolbar>
      {warehouses.isError && <div role="alert">Warehouse labels unavailable.<Button variant="secondary" onClick={() => void warehouses.refetch()}>Retry warehouses</Button></div>}
      {query.isError ? <div role="alert">{query.error.message}<Button variant="secondary" onClick={() => void query.refetch()}>Retry serials</Button></div> : query.isPending ? <p role="status">Loading serial numbers...</p> : <>
        <DataTable caption="Serial number register"><thead><tr><th>Serial</th><th>Warehouse</th><th>Status</th><th>Received / sold</th><th>Source line references</th><th>Notes</th></tr></thead>
          <tbody>{visible.map((record) => <tr key={record.id}>
            <td><code>{record.serial}</code></td><td>{warehouses.data?.find((warehouse) => warehouse.id === record.warehouseId)?.name ?? record.warehouseId ?? '--'}</td><td><StatusChip status={record.status} /></td>
            <td><div className="cell-stack"><span>{record.receivedAt ? formatDateTime(record.receivedAt) : '--'}</span><span>{record.soldAt ? formatDateTime(record.soldAt) : '--'}</span></div></td>
            <td><div className="cell-stack"><code>Receipt: {record.receiptLineId ?? '--'}</code><code>Invoice: {record.invoiceLineId ?? '--'}</code><code>Batch: {record.batchId ?? '--'}</code></div></td><td>{record.notes ?? '--'}</td>
          </tr>)}</tbody>
        </DataTable>
        {!visible.length && <p>No serial records match this view{mode === 'all' && search ? ' on this page' : ''}.</p>}
        <div className="document-actions"><Button variant="secondary" disabled={page === 0} onClick={() => { setPage(page - 1); if (mode === 'all') setSearch('') }}>Previous serials</Button><span>Page {currentPage + 1} of {pages}</span><Button variant="secondary" disabled={mode === 'all' ? records.data?.last !== false : currentPage + 1 >= pages} onClick={() => { setPage(page + 1); if (mode === 'all') setSearch('') }}>Next serials</Button></div>
      </>}
    </section>}
  </section>
}
