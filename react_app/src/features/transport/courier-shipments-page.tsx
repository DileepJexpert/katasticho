import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Plus, RefreshCw, Truck } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDateTime, formatStatusLabel } from '@/shared/format/format'
import {
  listCourierShipments,
  createCourierShipment,
  syncAllCourierShipments,
  type CourierShipment,
  type CreateCourierShipmentRequest,
} from '@/features/transport/transport-api'
import { listContacts } from '@/features/contacts/contacts-api'

const statusOptions = [
  { label: 'All', value: null },
  { label: 'Draft', value: 'DRAFT' },
  { label: 'Booked', value: 'BOOKED' },
  { label: 'Picked Up', value: 'PICKED_UP' },
  { label: 'In Transit', value: 'IN_TRANSIT' },
  { label: 'Out For Delivery', value: 'OUT_FOR_DELIVERY' },
  { label: 'Delivered', value: 'DELIVERED' },
  { label: 'RTO Initiated', value: 'RTO_INITIATED' },
  { label: 'RTO Delivered', value: 'RTO_DELIVERED' },
  { label: 'Cancelled', value: 'CANCELLED' },
] as const

type StatusFilter = typeof statusOptions[number]['value']

export function CourierShipmentsPage() {
  const [filter, setFilter] = useState<StatusFilter>(null)
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [feedback, setFeedback] = useState<string | null>(null)
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const shipmentsQuery = useQuery({
    queryKey: ['courier-shipments', filter],
    queryFn: () => listCourierShipments(filter),
  })

  const contactsQuery = useQuery({
    queryKey: ['contacts-dropdown'],
    queryFn: () => listContacts({ filter: 'ALL', page: 0 }),
  })

  const syncAllMutation = useMutation({
    mutationFn: syncAllCourierShipments,
    onSuccess: (res) => {
      setFeedback(`Live sync finished: ${res.updated} shipment(s) updated.`)
      queryClient.invalidateQueries({ queryKey: ['courier-shipments'] })
    },
  })

  const createMutation = useMutation({
    mutationFn: (data: CreateCourierShipmentRequest) => createCourierShipment(data),
    onSuccess: (created) => {
      setIsModalOpen(false)
      queryClient.invalidateQueries({ queryKey: ['courier-shipments'] })
      navigate(appRoutes.courierShipmentDetail(created.id))
    },
  })

  const shipments = shipmentsQuery.data ?? []

  const inTransitCount = shipments.filter((s) => s.status === 'IN_TRANSIT' || s.status === 'PICKED_UP').length
  const deliveredCount = shipments.filter((s) => s.status === 'DELIVERED').length
  const rtoCount = shipments.filter((s) => s.status === 'RTO_INITIATED' || s.status === 'RTO_DELIVERED').length
  const codPendingCount = shipments.filter((s) => s.cod && s.status !== 'DELIVERED' && s.status !== 'CANCELLED').length

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Logistics & Transport"
        title="Courier Shipments"
        description="Outbound parcel consignments, automated AWB tracking, courier aggregator dispatches, and COD reconciliations."
        actions={
          <div className="button-group">
            <Button
              disabled={syncAllMutation.isPending}
              onClick={() => syncAllMutation.mutate()}
              variant="secondary"
            >
              <RefreshCw aria-hidden="true" className={syncAllMutation.isPending ? 'spin' : ''} size={16} />
              {syncAllMutation.isPending ? 'Syncing...' : 'Sync All Tracking'}
            </Button>
            <Button onClick={() => setIsModalOpen(true)} variant="primary">
              <Plus aria-hidden="true" size={16} />
              Book Shipment
            </Button>
          </div>
        }
      />

      {feedback ? (
        <div className="notification-banner notification-banner--success" role="status">
          <p>{feedback}</p>
          <button className="banner-dismiss" onClick={() => setFeedback(null)} type="button">×</button>
        </div>
      ) : null}

      <div className="metrics-grid">
        <article className="metric-card">
          <span className="metric-label">Total Shipments</span>
          <strong className="metric-value">{shipments.length}</strong>
        </article>
        <article className="metric-card">
          <span className="metric-label">In Transit / Pickup</span>
          <strong className="metric-value">{inTransitCount}</strong>
        </article>
        <article className="metric-card">
          <span className="metric-label">Delivered</span>
          <strong className="metric-value">{deliveredCount}</strong>
        </article>
        <article className="metric-card">
          <span className="metric-label">Active COD Parcels</span>
          <strong className="metric-value">{codPendingCount}</strong>
        </article>
        <article className="metric-card">
          <span className="metric-label">RTO In Queue</span>
          <strong className="metric-value">{rtoCount}</strong>
        </article>
      </div>

      <section className="list-panel" aria-label="Courier shipments directory">
        <div className="list-toolbar list-toolbar--stacked">
          <div className="role-tabs" aria-label="Filter shipments by status" role="tablist">
            {statusOptions.map((opt) => (
              <button
                aria-selected={filter === opt.value}
                className={filter === opt.value ? 'role-tab role-tab--active' : 'role-tab'}
                key={opt.label}
                onClick={() => setFilter(opt.value)}
                role="tab"
                type="button"
              >
                {opt.label}
              </button>
            ))}
          </div>
        </div>

        {shipmentsQuery.isError ? (
          <div className="directory-state directory-state--error" role="alert">
            <strong>Courier shipments could not be loaded.</strong>
            <p>Check your connection and permissions, then refresh the page.</p>
          </div>
        ) : shipmentsQuery.isLoading ? (
          <div aria-live="polite" className="directory-state">Loading courier shipments...</div>
        ) : shipments.length ? (
          <DataTable caption="Courier shipments">
            <thead>
              <tr>
                <th scope="col">Shipment #</th>
                <th scope="col">Partner / AWB</th>
                <th scope="col">Service</th>
                <th scope="col">Weight (kg)</th>
                <th scope="col">Payment / COD</th>
                <th scope="col">Status</th>
                <th scope="col">Dispatched</th>
                <th scope="col">Delivered</th>
              </tr>
            </thead>
            <tbody>
              {shipments.map((s) => (
                <CourierShipmentRow
                  key={s.id}
                  onOpen={() => navigate(appRoutes.courierShipmentDetail(s.id))}
                  shipment={s}
                />
              ))}
            </tbody>
          </DataTable>
        ) : (
          <div className="directory-state directory-state--empty">
            <Truck aria-hidden="true" size={32} />
            <strong>No shipments found.</strong>
            <p>Book a new courier dispatch for customer delivery challans or invoices.</p>
          </div>
        )}
      </section>

      {isModalOpen ? (
        <CreateCourierShipmentModal
          contacts={contactsQuery.data?.content ?? []}
          isSubmitting={createMutation.isPending}
          onClose={() => setIsModalOpen(false)}
          onSubmit={(data) => createMutation.mutate(data)}
        />
      ) : null}
    </section>
  )
}

