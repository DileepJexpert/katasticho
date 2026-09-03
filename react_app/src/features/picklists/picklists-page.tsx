import { useQuery } from '@tanstack/react-query'
import { ChevronLeft, ChevronRight, ListChecks } from 'lucide-react'
import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDateTime, formatStatusLabel } from '@/shared/format/format'
import { listPicklists, type Picklist } from '@/features/picklists/picklists-api'
import { PickProgress } from '@/features/picklists/pick-progress'

export function PicklistsPage() {
  const [page, setPage] = useState(0)
  const navigate = useNavigate()
  const picklists = useQuery({
    queryKey: ['picklists', { page }],
    queryFn: () => listPicklists(page),
  })
  const picklistPage = picklists.data

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Inventory / Warehouse"
        title="Picklists"
        description="Warehouse picking coverage from the existing fulfilment workflow."
        actions={<StatusChip status="Read-only pilot" />}
      />

      <section className="list-panel" aria-label="Picklist directory">
        <div className="list-toolbar list-toolbar--stacked">
          <p className="list-toolbar-note">The current Picklist API provides server pagination only. Status filtering and search are intentionally unavailable until the backend contract supports them.</p>
        </div>

        {picklists.isError ? (
          <div className="directory-state directory-state--error" role="alert">
            <strong>Picklists could not be loaded.</strong>
            <p>Check your connection and permissions, then refresh the page.</p>
          </div>
        ) : picklists.isLoading ? (
          <div aria-live="polite" className="directory-state">Loading picklists...</div>
        ) : picklistPage?.content.length ? (
          <>
            <DataTable caption="Picklists">
              <thead>
                <tr>
                  <th scope="col">Picklist</th>
                  <th scope="col">Sales order</th>
                  <th scope="col">Warehouse</th>
                  <th scope="col">Line coverage</th>
                  <th scope="col">Created</th>
                  <th scope="col">Status</th>
                </tr>
              </thead>
              <tbody>
                {picklistPage.content.map((picklist) => <PicklistRow key={picklist.id} onOpen={() => navigate(appRoutes.picklistDetail(picklist.id))} picklist={picklist} />)}
              </tbody>
            </DataTable>
            <footer className="table-footer">
              <span>{picklistPage.totalElements} picklist{picklistPage.totalElements === 1 ? '' : 's'} in this organisation</span>
              <div className="pagination-actions">
                <button aria-label="Previous page" disabled={picklistPage.page === 0} onClick={() => setPage((current) => current - 1)} type="button"><ChevronLeft aria-hidden="true" size={16} /></button>
                <span>Page {picklistPage.page + 1} of {Math.max(picklistPage.totalPages, 1)}</span>
                <button aria-label="Next page" disabled={picklistPage.last} onClick={() => setPage((current) => current + 1)} type="button"><ChevronRight aria-hidden="true" size={16} /></button>
              </div>
            </footer>
          </>
        ) : (
          <div className="directory-state">
            <ListChecks aria-hidden="true" size={24} />
            <strong>No picklists found.</strong>
            <p>Create and work picklists in the existing Flutter workflow while this React module remains read-only.</p>
          </div>
        )}
      </section>

      <p className="directory-note">Open a picklist to review server-returned warehouse, source-order, line, batch, rack, and pick-quantity information. All operational changes remain in Flutter during migration.</p>
    </section>
  )
}

function PicklistRow({ onOpen, picklist }: { onOpen: () => void; picklist: Picklist }) {
  return (
    <tr>
      <td><Button className="document-link" onClick={onOpen} variant="ghost"><code>{picklist.picklistNumber}</code></Button></td>
      <td><code>{picklist.salesOrderNumber ?? '--'}</code></td>
      <td>{picklist.warehouseName ?? '--'}</td>
      <td><PickProgress pickedCount={picklist.pickedCount} totalCount={picklist.lineCount} /></td>
      <td>{formatDateTime(picklist.createdAt)}</td>
      <td><StatusChip status={formatStatusLabel(picklist.status)} /></td>
    </tr>
  )
}
