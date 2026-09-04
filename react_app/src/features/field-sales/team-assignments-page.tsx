import { useState, useMemo } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import {
  CheckCircle2,
  MapPin,
  Plus,
  RefreshCw,
  Search,
  Truck,
  UserCheck,
  Users,
} from 'lucide-react'
import {
  Button,
  DataTable,
  DocumentCard,
  PageHeader,
  StatusChip,
} from '@/design-system'
import {
  createAssignment,
  endAssignment,
  listAssignments,
  listBeats,
  listRoutes,
  listVans,
  type FieldSalesAssignment,
  type SalesBeat,
  type SalesRoute,
  type SalesVan,
} from '@/features/field-sales/field-sales-api'

function getTodayIso(): string {
  const now = new Date()
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`
}

export function TeamAssignmentsPage() {
  const queryClient = useQueryClient()
  const [searchTerm, setSearchTerm] = useState('')
  const [includeInactive, setIncludeInactive] = useState(false)
  const [showCreateModal, setShowCreateModal] = useState(false)
  const [actionSuccess, setActionSuccess] = useState<string | null>(null)

  // Form states
  const [salespersonId, setSalespersonId] = useState('')
  const [routeId, setRouteId] = useState('')
  const [beatId, setBeatId] = useState('')
  const [vanId, setVanId] = useState('')
  const [startDate, setStartDate] = useState(getTodayIso())

  const assignmentsQuery = useQuery({
    queryKey: ['field-sales', 'assignments', includeInactive],
    queryFn: () => listAssignments(includeInactive),
  })

  const routesQuery = useQuery({
    queryKey: ['field-sales', 'routes'],
    queryFn: () => listRoutes(0, 100),
  })

  const beatsQuery = useQuery({
    queryKey: ['field-sales', 'beats'],
    queryFn: () => listBeats(0, 100),
  })

  const vansQuery = useQuery({
    queryKey: ['field-sales', 'vans'],
    queryFn: () => listVans(0, 100),
  })

  function handleRefresh() {
    queryClient.invalidateQueries({ queryKey: ['field-sales', 'assignments'] })
  }

  const createMutation = useMutation({
    mutationFn: () =>
      createAssignment({
        salespersonId,
        routeId: routeId || undefined,
        beatId: beatId || undefined,
        vanId: vanId || undefined,
        startDate,
      }),
    onSuccess: () => {
      setActionSuccess('Territory assignment created successfully.')
      setShowCreateModal(false)
      setSalespersonId('')
      setRouteId('')
      setBeatId('')
      setVanId('')
      queryClient.invalidateQueries({ queryKey: ['field-sales', 'assignments'] })
    },
  })

  const endMutation = useMutation({
    mutationFn: (id: string) => endAssignment(id, getTodayIso()),
    onSuccess: () => {
      setActionSuccess('Assignment ended.')
      queryClient.invalidateQueries({ queryKey: ['field-sales', 'assignments'] })
    },
  })

  const assignments: FieldSalesAssignment[] = useMemo(
    () => assignmentsQuery.data ?? [],
    [assignmentsQuery.data]
  )
  const routes: SalesRoute[] = routesQuery.data?.content ?? []
  const beats: SalesBeat[] = beatsQuery.data?.content ?? []
  const vans: SalesVan[] = vansQuery.data?.content ?? []

  const filteredAssignments = useMemo(() => {
    if (!searchTerm.trim()) return assignments
    const term = searchTerm.trim().toLowerCase()
    return assignments.filter((a) => {
      const spMatch = (a.salespersonName || '').toLowerCase().includes(term)
      const rMatch = (a.routeName || '').toLowerCase().includes(term)
      const bMatch = (a.beatName || '').toLowerCase().includes(term)
      return spMatch || rMatch || bMatch
    })
  }, [assignments, searchTerm])

  const activeCount = assignments.filter((a) => a.active).length

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <div className="flex items-center gap-2">
            <Button
              aria-label="Refresh assignments"
              onClick={handleRefresh}
              variant="secondary"
            >
              <RefreshCw size={15} aria-hidden="true" />
              <span>Refresh</span>
            </Button>
            <Button
              onClick={() => setShowCreateModal(true)}
              variant="primary"
            >
              <Plus size={15} aria-hidden="true" />
              <span>New Assignment</span>
            </Button>
          </div>
        }
        eyebrow="Field Operations • Territory Administration"
        title="Team Route & Beat Assignments"
        description="Territory beat and route allocations to sales representatives, van assignments, and active tenure management."
      />

      <div className="dashboard-workspace">
        {actionSuccess && (
          <div className="p-3 text-sm rounded bg-emerald-50 text-emerald-800 border border-emerald-200 flex items-center gap-2">
            <CheckCircle2 size={16} className="text-emerald-600 flex-none" />
            <span>{actionSuccess}</span>
          </div>
        )}

        {/* ── Summary Strip ── */}
        <section aria-label="Assignment metrics" className="metric-grid">
          <article className="metric-card metric-card--brand">
            <span className="metric-icon">
              <UserCheck size={18} aria-hidden="true" />
            </span>
            <div className="metric-content">
              <span className="metric-label">Active Assignments</span>
              <span className="metric-value font-mono">
                {assignmentsQuery.isLoading ? '—' : activeCount}
              </span>
              <span className="metric-footnote">Reps currently assigned to routes</span>
            </div>
          </article>

          <article className="metric-card">
            <span className="metric-icon">
              <MapPin size={18} aria-hidden="true" />
            </span>
            <div className="metric-content">
              <span className="metric-label">Covered Routes</span>
              <span className="metric-value font-mono">
                {routes.length}
              </span>
              <span className="metric-footnote">Active master sales routes</span>
            </div>
          </article>

          <article className="metric-card metric-card--success">
            <span className="metric-icon">
              <Truck size={18} aria-hidden="true" />
            </span>
            <div className="metric-content">
              <span className="metric-label">Fleet Vans Allocated</span>
              <span className="metric-value font-mono">
                {assignments.filter((a) => Boolean(a.vanId)).length}
              </span>
              <span className="metric-footnote">Vehicles paired to representatives</span>
            </div>
          </article>
        </section>

        {/* ── Search & Filter Controls ── */}
        <section
          aria-label="Assignment filters"
          className="flex flex-wrap items-center justify-between gap-3 p-3 bg-surface border border-subtle rounded-lg"
        >
          <div className="relative" style={{ width: '280px' }}>
            <Search
              size={14}
              className="absolute left-3 top-1/2 -translate-y-1/2 text-muted pointer-events-none"
            />
            <input
              aria-label="Search assignments"
              className="dashboard-branch-select"
              placeholder="Search rep, route, or beat..."
              style={{ width: '100%', paddingLeft: '32px' }}
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>

          <label className="flex items-center gap-2 text-xs text-secondary cursor-pointer">
            <input
              type="checkbox"
              checked={includeInactive}
              onChange={(e) => setIncludeInactive(e.target.checked)}
            />
            <span>Include Inactive / Historical Assignments</span>
          </label>
        </section>

        {/* ── Assignments Table ── */}
        <DocumentCard title={`Assignments Registry (${filteredAssignments.length})`}>
          {assignmentsQuery.isLoading ? (
            <div className="p-4 text-secondary text-sm">Loading assignments...</div>
          ) : filteredAssignments.length > 0 ? (
            <DataTable caption="Active field representative territory assignments">
              <thead>
                <tr>
                  <th scope="col">Sales Representative</th>
                  <th scope="col">Assigned Route</th>
                  <th scope="col">Assigned Beat</th>
                  <th scope="col">Mobile Van</th>
                  <th scope="col">Tenure</th>
                  <th scope="col">Status</th>
                  <th className="numeric-cell" scope="col">Action</th>
                </tr>
              </thead>
              <tbody>
                {filteredAssignments.map((a) => (
                  <tr key={a.id}>
                    <td>
                      <strong>{a.salespersonName || 'Representative'}</strong>
                    </td>
                    <td>
                      <span className="text-secondary">{a.routeName || '—'}</span>
                    </td>
                    <td>
                      <span className="text-secondary">{a.beatName || '—'}</span>
                    </td>
                    <td>
                      {a.vanPlateNumber ? (
                        <span className="font-mono text-xs text-brand font-semibold">
                          {a.vanPlateNumber}
                        </span>
                      ) : (
                        <span className="text-muted text-xs">—</span>
                      )}
                    </td>
                    <td>
                      <span className="font-mono text-xs text-muted">
                        {a.startDate} {a.endDate ? `to ${a.endDate}` : '(Current)'}
                      </span>
                    </td>
                    <td>
                      <StatusChip status={a.active ? 'ACTIVE' : 'INACTIVE'} />
                    </td>
                    <td className="numeric-cell">
                      {a.active && (
                        <Button
                          disabled={endMutation.isPending}
                          onClick={() => endMutation.mutate(a.id)}
                          variant="secondary"
                        >
                          <span>End</span>
                        </Button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          ) : (
            <div className="p-8 text-center text-secondary text-sm">
              <Users size={28} className="mx-auto mb-2 text-muted opacity-40" />
              <span>No assignments matching criteria.</span>
            </div>
          )}
        </DocumentCard>

        {/* ── New Assignment Modal ── */}
        {showCreateModal && (
          <div
            className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40 backdrop-blur-sm"
            role="dialog"
            aria-modal="true"
          >
            <div className="bg-surface border border-subtle rounded-xl shadow-xl max-w-lg w-full p-5 flex flex-col gap-4">
              <div className="flex items-center justify-between pb-3 border-b border-subtle">
                <strong className="text-base font-semibold text-primary">
                  New Territory Assignment
                </strong>
                <button
                  type="button"
                  onClick={() => setShowCreateModal(false)}
                  className="text-muted hover:text-primary text-sm p-1"
                >
                  ✕
                </button>
              </div>

              <div className="flex flex-col gap-3">
                <label className="field-group">
                  <span className="text-xs font-semibold text-secondary">Salesperson UUID / ID *</span>
                  <input
                    aria-label="Salesperson ID"
                    placeholder="Enter salesperson UUID..."
                    className="dashboard-branch-select"
                    value={salespersonId}
                    onChange={(e) => setSalespersonId(e.target.value)}
                  />
                </label>

                <label className="field-group">
                  <span className="text-xs font-semibold text-secondary">Assigned Route</span>
                  <select
                    aria-label="Assigned Route"
                    className="dashboard-branch-select"
                    value={routeId}
                    onChange={(e) => setRouteId(e.target.value)}
                  >
                    <option value="">None (Ad-hoc)</option>
                    {routes.map((r) => (
                      <option key={r.id} value={r.id}>
                        {r.name} ({r.code})
                      </option>
                    ))}
                  </select>
                </label>

                <label className="field-group">
                  <span className="text-xs font-semibold text-secondary">Assigned Beat</span>
                  <select
                    aria-label="Assigned Beat"
                    className="dashboard-branch-select"
                    value={beatId}
                    onChange={(e) => setBeatId(e.target.value)}
                  >
                    <option value="">None</option>
                    {beats.map((b) => (
                      <option key={b.id} value={b.id}>
                        {b.name} ({b.code})
                      </option>
                    ))}
                  </select>
                </label>

                <label className="field-group">
                  <span className="text-xs font-semibold text-secondary">Mobile Van</span>
                  <select
                    aria-label="Mobile Van"
                    className="dashboard-branch-select"
                    value={vanId}
                    onChange={(e) => setVanId(e.target.value)}
                  >
                    <option value="">None</option>
                    {vans.map((v) => (
                      <option key={v.id} value={v.id}>
                        {v.plateNumber} - {v.name}
                      </option>
                    ))}
                  </select>
                </label>

                <label className="field-group">
                  <span className="text-xs font-semibold text-secondary">Start Date</span>
                  <input
                    aria-label="Start Date"
                    type="date"
                    className="dashboard-branch-select font-mono text-xs"
                    value={startDate}
                    onChange={(e) => setStartDate(e.target.value)}
                  />
                </label>
              </div>

              <div className="pt-3 border-t border-subtle flex justify-end gap-2">
                <Button onClick={() => setShowCreateModal(false)} variant="secondary">
                  Cancel
                </Button>
                <Button
                  disabled={!salespersonId || createMutation.isPending}
                  onClick={() => createMutation.mutate()}
                  variant="primary"
                >
                  <span>{createMutation.isPending ? 'Assigning...' : 'Confirm Assignment'}</span>
                </Button>
              </div>
            </div>
          </div>
        )}
      </div>
    </section>
  )
}
