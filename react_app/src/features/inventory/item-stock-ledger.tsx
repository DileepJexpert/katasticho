import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Button, DataTable, DirectoryToolbar, DocumentCard, Fact, FactList, Modal, Money, Quantity, SearchInput, StatusChip } from '@/design-system'
import { getItemMovements, type StockMovement } from '@/features/items/items-api'
import { formatDate, formatDateTime, formatStatusLabel } from '@/shared/format/format'

const PAGE_SIZE = 50

export function ItemStockLedger({ itemId, unit }: { itemId: string; unit: string | null }) {
  const [page, setPage] = useState(0)
  const [search, setSearch] = useState('')
  const [selected, setSelected] = useState<StockMovement | null>(null)
  const query = useQuery({
    queryKey: ['items', itemId, 'movements', page],
    queryFn: () => getItemMovements(itemId, page),
  })
  const rows = query.data ?? []
  const term = search.trim().toLowerCase()
  const visible = rows.filter((row) => [row.id, row.movementType, row.warehouseName, row.referenceNumber, row.referenceId, row.batchNumber, row.notes]
    .some((value) => value?.toLowerCase().includes(term)))

  function changePage(next: number) {
    setPage(next)
    setSearch('')
    setSelected(null)
  }

  return <DocumentCard title="Stock ledger" variant="lines">
    <DirectoryToolbar ariaLabel="Stock ledger controls">
      <SearchInput value={search} onChange={setSearch} onClear={() => setSearch('')} placeholder="Search movements on this page" />
      <Button variant="secondary" disabled={query.isFetching} onClick={() => { setSelected(null); void query.refetch() }}>Refresh ledger</Button>
    </DirectoryToolbar>
    <p className="banner">Read-only stock audit. Correct linked receipts, dispatches and invoices through their document workflows, not by reversing individual stock rows here.</p>
    {query.isError ? <div role="alert" className="directory-state directory-state--error">{query.error.message}<Button variant="secondary" onClick={() => void query.refetch()}>Retry ledger</Button></div>
      : query.isPending ? <p role="status">Loading stock ledger...</p> : <>
        <DataTable caption="Item stock ledger">
          <thead><tr><th>Date</th><th>Movement</th><th>Warehouse</th><th>Reference</th><th>Batch</th><th className="numeric-cell">Quantity</th><th className="numeric-cell">Unit cost</th><th className="numeric-cell">Cost value</th><th>State</th><th>Audit</th></tr></thead>
          <tbody>{visible.map((movement) => <tr key={movement.id}>
            <td>{formatDate(movement.movementDate)}</td>
            <td>{formatStatusLabel(movement.movementType)}</td>
            <td>{movement.warehouseName}</td>
            <td><div className="cell-stack"><code>{movement.referenceNumber ?? movement.referenceId ?? '--'}</code><span className="cell-muted">{formatStatusLabel(movement.referenceType)}</span></div></td>
            <td><code>{movement.batchNumber ?? '--'}</code></td>
            <td className="numeric-cell"><Quantity unit={unit} value={movement.quantity} /></td>
            <td className="numeric-cell"><Money amount={movement.unitCost} /></td>
            <td className="numeric-cell"><Money amount={movement.totalCost} /></td>
            <td><StatusChip status={movement.reversed ? 'Reversed' : movement.reversal ? 'Reversal' : 'Recorded'} /></td>
            <td><Button variant="ghost" aria-label={`Audit movement ${movement.id}`} onClick={() => setSelected(movement)}>Details</Button></td>
          </tr>)}</tbody>
        </DataTable>
        {!visible.length && <p className="directory-state">{search ? 'No matching movements on this page.' : page > 0 ? 'End of the stock ledger. Return to the previous page.' : 'No stock movements have been recorded for this item.'}</p>}
      </>}
    <div className="document-actions" aria-label="Stock ledger pagination">
      <Button variant="secondary" disabled={page === 0 || query.isFetching} onClick={() => changePage(page - 1)}>Previous movements</Button>
      <span>Page {page + 1}</span>
      <Button variant="secondary" disabled={query.isFetching || query.isError || rows.length < PAGE_SIZE} onClick={() => changePage(page + 1)}>Next movements</Button>
      <span className="cell-muted">Up to 50 movements per page. The API does not return a total count.</span>
    </div>
    {selected && <Modal isOpen onClose={() => setSelected(null)} title="Stock movement audit" size="lg" footer={<Button variant="secondary" onClick={() => setSelected(null)}>Close audit</Button>}>
      <FactList>
        <Fact label="Movement ID" mono value={selected.id} />
        <Fact label="Movement date" value={formatDate(selected.movementDate)} />
        <Fact label="Recorded at" value={formatDateTime(selected.createdAt)} />
        <Fact label="Movement type" value={formatStatusLabel(selected.movementType)} />
        <Fact label="Warehouse" value={selected.warehouseName} />
        <Fact label="Quantity change" value={<Quantity unit={unit} value={selected.quantity} />} />
        <Fact label="Recorded unit cost" value={<Money amount={selected.unitCost} />} />
        <Fact label="Recorded cost value" value={<Money amount={selected.totalCost} />} />
        <Fact label="Reference type" value={formatStatusLabel(selected.referenceType)} />
        <Fact label="Reference number" mono value={selected.referenceNumber} />
        <Fact label="Reference ID" mono value={selected.referenceId} />
        <Fact label="Batch number" mono value={selected.batchNumber} />
        <Fact label="Batch ID" mono value={selected.batchId} />
        <Fact label="Batch expiry" value={formatDate(selected.batchExpiryDate)} />
        <Fact label="Reversal of movement" mono value={selected.reversalOfId} />
        <Fact label="Original reversed" value={selected.reversed ? 'Yes' : 'No'} />
        <Fact label="Reason / notes" value={selected.notes} />
      </FactList>
      <p className="cell-muted">Cost value is the amount recorded by the stock service, not a journal debit or credit. Quantity carries the movement direction.</p>
    </Modal>}
  </DocumentCard>
}
