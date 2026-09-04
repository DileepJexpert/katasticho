import { useState } from 'react'
import type { ReactNode } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  ArrowLeft,
  CheckCircle2,
  ClipboardCheck,
  XCircle,
} from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatDateTime, formatStatusLabel } from '@/shared/format/format'
import {
  cancelStockCount,
  getStockCount,
  postStockCount,
  updateStockCountLines,
  type StockCountLine,
} from '@/features/stock-counts/stock-counts-api'

export function StockCountDetailPage() {
  const { countId } = useParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [selectedLineForCount, setSelectedLineForCount] = useState<StockCountLine | null>(null)

  const count = useQuery({
    queryKey: ['stock-counts', countId],
    queryFn: () => getStockCount(countId!),
    enabled: Boolean(countId),
  })

  const postMutation = useMutation({
    mutationFn: () => postStockCount(countId!),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['stock-counts', countId] }),
  })

  const cancelMutation = useMutation({
    mutationFn: () => cancelStockCount(countId!),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['stock-counts', countId] }),
  })

  if (!countId) return <DocumentError onBack={() => navigate(appRoutes.stockCounts)} />
  if (count.isLoading) return <section className="workspace-page"><div aria-live="polite" className="directory-state">Loading stock count audit...</div></section>
  if (count.isError || !count.data) return <DocumentError onBack={() => navigate(appRoutes.stockCounts)} />

  const doc = count.data
  const isInProgress = doc.status === 'IN_PROGRESS'
  const isPosted = doc.status === 'POSTED'
  const isCancelled = doc.status === 'CANCELLED'

  const totalVarianceValue = doc.lines.reduce((sum, l) => sum + Number(l.discrepancyValue || 0), 0)

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Inventory / Audits / Stock Count"
        title={doc.countNumber}
        description={`Warehouse: ${doc.warehouseName ?? doc.warehouseId} · Created ${formatDate(doc.createdAt)}`}
        actions={
          <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
            {isInProgress && (
              <Button disabled={postMutation.isPending} onClick={() => postMutation.mutate()} variant="primary">
                <CheckCircle2 size={16} /> Post & Reconcile Journal
              </Button>
            )}
            {!isPosted && !isCancelled && (
              <Button disabled={cancelMutation.isPending} onClick={() => cancelMutation.mutate()} variant="destructive">
                <XCircle size={16} /> Cancel Audit
              </Button>
            )}
            <StatusChip status={formatStatusLabel(doc.status)} />
          </div>
        }
      />

      <div className="document-actions">
        <Button onClick={() => navigate(appRoutes.stockCounts)} variant="secondary">
          <ArrowLeft aria-hidden="true" size={16} /> Back to stock counts
        </Button>
      </div>

      <div className="document-layout">
        <section className="document-card">
          <h2>Audit Information</h2>
          <dl className="document-facts">
            <Fact label="Warehouse" value={doc.warehouseName ?? doc.warehouseId} />
            <Fact label="Audit Date" value={formatDate(doc.createdAt)} />
            <Fact label="Posted At" value={formatDateTime(doc.postedAt)} />
            <Fact label="Notes" value={doc.notes ?? '--'} />
          </dl>
        </section>

        <aside className="document-card document-card--summary">
          <h2>Variance Matrix</h2>
          <div className="progress-row"><span>Audited Lines</span><strong>{doc.lines.length}</strong></div>
          <div className="progress-row"><span>Total Variance Value</span><strong><Money amount={totalVarianceValue} /></strong></div>
          <div className="progress-row progress-row--total"><span>Status</span><StatusChip status={formatStatusLabel(doc.status)} /></div>
        </aside>
      </div>

      <section className="document-card document-card--lines">
        <h2>Count Matrix & Ledger Variance</h2>
        <DataTable caption="Stock count lines">
          <thead>
            <tr>
              <th scope="col">Item</th>
              <th scope="col">Batch #</th>
              <th className="numeric-cell" scope="col">System Qty</th>
              <th className="numeric-cell" scope="col">Counted Qty</th>
              <th className="numeric-cell" scope="col">Variance Qty</th>
              <th className="numeric-cell" scope="col">Variance Value</th>
              <th scope="col">Notes</th>
              <th scope="col">Actions</th>
            </tr>
          </thead>
          <tbody>
            {doc.lines.map((line) => {
              const diff = Number(line.countedQuantity) - Number(line.systemQuantity)
              return (
                <tr key={line.id}>
                  <td>
                    <div className="item-primary">
                      <span aria-hidden="true" className="item-avatar"><ClipboardCheck size={15} /></span>
                      <div className="cell-stack">
                        <strong>{line.itemName}</strong>
                        <code>{line.itemSku ?? line.itemId}</code>
                      </div>
                    </div>
                  </td>
                  <td>{line.batchNumber ? <code>{line.batchNumber}</code> : '--'}</td>
                  <td className="numeric-cell">{line.systemQuantity}</td>
                  <td className="numeric-cell">
                    <strong>{line.countedQuantity}</strong>
                  </td>
                  <td className="numeric-cell">
                    <strong style={{ color: diff < 0 ? 'var(--color-danger, #d32f2f)' : diff > 0 ? 'var(--color-success, #2e7d32)' : 'inherit' }}>
                      {diff > 0 ? `+${diff}` : diff}
                    </strong>
                  </td>
                  <td className="numeric-cell"><Money amount={line.discrepancyValue} /></td>
                  <td>{line.notes ?? '--'}</td>
                  <td>
                    {isInProgress && (
                      <Button onClick={() => setSelectedLineForCount(line)} variant="ghost">
                        Update Count
                      </Button>
                    )}
                  </td>
                </tr>
              )
            })}
          </tbody>
        </DataTable>
      </section>

      {/* Edit Count Line Modal */}
      {selectedLineForCount && (
        <UpdateCountLineModal
          countId={countId}
          line={selectedLineForCount}
          onClose={() => setSelectedLineForCount(null)}
          onSuccess={() => {
            setSelectedLineForCount(null)
            queryClient.invalidateQueries({ queryKey: ['stock-counts', countId] })
          }}
        />
      )}
    </section>
  )
}

