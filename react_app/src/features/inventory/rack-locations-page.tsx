import { useState, type FormEvent } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Button, DataTable, DirectoryToolbar, EntityPicker, FormField, FormGrid, Modal, PageHeader, SearchInput, SelectInput, StatusChip, TextInput } from '@/design-system'
import { createRackLocation, listRackLocations, type RackLocation } from '@/features/pharmacy/pharmacy-api'
import { listWarehouses, type Warehouse } from '@/features/warehouses/warehouses-api'
import { useInventoryAccess } from './inventory-access'
import { InventoryWarehousePicker } from './inventory-pickers'

export function RackPicker({ warehouseId, value, onChange, disabled, id, label = 'Select rack' }: {
  warehouseId: string; value: string | null; onChange: (id: string | null) => void; disabled?: boolean; id?: string; label?: string
}) {
  const access = useInventoryAccess()
  const query = useQuery({ queryKey: ['pharmacy-racks', warehouseId], queryFn: () => listRackLocations(warehouseId), enabled: Boolean(warehouseId) && access.operate })
  const options = (query.data ?? []).filter((rack) => rack.active && rack.warehouseId === warehouseId)
  return <>
    <EntityPicker<RackLocation> id={id} ariaLabel={label} value={value} selectedEntity={options.find((rack) => rack.id === value)}
      options={options} getOptionId={(rack) => rack.id} getOptionLabel={(rack) => rack.code}
      getOptionDescription={(rack) => [rack.name, rack.zone, rack.aisle, rack.shelf, rack.bin].filter(Boolean).join(' / ')}
      onChange={onChange} disabled={disabled || !warehouseId || !access.operate || query.isPending || query.isError} />
    {query.isError && <div role="alert">{query.error.message}<Button variant="secondary" disabled={disabled} onClick={() => void query.refetch()}>Retry racks</Button></div>}
  </>
}

export function RackLocationsPage() {
  return <section className="workspace-page">
    <PageHeader eyebrow="Inventory / Storage" title="Rack locations" description="Warehouse-scoped storage labels used by item defaults and putaway tasks." />
    <RackLocationsWorkspace />
  </section>
}

export function RackLocationsWorkspace() {
  const access = useInventoryAccess()
  const [warehouseId, setWarehouseId] = useState('')
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(0)
  const [creating, setCreating] = useState(false)
  const warehouses = useQuery({ queryKey: ['warehouses'], queryFn: listWarehouses, enabled: access.operate })
  const racks = useQuery({ queryKey: ['pharmacy-racks', warehouseId], queryFn: () => listRackLocations(warehouseId || undefined), enabled: access.operate })
  const rows = (racks.data ?? []).filter((rack) => [rack.code, rack.name, rack.zone, rack.aisle, rack.shelf, rack.bin].some((value) => value?.toLowerCase().includes(search.trim().toLowerCase())))
  const pages = Math.max(1, Math.ceil(rows.length / 25))
  const currentPage = Math.min(page, pages - 1)
  if (!access.operate) return <p>Your role cannot access rack locations.</p>
  return <section className="list-panel" aria-label="Rack locations">
    <DirectoryToolbar ariaLabel="Filter rack locations">
      <SearchInput value={search} onChange={(value) => { setSearch(value); setPage(0) }} onClear={() => setSearch('')} placeholder="Search rack, zone, aisle or bin" />
      <SelectInput aria-label="Filter racks by warehouse" value={warehouseId} onChange={(event) => { setWarehouseId(event.target.value); setPage(0) }} placeholderOption="All warehouses" options={(warehouses.data ?? []).map((warehouse) => ({ value: warehouse.id, label: `${warehouse.code} / ${warehouse.name}` }))} />
      <Button onClick={() => setCreating(true)}>New rack location</Button>
    </DirectoryToolbar>
    <p className="cell-muted">Racks are location labels, not quantity-per-bin balances. The existing API supports creation only, not rack editing or removal.</p>
    {warehouses.isError && <div role="alert">Warehouse names could not be loaded.<Button variant="secondary" onClick={() => void warehouses.refetch()}>Retry warehouses</Button></div>}
    {racks.isError ? <div role="alert">{racks.error.message}<Button variant="secondary" onClick={() => void racks.refetch()}>Retry racks</Button></div> : racks.isPending ? <p role="status">Loading rack locations...</p> : <>
      <DataTable caption="Rack locations"><thead><tr><th>Rack</th><th>Warehouse</th><th>Zone</th><th>Aisle / shelf / bin</th><th>Status</th></tr></thead>
        <tbody>{rows.slice(currentPage * 25, currentPage * 25 + 25).map((rack) => <tr key={rack.id}>
          <td><div className="cell-stack"><code>{rack.code}</code><span>{rack.name ?? '--'}</span></div></td>
          <td>{warehouses.data?.find((warehouse) => warehouse.id === rack.warehouseId)?.name ?? rack.warehouseId}</td>
          <td>{rack.zone ?? '--'}</td><td>{[rack.aisle, rack.shelf, rack.bin].map((value) => value || '--').join(' / ')}</td>
          <td><StatusChip status={rack.active ? 'Active' : 'Inactive'} /></td>
        </tr>)}</tbody>
      </DataTable>
      {!rows.length && <p>No rack locations match the selected filters.</p>}
      <div className="document-actions"><Button variant="secondary" disabled={currentPage === 0} onClick={() => setPage(currentPage - 1)}>Previous racks</Button><span>Page {currentPage + 1} of {pages}</span><Button variant="secondary" disabled={currentPage + 1 >= pages} onClick={() => setPage(currentPage + 1)}>Next racks</Button></div>
    </>}
    {creating && <CreateRackModal initialWarehouse={(warehouses.data ?? []).find((warehouse) => warehouse.id === warehouseId && warehouse.active) ?? null} onClose={() => setCreating(false)} />}
  </section>
}

