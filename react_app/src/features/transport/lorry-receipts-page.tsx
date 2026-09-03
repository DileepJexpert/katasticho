import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { FileSpreadsheet, Plus } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import {
  listLorryReceipts,
  createLorryReceipt,
  type CreateLorryReceiptRequest,
} from '@/features/transport/transport-api'
import { listContacts } from '@/features/contacts/contacts-api'

const statusFilters = [
  { label: 'All', value: null },
  { label: 'Draft', value: 'DRAFT' },
  { label: 'Issued', value: 'ISSUED' },
  { label: 'In Transit', value: 'IN_TRANSIT' },
  { label: 'Delivered', value: 'DELIVERED' },
  { label: 'Cancelled', value: 'CANCELLED' },
] as const

type StatusFilter = typeof statusFilters[number]['value']

export function LorryReceiptsPage() {
  const [filter, setFilter] = useState<StatusFilter>(null)
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [feedback, setFeedback] = useState<string | null>(null)
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const lrQuery = useQuery({
    queryKey: ['lorry-receipts', filter],
    queryFn: () => listLorryReceipts(filter),
  })

  const contactsQuery = useQuery({
    queryKey: ['transporters-dropdown'],
    queryFn: () => listContacts({ filter: 'ALL', page: 0 }),
  })

  const createMutation = useMutation({
    mutationFn: (data: CreateLorryReceiptRequest) => createLorryReceipt(data),
    onSuccess: (lr) => {
      setIsModalOpen(false)
      setFeedback(`Lorry receipt ${lr.lrNumber} created.`)
      queryClient.invalidateQueries({ queryKey: ['lorry-receipts'] })
      navigate(appRoutes.lorryReceiptDetail(lr.id))
    },
  })

  const receipts = lrQuery.data ?? []
  const issuedCount = receipts.filter((r) => r.status === 'ISSUED' || r.status === 'IN_TRANSIT').length
  const deliveredCount = receipts.filter((r) => r.status === 'DELIVERED').length
  const toBeBilledCount = receipts.filter((r) => r.freightBasis === 'TO_BE_BILLED' && !r.freightBillId).length

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Logistics & Transport / Road Freight"
        title="Lorry Receipts (LR)"
        description="Goods Transport Agency (GTA) consignment notes, road transport dispatches, e-Way bill bindings, and automated AP freight billing."
        actions={
          <Button onClick={() => setIsModalOpen(true)} variant="primary">
            <Plus aria-hidden="true" size={16} />
            New Lorry Receipt (LR)
          </Button>
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
          <span className="metric-label">Total Lorry Receipts</span>
          <strong className="metric-value">{receipts.length}</strong>
        </article>
        <article className="metric-card">
          <span className="metric-label">In Transit / Active Dispatches</span>
          <strong className="metric-value">{issuedCount}</strong>
        </article>
        <article className="metric-card">
          <span className="metric-label">Delivered Consignments</span>
          <strong className="metric-value">{deliveredCount}</strong>
        </article>
        <article className="metric-card">
          <span className="metric-label">Pending Transporter Freight Bills</span>
          <strong className="metric-value">{toBeBilledCount}</strong>
        </article>
      </div>

      <section className="list-panel" aria-label="Lorry receipts directory">
        <div className="list-toolbar list-toolbar--stacked">
          <div className="role-tabs" aria-label="Filter lorry receipts by status" role="tablist">
            {statusFilters.map((opt) => (
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

        {lrQuery.isError ? (
          <div className="directory-state directory-state--error" role="alert">
            <strong>Lorry receipts could not be loaded.</strong>
            <p>Check your connection and permissions, then refresh the page.</p>
          </div>
        ) : lrQuery.isLoading ? (
          <div aria-live="polite" className="directory-state">Loading lorry receipts...</div>
        ) : receipts.length ? (
          <DataTable caption="Lorry receipts">
            <thead>
              <tr>
                <th scope="col">LR #</th>
                <th scope="col">LR Date</th>
                <th scope="col">Route (Lane)</th>
                <th scope="col">Vehicle / Driver</th>
                <th scope="col">e-Way Bill</th>
                <th scope="col">Weight / Pkgs</th>
                <th scope="col">Freight & GST</th>
                <th scope="col">Freight Basis</th>
                <th scope="col">Status</th>
              </tr>
            </thead>
            <tbody>
              {receipts.map((lr) => (
                <tr
                  className="data-table-row--interactive"
                  key={lr.id}
                  onClick={() => navigate(appRoutes.lorryReceiptDetail(lr.id))}
                  tabIndex={0}
                >
                  <td>
                    <strong>{lr.lrNumber}</strong>
                  </td>
                  <td>{formatDate(lr.lrDate)}</td>
                  <td>
                    <div className="cell-stack">
                      <span>{lr.origin || '--'} â†’ {lr.destination || '--'}</span>
                      {lr.distanceKm ? <span className="cell-muted">{lr.distanceKm} km</span> : null}
                    </div>
                  </td>
                  <td>
                    <div className="cell-stack">
                      <strong>{lr.vehicleNumber || '--'}</strong>
                      {lr.driverName ? <span className="cell-muted">{lr.driverName}</span> : null}
                    </div>
                  </td>
                  <td>
                    <span className="mono-code">{lr.ewayBillNo || '--'}</span>
                  </td>
                  <td>
                    <div className="cell-stack">
                      <span>{lr.weightKg ? `${lr.weightKg} kg` : '--'}</span>
                      {lr.numPackages ? <span className="cell-muted">{lr.numPackages} pkgs</span> : null}
                    </div>
                  </td>
                  <td>
                    <div className="cell-stack">
                      <Money amount={lr.freightAmount} />
                      <span className="cell-muted">{lr.gstTreatment || 'RCM'} {lr.freightGstRate ? `(${lr.freightGstRate}%)` : ''}</span>
                    </div>
                  </td>
                  <td>
                    <StatusChip status={formatStatusLabel(lr.freightBasis || 'TO_BE_BILLED')} />
                  </td>
                  <td>
                    <StatusChip status={formatStatusLabel(lr.status)} />
                  </td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        ) : (
          <div className="directory-state directory-state--empty">
            <FileSpreadsheet aria-hidden="true" size={32} />
            <strong>No Lorry Receipts found.</strong>
            <p>Issue an LR for outbound freight dispatches or inter-branch transport.</p>
          </div>
        )}
      </section>

      {isModalOpen ? (
        <CreateLorryReceiptModal
          contacts={contactsQuery.data?.content ?? []}
          isSubmitting={createMutation.isPending}
          onClose={() => setIsModalOpen(false)}
          onSubmit={(data) => createMutation.mutate(data)}
        />
      ) : null}
    </section>
  )
}

function CreateLorryReceiptModal({
  contacts,
  isSubmitting,
  onClose,
  onSubmit,
}: {
  contacts: Array<{ id: string; displayName: string }>
  isSubmitting: boolean
  onClose: () => void
  onSubmit: (data: CreateLorryReceiptRequest) => void
}) {
  const [lrDate, setLrDate] = useState(new Date().toISOString().slice(0, 10))
  const [transporterContactId, setTransporterContactId] = useState(contacts[0]?.id ?? '')
  const [contactId, setContactId] = useState('')
  const [ewayBillNo, setEwayBillNo] = useState('')
  const [vehicleNumber, setVehicleNumber] = useState('')
  const [driverName, setDriverName] = useState('')
  const [driverPhone, setDriverPhone] = useState('')
  const [origin, setOrigin] = useState('')
  const [destination, setDestination] = useState('')
  const [distanceKm, setDistanceKm] = useState<number | undefined>(undefined)
  const [mode, setMode] = useState('ROAD')
  const [numPackages, setNumPackages] = useState<number | undefined>(undefined)
  const [weightKg, setWeightKg] = useState<number | undefined>(undefined)
  const [declaredValue, setDeclaredValue] = useState<number | undefined>(undefined)
  const [freightAmount, setFreightAmount] = useState<number | undefined>(undefined)
  const [freightBasis, setFreightBasis] = useState('TO_BE_BILLED')
  const [gstTreatment, setGstTreatment] = useState('RCM')
  const [freightGstRate, setFreightGstRate] = useState<number>(5)
  const [notes, setNotes] = useState('')

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (!transporterContactId) return
    onSubmit({
      lrDate,
      transporterContactId,
      contactId: contactId || null,
      ewayBillNo: ewayBillNo.trim() || null,
      vehicleNumber: vehicleNumber.trim() || null,
      driverName: driverName.trim() || null,
      driverPhone: driverPhone.trim() || null,
      origin: origin.trim() || null,
      destination: destination.trim() || null,
      distanceKm: distanceKm ?? null,
      mode,
      numPackages: numPackages ?? null,
      weightKg: weightKg ?? null,
      declaredValue: declaredValue ?? null,
      freightAmount: freightAmount ?? null,
      freightBasis,
      gstTreatment,
      freightGstRate: freightGstRate ?? 5,
      notes: notes.trim() || null,
    })
  }

  return (
    <div className="modal-backdrop" role="dialog" aria-modal="true">
      <div className="modal-card modal-card--wide">
        <header className="modal-header">
          <h2>Create Lorry Receipt (LR)</h2>
          <button className="modal-close" onClick={onClose} type="button">×</button>
        </header>
        <form onSubmit={handleSubmit}>
          <div className="form-row">
            <div className="form-group">
              <label htmlFor="lr-transporter">Transporter / GTA Vendor *</label>
              <select
                id="lr-transporter"
                required
                value={transporterContactId}
                onChange={(e) => setTransporterContactId(e.target.value)}
              >
                <option value="">Select transporter...</option>
                {contacts.map((c) => (
                  <option key={c.id} value={c.id}>{c.displayName}</option>
                ))}
              </select>
            </div>
            <div className="form-group">
              <label htmlFor="lr-consignee">Consignee Customer (optional)</label>
              <select
                id="lr-consignee"
                value={contactId}
                onChange={(e) => setContactId(e.target.value)}
              >
                <option value="">Select customer...</option>
                {contacts.map((c) => (
                  <option key={c.id} value={c.id}>{c.displayName}</option>
                ))}
              </select>
            </div>
            <div className="form-group">
              <label htmlFor="lr-date">LR Date *</label>
              <input
                id="lr-date"
                required
                type="date"
                value={lrDate}
                onChange={(e) => setLrDate(e.target.value)}
              />
            </div>
          </div>

          <div className="form-row">
            <div className="form-group">
              <label htmlFor="lr-origin">Origin / Pickup Location</label>
              <input
                id="lr-origin"
                placeholder="e.g. Central Warehouse, Bhiwandi"
                type="text"
                value={origin}
                onChange={(e) => setOrigin(e.target.value)}
              />
            </div>
            <div className="form-group">
              <label htmlFor="lr-dest">Destination / Delivery Location</label>
              <input
                id="lr-dest"
                placeholder="e.g. Pune Distribution Hub"
                type="text"
                value={destination}
                onChange={(e) => setDestination(e.target.value)}
              />
            </div>
            <div className="form-group">
              <label htmlFor="lr-distance">Distance (km)</label>
              <input
                id="lr-distance"
                min="0"
                type="number"
                value={distanceKm ?? ''}
                onChange={(e) => setDistanceKm(e.target.value ? Number(e.target.value) : undefined)}
              />
            </div>
          </div>

          <div className="form-row">
            <div className="form-group">
              <label htmlFor="lr-vehicle">Vehicle Number</label>
              <input
                id="lr-vehicle"
                placeholder="e.g. MH12AB1234"
                type="text"
                value={vehicleNumber}
                onChange={(e) => setVehicleNumber(e.target.value)}
              />
            </div>
            <div className="form-group">
              <label htmlFor="lr-driver">Driver Name</label>
              <input
                id="lr-driver"
                placeholder="Driver full name"
                type="text"
                value={driverName}
                onChange={(e) => setDriverName(e.target.value)}
              />
            </div>
            <div className="form-group">
              <label htmlFor="lr-phone">Driver Phone</label>
              <input
                id="lr-phone"
                placeholder="10-digit mobile"
                type="tel"
                value={driverPhone}
                onChange={(e) => setDriverPhone(e.target.value)}
              />
            </div>
            <div className="form-group">
              <label htmlFor="lr-eway">e-Way Bill No</label>
              <input
                id="lr-eway"
                placeholder="12-digit e-Way Bill"
                type="text"
                value={ewayBillNo}
                onChange={(e) => setEwayBillNo(e.target.value)}
              />
            </div>
          </div>

          <div className="form-row">
            <div className="form-group">
              <label htmlFor="lr-mode">Transport Mode</label>
              <select id="lr-mode" value={mode} onChange={(e) => setMode(e.target.value)}>
                <option value="ROAD">Road (GTA)</option>
                <option value="RAIL">Rail Cargo</option>
                <option value="AIR">Air Cargo</option>
              </select>
            </div>
            <div className="form-group">
              <label htmlFor="lr-packages">No. of Packages</label>
              <input
                id="lr-packages"
                min="1"
                type="number"
                value={numPackages ?? ''}
                onChange={(e) => setNumPackages(e.target.value ? Number(e.target.value) : undefined)}
              />
            </div>
            <div className="form-group">
              <label htmlFor="lr-weight">Total Weight (kg)</label>
              <input
                id="lr-weight"
                min="0"
                step="0.01"
                type="number"
                value={weightKg ?? ''}
                onChange={(e) => setWeightKg(e.target.value ? Number(e.target.value) : undefined)}
              />
            </div>
            <div className="form-group">
              <label htmlFor="lr-declared">Declared Goods Value (â‚¹)</label>
              <input
                id="lr-declared"
                min="0"
                step="0.01"
                type="number"
                value={declaredValue ?? ''}
                onChange={(e) => setDeclaredValue(e.target.value ? Number(e.target.value) : undefined)}
              />
            </div>
          </div>

          <div className="form-row">
            <div className="form-group">
              <label htmlFor="lr-freight">Freight Amount (â‚¹)</label>
              <input
                id="lr-freight"
                min="0"
                step="0.01"
                type="number"
                value={freightAmount ?? ''}
                onChange={(e) => setFreightAmount(e.target.value ? Number(e.target.value) : undefined)}
              />
            </div>
            <div className="form-group">
              <label htmlFor="lr-basis">Freight Payment Basis</label>
              <select id="lr-basis" value={freightBasis} onChange={(e) => setFreightBasis(e.target.value)}>
                <option value="TO_BE_BILLED">To Be Billed (AP Purchase Bill)</option>
                <option value="PAID">Paid (Consignor Prepaid)</option>
                <option value="TO_PAY">To Pay (Consignee Cash/Credit)</option>
              </select>
            </div>
            <div className="form-group">
              <label htmlFor="lr-gst">GST Treatment</label>
              <select id="lr-gst" value={gstTreatment} onChange={(e) => setGstTreatment(e.target.value)}>
                <option value="RCM">Reverse Charge Mechanism (RCM 5%)</option>
                <option value="FORWARD">Forward Charge (12% / 18%)</option>
                <option value="EXEMPT">Exempt</option>
              </select>
            </div>
            <div className="form-group">
              <label htmlFor="lr-gst-rate">Freight GST Rate (%)</label>
              <input
                id="lr-gst-rate"
                min="0"
                type="number"
                value={freightGstRate}
                onChange={(e) => setFreightGstRate(Number(e.target.value))}
              />
            </div>
          </div>

          <div className="form-group">
            <label htmlFor="lr-notes">Notes / Consignment Instructions</label>
            <input
              id="lr-notes"
              type="text"
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
            />
          </div>

          <footer className="modal-footer">
            <Button onClick={onClose} type="button" variant="secondary">Cancel</Button>
            <Button disabled={isSubmitting} type="submit" variant="primary">
              {isSubmitting ? 'Creating...' : 'Issue Lorry Receipt'}
            </Button>
          </footer>
        </form>
      </div>
    </div>
  )
}