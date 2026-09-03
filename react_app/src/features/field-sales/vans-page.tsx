import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Link } from 'react-router-dom'
import {
  Plus,
  Search,
  Trash2,
  Truck,
  X,
} from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import {
  createVan,
  deleteVan,
  listVans,
  type Van,
} from '@/features/field-sales/field-sales-api'

export function VansPage() {
  const [searchTerm, setSearchTerm] = useState('')
  const [isAddOpen, setIsAddOpen] = useState(false)
  const queryClient = useQueryClient()

  const { data, isLoading, isError } = useQuery({
    queryKey: ['field-sales', 'vans'],
    queryFn: () => listVans(0, 50),
  })

  const vans: Van[] = data?.content || []

  const deleteMutation = useMutation({
    mutationFn: deleteVan,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['field-sales', 'vans'] })
    },
  })

  const createMutation = useMutation({
    mutationFn: createVan,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['field-sales', 'vans'] })
      setIsAddOpen(false)
    },
  })

  const filteredVans = vans.filter(
    (v) =>
      (v.name && v.name.toLowerCase().includes(searchTerm.toLowerCase())) ||
      v.code.toLowerCase().includes(searchTerm.toLowerCase()) ||
      v.vehicleNumber.toLowerCase().includes(searchTerm.toLowerCase())
  )

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <Button onClick={() => setIsAddOpen(true)} type="button" variant="primary">
            <Plus aria-hidden="true" size={16} />
            <span>Add Mobile Van</span>
          </Button>
        }
        description="Mobile distribution fleet, van on-board stock balances, and load/return stock transfers."
        eyebrow="Van Sales & Distribution"
        title="Mobile Vans Fleet"
      />

      <div className="summary-strip">
        <div className="metric-cell">
          <span className="metric-label">Active Vans</span>
          <strong className="metric-value">{vans.length}</strong>
        </div>
      </div>

      <div className="table-card">
        <div className="search-bar-wrap" style={{ padding: '16px 20px', borderBottom: '1px solid var(--k-color-border)' }}>
          <div className="search-input-group" style={{ display: 'flex', alignItems: 'center', gap: 8, maxWidth: 360 }}>
            <Search aria-hidden="true" size={16} />
            <input
              aria-label="Search vans"
              className="form-input"
              onChange={(e) => setSearchTerm(e.target.value)}
              placeholder="Search by code, registration number, or name..."
              type="search"
              value={searchTerm}
            />
          </div>
        </div>

        {isLoading ? (
          <div className="directory-state">Loading van fleet...</div>
        ) : isError ? (
          <div className="directory-state directory-state--error">Failed to load van fleet.</div>
        ) : filteredVans.length === 0 ? (
          <div className="directory-state">
            <Truck aria-hidden="true" size={32} />
            <p>No mobile distribution vans found. Add a vehicle to enable direct spot-selling.</p>
          </div>
        ) : (
          <DataTable caption="Mobile Vans Fleet Register">
            <thead>
              <tr>
                <th scope="col">Van Code</th>
                <th scope="col">Registration Number</th>
                <th scope="col">Vehicle Name / Model</th>
                <th scope="col">Vehicle Type</th>
                <th scope="col" style={{ textAlign: 'right' }}>Capacity (KG)</th>
                <th scope="col">Status</th>
                <th scope="col" style={{ textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredVans.map((van) => (
                <tr key={van.id}>
                  <td>
                    <Link className="table-link" to={`/vans/${van.id}`}>
                      <strong>{van.code}</strong>
                    </Link>
                  </td>
                  <td><strong>{van.vehicleNumber}</strong></td>
                  <td>{van.name || 'â€”'}</td>
                  <td><StatusChip status={van.vehicleType || 'VAN'} /></td>
                  <td style={{ textAlign: 'right' }}>{van.capacityWeightKg ?? 'â€”'}</td>
                  <td><StatusChip status={van.isActive ? 'ACTIVE' : 'INACTIVE'} /></td>
                  <td style={{ textAlign: 'right' }}>
                    <button
                      aria-label={`Delete ${van.name || van.code}`}
                      className="button button--ghost"
                      onClick={() => {
                        if (window.confirm(`Delete van ${van.name || van.code}?`)) {
                          deleteMutation.mutate(van.id)
                        }
                      }}
                      type="button"
                    >
                      <Trash2 aria-hidden="true" size={16} />
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        )}
      </div>

      {isAddOpen ? (
        <AddVanModal
          isPending={createMutation.isPending}
          onClose={() => setIsAddOpen(false)}
          onSubmit={(payload) => createMutation.mutate(payload)}
        />
      ) : null}
    </section>
  )
}

function AddVanModal({
  onClose,
  onSubmit,
  isPending,
}: {
  onClose: () => void
  onSubmit: (payload: { code: string; vehicleNumber: string; name?: string; vehicleType?: string; capacityWeightKg?: number }) => void
  isPending: boolean
}) {
  const [code, setCode] = useState('')
  const [vehicleNumber, setVehicleNumber] = useState('')
  const [name, setName] = useState('')
  const [vehicleType, setVehicleType] = useState('MINI_TRUCK')
  const [capacityWeightKg, setCapacityWeightKg] = useState(1000)

  return (
    <div className="modal-backdrop">
      <div className="modal-card" style={{ maxWidth: 440 }}>
        <div className="modal-header">
          <h2 className="modal-title">Add Mobile Van</h2>
          <button aria-label="Close" className="button button--ghost" onClick={onClose} type="button">
            <X aria-hidden="true" size={18} />
          </button>
        </div>

        <form
          onSubmit={(e) => {
            e.preventDefault()
            onSubmit({
              code,
              vehicleNumber,
              name: name || undefined,
              vehicleType,
              capacityWeightKg: capacityWeightKg || undefined,
            })
          }}
        >
          <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              <div className="form-field">
                <label className="form-label" htmlFor="v-code">Van Code *</label>
                <input
                  className="form-input"
                  id="v-code"
                  onChange={(e) => setCode(e.target.value)}
                  placeholder="VAN-01"
                  required
                  value={code}
                />
              </div>

              <div className="form-field">
                <label className="form-label" htmlFor="v-reg">Vehicle Reg # *</label>
                <input
                  className="form-input"
                  id="v-reg"
                  onChange={(e) => setVehicleNumber(e.target.value)}
                  placeholder="MH-01-AB-1234"
                  required
                  value={vehicleNumber}
                />
              </div>
            </div>

            <div className="form-field">
              <label className="form-label" htmlFor="v-name">Vehicle Name / Make</label>
              <input
                className="form-input"
                id="v-name"
                onChange={(e) => setName(e.target.value)}
                placeholder="Tata Ace Gold"
                value={name}
              />
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              <div className="form-field">
                <label className="form-label" htmlFor="v-type">Vehicle Type</label>
                <select
                  className="form-input"
                  id="v-type"
                  onChange={(e) => setVehicleType(e.target.value)}
                  value={vehicleType}
                >
                  <option value="MINI_TRUCK">Mini Truck</option>
                  <option value="VAN">Van</option>
                  <option value="THREE_WHEELER">Three Wheeler</option>
                  <option value="TWO_WHEELER">Two Wheeler</option>
                </select>
              </div>

              <div className="form-field">
                <label className="form-label" htmlFor="v-cap">Capacity (KG)</label>
                <input
                  className="form-input"
                  id="v-cap"
                  min={0}
                  onChange={(e) => setCapacityWeightKg(parseFloat(e.target.value) || 0)}
                  type="number"
                  value={capacityWeightKg}
                />
              </div>
            </div>
          </div>

          <div className="modal-footer">
            <Button onClick={onClose} type="button" variant="secondary">Cancel</Button>
            <Button disabled={isPending || !code || !vehicleNumber} type="submit" variant="primary">
              {isPending ? 'Saving...' : 'Add Van'}
            </Button>
          </div>
        </form>
      </div>
    </div>
  )
}
