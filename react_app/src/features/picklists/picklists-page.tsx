import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ChevronLeft, ChevronRight, ListChecks, Plus } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDateTime, formatStatusLabel } from '@/shared/format/format'
import {
  createPicklist,
  listPicklists,
  type CreatePicklistRequest,
  type Picklist,
} from '@/features/picklists/picklists-api'
import { PickProgress } from '@/features/picklists/pick-progress'

export function PicklistsPage() {
  const [page, setPage] = useState(0)
  const [showCreateModal, setShowCreateModal] = useState(false)
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const picklists = useQuery({
    queryKey: ['picklists', { page }],
    queryFn: () => listPicklists(page),
  })
  const picklistPage = picklists.data

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Inventory / Warehouse Fulfilment"
        title="Picklists"
        description="Warehouse wave picking, barcode rack validation, and item batch allocation for sales orders."
        actions={
          <Button onClick={() => setShowCreateModal(true)} variant="primary">
            <Plus size={16} /> Create Picklist
          </Button>
        }
      />

      <section className="list-panel" aria-label="Picklist directory">
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
                  <th scope="col">Actions</th>
                </tr>
              </thead>
              <tbody>
                {picklistPage.content.map((picklist) => (
                  <PicklistRow
                    key={picklist.id}
                    onOpen={() => navigate(appRoutes.picklistDetail ? appRoutes.picklistDetail(picklist.id) : `/picklists/${picklist.id}`)}
                    picklist={picklist}
                  />
                ))}
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
            <p>Generate a picklist from a confirmed Sales Order to begin warehouse picking.</p>
          </div>
        )}
      </section>

      {/* Create Picklist Modal */}
      {showCreateModal && (
        <CreatePicklistModal
          onClose={() => setShowCreateModal(false)}
          onSuccess={(newId) => {
            setShowCreateModal(false)
            queryClient.invalidateQueries({ queryKey: ['picklists'] })
            if (newId) {
              navigate(appRoutes.picklistDetail ? appRoutes.picklistDetail(newId) : `/picklists/${newId}`)
            }
          }}
        />
      )}
    </section>
  )
}

function PicklistRow({ onOpen, picklist }: { onOpen: () => void; picklist: Picklist }) {
  return (
    <tr onClick={onOpen} style={{ cursor: 'pointer' }}>
      <td>
        <div className="item-primary">
          <span aria-hidden="true" className="item-avatar"><ListChecks size={15} /></span>
          <div className="cell-stack">
            <strong>{picklist.picklistNumber}</strong>
            <span>{picklist.lineCount} line{picklist.lineCount === 1 ? '' : 's'}</span>
          </div>
        </div>
      </td>
      <td><code>{picklist.salesOrderNumber ?? picklist.salesOrderId}</code></td>
      <td>{picklist.warehouseName ?? picklist.warehouseId}</td>
      <td><PickProgress pickedCount={picklist.pickedCount} totalCount={picklist.lineCount} /></td>
      <td>{formatDateTime(picklist.createdAt)}</td>
      <td><StatusChip status={formatStatusLabel(picklist.status)} /></td>
      <td>
        <Button onClick={(e) => { e.stopPropagation(); onOpen() }} variant="ghost">
          Open Picklist
        </Button>
      </td>
    </tr>
  )
}

function CreatePicklistModal({ onClose, onSuccess }: { onClose: () => void; onSuccess: (id: string) => void }) {
  const [salesOrderId, setSalesOrderId] = useState('')
  const [warehouseId, setWarehouseId] = useState('WH-MAIN')
  const [notes, setNotes] = useState('')

  const mutation = useMutation({
    mutationFn: () => {
      const payload: CreatePicklistRequest = {
        salesOrderId,
        warehouseId,
        notes: notes || undefined,
      }
      return createPicklist(payload)
    },
    onSuccess: (res) => onSuccess(res.id),
  })

  return (
    <div className="modal-backdrop" role="dialog">
      <div className="modal-dialog">
        <header className="modal-header">
          <h3>Create Warehouse Picklist</h3>
          <Button onClick={onClose} variant="ghost">âœ•</Button>
        </header>
        <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <label className="field-group">
            <span>Sales Order ID / Number *</span>
            <input onChange={(e) => setSalesOrderId(e.target.value)} placeholder="e.g. SO-2026-001" value={salesOrderId} />
          </label>
          <label className="field-group">
            <span>Fulfillment Warehouse ID *</span>
            <input onChange={(e) => setWarehouseId(e.target.value)} value={warehouseId} />
          </label>
          <label className="field-group">
            <span>Picklist Notes</span>
            <input onChange={(e) => setNotes(e.target.value)} placeholder="e.g. Priority dispatch, fragile packaging" value={notes} />
          </label>
        </div>
        <footer className="modal-footer">
          <Button onClick={onClose} variant="secondary">Cancel</Button>
          <Button disabled={!salesOrderId || mutation.isPending} onClick={() => mutation.mutate()} variant="primary">
            {mutation.isPending ? 'Generating...' : 'Generate Picklist'}
          </Button>
        </footer>
      </div>
    </div>
  )
}