function UpdateCountLineModal({
  countId,
  line,
  onClose,
  onSuccess,
}: {
  countId: string
  line: StockCountLine
  onClose: () => void
  onSuccess: () => void
}) {
  const [countedQuantity, setCountedQuantity] = useState(Number(line.countedQuantity))
  const [notes, setNotes] = useState(line.notes || '')

  const mutation = useMutation({
    mutationFn: () =>
      updateStockCountLines(countId, [
        {
          lineId: line.id,
          countedQuantity,
          notes: notes || undefined,
        },
      ]),
    onSuccess: () => onSuccess(),
  })

  return (
    <div className="modal-backdrop" role="dialog">
      <div className="modal-dialog">
        <header className="modal-header">
          <h3>Record Physical Count</h3>
          <Button onClick={onClose} variant="ghost">✕</Button>
        </header>
        <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <p>
            Item: <strong>{line.itemName}</strong> (System Balance: {line.systemQuantity})
          </p>
          <label className="field-group">
            <span>Physical Counted Quantity</span>
            <input
              min={0}
              onChange={(e) => setCountedQuantity(Number(e.target.value))}
              type="number"
              value={countedQuantity}
            />
          </label>
          <label className="field-group">
            <span>Variance Reason / Notes</span>
            <input onChange={(e) => setNotes(e.target.value)} placeholder="e.g. Broken packaging, misplacement" value={notes} />
          </label>
        </div>
        <footer className="modal-footer">
          <Button onClick={onClose} variant="secondary">Cancel</Button>
          <Button disabled={mutation.isPending} onClick={() => mutation.mutate()} variant="primary">
            {mutation.isPending ? 'Saving...' : 'Save Count'}
          </Button>
        </footer>
      </div>
    </div>
  )
}

function Fact({ label, value }: { label: string; value: ReactNode }) {
  return (
    <div className="document-fact">
      <dt>{label}</dt>
      <dd>{value}</dd>
    </div>
  )
}

function DocumentError({ onBack }: { onBack: () => void }) {
  return (
    <section className="workspace-page">
      <div className="directory-state directory-state--error" role="alert">
        <strong>Stock count audit not found.</strong>
        <p>The requested audit record could not be loaded.</p>
        <Button onClick={onBack} variant="secondary">Back to stock counts</Button>
      </div>
    </section>
  )
}