function CreateRackModal({ initialWarehouse, onClose }: { initialWarehouse: Warehouse | null; onClose: () => void }) {
  const access = useInventoryAccess()
  const client = useQueryClient()
  const [warehouse, setWarehouse] = useState(initialWarehouse)
  const [form, setForm] = useState({ code: '', name: '', zone: '', aisle: '', shelf: '', bin: '' })
  const [error, setError] = useState('')
  const save = useMutation({ mutationFn: createRackLocation, onSuccess: () => { void client.invalidateQueries({ queryKey: ['pharmacy-racks'] }); onClose() } })
  function submit(event: FormEvent) {
    event.preventDefault()
    if (save.isPending || !access.operate) return
    if (!warehouse?.active || !form.code.trim()) { setError('Choose an active warehouse and enter a rack code.'); return }
    if (Object.entries(form).some(([key, value]) => value.trim().length > (key === 'name' ? 100 : 50))) { setError('Rack name supports 100 characters; other fields support 50.'); return }
    setError('')
    save.mutate({ warehouseId: warehouse.id, code: form.code.trim(), name: form.name.trim() || undefined, zone: form.zone.trim() || undefined, aisle: form.aisle.trim() || undefined, shelf: form.shelf.trim() || undefined, bin: form.bin.trim() || undefined })
  }
  return <Modal isOpen title="New rack location" onClose={() => { if (!save.isPending) onClose() }} error={error || save.error?.message}>
    <form onSubmit={submit} className="create-form-container">
      <FormField label="Warehouse" required><InventoryWarehousePicker value={warehouse} onChange={setWarehouse} disabled={save.isPending} /></FormField>
      <FormGrid columns={2}>{(Object.keys(form) as (keyof typeof form)[]).map((key) => <FormField key={key} label={{ code: 'Rack code', name: 'Location name', zone: 'Zone label', aisle: 'Aisle', shelf: 'Shelf', bin: 'Bin' }[key]} required={key === 'code'}>
        <TextInput value={form[key]} maxLength={key === 'name' ? 100 : 50} required={key === 'code'} disabled={save.isPending} onChange={(event) => setForm({ ...form, [key]: event.target.value })} />
      </FormField>)}</FormGrid>
      <p className="cell-muted">Check the warehouse and code carefully. This API has no edit or delete operation.</p>
      <div className="document-actions"><Button variant="secondary" disabled={save.isPending} onClick={onClose}>Cancel</Button><Button type="submit" loading={save.isPending}>Create rack</Button></div>
    </form>
  </Modal>
}
