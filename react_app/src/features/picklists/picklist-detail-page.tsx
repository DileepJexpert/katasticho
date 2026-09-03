import { useState } from 'react'
import type { ReactNode } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, CheckCircle2, ListChecks, Play, XCircle } from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import { formatDateTime, formatStatusLabel } from '@/shared/format/format'
import {
  cancelPicklist,
  completePicklist,
  getPicklist,
  startPicklist,
  updatePicklistLines,
  type PicklistLine,
} from '@/features/picklists/picklists-api'
import { PickProgress } from '@/features/picklists/pick-progress'

export function PicklistDetailPage() {
  const { picklistId } = useParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [selectedLineForEdit, setSelectedLineForEdit] = useState<PicklistLine | null>(null)

  const picklist = useQuery({
    queryKey: ['picklists', picklistId],
    queryFn: () => getPicklist(picklistId!),
    enabled: Boolean(picklistId),
  })

  // Workflow mutations
  const startMutation = useMutation({
    mutationFn: () => startPicklist(picklistId!),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['picklists', picklistId] }),
  })

  const completeMutation = useMutation({
    mutationFn: () => completePicklist(picklistId!),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['picklists', picklistId] }),
  })

  const cancelMutation = useMutation({
    mutationFn: () => cancelPicklist(picklistId!),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['picklists', picklistId] }),
  })

  if (!picklistId) return <DocumentError onBack={() => navigate(appRoutes.picklists)} />
  if (picklist.isLoading) return <section className="workspace-page"><div aria-live="polite" className="directory-state">Loading picklist...</div></section>
  if (picklist.isError || !picklist.data) return <DocumentError onBack={() => navigate(appRoutes.picklists)} />

  const document = picklist.data
  const isDraft = document.status === 'DRAFT'
  const isInProgress = document.status === 'IN_PROGRESS'
  const isCompleted = document.status === 'COMPLETED'
  const isCancelled = document.status === 'CANCELLED'

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Inventory / Warehouse / Picklist"
        title={document.picklistNumber}
        description={`${document.warehouseName ?? 'Warehouse'} Â· created ${formatDateTime(document.createdAt)}`}
        actions={
          <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
            {isDraft && (
              <Button disabled={startMutation.isPending} onClick={() => startMutation.mutate()} variant="primary">
                <Play size={16} /> Start Picking
              </Button>
            )}
            {isInProgress && (
              <Button disabled={completeMutation.isPending} onClick={() => completeMutation.mutate()} variant="primary">
                <CheckCircle2 size={16} /> Complete Picklist
              </Button>
            )}
            {!isCompleted && !isCancelled && (
              <Button disabled={cancelMutation.isPending} onClick={() => cancelMutation.mutate()} variant="destructive">
                <XCircle size={16} /> Cancel
              </Button>
            )}
            <StatusChip status={formatStatusLabel(document.status)} />
          </div>
        }
      />

      <div className="document-actions">
        <Button onClick={() => navigate(appRoutes.picklists)} variant="secondary">
          <ArrowLeft aria-hidden="true" size={16} /> Back to picklists
        </Button>
      </div>

      <div className="document-layout">
        <section className="document-card">
          <h2>Picklist information</h2>
          <dl className="document-facts">
            <Fact
              label="Source sales order"
              value={
                document.salesOrderNumber ? (
                  <Button className="document-link" onClick={() => navigate(appRoutes.salesOrderDetail ? appRoutes.salesOrderDetail(document.salesOrderId) : `/sales-orders/${document.salesOrderId}`)} variant="ghost">
                    <code>{document.salesOrderNumber}</code>
                  </Button>
                ) : (
                  '--'
                )
              }
            />
            <Fact label="Warehouse" value={document.warehouseName ?? '--'} />
            <Fact label="Created" value={formatDateTime(document.createdAt)} />
            <Fact label="Started" value={formatDateTime(document.startedAt)} />
            <Fact label="Completed" value={formatDateTime(document.completedAt)} />
          </dl>
        </section>

        <aside className="document-card document-card--summary">
          <h2>Picking coverage</h2>
          <PickProgress pickedCount={document.pickedCount} totalCount={document.lineCount} />
          <div className="progress-row"><span>Lines</span><strong>{document.lineCount}</strong></div>
          <div className="progress-row"><span>Lines with quantity recorded</span><strong>{document.pickedCount}</strong></div>
          <div className="progress-row progress-row--total"><span>Status</span><StatusChip status={formatStatusLabel(document.status)} /></div>
        </aside>
      </div>

      <section className="document-card document-card--lines">
        <h2>Pick lines</h2>
        <DataTable caption="Picklist lines">
          <thead>
            <tr>
              <th scope="col">Item</th>
              <th className="numeric-cell" scope="col">Required</th>
              <th className="numeric-cell" scope="col">Picked</th>
              <th scope="col">Coverage</th>
              <th scope="col">Batch</th>
              <th scope="col">Rack</th>
              <th scope="col">Notes</th>
              <th scope="col">Actions</th>
            </tr>
          </thead>
          <tbody>
            {document.lines.length ? (
              document.lines.map((line) => (
                <tr key={line.id}>
                  <td>
                    <div className="item-primary">
                      <span aria-hidden="true" className="item-avatar"><ListChecks size={15} /></span>
                      <div className="cell-stack">
                        <strong>{line.itemName}</strong>
                        <code>{line.itemSku ?? line.itemId}</code>
                      </div>
                    </div>
                  </td>
                  <td className="numeric-cell"><Quantity unit={line.unitOfMeasure} value={line.requiredQuantity} /></td>
                  <td className="numeric-cell">
                    <strong style={{ color: Number(line.pickedQuantity) >= Number(line.requiredQuantity) ? 'var(--color-success, #2e7d32)' : 'inherit' }}>
                      <Quantity unit={line.unitOfMeasure} value={line.pickedQuantity} />
                    </strong>
                  </td>
                  <td>
                    <StatusChip
                      status={
                        Number(line.pickedQuantity) >= Number(line.requiredQuantity)
                          ? 'Picked'
                          : Number(line.pickedQuantity) > 0
                            ? 'Partial'
                            : 'Pending'
                      }
                    />
                  </td>
                  <td>{line.batchNumber ? <code>{line.batchNumber}</code> : '--'}</td>
                  <td>{line.rackLocation ?? '--'}</td>
                  <td>{line.notes ?? '--'}</td>
                  <td>
                    {isInProgress && (
                      <Button onClick={() => setSelectedLineForEdit(line)} variant="ghost">
                        Update Qty
                      </Button>
                    )}
                  </td>
                </tr>
              ))
            ) : (
              <tr>
                <td className="cell-muted" colSpan={8}>No pick lines were returned for this picklist.</td>
              </tr>
            )}
          </tbody>
        </DataTable>
      </section>

      <section className="document-card document-card--notes">
        <h2>Notes</h2>
        <div className="document-notes"><p>{document.notes ?? '--'}</p></div>
      </section>

      {/* Edit Pick Line Modal */}
      {selectedLineForEdit && (
        <UpdatePickLineModal
          line={selectedLineForEdit}
          onClose={() => setSelectedLineForEdit(null)}
          onSuccess={() => {
            setSelectedLineForEdit(null)
            queryClient.invalidateQueries({ queryKey: ['picklists', picklistId] })
          }}
          picklistId={picklistId}
        />
      )}
    </section>
  )
}

