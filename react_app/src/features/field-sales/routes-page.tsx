import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Link } from 'react-router-dom'
import {
  Navigation,
  Plus,
  Search,
  Trash2,
  X,
} from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import {
  createRoute,
  deleteRoute,
  listRoutes,
  type RouteSummary,
} from '@/features/field-sales/field-sales-api'

export function RoutesPage() {
  const [searchTerm, setSearchTerm] = useState('')
  const [isAddOpen, setIsAddOpen] = useState(false)
  const queryClient = useQueryClient()

  const { data: routePage, isLoading, isError } = useQuery({
    queryKey: ['field-sales', 'routes'],
    queryFn: () => listRoutes(),
  })

  const routes: RouteSummary[] = routePage?.content ?? []

  const deleteMutation = useMutation({
    mutationFn: deleteRoute,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['field-sales', 'routes'] })
    },
  })

  const createMutation = useMutation({
    mutationFn: createRoute,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['field-sales', 'routes'] })
      setIsAddOpen(false)
    },
  })

  const filteredRoutes = routes.filter(
    (r: RouteSummary) =>
      (r.name || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
      (r.code || '').toLowerCase().includes(searchTerm.toLowerCase())
  )

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <Button onClick={() => setIsAddOpen(true)} type="button" variant="primary">
            <Plus aria-hidden="true" size={16} />
            <span>Create Route</span>
          </Button>
        }
        description="Multi-beat sales routes, weekly day schedules, and vehicle route lines."
        eyebrow="Field Sales & Logistics"
        title="Sales Routes"
      />

      <div className="summary-strip">
        <div className="metric-cell">
          <span className="metric-label">Active Routes</span>
          <strong className="metric-value">{routes.length}</strong>
        </div>
      </div>

      <div className="table-card">
        <div className="search-bar-wrap" style={{ padding: '16px 20px', borderBottom: '1px solid var(--k-color-border)' }}>
          <div className="search-input-group" style={{ display: 'flex', alignItems: 'center', gap: 8, maxWidth: 360 }}>
            <Search aria-hidden="true" size={16} />
            <input
              aria-label="Search routes"
              className="form-input"
              onChange={(e) => setSearchTerm(e.target.value)}
              placeholder="Search by route code or name..."
              type="search"
              value={searchTerm}
            />
          </div>
        </div>

        {isLoading ? (
          <div className="directory-state">Loading sales routes...</div>
        ) : isError ? (
          <div className="directory-state directory-state--error">Failed to load sales routes.</div>
        ) : filteredRoutes.length === 0 ? (
          <div className="directory-state">
            <Navigation aria-hidden="true" size={32} />
            <p>No sales routes found. Create a route to combine beats into scheduled van runs.</p>
          </div>
        ) : (
          <DataTable caption="Sales Routes Master">
            <thead>
              <tr>
                <th scope="col">Route Code</th>
                <th scope="col">Route Name</th>
                <th scope="col">Scheduled Day</th>
                <th scope="col">Frequency</th>
                <th scope="col" style={{ textAlign: 'right' }}>Total Beats</th>
                <th scope="col">Status</th>
                <th scope="col" style={{ textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredRoutes.map((r: RouteSummary) => (
                <tr key={r.id}>
                  <td>
                    <Link className="table-link" to={`/routes/${r.id}`}>
                      <strong>{r.code}</strong>
                    </Link>
                  </td>
                  <td>{r.name}</td>
                  <td>{r.dayOfWeek || 'All Days'}</td>
                  <td>{r.frequency || 'WEEKLY'}</td>
                  <td style={{ textAlign: 'right' }}>{r.beatCount ?? 0}</td>
                  <td><StatusChip status={r.active ? 'ACTIVE' : 'INACTIVE'} /></td>
                  <td style={{ textAlign: 'right' }}>
                    <button
                      aria-label={`Delete ${r.name}`}
                      className="button button--ghost"
                      onClick={() => {
                        if (window.confirm(`Delete route ${r.name}?`)) {
                          deleteMutation.mutate(r.id)
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
        <CreateRouteModal
          isPending={createMutation.isPending}
          onClose={() => setIsAddOpen(false)}
          onSubmit={(payload) => createMutation.mutate(payload)}
        />
      ) : null}
    </section>
  )
}

function CreateRouteModal({
  onClose,
  onSubmit,
  isPending,
}: {
  onClose: () => void
  onSubmit: (payload: { code: string; name: string; dayOfWeek?: string; frequency?: string; warehouseId?: string; beatIds?: string[] }) => void
  isPending: boolean
}) {
  const [code, setCode] = useState('')
  const [name, setName] = useState('')
  const [dayOfWeek, setDayOfWeek] = useState('MONDAY')
  const [frequency, setFrequency] = useState('WEEKLY')
  const [warehouseId, setWarehouseId] = useState('')

  return (
    <div className="modal-backdrop">
      <div className="modal-card" style={{ maxWidth: 440 }}>
        <div className="modal-header">
          <h2 className="modal-title">Create Sales Route</h2>
          <button aria-label="Close" className="button button--ghost" onClick={onClose} type="button">
            <X aria-hidden="true" size={18} />
          </button>
        </div>

        <form
          onSubmit={(e) => {
            e.preventDefault()
            onSubmit({
              code,
              name,
              dayOfWeek: dayOfWeek || undefined,
              frequency: frequency || undefined,
              warehouseId: warehouseId || undefined,
            })
          }}
        >
          <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            <div>
              <label className="form-label" htmlFor="route-code">Route Code *</label>
              <input
                className="form-input"
                id="route-code"
                onChange={(e) => setCode(e.target.value)}
                placeholder="e.g. RT-NORTH-MON"
                required
                type="text"
                value={code}
              />
            </div>

            <div>
              <label className="form-label" htmlFor="route-name">Route Name *</label>
              <input
                className="form-input"
                id="route-name"
                onChange={(e) => setName(e.target.value)}
                placeholder="e.g. North Zone Monday Run"
                required
                type="text"
                value={name}
              />
            </div>

            <div>
              <label className="form-label" htmlFor="route-day">Scheduled Day of Week</label>
              <select
                className="form-input"
                id="route-day"
                onChange={(e) => setDayOfWeek(e.target.value)}
                value={dayOfWeek}
              >
                <option value="MONDAY">Monday</option>
                <option value="TUESDAY">Tuesday</option>
                <option value="WEDNESDAY">Wednesday</option>
                <option value="THURSDAY">Thursday</option>
                <option value="FRIDAY">Friday</option>
                <option value="SATURDAY">Saturday</option>
                <option value="SUNDAY">Sunday</option>
              </select>
            </div>

            <div>
              <label className="form-label" htmlFor="route-freq">Execution Frequency</label>
              <select
                className="form-input"
                id="route-freq"
                onChange={(e) => setFrequency(e.target.value)}
                value={frequency}
              >
                <option value="DAILY">Daily</option>
                <option value="WEEKLY">Weekly</option>
                <option value="BIWEEKLY">Bi-Weekly</option>
                <option value="MONTHLY">Monthly</option>
              </select>
            </div>

            <div>
              <label className="form-label" htmlFor="route-warehouse">Source Warehouse ID (Optional)</label>
              <input
                className="form-input"
                id="route-warehouse"
                onChange={(e) => setWarehouseId(e.target.value)}
                placeholder="Warehouse UUID"
                type="text"
                value={warehouseId}
              />
            </div>
          </div>

          <div className="modal-footer" style={{ display: 'flex', justifyContent: 'flex-end', gap: 8, marginTop: 16 }}>
            <Button onClick={onClose} type="button" variant="secondary">Cancel</Button>
            <Button disabled={isPending || !code || !name} type="submit" variant="primary">
              {isPending ? 'Saving...' : 'Create Route'}
            </Button>
          </div>
        </form>
      </div>
    </div>
  )
}
