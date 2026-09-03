import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Plus, Trash2, Truck } from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import {
  listVehicleLogs,
  createVehicleLog,
  deleteVehicleLog,
  getVehicleTcoSummary,
  type VehicleLogRequest,
} from '@/features/transport/transport-api'
import { listContacts } from '@/features/contacts/contacts-api'

const logTypes = [
  'FUEL',
  'SERVICE',
  'REPAIR',
  'INSURANCE',
  'FITNESS',
  'PERMIT',
  'TYRE',
  'OTHER',
]

export function VehicleLogsPage() {
  const [vehicleFilter, setVehicleFilter] = useState('')
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [feedback, setFeedback] = useState<string | null>(null)
  const queryClient = useQueryClient()

  const logsQuery = useQuery({
    queryKey: ['vehicle-logs', vehicleFilter],
    queryFn: () => listVehicleLogs(vehicleFilter || undefined),
  })

  const tcoQuery = useQuery({
    queryKey: ['vehicle-tco-summary', vehicleFilter],
    queryFn: () => getVehicleTcoSummary(vehicleFilter),
    enabled: Boolean(vehicleFilter.trim()),
  })

  const contactsQuery = useQuery({
    queryKey: ['contacts-vendors'],
    queryFn: () => listContacts({ filter: 'VENDOR', page: 0 }),
  })

  const createMutation = useMutation({
    mutationFn: (data: VehicleLogRequest) => createVehicleLog(data),
    onSuccess: () => {
      setIsModalOpen(false)
      setFeedback('Vehicle log entry recorded.')
      queryClient.invalidateQueries({ queryKey: ['vehicle-logs'] })
      if (vehicleFilter) queryClient.invalidateQueries({ queryKey: ['vehicle-tco-summary', vehicleFilter] })
    },
  })

  const deleteMutation = useMutation({
    mutationFn: (id: string) => deleteVehicleLog(id),
    onSuccess: () => {
      setFeedback('Log entry removed.')
      queryClient.invalidateQueries({ queryKey: ['vehicle-logs'] })
      if (vehicleFilter) queryClient.invalidateQueries({ queryKey: ['vehicle-tco-summary', vehicleFilter] })
    },
  })

  const logs = logsQuery.data ?? []

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Logistics & Fleet / Expenses"
        title="Vehicle Logs & TCO"
        description="Fleet running cost ledger, fuel mileage tracking, preventive maintenance logs, and per-vehicle Total Cost of Ownership (TCO) analytics."
        actions={
          <Button onClick={() => setIsModalOpen(true)} variant="primary">
            <Plus aria-hidden="true" size={16} />
            Log Vehicle Expense
          </Button>
        }
      />

      {feedback ? (
        <div className="notification-banner notification-banner--success" role="status">
          <p>{feedback}</p>
          <button className="banner-dismiss" onClick={() => setFeedback(null)} type="button">×</button>
        </div>
      ) : null}

      <div className="grid-2-cols" style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: '1.5rem' }}>
        <main>
          <div className="list-toolbar">
            <div className="form-group" style={{ maxWidth: '300px' }}>
              <label htmlFor="v-filter">Filter by Vehicle Registration</label>
              <input
                id="v-filter"
                placeholder="e.g. MH12AB1234"
                type="text"
                value={vehicleFilter}
                onChange={(e) => setVehicleFilter(e.target.value.toUpperCase())}
              />
            </div>
          </div>

          {logsQuery.isError ? (
            <div className="directory-state directory-state--error" role="alert">
              <strong>Vehicle logs could not be loaded.</strong>
            </div>
          ) : logsQuery.isLoading ? (
            <div className="directory-state">Loading vehicle logs...</div>
          ) : logs.length ? (
            <DataTable caption="Vehicle expense logs">
              <thead>
                <tr>
                  <th scope="col">Vehicle #</th>
                  <th scope="col">Type</th>
                  <th scope="col">Date</th>
                  <th scope="col">Odometer (km)</th>
                  <th scope="col">Quantity (L)</th>
                  <th scope="col">Amount</th>
                  <th scope="col">Ref # / Notes</th>
                  <th scope="col">Actions</th>
                </tr>
              </thead>
              <tbody>
                {logs.map((lg) => (
                  <tr key={lg.id}>
                    <td><strong>{lg.vehicleNumber}</strong></td>
                    <td><StatusChip status={formatStatusLabel(lg.logType)} /></td>
                    <td>{formatDate(lg.logDate)}</td>
                    <td>{lg.odometerKm ? `${lg.odometerKm} km` : '--'}</td>
                    <td>{lg.quantity ? `${lg.quantity} L` : '--'}</td>
                    <td><strong><Money amount={lg.amount} /></strong></td>
                    <td>
                      <div className="cell-stack">
                        <span>{lg.referenceNo || '--'}</span>
                        {lg.notes ? <span className="cell-muted">{lg.notes}</span> : null}
                      </div>
                    </td>
                    <td>
                      <Button
                        onClick={() => {
                          if (confirm('Delete this vehicle log entry?')) deleteMutation.mutate(lg.id)
                        }}
                        type="button"
                        variant="ghost"
                      >
                        <Trash2 size={14} />
                      </Button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          ) : (
            <div className="directory-state directory-state--empty">
              <Truck aria-hidden="true" size={32} />
              <strong>No vehicle logs found.</strong>
              <p>Log fuel, service, tyre, or maintenance expenses for company vehicles.</p>
            </div>
          )}
        </main>

        <aside>
          <article className="document-card">
            <header className="document-card-header">
              <h2>Vehicle TCO Analytics</h2>
            </header>
            {vehicleFilter.trim() ? (
              tcoQuery.isLoading ? (
                <p>Computing vehicle TCO metrics...</p>
              ) : tcoQuery.data ? (
                <div className="tco-metrics">
                  <div className="progress-row">
                    <span>Total Spend</span>
                    <strong><Money amount={tcoQuery.data.totalSpend} /></strong>
                  </div>
                  <div className="progress-row">
                    <span>Distance Run</span>
                    <span>{tcoQuery.data.distanceKm} km</span>
                  </div>
                  <div className="progress-row">
                    <span>Operating Cost / km</span>
                    <strong style={{ color: 'var(--k-color-brand, #0f8576)' }}>
                      â‚¹{Number(tcoQuery.data.costPerKm || 0).toFixed(2)} / km
                    </strong>
                  </div>
                  <div className="progress-row">
                    <span>Fuel Consumed</span>
                    <span>{tcoQuery.data.fuelLitres} Litres</span>
                  </div>
                  <div className="progress-row">
                    <span>Average Mileage</span>
                    <span>{Number(tcoQuery.data.mileageKmPerLitre || 0).toFixed(2)} km/L</span>
                  </div>
                  <div className="progress-row">
                    <span>Log Entries</span>
                    <span>{tcoQuery.data.entryCount} logs</span>
                  </div>

                  <h3 style={{ marginTop: '1.25rem', marginBottom: '0.5rem', fontSize: '0.95rem' }}>Spend Breakdown</h3>
                  {Object.entries(tcoQuery.data.spendByType || {}).map(([type, amt]) => (
                    <div className="progress-row" key={type}>
                      <span>{formatStatusLabel(type)}</span>
                      <Money amount={amt} />
                    </div>
                  ))}
                </div>
              ) : (
                <p className="cell-muted">No data available for vehicle {vehicleFilter}.</p>
              )
            ) : (
              <p className="cell-muted">Type a Vehicle Registration number in the search filter to view live TCO analytics.</p>
            )}
          </article>
        </aside>
      </div>

      {isModalOpen ? (
        <CreateVehicleLogModal
          contacts={contactsQuery.data?.content ?? []}
          initialVehicle={vehicleFilter}
          isSubmitting={createMutation.isPending}
          onClose={() => setIsModalOpen(false)}
          onSubmit={(d) => createMutation.mutate(d)}
        />
      ) : null}
    </section>
  )
}

function CreateVehicleLogModal({
  initialVehicle,
  contacts,
  isSubmitting,
  onClose,
  onSubmit,
}: {
  initialVehicle: string
  contacts: Array<{ id: string; displayName: string }>
  isSubmitting: boolean
  onClose: () => void
  onSubmit: (data: VehicleLogRequest) => void
}) {
  const [vehicleNumber, setVehicleNumber] = useState(initialVehicle || '')
  const [logType, setLogType] = useState('FUEL')
  const [logDate, setLogDate] = useState(new Date().toISOString().slice(0, 10))
  const [odometerKm, setOdometerKm] = useState<number | undefined>(undefined)
  const [quantity, setQuantity] = useState<number | undefined>(undefined)
  const [amount, setAmount] = useState<number>(0)
  const [vendorContactId, setVendorContactId] = useState('')
  const [referenceNo, setReferenceNo] = useState('')
  const [notes, setNotes] = useState('')

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (!vehicleNumber.trim() || amount <= 0) return
    onSubmit({
      vehicleNumber: vehicleNumber.trim().toUpperCase(),
      logType,
      logDate,
      odometerKm: odometerKm ?? null,
      quantity: quantity ?? null,
      amount,
      vendorContactId: vendorContactId || null,
      referenceNo: referenceNo.trim() || null,
      notes: notes.trim() || null,
    })
  }

  return (
    <div className="modal-backdrop" role="dialog" aria-modal="true">
      <div className="modal-card">
        <header className="modal-header">
          <h2>Log Vehicle Running Expense</h2>
          <button className="modal-close" onClick={onClose} type="button">×</button>
        </header>
        <form onSubmit={handleSubmit}>
          <div className="form-row">
            <div className="form-group">
              <label htmlFor="vl-vehicle">Vehicle Registration Number *</label>
              <input
                id="vl-vehicle"
                placeholder="e.g. MH12AB1234"
                required
                type="text"
                value={vehicleNumber}
                onChange={(e) => setVehicleNumber(e.target.value.toUpperCase())}
              />
            </div>
            <div className="form-group">
              <label htmlFor="vl-type">Expense Type *</label>
              <select id="vl-type" value={logType} onChange={(e) => setLogType(e.target.value)}>
                {logTypes.map((t) => (
                  <option key={t} value={t}>{formatStatusLabel(t)}</option>
                ))}
              </select>
            </div>
          </div>

          <div className="form-row">
            <div className="form-group">
              <label htmlFor="vl-date">Expense Date *</label>
              <input
                id="vl-date"
                required
                type="date"
                value={logDate}
                onChange={(e) => setLogDate(e.target.value)}
              />
            </div>
            <div className="form-group">
              <label htmlFor="vl-odo">Odometer Reading (km)</label>
              <input
                id="vl-odo"
                min="0"
                type="number"
                value={odometerKm ?? ''}
                onChange={(e) => setOdometerKm(e.target.value ? Number(e.target.value) : undefined)}
              />
            </div>
          </div>

          <div className="form-row">
            <div className="form-group">
              <label htmlFor="vl-qty">Fuel Quantity (Litres)</label>
              <input
                id="vl-qty"
                min="0"
                step="0.01"
                type="number"
                value={quantity ?? ''}
                onChange={(e) => setQuantity(e.target.value ? Number(e.target.value) : undefined)}
              />
            </div>
            <div className="form-group">
              <label htmlFor="vl-amt">Expense Amount (â‚¹) *</label>
              <input
                id="vl-amt"
                min="0.01"
                required
                step="0.01"
                type="number"
                value={amount || ''}
                onChange={(e) => setAmount(Number(e.target.value))}
              />
            </div>
          </div>

          <div className="form-row">
            <div className="form-group">
              <label htmlFor="vl-vendor">Service Station / Vendor</label>
              <select
                id="vl-vendor"
                value={vendorContactId}
                onChange={(e) => setVendorContactId(e.target.value)}
              >
                <option value="">Select vendor...</option>
                {contacts.map((c) => (
                  <option key={c.id} value={c.id}>{c.displayName}</option>
                ))}
              </select>
            </div>
            <div className="form-group">
              <label htmlFor="vl-ref">Bill / Receipt Ref Number</label>
              <input
                id="vl-ref"
                placeholder="e.g. INV-91823"
                type="text"
                value={referenceNo}
                onChange={(e) => setReferenceNo(e.target.value)}
              />
            </div>
          </div>

          <div className="form-group">
            <label htmlFor="vl-notes">Notes</label>
            <input
              id="vl-notes"
              type="text"
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
            />
          </div>

          <footer className="modal-footer">
            <Button onClick={onClose} type="button" variant="secondary">Cancel</Button>
            <Button disabled={isSubmitting} type="submit" variant="primary">
              {isSubmitting ? 'Logging...' : 'Save Expense'}
            </Button>
          </footer>
        </form>
      </div>
    </div>
  )
}