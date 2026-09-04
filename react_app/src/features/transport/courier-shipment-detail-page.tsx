import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, CheckCircle2, MapPin, RefreshCw, XCircle, PlusCircle } from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDateTime, formatStatusLabel } from '@/shared/format/format'
import {
  getCourierShipment,
  bookCourierShipment,
  cancelCourierShipment,
  recordCourierEvent,
  syncCourierShipment,
  type RecordCourierEventRequest,
} from '@/features/transport/transport-api'

export function CourierShipmentDetailPage() {
  const { shipmentId } = useParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [isEventModalOpen, setIsEventModalOpen] = useState(false)
  const [isCancelModalOpen, setIsCancelModalOpen] = useState(false)
  const [cancelReason, setCancelReason] = useState('')
  const [awbInput] = useState('')
  const [feedback, setFeedback] = useState<string | null>(null)

  const shipmentQuery = useQuery({
    queryKey: ['courier-shipment', shipmentId],
    queryFn: () => getCourierShipment(shipmentId!),
    enabled: Boolean(shipmentId),
  })

  const syncMutation = useMutation({
    mutationFn: () => syncCourierShipment(shipmentId!),
    onSuccess: () => {
      setFeedback('Tracking status refreshed from carrier gateway.')
      queryClient.invalidateQueries({ queryKey: ['courier-shipment', shipmentId] })
    },
  })

  const bookMutation = useMutation({
    mutationFn: () => bookCourierShipment(shipmentId!, awbInput.trim() || undefined),
    onSuccess: () => {
      setFeedback('Shipment marked BOOKED with carrier.')
      queryClient.invalidateQueries({ queryKey: ['courier-shipment', shipmentId] })
    },
  })

  const cancelMutation = useMutation({
    mutationFn: () => cancelCourierShipment(shipmentId!, cancelReason.trim() || undefined),
    onSuccess: () => {
      setIsCancelModalOpen(false)
      setFeedback('Shipment cancelled.')
      queryClient.invalidateQueries({ queryKey: ['courier-shipment', shipmentId] })
    },
  })

  const eventMutation = useMutation({
    mutationFn: (data: RecordCourierEventRequest) => recordCourierEvent(shipmentId!, data),
    onSuccess: () => {
      setIsEventModalOpen(false)
      setFeedback('Tracking milestone logged.')
      queryClient.invalidateQueries({ queryKey: ['courier-shipment', shipmentId] })
    },
  })

  if (!shipmentId) return <div className="directory-state directory-state--error">Shipment ID missing.</div>
  if (shipmentQuery.isLoading) return <div className="directory-state">Loading shipment details...</div>
  if (shipmentQuery.isError || !shipmentQuery.data) {
    return (
      <div className="directory-state directory-state--error">
        <strong>Shipment could not be loaded.</strong>
        <Button onClick={() => navigate(appRoutes.courierShipments)} variant="secondary">Back to shipments</Button>
      </div>
    )
  }

  const shipment = shipmentQuery.data

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Logistics & Transport / Shipment"
        title={shipment.courierShipmentNumber}
        description={`${shipment.courierPartner} · ${shipment.awbNumber ? `AWB: ${shipment.awbNumber}` : 'AWB Not Assigned'}`}
        actions={
          <div className="button-group">
            <Button
              disabled={syncMutation.isPending}
              onClick={() => syncMutation.mutate()}
              variant="secondary"
            >
              <RefreshCw aria-hidden="true" className={syncMutation.isPending ? 'spin' : ''} size={16} />
              {syncMutation.isPending ? 'Syncing...' : 'Sync Gateway'}
            </Button>
            {shipment.status === 'DRAFT' ? (
              <Button
                disabled={bookMutation.isPending}
                onClick={() => bookMutation.mutate()}
                variant="primary"
              >
                <CheckCircle2 aria-hidden="true" size={16} />
                Book Consignment
              </Button>
            ) : null}
            {shipment.status !== 'DELIVERED' && shipment.status !== 'CANCELLED' && shipment.status !== 'RTO_DELIVERED' ? (
              <>
                <Button onClick={() => setIsEventModalOpen(true)} variant="secondary">
                  <PlusCircle aria-hidden="true" size={16} />
                  Record Milestone
                </Button>
                <Button onClick={() => setIsCancelModalOpen(true)} variant="destructive">
                  <XCircle aria-hidden="true" size={16} />
                  Cancel
                </Button>
              </>
            ) : null}
          </div>
        }
      />

      <div className="document-actions">
        <Button onClick={() => navigate(appRoutes.courierShipments)} variant="secondary">
          <ArrowLeft aria-hidden="true" size={16} />
          Back to Shipments
        </Button>
        <StatusChip status={formatStatusLabel(shipment.status)} />
      </div>

      {feedback ? (
        <div className="notification-banner notification-banner--success" role="status">
          <p>{feedback}</p>
          <button className="banner-dismiss" onClick={() => setFeedback(null)} type="button">×</button>
        </div>
      ) : null}

      <div className="document-layout">
        <section className="document-card">
          <h2>Consignment & Carrier Details</h2>
          <dl className="document-facts">
            <Fact label="Courier Partner" value={shipment.courierPartner} />
            <Fact label="Air Waybill (AWB)" value={shipment.awbNumber ?? 'Not assigned'} />
            <Fact label="Carrier Service" value={shipment.courierService ?? '--'} />
            <Fact label="Weight" value={shipment.weightKg ? `${shipment.weightKg} kg` : '--'} />
            <Fact label="Declared Value" value={shipment.declaredValue ? `₹${shipment.declaredValue}` : '--'} />
            <Fact label="Freight Cost" value={shipment.freightAmount ? `₹${shipment.freightAmount}` : '--'} />
            <Fact label="Booked At" value={formatDateTime(shipment.bookedAt)} />
            <Fact label="Delivered At" value={formatDateTime(shipment.deliveredAt)} />
            <Fact label="RTO Initiated" value={formatDateTime(shipment.rtoInitiatedAt)} />
            <Fact label="RTO Delivered" value={formatDateTime(shipment.rtoDeliveredAt)} />
            <Fact label="Special Instructions" value={shipment.notes ?? '--'} />
          </dl>
        </section>

        <aside className="document-card document-card--summary">
          <h2>Payment & COD Profile</h2>
          <div className="progress-row">
            <span>Payment Mode</span>
            <StatusChip status={shipment.cod ? 'Cash on Delivery' : 'Prepaid'} />
          </div>
          {shipment.cod ? (
            <>
              <div className="progress-row">
                <span>COD Amount</span>
                <Money amount={shipment.codAmount} />
              </div>
              <div className="progress-row">
                <span>Estimated COD Fee</span>
                <Money amount={shipment.codFee} />
              </div>
              <div className="progress-row">
                <span>Remittance Status</span>
                <StatusChip status={shipment.codRemittanceLineId ? 'Remitted' : 'Pending Remittance'} />
              </div>
            </>
          ) : null}
          <div className="progress-row">
            <span>Tracking Events</span>
            <strong>{shipment.events?.length ?? 0}</strong>
          </div>
        </aside>
      </div>

      <section className="document-card">
        <h2>Tracking Milestones & History</h2>
        {shipment.events && shipment.events.length > 0 ? (
          <DataTable caption="Tracking timeline">
            <thead>
              <tr>
                <th scope="col">Status Event</th>
                <th scope="col">Timestamp</th>
                <th scope="col">Location</th>
                <th scope="col">Source</th>
              </tr>
            </thead>
            <tbody>
              {shipment.events.map((evt) => (
                <tr key={evt.id}>
                  <td>
                    <div className="cell-stack">
                      <strong>{formatStatusLabel(evt.eventStatus)}</strong>
                    </div>
                  </td>
                  <td>{formatDateTime(evt.eventAt)}</td>
                  <td>
                    <div className="cell-stack">
                      <MapPin aria-hidden="true" size={14} />
                      <span>{evt.location || '--'}</span>
                    </div>
                  </td>
                  <td>
                    <StatusChip status={evt.source || 'MANUAL'} />
                  </td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        ) : (
          <div className="directory-state directory-state--empty">
            <p>No tracking events recorded yet. Click &quot;Record Milestone&quot; or sync with carrier.</p>
          </div>
        )}
      </section>

      {isEventModalOpen ? (
        <RecordEventModal
          isSubmitting={eventMutation.isPending}
          onClose={() => setIsEventModalOpen(false)}
          onSubmit={(data) => eventMutation.mutate(data)}
        />
      ) : null}

      {isCancelModalOpen ? (
        <div className="modal-backdrop" role="dialog" aria-modal="true">
          <div className="modal-card">
            <header className="modal-header">
              <h2>Cancel Consignment</h2>
              <button className="modal-close" onClick={() => setIsCancelModalOpen(false)} type="button">×</button>
            </header>
            <form onSubmit={(e) => { e.preventDefault(); cancelMutation.mutate(); }}>
              <div className="form-group">
                <label htmlFor="cancel-reason">Reason for cancellation</label>
                <textarea
                  id="cancel-reason"
                  placeholder="e.g. Customer cancelled order, duplicate booking..."
                  rows={3}
                  value={cancelReason}
                  onChange={(e) => setCancelReason(e.target.value)}
                />
              </div>
              <footer className="modal-footer">
                <Button onClick={() => setIsCancelModalOpen(false)} type="button" variant="secondary">Keep Shipment</Button>
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

function RecordEventModal({
  isSubmitting,
  onClose,
  onSubmit,
}: {
  isSubmitting: boolean
  onClose: () => void
  onSubmit: (data: RecordCourierEventRequest) => void
}) {
  const [eventStatus, setEventStatus] = useState('PICKED_UP')
  const [location, setLocation] = useState('')
  const [rawPayload, setRawPayload] = useState('')

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    onSubmit({
      eventStatus,
      eventAt: new Date().toISOString(),
      location: location.trim() || null,
      rawPayload: rawPayload.trim() || null,
      source: 'MANUAL',
    })
  }

  return (
    <div className="modal-backdrop" role="dialog" aria-modal="true">
      <div className="modal-card">
        <header className="modal-header">
          <h2>Record Tracking Milestone</h2>
          <button className="modal-close" onClick={onClose} type="button">×</button>
        </header>
        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label htmlFor="event-status">Milestone Status *</label>
            <select
              id="event-status"
              value={eventStatus}
              onChange={(e) => setEventStatus(e.target.value)}
            >
              <option value="PICKED_UP">Picked Up from Hub</option>
              <option value="IN_TRANSIT">In Transit (Hub Scan)</option>
              <option value="OUT_FOR_DELIVERY">Out for Delivery</option>
              <option value="DELIVERED">Delivered to Consignee</option>
              <option value="RTO_INITIATED">RTO Initiated (Customer Refused/Undelivered)</option>
              <option value="RTO_DELIVERED">RTO Delivered to Warehouse</option>
              <option value="EXCEPTION">Delivery Exception / Delay</option>
            </select>
          </div>

          <div className="form-group">
            <label htmlFor="event-loc">Location / Hub Name</label>
            <input
              id="event-loc"
              placeholder="e.g. Mumbai Sorting Center, Hub 4B"
              type="text"
              value={location}
              onChange={(e) => setLocation(e.target.value)}
            />
          </div>

          <div className="form-group">
            <label htmlFor="event-remarks">Remarks / Description</label>
            <input
              id="event-remarks"
              placeholder="Optional remarks or courier rider note"
              type="text"
              value={rawPayload}
              onChange={(e) => setRawPayload(e.target.value)}
            />
          </div>

          <footer className="modal-footer">
            <Button onClick={onClose} type="button" variant="secondary">Cancel</Button>
            <Button disabled={isSubmitting} type="submit" variant="primary">
              {isSubmitting ? 'Recording...' : 'Save Milestone'}
            </Button>
          </footer>
        </form>
      </div>
    </div>
  )
}

function Fact({ label, value }: { label: string; value: string }) {
  return (
    <div className="document-fact">
      <dt>{label}</dt>
      <dd>{value}</dd>
    </div>
  )
}