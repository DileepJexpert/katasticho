import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, Play, CheckCircle2, XCircle } from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { Button } from '@/design-system/button'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import {
  getMaintenanceWorkOrder,
  startMaintenanceWorkOrder,
  completeMaintenanceWorkOrder,
  cancelMaintenanceWorkOrder,
} from '@/features/maintenance/maintenance-api'

export function MaintenanceWorkOrderDetailPage() {
  const { orderId, mwoId, id: routeId } = useParams()
  const id = orderId || mwoId || routeId
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const [isCompleteOpen, setIsCompleteOpen] = useState(false)
  const [cost, setCost] = useState('250')
  const [notes, setNotes] = useState('')

  const query = useQuery({
    queryKey: ['maintenance-work-orders', id],
    queryFn: () => getMaintenanceWorkOrder(id!),
    enabled: Boolean(id),
  })

  const startMutation = useMutation({
    mutationFn: () => startMaintenanceWorkOrder(id!),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['maintenance-work-orders', id] }),
  })

  const completeMutation = useMutation({
    mutationFn: () => completeMaintenanceWorkOrder(id!, notes, Number(cost)),
    onSuccess: () => {
      setIsCompleteOpen(false)
      queryClient.invalidateQueries({ queryKey: ['maintenance-work-orders', id] })
    },
  })

  const cancelMutation = useMutation({
    mutationFn: () => cancelMaintenanceWorkOrder(id!),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['maintenance-work-orders', id] }),
  })

  if (!id) return <div className="directory-state">No MWO ID provided.</div>
  if (query.isLoading) return <div className="directory-state">Loading maintenance order details...</div>
  if (query.isError || !query.data) {
    return (
      <div className="directory-state directory-state--error">
        <strong>Unable to load maintenance work order.</strong>
        <Button onClick={() => navigate('/maintenance-work-orders')} variant="secondary">Back to orders</Button>
      </div>
    )
  }

  const document = query.data

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Manufacturing / Equipment Maintenance"
        title={document.mwoNumber}
        description={`Work Center: ${document.workstationName || document.workstationId} · Type: ${document.maintenanceType}`}
        actions={
          <div className="table-actions">
            <span className={document.priority === 'URGENT' ? 'status-badge status-badge--danger' : 'status-badge'}>
              {document.priority}
            </span>
            <StatusChip status={formatStatusLabel(document.status)} />
          </div>
        }
      />

      <div className="document-actions">
        <Button onClick={() => navigate('/maintenance-work-orders')} variant="secondary">
          <ArrowLeft aria-hidden="true" size={16} />
          Back to maintenance orders
        </Button>

        {document.status === 'DRAFT' && (
          <Button
            disabled={startMutation.isPending}
            onClick={() => startMutation.mutate()}
            variant="primary"
          >
            <Play size={16} />
            Start Service
          </Button>
        )}

        {document.status === 'IN_PROGRESS' && (
          <Button onClick={() => setIsCompleteOpen(true)} variant="primary">
            <CheckCircle2 size={16} />
            Complete Service
          </Button>
        )}

        {document.status !== 'CANCELLED' && document.status !== 'COMPLETED' && (
          <Button
            disabled={cancelMutation.isPending}
            onClick={() => cancelMutation.mutate()}
            variant="destructive"
          >
            <XCircle size={16} />
            Cancel
          </Button>
        )}
      </div>

      <div className="document-layout">
        <section className="document-card">
          <h2>Maintenance Order Facts</h2>
          <dl className="document-facts">
            <div className="document-fact"><dt>Work Center</dt><dd>{document.workstationName || document.workstationId}</dd></div>
            <div className="document-fact"><dt>Title</dt><dd>{document.title}</dd></div>
            <div className="document-fact"><dt>Description</dt><dd>{document.description || '--'}</dd></div>
            <div className="document-fact"><dt>Reported Date</dt><dd>{formatDate(document.reportedAt)}</dd></div>
            <div className="document-fact"><dt>Completion Notes</dt><dd>{document.completionNotes || '--'}</dd></div>
          </dl>
        </section>

        <aside className="document-card document-card--summary">
          <h2>Service Cost & Downtime</h2>
          <div className="progress-row">
            <span>Downtime Logged</span>
            <strong>{document.downtimeMinutes ?? 0} mins</strong>
          </div>
          <div className="progress-row progress-row--total">
            <span>Maintenance Cost</span>
            <Money amount={document.cost} />
          </div>
        </aside>
      </div>

      {isCompleteOpen && (
        <div className="modal-backdrop">
          <div className="modal-card">
            <h3>Complete Maintenance Service</h3>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', marginTop: '12px' }}>
              <label>
                <span style={{ fontSize: '13px', fontWeight: 600 }}>Total Service & Parts Cost:</span>
                <input
                  className="search-input"
                  onChange={(e) => setCost(e.target.value)}
                  style={{ width: '100%', marginTop: '4px' }}
                  type="number"
                  value={cost}
                />
              </label>
              <label>
                <span style={{ fontSize: '13px', fontWeight: 600 }}>Completion Notes:</span>
                <textarea
                  className="search-input"
                  onChange={(e) => setNotes(e.target.value)}
                  placeholder="Replaced worn bearing, test run verified OK..."
                  rows={2}
                  style={{ width: '100%', marginTop: '4px' }}
                  value={notes}
                />
              </label>
            </div>
            <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end', marginTop: '16px' }}>
              <Button onClick={() => setIsCompleteOpen(false)} variant="secondary">Cancel</Button>
              <Button
                disabled={completeMutation.isPending}
                onClick={() => completeMutation.mutate()}
                variant="primary"
              >
                Complete Maintenance
              </Button>
            </div>
          </div>
        </div>
      )}
    </section>
  )
}