function CourierShipmentRow({
  shipment,
  onOpen,
}: {
  shipment: CourierShipment
  onOpen: () => void
}) {
  return (
    <tr className="data-table-row--interactive" onClick={onOpen} tabIndex={0}>
      <td>
        <div className="cell-stack">
          <strong>{shipment.courierShipmentNumber}</strong>
          {shipment.notes ? <span className="cell-muted">{shipment.notes}</span> : null}
        </div>
      </td>
      <td>
        <div className="cell-stack">
          <strong>{shipment.courierPartner}</strong>
          <span className="cell-muted">{shipment.awbNumber ? `AWB: ${shipment.awbNumber}` : 'Pending AWB'}</span>
        </div>
      </td>
      <td>{shipment.courierService || '--'}</td>
      <td>{shipment.weightKg ? `${shipment.weightKg} kg` : '--'}</td>
      <td>
        {shipment.cod ? (
          <div className="cell-stack">
            <StatusChip status="COD" />
            <Money amount={shipment.codAmount} />
          </div>
        ) : (
          <StatusChip status="Prepaid" />
        )}
      </td>
      <td>
        <StatusChip status={formatStatusLabel(shipment.status)} />
      </td>
      <td>{formatDateTime(shipment.bookedAt)}</td>
      <td>{formatDateTime(shipment.deliveredAt)}</td>
    </tr>
  )
}

