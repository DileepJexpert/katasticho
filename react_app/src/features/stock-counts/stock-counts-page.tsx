import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ChevronLeft, ChevronRight, ClipboardCheck, Plus } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import {
  createStockCount,
  listStockCounts,
  type CreateStockCountRequest,
  type StockCount,
} from '@/features/stock-counts/stock-counts-api'

export function StockCountsPage() {
  const [page, setPage] = useState(0)
  const [showCreateModal, setShowCreateModal] = useState(false)
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const counts = useQuery({
    queryKey: ['stock-counts', { page }],
    queryFn: () => listStockCounts(page),
  })
  const countPage = counts.data

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Inventory / Audits"
        title="Physical Stock Counts & Audits"
        description="Physical inventory audits, variance reconciliation, and automated stock adjustment journal posting."
        actions={
          <Button onClick={() => setShowCreateModal(true)} variant="primary">
            <Plus size={16} /> Start Stock Count
          </Button>
        }
      />

      <section className="list-panel" aria-label="Stock count directory">
        {counts.isError ? (
          <div className="directory-state directory-state--error" role="alert">
            <strong>Stock counts could not be loaded.</strong>
            <p>Check your connection and permissions, then refresh the page.</p>
          </div>
        ) : counts.isLoading ? (
          <div aria-live="polite" className="directory-state">Loading stock counts...</div>
        ) : countPage?.content.length ? (
          <>
            <DataTable caption="Stock counts">
              <thead>
                <tr>
                  <th scope="col">Count #</th>
                  <th scope="col">Warehouse</th>
                  <th scope="col">Audit date</th>
                  <th scope="col">Lines</th>
                  <th scope="col">Status</th>
                  <th scope="col">Actions</th>
                </tr>
              </thead>
              <tbody>
                {countPage.content.map((count) => (
                  <StockCountRow
                    count={count}
                    key={count.id}
                    onOpen={() => navigate(appRoutes.stockCountDetail ? appRoutes.stockCountDetail(count.id) : `/stock-counts/${count.id}`)}
                  />
                ))}
              </tbody>
            </DataTable>
            <footer className="table-footer">
              <span>{countPage.totalElements} count{countPage.totalElements === 1 ? '' : 's'} in this organisation</span>
              <div className="pagination-actions">
                <button aria-label="Previous page" disabled={countPage.page === 0} onClick={() => setPage((current) => current - 1)} type="button"><ChevronLeft aria-hidden="true" size={16} /></button>
                <span>Page {countPage.page + 1} of {Math.max(countPage.totalPages, 1)}</span>
                <button aria-label="Next page" disabled={countPage.last} onClick={() => setPage((current) => current + 1)} type="button"><ChevronRight aria-hidden="true" size={16} /></button>
              </div>
            </footer>
          </>
        ) : (
          <div className="directory-state">
            <ClipboardCheck aria-hidden="true" size={24} />
            <strong>No stock counts recorded.</strong>
            <p>Create a physical count audit to reconcile warehouse inventory balances against ledger records.</p>
          </div>
        )}
      </section>

      {/* Create Modal */}
      {showCreateModal && (
        <CreateStockCountModal
          onClose={() => setShowCreateModal(false)}
          onSuccess={(id) => {
            setShowCreateModal(false)
            queryClient.invalidateQueries({ queryKey: ['stock-counts'] })
            navigate(appRoutes.stockCountDetail ? appRoutes.stockCountDetail(id) : `/stock-counts/${id}`)
          }}
        />
      )}
    </section>
  )
}

function StockCountRow({ onOpen, count }: { onOpen: () => void; count: StockCount }) {
  return (
    <tr onClick={onOpen} style={{ cursor: 'pointer' }}>
      <td>
        <div className="item-primary">
          <span aria-hidden="true" className="item-avatar"><ClipboardCheck size={15} /></span>
          <div className="cell-stack">
            <strong>{count.countNumber}</strong>
          </div>
        </div>
      </td>
      <td>{count.warehouseName ?? count.warehouseId}</td>
      <td>{formatDate(count.createdAt)}</td>
      <td>{count.lines.length} item{count.lines.length === 1 ? '' : 's'}</td>
      <td><StatusChip status={formatStatusLabel(count.status)} /></td>
      <td>
        <Button onClick={(e) => { e.stopPropagation(); onOpen() }} variant="ghost">
          Open Audit
        </Button>
      </td>
    </tr>
  )
}

function CreateStockCountModal({ onClose, onSuccess }: { onClose: () => void; onSuccess: (id: string) => void }) {
  const [warehouseId, setWarehouseId] = useState('WH-MAIN')
  const [notes, setNotes] = useState('')

  const mutation = useMutation({
    mutationFn: () => {
      const payload: CreateStockCountRequest = {
        warehouseId,
        notes: notes || undefined,
      }
      return createStockCount(payload)
    },
    onSuccess: (res) => onSuccess(res.id),
  })

  return (
    <div className="modal-backdrop" role="dialog">
      <div className="modal-dialog">
        <header className="modal-header">
          <h3>Start Physical Stock Count</h3>
          <Button onClick={onClose} variant="ghost">✕</Button>
        </header>
        <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <label className="field-group">
            <span>Audit Warehouse ID *</span>
            <input onChange={(e) => setWarehouseId(e.target.value)} value={warehouseId} />
          </label>
          <label className="field-group">
            <span>Audit Purpose / Notes</span>
            <input onChange={(e) => setNotes(e.target.value)} placeholder="e.g. Month-end inventory verification" value={notes} />
          </label>
        </div>
        <footer className="modal-footer">
          <Button onClick={onClose} variant="secondary">Cancel</Button>
          <Button disabled={!warehouseId || mutation.isPending} onClick={() => mutation.mutate()} variant="primary">
            {mutation.isPending ? 'Starting...' : 'Start Audit'}
          </Button>
        </footer>
      </div>
    </div>
  )
}