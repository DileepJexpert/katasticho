import { useState } from 'react'
import type { ReactNode } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  ArrowLeft,
  ArrowLeftRight,
  CheckCircle,
  MapPin,
  Truck,
  XCircle,
} from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatDateTime, formatStatusLabel } from '@/shared/format/format'
import {
  cancelTransferOrder,
  getTransferOrder,
  pingTransitTelemetry,
  receiveTransferOrder,
  shipTransferOrder,
  type TransferOrderLine,
} from '@/features/transfer-orders/transfer-orders-api'

export function TransferOrderDetailPage() {
  const { transferOrderId } = useParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  // Modals
  const [showShipModal, setShowShipModal] = useState(false)
  const [showReceiveModal, setShowReceiveModal] = useState(false)
  const [showPingModal, setShowPingModal] = useState(false)

  const transfer = useQuery({
    queryKey: ['transfer-orders', transferOrderId],
    queryFn: () => getTransferOrder(transferOrderId!),
    enabled: Boolean(transferOrderId),
  })

  const cancelMutation = useMutation({
    mutationFn: () => cancelTransferOrder(transferOrderId!),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['transfer-orders', transferOrderId] }),
  })

  if (!transferOrderId) return <DocumentError onBack={() => navigate(appRoutes.transferOrders)} />
  if (transfer.isLoading) return <section className="workspace-page"><div aria-live="polite" className="directory-state">Loading transfer order...</div></section>
  if (transfer.isError || !transfer.data) return <DocumentError onBack={() => navigate(appRoutes.transferOrders)} />

  const doc = transfer.data
  const isDraft = doc.status === 'DRAFT'
  const isShipped = doc.status === 'SHIPPED'
  const isReceived = doc.status === 'RECEIVED'
  const isCancelled = doc.status === 'CANCELLED'

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Inventory / Operations / Transfer Order"
        title={doc.orderNumber}
        description={`Transfer from ${doc.sourceWarehouseName ?? doc.sourceWarehouseId} to ${doc.destinationWarehouseName ?? doc.destinationWarehouseId}`}
        actions={
          <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
            {isDraft && (
              <Button onClick={() => setShowShipModal(true)} variant="primary">
                <Truck size={16} /> Ship & Dispatch
              </Button>
            )}
            {isShipped && (
              <>
                <Button onClick={() => setShowPingModal(true)} variant="secondary">
                  <MapPin size={16} /> GPS / Transit Ping
                </Button>
                <Button onClick={() => setShowReceiveModal(true)} variant="primary">
                  <CheckCircle size={16} /> Receive Inward
                </Button>
              </>
            )}
            {!isReceived && !isCancelled && (
              <Button disabled={cancelMutation.isPending} onClick={() => cancelMutation.mutate()} variant="destructive">
                <XCircle size={16} /> Cancel Transfer
              </Button>
            )}
            <StatusChip status={formatStatusLabel(doc.status)} />
          </div>
        }
      />

      <div className="document-actions">
        <Button onClick={() => navigate(appRoutes.transferOrders)} variant="secondary">
          <ArrowLeft aria-hidden="true" size={16} /> Back to transfer orders
        </Button>
      </div>

      <div className="document-layout">
        <section className="document-card">
          <h2>Transfer Route & Facility Facts</h2>
          <dl className="document-facts">
            <Fact label="Source Warehouse" value={doc.sourceWarehouseName ?? doc.sourceWarehouseId} />
            <Fact label="Destination Warehouse" value={doc.destinationWarehouseName ?? doc.destinationWarehouseId} />
            <Fact label="Order Date" value={formatDate(doc.createdAt)} />
            <Fact label="Shipped Date" value={formatDateTime(doc.shippedAt)} />
            <Fact label="Received Date" value={formatDateTime(doc.receivedAt)} />
          </dl>
        </section>

        <aside className="document-card document-card--summary">
          <h2>Transfer Summary</h2>
          <div className="progress-row"><span>Total Lines</span><strong>{doc.lines.length}</strong></div>
          <div className="progress-row"><span>Status</span><StatusChip status={formatStatusLabel(doc.status)} /></div>
        </aside>
      </div>

      <section className="document-card document-card--lines">
        <h2>Transfer Line Items</h2>
        <DataTable caption="Transfer order lines">
          <thead>
            <tr>
              <th scope="col">Item</th>
              <th className="numeric-cell" scope="col">Requested</th>
              <th className="numeric-cell" scope="col">Shipped</th>
              <th className="numeric-cell" scope="col">Received</th>
              <th scope="col">Batch #</th>
            </tr>
          </thead>
          <tbody>
            {doc.lines.map((line) => (
              <tr key={line.id}>
                <td>
                  <div className="item-primary">
                    <span aria-hidden="true" className="item-avatar"><ArrowLeftRight size={15} /></span>
                    <div className="cell-stack">
                      <strong>{line.itemName}</strong>
                      <code>{line.itemSku ?? line.itemId}</code>
                    </div>
                  </div>
                </td>
                <td className="numeric-cell"><Quantity unit={line.unitOfMeasure} value={line.requestedQuantity} /></td>
                <td className="numeric-cell"><Quantity unit={line.unitOfMeasure} value={line.shippedQuantity ?? line.requestedQuantity} /></td>
                <td className="numeric-cell">
                  <strong style={{ color: Number(line.receivedQuantity) > 0 ? 'var(--color-success, #2e7d32)' : 'inherit' }}>
                    <Quantity unit={line.unitOfMeasure} value={line.receivedQuantity ?? 0} />
                  </strong>
                </td>
                <td>{line.batchNumber ? <code>{line.batchNumber}</code> : '--'}</td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      </section>

      <section className="document-card document-card--notes">
        <h2>Notes</h2>
        <div className="document-notes"><p>{doc.notes ?? '--'}</p></div>
      </section>

      {/* Ship Modal */}
      {showShipModal && (
        <ShipOrderModal
          onClose={() => setShowShipModal(false)}
          onSuccess={() => {
            setShowShipModal(false)
            queryClient.invalidateQueries({ queryKey: ['transfer-orders', transferOrderId] })
          }}
          transferOrderId={transferOrderId}
        />
      )}

      {/* Receive Modal */}
      {showReceiveModal && (
        <ReceiveOrderModal
          lines={doc.lines}
          onClose={() => setShowReceiveModal(false)}
          onSuccess={() => {
            setShowReceiveModal(false)
            queryClient.invalidateQueries({ queryKey: ['transfer-orders', transferOrderId] })
          }}
          transferOrderId={transferOrderId}
        />
      )}

      {/* Transit Telemetry Ping Modal */}
      {showPingModal && (
        <TransitPingModal
          onClose={() => setShowPingModal(false)}
          onSuccess={() => setShowPingModal(false)}
          transferOrderId={transferOrderId}
        />
      )}
    </section>
  )
}

function ShipOrderModal({
  transferOrderId,
  onClose,
  onSuccess,
}: {
  transferOrderId: string
  onClose: () => void
  onSuccess: () => void
}) {
  const [vehicleNumber, setVehicleNumber] = useState('')
  const [driverName, setDriverName] = useState('')
  const [driverPhone, setDriverPhone] = useState('')
  const [expectedDeliveryDate, setExpectedDeliveryDate] = useState('')

  const mutation = useMutation({
    mutationFn: () =>
      shipTransferOrder(transferOrderId, {
        vehicleNumber,
        driverName: driverName || undefined,
        driverPhone: driverPhone || undefined,
        expectedDeliveryDate: expectedDeliveryDate || undefined,
      }),
    onSuccess: () => onSuccess(),
  })

  return (
    <div className="modal-backdrop" role="dialog">
      <div className="modal-dialog">
        <header className="modal-header">
          <h3>Ship & Dispatch Transfer Order</h3>
          <Button onClick={onClose} variant="ghost">âœ•</Button>
        </header>
        <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <label className="field-group">
            <span>Vehicle / Truck Registration Number *</span>
            <input onChange={(e) => setVehicleNumber(e.target.value)} placeholder="e.g. MH-12-AB-1234" value={vehicleNumber} />
          </label>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
            <label className="field-group">
              <span>Driver Name</span>
              <input onChange={(e) => setDriverName(e.target.value)} placeholder="e.g. Rajesh Kumar" value={driverName} />
            </label>
            <label className="field-group">
              <span>Driver Phone</span>
              <input onChange={(e) => setDriverPhone(e.target.value)} placeholder="+91 9876543210" value={driverPhone} />
            </label>
          </div>
          <label className="field-group">
            <span>Expected Delivery Date</span>
            <input onChange={(e) => setExpectedDeliveryDate(e.target.value)} type="date" value={expectedDeliveryDate} />
          </label>
        </div>
        <footer className="modal-footer">
          <Button onClick={onClose} variant="secondary">Cancel</Button>
          <Button disabled={!vehicleNumber || mutation.isPending} onClick={() => mutation.mutate()} variant="primary">
            {mutation.isPending ? 'Shipping...' : 'Confirm Shipment'}
          </Button>
        </footer>
      </div>
    </div>
  )
}

function ReceiveOrderModal({
  transferOrderId,
  lines,
  onClose,
  onSuccess,
}: {
  transferOrderId: string
  lines: TransferOrderLine[]
  onClose: () => void
  onSuccess: () => void
}) {
  const [receivedMap, setReceivedMap] = useState<Record<string, number>>(
    lines.reduce((acc, l) => ({ ...acc, [l.id]: Number(l.shippedQuantity || l.requestedQuantity) }), {})
  )
  const [notes, setNotes] = useState('')

  const mutation = useMutation({
    mutationFn: () =>
      receiveTransferOrder(transferOrderId, {
        receivedLines: lines.map((l) => ({
          lineId: l.id,
          receivedQuantity: receivedMap[l.id] ?? Number(l.requestedQuantity),
          notes: notes || undefined,
        })),
      }),
    onSuccess: () => onSuccess(),
  })

  return (
    <div className="modal-backdrop" role="dialog">
      <div className="modal-dialog" style={{ maxWidth: '600px' }}>
        <header className="modal-header">
          <h3>Inward Goods Receipt</h3>
          <Button onClick={onClose} variant="ghost">âœ•</Button>
        </header>
        <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <p style={{ fontSize: '0.875rem', color: 'var(--color-muted)' }}>
            Confirm quantities received at destination warehouse. Discrepancies will adjust transit ledger.
          </p>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
            {lines.map((l) => (
              <div key={l.id} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <div>
                  <strong>{l.itemName}</strong>
                  <div style={{ fontSize: '0.75rem', color: 'var(--color-muted)' }}>Shipped: {l.shippedQuantity ?? l.requestedQuantity} {l.unitOfMeasure}</div>
                </div>
                <label style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                  <span>Received:</span>
                  <input
                    min={0}
                    onChange={(e) => setReceivedMap({ ...receivedMap, [l.id]: Number(e.target.value) })}
                    style={{ width: '80px' }}
                    type="number"
                    value={receivedMap[l.id] ?? 0}
                  />
                </label>
              </div>
            ))}
          </div>
          <label className="field-group">
            <span>Discrepancy / Inward Notes</span>
            <input onChange={(e) => setNotes(e.target.value)} placeholder="e.g. All cartons intact, seal verified" value={notes} />
          </label>
        </div>
        <footer className="modal-footer">
          <Button onClick={onClose} variant="secondary">Cancel</Button>
          <Button disabled={mutation.isPending} onClick={() => mutation.mutate()} variant="primary">
            {mutation.isPending ? 'Receiving...' : 'Complete Inward Receipt'}
          </Button>
        </footer>
      </div>
    </div>
  )
}

function TransitPingModal({
  transferOrderId,
  onClose,
  onSuccess,
}: {
  transferOrderId: string
  onClose: () => void
  onSuccess: () => void
}) {
  const [locationName, setLocationName] = useState('')
  const [latitude, setLatitude] = useState(19.076)
  const [longitude, setLongitude] = useState(72.8777)
  const [statusNotes, setStatusNotes] = useState('In transit on highway')

  const mutation = useMutation({
    mutationFn: () =>
      pingTransitTelemetry({
        transitDispatchId: transferOrderId,
        latitude,
        longitude,
        locationName: locationName || 'Checkpoint Highway',
        statusNotes,
      }),
    onSuccess: () => onSuccess(),
  })

  return (
    <div className="modal-backdrop" role="dialog">
      <div className="modal-dialog">
        <header className="modal-header">
          <h3>Record Transit Telemetry Ping</h3>
          <Button onClick={onClose} variant="ghost">âœ•</Button>
        </header>
        <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <label className="field-group">
            <span>Location Name / Toll Checkpoint</span>
            <input onChange={(e) => setLocationName(e.target.value)} placeholder="e.g. Pune Highway Toll Plaza" value={locationName} />
          </label>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
            <label className="field-group">
              <span>Latitude</span>
              <input onChange={(e) => setLatitude(Number(e.target.value))} type="number" value={latitude} />
            </label>
            <label className="field-group">
              <span>Longitude</span>
              <input onChange={(e) => setLongitude(Number(e.target.value))} type="number" value={longitude} />
            </label>
          </div>
          <label className="field-group">
            <span>Status Notes</span>
            <input onChange={(e) => setStatusNotes(e.target.value)} value={statusNotes} />
          </label>
        </div>
        <footer className="modal-footer">
          <Button onClick={onClose} variant="secondary">Cancel</Button>
          <Button disabled={mutation.isPending} onClick={() => mutation.mutate()} variant="primary">
            {mutation.isPending ? 'Logging Ping...' : 'Record Telemetry Ping'}
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
        <strong>Transfer order not found.</strong>
        <p>The requested transfer order could not be loaded.</p>
        <Button onClick={onBack} variant="secondary">Back to transfer orders</Button>
      </div>
    </section>
  )
}