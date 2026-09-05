import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Button, DataTable, Modal, Quantity, SearchInput } from '@/design-system'
import { getItem } from '@/features/items/items-api'
import { formatDate } from '@/shared/format/format'
import { listAvailableBatches, type BatchDetail } from './batches-api'

export function BatchAllocationPicker({ itemId, value, onChange, warehouseId, warehouseName, quantity, automatic = false, disabled = false, allowClear = true, instruction }: {
  itemId: string | null; value: string | null; onChange: (batchId: string | undefined, batch?: BatchDetail) => void
  warehouseId?: string | null; warehouseName?: string | null; quantity: number; automatic?: boolean; disabled?: boolean; allowClear?: boolean; instruction?: string
}) {
  const [open, setOpen] = useState(false)
  const [search, setSearch] = useState('')
  const item = useQuery({ queryKey: ['items', itemId, 'batch-policy'], queryFn: () => getItem(itemId!), enabled: open && Boolean(itemId) })
  const batches = useQuery({ queryKey: ['available-batches', itemId, warehouseId ?? 'default'], queryFn: () => listAvailableBatches(itemId!, warehouseId), enabled: open && Boolean(item.data?.trackBatches) })
  if (!itemId) return <span className="cell-muted">Non-stock line</span>
  const rows = (batches.data ?? []).filter((batch) => batch.batchNumber.toLowerCase().includes(search.toLowerCase()))
  const selected = batches.data?.find((batch) => batch.id === value)
  const label = value ? selected?.batchNumber ?? 'Batch selected' : automatic ? 'Automatic FEFO' : 'Select batch'
  function choose(batch?: BatchDetail) { onChange(batch?.id, batch); setOpen(false) }
  return <>
    <Button disabled={disabled} variant="secondary" onClick={() => setOpen(true)}>{label}</Button>
    {open && <Modal isOpen size="lg" title="Batch allocation" onClose={() => setOpen(false)}
      description={`Available stock in ${warehouseName || (warehouseId ? 'the order warehouse' : 'the default warehouse')}, ordered by earliest expiry. Availability is checked again when stock is issued.`}
      error={item.isError ? item.error.message : batches.isError ? batches.error.message : null}
      footer={<><Button variant="secondary" onClick={() => setOpen(false)}>Close</Button>{!automatic && allowClear && value && <Button variant="secondary" onClick={() => choose()}>Clear batch selection</Button>}{automatic && <Button onClick={() => choose()}>Use automatic FEFO</Button>}</>}>
      {item.isPending || (item.data?.trackBatches && batches.isPending) ? <div className="directory-state" role="status">Loading available batches...</div>
        : item.isError || batches.isError ? <Button onClick={() => { void item.refetch(); if (item.data?.trackBatches) void batches.refetch() }} variant="secondary">Retry</Button>
          : !item.data?.trackBatches ? <p>This item does not use batch tracking.</p> : <>
            <div className="pricing-control-row"><SearchInput ariaLabel="Search batch number" value={search} onChange={setSearch} placeholder="Search batch number" /><span>Requested: <Quantity value={quantity} /></span><Button variant="ghost" onClick={() => void batches.refetch()}>Refresh</Button></div>
            {!automatic && <p className="cell-muted">{instruction ?? "Select a batch to record this challan's batch-level stock movement. This dispatch does not automatically split the line across batches."}</p>}
            {rows.length ? <DataTable caption="Available batches in FEFO order"><thead><tr><th scope="col">Batch</th><th scope="col">Expiry</th><th className="numeric-cell" scope="col">Available</th><th scope="col">Allocation</th></tr></thead><tbody>{rows.map((batch) => <tr key={batch.id}>
              <td><code>{batch.batchNumber}</code></td><td>{formatDate(batch.expiryDate)}</td><td className="numeric-cell"><Quantity value={batch.quantityAvailable} /></td>
              <td><Button variant={batch.id === value ? 'primary' : 'secondary'} disabled={Number(batch.quantityAvailable) < quantity} onClick={() => choose(batch)}>{Number(batch.quantityAvailable) < quantity ? 'Insufficient for line' : batch.id === value ? 'Selected' : 'Select'}</Button></td>
            </tr>)}</tbody></DataTable> : <div className="directory-state">{search ? 'No batches match this search.' : 'No available batches in this warehouse.'}</div>}
          </>}
    </Modal>}
  </>
}
