import { useState } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { Link, useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button, DataTable, PageHeader, StatusChip } from '@/design-system'
import { formatDateTime } from '@/shared/format/format'
import { useInventoryAccess } from '@/features/inventory/inventory-access'
import { listPicklists } from './picklists-api'
import { CreatePicklistModal } from './picklist-create-modal'
import { PickProgress } from './pick-progress'

export function PicklistsPage() {
  const [page, setPage] = useState(0)
  const [creating, setCreating] = useState(false)
  const access = useInventoryAccess()
  const client = useQueryClient()
  const navigate = useNavigate()
  const query = useQuery({ queryKey: ['picklists', { page }], queryFn: () => listPicklists(page) })
  return <section className="workspace-page">
    <PageHeader eyebrow="Inventory / Fulfilment" title="Picklists" description="Plan warehouse picking against shippable sales-order lines, then record the quantities actually picked."
      actions={<><Button variant="secondary" onClick={() => void query.refetch()}>Refresh</Button>{access.operate && <Button onClick={() => setCreating(true)}>Create picklist</Button>}</>} />
    <section className="list-panel" aria-label="Picklist directory">
      {query.isError ? <div className="directory-state directory-state--error" role="alert">{query.error.message}<Button variant="secondary" onClick={() => void query.refetch()}>Retry</Button></div>
        : query.isPending ? <div className="directory-state" role="status">Loading picklists...</div> : <>
          <DataTable caption="Picklists"><thead><tr><th>Picklist</th><th>Sales order</th><th>Warehouse</th><th>Line coverage</th><th>Created</th><th>Status</th></tr></thead><tbody>{query.data.content.map((entry) => <tr key={entry.id}>
            <td><Link className="table-row-link" to={appRoutes.picklistDetail(entry.id)}><code>{entry.picklistNumber}</code></Link></td><td><code>{entry.salesOrderNumber ?? '--'}</code></td><td>{entry.warehouseName ?? '--'}</td>
            <td><PickProgress pickedCount={entry.pickedCount} totalCount={entry.lineCount} /></td><td>{formatDateTime(entry.createdAt)}</td><td><StatusChip status={entry.status} /></td>
          </tr>)}</tbody></DataTable>
          {!query.data.content.length && <div className="directory-state">No picklists on this page.</div>}
          <footer className="table-footer"><span>{query.data.totalElements} picklists</span><div className="pagination-actions"><Button variant="secondary" disabled={page === 0} onClick={() => setPage(page - 1)}>Previous</Button><span>Page {page + 1} of {Math.max(1, query.data.totalPages)}</span><Button variant="secondary" disabled={query.data.last} onClick={() => setPage(page + 1)}>Next</Button></div></footer>
        </>}
    </section>
    {creating && <CreatePicklistModal onClose={() => setCreating(false)} onSuccess={(id) => { setCreating(false); void client.invalidateQueries({ queryKey: ['picklists'] }); navigate(appRoutes.picklistDetail(id)) }} />}
  </section>
}
