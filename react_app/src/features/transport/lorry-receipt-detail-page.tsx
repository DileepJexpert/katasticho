import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, CheckCircle2, Receipt, Send, XCircle } from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import {
  getLorryReceipt,
  issueLorryReceipt,
  deliverLorryReceipt,
  cancelLorryReceipt,
  billLorryReceiptFreight,
} from '@/features/transport/transport-api'

export function LorryReceiptDetailPage() {
  const { lrId } = useParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [feedback, setFeedback] = useState<string | null>(null)
  const [isCancelModalOpen, setIsCancelModalOpen] = useState(false)
  const [cancelReason, setCancelReason] = useState('')

  const lrQuery = useQuery({
    queryKey: ['lorry-receipt', lrId],
    queryFn: () => getLorryReceipt(lrId!),
    enabled: Boolean(lrId),
  })

  const issueMutation = useMutation({
    mutationFn: () => issueLorryReceipt(lrId!),
    onSuccess: () => {
      setFeedback('Lorry Receipt officially ISSUED for transport.')
      queryClient.invalidateQueries({ queryKey: ['lorry-receipt', lrId] })
    },
  })

  const deliverMutation = useMutation({
    mutationFn: () => deliverLorryReceipt(lrId!),
    onSuccess: () => {
      setFeedback('Lorry Receipt marked DELIVERED at destination.')
      queryClient.invalidateQueries({ queryKey: ['lorry-receipt', lrId] })
    },
  })

  const billFreightMutation = useMutation({
    mutationFn: () => billLorryReceiptFreight(lrId!),
    onSuccess: (res) => {
      setFeedback(`Draft Purchase Bill ${res.billNumber} created in AP for transporter freight.`)
      queryClient.invalidateQueries({ queryKey: ['lorry-receipt', lrId] })
    },
  })

  const cancelMutation = useMutation({
    mutationFn: () => cancelLorryReceipt(lrId!, cancelReason.trim() || undefined),
    onSuccess: () => {
      setIsCancelModalOpen(false)
      setFeedback('Lorry receipt cancelled.')
      queryClient.invalidateQueries({ queryKey: ['lorry-receipt', lrId] })
    },
  })

  if (!lrId) return <div className="directory-state directory-state--error">LR ID missing.</div>
  if (lrQuery.isLoading) return <div className="directory-state">Loading LR consignment...</div>
  if (lrQuery.isError || !lrQuery.data) {
    return (
      <div className="directory-state directory-state--error">
        <strong>Lorry receipt could not be loaded.</strong>
        <Button onClick={() => navigate(appRoutes.lorryReceipts)} variant="secondary">Back to LRs</Button>
      </div>
    )
  }

  const lr = lrQuery.data

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Logistics & Transport / Consignment Note"
        title={lr.lrNumber}
        description={`${lr.origin ?? 'Origin'} â†’ ${lr.destination ?? 'Destination'} · Vehicle: ${lr.vehicleNumber ?? 'Unassigned'}`}
        actions={
          <div className="button-group">
            {lr.status === 'DRAFT' ? (
              <Button
                disabled={issueMutation.isPending}
                onClick={() => issueMutation.mutate()}
                variant="primary"
              >
                <Send aria-hidden="true" size={16} />
                Issue LR
              </Button>
            ) : null}

            {lr.status === 'ISSUED' || lr.status === 'IN_TRANSIT' ? (
              <Button
                disabled={deliverMutation.isPending}
                onClick={() => deliverMutation.mutate()}
                variant="primary"
              >
                <CheckCircle2 aria-hidden="true" size={16} />
                Mark Delivered
              </Button>
            ) : null}

            {lr.freightBasis === 'TO_BE_BILLED' && !lr.freightBillId && lr.status !== 'CANCELLED' ? (
              <Button
                disabled={billFreightMutation.isPending}
                onClick={() => billFreightMutation.mutate()}
                variant="secondary"
              >
                <Receipt aria-hidden="true" size={16} />
                {billFreightMutation.isPending ? 'Billing...' : 'Bill Freight (AP Purchase Bill)'}
              </Button>
            ) : null}

            {lr.status !== 'DELIVERED' && lr.status !== 'CANCELLED' ? (
              <Button onClick={() => setIsCancelModalOpen(true)} variant="destructive">
                <XCircle aria-hidden="true" size={16} />
                Cancel LR
              </Button>
            ) : null}
          </div>
        }
      />

      <div className="document-actions">
        <Button onClick={() => navigate(appRoutes.lorryReceipts)} variant="secondary">
          <ArrowLeft aria-hidden="true" size={16} />
          Back to Lorry Receipts
        </Button>
        <StatusChip status={formatStatusLabel(lr.status)} />
      </div>

      {feedback ? (
        <div className="notification-banner notification-banner--success" role="status">
          <p>{feedback}</p>
          <button className="banner-dismiss" onClick={() => setFeedback(null)} type="button">×</button>
        </div>
      ) : null}

      <div className="document-layout">
        <section className="document-card">
          <h2>Consignment & Vehicle Lane Profile</h2>
          <dl className="document-facts">
            <div className="document-fact">
              <dt>LR Date</dt>
              <dd>{formatDate(lr.lrDate)}</dd>
            </div>
            <div className="document-fact">
              <dt>Route Origin</dt>
              <dd>{lr.origin ?? '--'}</dd>
            </div>
            <div className="document-fact">
              <dt>Route Destination</dt>
              <dd>{lr.destination ?? '--'}</dd>
            </div>
            <div className="document-fact">
              <dt>Transit Distance</dt>
              <dd>{lr.distanceKm ? `${lr.distanceKm} km` : '--'}</dd>
            </div>
            <div className="document-fact">
              <dt>Transport Mode</dt>
              <dd>{lr.mode ?? 'ROAD'}</dd>
            </div>
            <div className="document-fact">
              <dt>Vehicle Registration</dt>
              <dd><strong>{lr.vehicleNumber ?? '--'}</strong></dd>
            </div>
            <div className="document-fact">
              <dt>Driver Details</dt>
              <dd>{lr.driverName ? `${lr.driverName} (${lr.driverPhone ?? 'No phone'})` : '--'}</dd>
            </div>
            <div className="document-fact">
              <dt>e-Way Bill Number</dt>
              <dd><span className="mono-code">{lr.ewayBillNo ?? 'Not Generated'}</span></dd>
            </div>
            <div className="document-fact">
              <dt>Cargo Packages</dt>
              <dd>{lr.numPackages ? `${lr.numPackages} units` : '--'}</dd>
            </div>
            <div className="document-fact">
              <dt>Total Weight</dt>
              <dd>{lr.weightKg ? `${lr.weightKg} kg` : '--'}</dd>
            </div>
            <div className="document-fact">
              <dt>Declared Consignment Value</dt>
              <dd><Money amount={lr.declaredValue} /></dd>
            </div>
            <div className="document-fact">
              <dt>Consignment Notes</dt>
              <dd>{lr.notes ?? '--'}</dd>
            </div>
          </dl>
        </section>

        <aside className="document-card document-card--summary">
          <h2>Freight & AP Billing Terms</h2>
          <div className="progress-row">
            <span>Freight Charge</span>
            <Money amount={lr.freightAmount} />
          </div>
          <div className="progress-row">
            <span>Payment Basis</span>
            <StatusChip status={formatStatusLabel(lr.freightBasis || 'TO_BE_BILLED')} />
          </div>
          <div className="progress-row">
            <span>GST Mechanism</span>
            <StatusChip status={lr.gstTreatment || 'RCM'} />
          </div>
          <div className="progress-row">
            <span>Applicable GST Rate</span>
            <span>{lr.freightGstRate ?? 5}%</span>
          </div>
          <div className="progress-row">
            <span>AP Freight Bill Link</span>
            {lr.freightBillId ? (
              <button
                className="link-button"
                onClick={() => navigate(appRoutes.billDetail(lr.freightBillId!))}
                type="button"
              >
                View AP Bill
              </button>
            ) : (
              <span className="cell-muted">Not billed yet</span>
            )}
          </div>
        </aside>
      </div>

      {isCancelModalOpen ? (
        <div className="modal-backdrop" role="dialog" aria-modal="true">
          <div className="modal-card">
            <header className="modal-header">
              <h2>Cancel Lorry Receipt</h2>
              <button className="modal-close" onClick={() => setIsCancelModalOpen(false)} type="button">×</button>
            </header>
            <form onSubmit={(e) => { e.preventDefault(); cancelMutation.mutate(); }}>
              <div className="form-group">
                <label htmlFor="lr-cancel-reason">Reason for cancellation</label>
                <textarea
                  id="lr-cancel-reason"
                  placeholder="e.g. Transporter vehicle unavailable, route amended..."
                  rows={3}
                  value={cancelReason}
                  onChange={(e) => setCancelReason(e.target.value)}
                />
              </div>
              <footer className="modal-footer">
                <Button onClick={() => setIsCancelModalOpen(false)} type="button" variant="secondary">Keep LR</Button>
                <Button disabled={cancelMutation.isPending} type="submit" variant="destructive">
                  {cancelMutation.isPending ? 'Cancelling...' : 'Confirm Cancellation'}
                </Button>
              </footer>
            </form>
          </div>
        </div>
      ) : null}
    </section>
  )
}