function UpdatePickLineModal({
  picklistId,
  line,
  onClose,
  onSuccess,
}: {
  picklistId: string
  line: PicklistLine
  onClose: () => void
  onSuccess: () => void
}) {
  const [pickedQuantity, setPickedQuantity] = useState(Number(line.pickedQuantity || line.requiredQuantity))
  const [batchNumber, setBatchNumber] = useState(line.batchNumber || '')
  const [notes, setNotes] = useState(line.notes || '')

  const mutation = useMutation({
    mutationFn: () =>
      updatePicklistLines(picklistId, [
        {
          lineId: line.id,
          pickedQuantity,
          batchNumber: batchNumber || undefined,
          notes: notes || undefined,
        },
      ]),
    onSuccess: () => onSuccess(),
  })

  return (
    <div className="modal-backdrop" role="dialog">
      <div className="modal-dialog">
        <header className="modal-header">
          <h3>Record Picked Quantity</h3>
          <Button onClick={onClose} variant="ghost">âœ•</Button>
        </header>
        <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <p>
            Item: <strong>{line.itemName}</strong> (Required: {line.requiredQuantity} {line.unitOfMeasure})
          </p>
          <label className="field-group">
            <span>Picked Quantity</span>
            <input
              min={0}
              onChange={(e) => setPickedQuantity(Number(e.target.value))}
              type="number"
              value={pickedQuantity}
            />
          </label>
          <label className="field-group">
            <span>Batch Number Picked</span>
            <input onChange={(e) => setBatchNumber(e.target.value)} placeholder="e.g. BATCH-001" value={batchNumber} />
          </label>
          <label className="field-group">
            <span>Notes</span>
            <input onChange={(e) => setNotes(e.target.value)} placeholder="Rack A-12, Bin 4" value={notes} />
          </label>
        </div>
        <footer className="modal-footer">
          <Button onClick={onClose} variant="secondary">Cancel</Button>
          <Button disabled={mutation.isPending} onClick={() => mutation.mutate()} variant="primary">
            {mutation.isPending ? 'Saving...' : 'Save Picked Qty'}
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
        <strong>Picklist not found.</strong>
        <p>The requested picklist could not be loaded.</p>
        <Button onClick={onBack} variant="secondary">Back to picklists</Button>
      </div>
    </section>
  )
}