function CreateCourierShipmentModal({
  contacts,
  isSubmitting,
  onClose,
  onSubmit,
}: {
  contacts: Array<{ id: string; displayName: string }>
  isSubmitting: boolean
  onClose: () => void
  onSubmit: (data: CreateCourierShipmentRequest) => void
}) {
  const [contactId, setContactId] = useState(contacts[0]?.id ?? '')
  const [courierPartner, setCourierPartner] = useState('BLUEDART')
  const [courierService, setCourierService] = useState('Surface Standard')
  const [awbNumber, setAwbNumber] = useState('')
  const [cod, setCod] = useState(false)
  const [codAmount, setCodAmount] = useState<number | undefined>(undefined)
  const [freightAmount, setFreightAmount] = useState<number | undefined>(undefined)
  const [codFee, setCodFee] = useState<number | undefined>(undefined)
  const [weightKg, setWeightKg] = useState<number | undefined>(undefined)
  const [declaredValue, setDeclaredValue] = useState<number | undefined>(undefined)
  const [pickupAddress, setPickupAddress] = useState('')
  const [deliveryAddress, setDeliveryAddress] = useState('')
  const [notes, setNotes] = useState('')

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (!contactId) return
    onSubmit({
      contactId,
      courierPartner,
      courierService: courierService.trim() || null,
      awbNumber: awbNumber.trim() || null,
      cod,
      codAmount: cod ? (codAmount ?? null) : null,
      freightAmount: freightAmount ?? null,
      codFee: codFee ?? null,
      weightKg: weightKg ?? null,
      declaredValue: declaredValue ?? null,
      pickupAddress: pickupAddress.trim() || null,
      deliveryAddress: deliveryAddress.trim() || null,
      notes: notes.trim() || null,
    })
  }

  return (
    <div className="modal-backdrop" role="dialog" aria-modal="true">
      <div className="modal-card">
        <header className="modal-header">
          <h2>Book Courier Shipment</h2>
          <button className="modal-close" onClick={onClose} type="button">×</button>
        </header>
        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label htmlFor="shipment-contact">Consignee / Customer *</label>
            <select
              id="shipment-contact"
              required
              value={contactId}
              onChange={(e) => setContactId(e.target.value)}
            >
              <option value="">Select customer...</option>
              {contacts.map((c) => (
                <option key={c.id} value={c.id}>{c.displayName}</option>
              ))}
            </select>
          </div>

          <div className="form-row">
            <div className="form-group">
              <label htmlFor="shipment-partner">Courier Partner *</label>
              <select
                id="shipment-partner"
                value={courierPartner}
                onChange={(e) => setCourierPartner(e.target.value)}
              >
                <option value="BLUEDART">Blue Dart</option>
                <option value="DELHIVERY">Delhivery</option>
                <option value="INDIA_POST">India Post (Speed Post)</option>
                <option value="DTDC">DTDC</option>
                <option value="SHIPROCKET">Shiprocket (Aggregator)</option>
                <option value="OTHER">Other / Regional</option>
              </select>
            </div>
            <div className="form-group">
              <label htmlFor="shipment-service">Service Tier</label>
              <input
                id="shipment-service"
                placeholder="e.g. Express Air, Surface"
                type="text"
                value={courierService}
                onChange={(e) => setCourierService(e.target.value)}
              />
            </div>
          </div>

          <div className="form-row">
            <div className="form-group">
              <label htmlFor="shipment-awb">AWB / Consignment # (optional)</label>
              <input
                id="shipment-awb"
                placeholder="Leave blank to auto-generate from API"
                type="text"
                value={awbNumber}
                onChange={(e) => setAwbNumber(e.target.value)}
              />
            </div>
            <div className="form-group">
              <label htmlFor="shipment-weight">Weight (kg)</label>
              <input
                id="shipment-weight"
                min="0"
                step="0.01"
                type="number"
                value={weightKg ?? ''}
                onChange={(e) => setWeightKg(e.target.value ? Number(e.target.value) : undefined)}
              />
            </div>
          </div>

          <div className="form-row">
            <div className="form-group">
              <label htmlFor="shipment-freight">Freight Amount (₹)</label>
              <input
                id="shipment-freight"
                min="0"
                step="0.01"
                type="number"
                value={freightAmount ?? ''}
                onChange={(e) => setFreightAmount(e.target.value ? Number(e.target.value) : undefined)}
              />
            </div>
            <div className="form-group">
              <label htmlFor="shipment-declared">Declared Value (₹)</label>
              <input
                id="shipment-declared"
                min="0"
                step="0.01"
                type="number"
                value={declaredValue ?? ''}
                onChange={(e) => setDeclaredValue(e.target.value ? Number(e.target.value) : undefined)}
              />
            </div>
          </div>

          <div className="form-group form-group--checkbox">
            <label>
              <input
                checked={cod}
                type="checkbox"
                onChange={(e) => setCod(e.target.checked)}
              />
              Cash on Delivery (COD) Order
            </label>
          </div>

          {cod ? (
            <div className="form-row">
              <div className="form-group">
                <label htmlFor="shipment-cod-amount">COD Collection Amount (₹) *</label>
                <input
                  id="shipment-cod-amount"
                  min="0"
                  required
                  step="0.01"
                  type="number"
                  value={codAmount ?? ''}
                  onChange={(e) => setCodAmount(e.target.value ? Number(e.target.value) : undefined)}
                />
              </div>
              <div className="form-group">
                <label htmlFor="shipment-cod-fee">Estimated COD Fee (₹)</label>
                <input
                  id="shipment-cod-fee"
                  min="0"
                  step="0.01"
                  type="number"
                  value={codFee ?? ''}
                  onChange={(e) => setCodFee(e.target.value ? Number(e.target.value) : undefined)}
                />
              </div>
            </div>
          ) : null}

          <div className="form-group">
            <label htmlFor="shipment-pickup-addr">Pickup Origin Address</label>
            <input
              id="shipment-pickup-addr"
              type="text"
              value={pickupAddress}
              onChange={(e) => setPickupAddress(e.target.value)}
            />
          </div>

          <div className="form-group">
            <label htmlFor="shipment-delivery-addr">Delivery Destination Address</label>
            <textarea
              id="shipment-delivery-addr"
              rows={2}
              value={deliveryAddress}
              onChange={(e) => setDeliveryAddress(e.target.value)}
            />
          </div>

          <div className="form-group">
            <label htmlFor="shipment-notes">Notes / Special Instructions</label>
            <input
              id="shipment-notes"
              type="text"
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
            />
          </div>

          <footer className="modal-footer">
            <Button onClick={onClose} type="button" variant="secondary">Cancel</Button>
            <Button disabled={isSubmitting} type="submit" variant="primary">
              {isSubmitting ? 'Booking...' : 'Create Shipment'}
            </Button>
          </footer>
        </form>
      </div>
    </div>
  )
}