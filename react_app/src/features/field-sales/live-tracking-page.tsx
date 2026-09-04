import { useState, useMemo } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import {
  Battery,
  Compass,
  Navigation,
  Radio,
  RefreshCw,
  Route as RouteIcon,
  Search,
  Users,
  X,
} from 'lucide-react'
import {
  Button,
  DataTable,
  DocumentCard,
  PageHeader,
} from '@/design-system'
import {
  getLiveLocations,
  getLocationTrail,
  type LiveLocationUser,
} from '@/features/field-sales/field-sales-api'

export function LiveTrackingPage() {
  const queryClient = useQueryClient()
  const [searchTerm, setSearchTerm] = useState('')
  const [selectedExecutionId, setSelectedExecutionId] = useState<string | null>(null)

  const liveQuery = useQuery({
    queryKey: ['field-sales', 'live-locations'],
    queryFn: () => getLiveLocations(),
    refetchInterval: 30000,
  })

  const trailQuery = useQuery({
    queryKey: ['field-sales', 'location-trail', selectedExecutionId],
    queryFn: () => getLocationTrail(selectedExecutionId!),
    enabled: Boolean(selectedExecutionId),
  })

  function handleRefresh() {
    queryClient.invalidateQueries({ queryKey: ['field-sales', 'live-locations'] })
  }

  const liveUsers: LiveLocationUser[] = useMemo(() => liveQuery.data ?? [], [liveQuery.data])

  const filteredUsers = useMemo(() => {
    if (!searchTerm.trim()) return liveUsers
    const term = searchTerm.trim().toLowerCase()
    return liveUsers.filter((u) => {
      const nameMatch = (u.salespersonName || u.fullName || '').toLowerCase().includes(term)
      const routeMatch = (u.routeName || '').toLowerCase().includes(term)
      return nameMatch || routeMatch
    })
  }, [liveUsers, searchTerm])

  const onlineCount = liveUsers.length
  const avgAccuracy = liveUsers.length > 0
    ? Math.round(liveUsers.reduce((sum, u) => sum + (u.accuracy || 10), 0) / liveUsers.length)
    : 0

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <div className="flex items-center gap-2">
            <Button
              aria-label="Refresh live locations"
              onClick={handleRefresh}
              variant="secondary"
            >
              <RefreshCw size={15} aria-hidden="true" />
              <span>Refresh Pings</span>
            </Button>
          </div>
        }
        eyebrow="Field Operations • Real-Time Telemetry"
        title="Field Live Tracking & GPS Trails"
        description="Real-time GPS telemetry, device battery levels, ping accuracy, and route breadcrumb trails."
      />

      <div className="dashboard-workspace">
        {/* ── Telemetry KPI Summary Strip ── */}
        <section aria-label="Live tracking metrics" className="metric-grid">
          <article className="metric-card metric-card--brand">
            <span className="metric-icon">
              <Radio size={18} aria-hidden="true" />
            </span>
            <div className="metric-content">
              <span className="metric-label">Reps Connected</span>
              <span className="metric-value font-mono">
                {liveQuery.isLoading ? '—' : onlineCount}
              </span>
              <span className="metric-footnote">Active GPS signals in last 30 mins</span>
            </div>
          </article>

          <article className="metric-card">
            <span className="metric-icon">
              <Compass size={18} aria-hidden="true" />
            </span>
            <div className="metric-content">
              <span className="metric-label">GPS Precision</span>
              <span className="metric-value font-mono">
                {liveQuery.isLoading ? '—' : `±${avgAccuracy}m`}
              </span>
              <span className="metric-footnote">Average geofence resolution</span>
            </div>
          </article>

          <article className="metric-card metric-card--success">
            <span className="metric-icon">
              <RouteIcon size={18} aria-hidden="true" />
            </span>
            <div className="metric-content">
              <span className="metric-label">Live Beat Missions</span>
              <span className="metric-value font-mono">
                {liveUsers.filter((u) => Boolean(u.executionId)).length}
              </span>
              <span className="metric-footnote">Dispatched routes in transit</span>
            </div>
          </article>
        </section>

        {/* ── Search Bar ── */}
        <section
          aria-label="Telemetry search"
          className="flex items-center justify-between gap-3 p-3 bg-surface border border-subtle rounded-lg"
        >
          <div className="relative" style={{ width: '280px' }}>
            <Search
              size={14}
              className="absolute left-3 top-1/2 -translate-y-1/2 text-muted pointer-events-none"
            />
            <input
              aria-label="Search live rep or route"
              className="dashboard-branch-select"
              placeholder="Search rep or assigned route..."
              style={{ width: '100%', paddingLeft: '32px' }}
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>

          <span className="text-xs text-muted font-mono">
            Auto-refresh active (every 30s)
          </span>
        </section>

        {/* ── Reps Telemetry Table ── */}
        <DocumentCard title={`Active Field Representatives (${filteredUsers.length})`}>
          {liveQuery.isLoading ? (
            <div className="p-4 text-secondary text-sm">Loading telemetry signals...</div>
          ) : filteredUsers.length > 0 ? (
            <DataTable caption="Live salesperson telemetry tracking and GPS locations">
              <thead>
                <tr>
                  <th scope="col">Salesperson</th>
                  <th scope="col">Assigned Route</th>
                  <th scope="col">Last Location (Lat, Lng)</th>
                  <th scope="col">Accuracy</th>
                  <th scope="col">Battery</th>
                  <th scope="col">Last Ping Time</th>
                  <th className="numeric-cell" scope="col">Trail Action</th>
                </tr>
              </thead>
              <tbody>
                {filteredUsers.map((user) => (
                  <tr key={user.userId}>
                    <td>
                      <div className="flex items-center gap-2">
                        <div className="w-2 h-2 rounded-full bg-emerald-500 flex-none animate-pulse" />
                        <strong>{user.salespersonName || user.fullName || 'Field Rep'}</strong>
                      </div>
                    </td>
                    <td>
                      <span className="text-secondary">{user.routeName || 'Ad-hoc Visit'}</span>
                    </td>
                    <td>
                      <span className="font-mono text-xs text-brand">
                        {user.latitude.toFixed(5)}, {user.longitude.toFixed(5)}
                      </span>
                    </td>
                    <td>
                      <span className="font-mono text-xs text-muted">
                        ±{user.accuracy || 10}m
                      </span>
                    </td>
                    <td>
                      <div className="flex items-center gap-1 text-xs font-mono">
                        <Battery size={14} className="text-muted" />
                        <span>{user.batteryLevel ? `${user.batteryLevel}%` : '—'}</span>
                      </div>
                    </td>
                    <td>
                      <span className="font-mono text-xs text-muted">
                        {user.updatedAt ? new Date(user.updatedAt).toLocaleTimeString('en-IN') : '—'}
                      </span>
                    </td>
                    <td className="numeric-cell">
                      {user.executionId ? (
                        <Button
                          onClick={() => setSelectedExecutionId(user.executionId!)}
                          variant="secondary"
                        >
                          <Navigation size={13} aria-hidden="true" />
                          <span>View Trail</span>
                        </Button>
                      ) : (
                        <span className="text-xs text-muted">No route active</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          ) : (
            <div className="p-8 text-center text-secondary text-sm">
              <Users size={28} className="mx-auto mb-2 text-muted opacity-40" />
              <strong>No active telemetry signals.</strong>
              <p className="text-xs text-muted mt-1">
                Field representatives will appear here once they log into the mobile app and start their beat execution.
              </p>
            </div>
          )}
        </DocumentCard>

        {/* ── Breadcrumb Trail Modal ── */}
        {selectedExecutionId && (
          <div
            className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40 backdrop-blur-sm"
            role="dialog"
            aria-modal="true"
          >
            <div className="bg-surface border border-subtle rounded-xl shadow-xl max-w-2xl w-full p-5 max-h-[85vh] flex flex-col">
              <div className="flex items-center justify-between pb-3 border-b border-subtle">
                <div className="flex items-center gap-2">
                  <Navigation size={18} className="text-brand" />
                  <strong className="text-base font-semibold text-primary">
                    Execution Location Trail
                  </strong>
                </div>
                <button
                  type="button"
                  onClick={() => setSelectedExecutionId(null)}
                  className="text-muted hover:text-primary p-1 rounded"
                >
                  <X size={18} />
                </button>
              </div>

              <div className="overflow-y-auto flex-1 py-4">
                {trailQuery.isLoading ? (
                  <div className="text-secondary text-sm p-4">Loading GPS breadcrumb trail...</div>
                ) : trailQuery.data?.trail && trailQuery.data.trail.length > 0 ? (
                  <div className="flex flex-col gap-3">
                    <div className="text-xs text-muted mb-2">
                      Showing {trailQuery.data.trail.length} GPS pings recorded during this execution mission:
                    </div>
                    {trailQuery.data.trail.map((pt, idx) => (
                      <div
                        key={idx}
                        className="flex items-center justify-between p-2.5 bg-subtle/30 rounded border border-subtle text-xs"
                      >
                        <div className="flex items-center gap-2.5">
                          <span className="font-mono font-bold text-muted w-5">{idx + 1}.</span>
                          <span className="font-mono font-semibold text-brand">
                            {pt.latitude.toFixed(5)}, {pt.longitude.toFixed(5)}
                          </span>
                        </div>
                        <div className="flex items-center gap-3">
                          {pt.activity && (
                            <span className="font-semibold text-secondary">{pt.activity}</span>
                          )}
                          <span className="font-mono text-muted">
                            {new Date(pt.timestamp).toLocaleTimeString('en-IN')}
                          </span>
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="text-center text-muted p-8 text-sm">
                    No GPS breadcrumbs recorded for this execution yet.
                  </div>
                )}
              </div>

              <div className="pt-3 border-t border-subtle flex justify-end">
                <Button onClick={() => setSelectedExecutionId(null)} variant="secondary">
                  Close Trail
                </Button>
              </div>
            </div>
          </div>
        )}
      </div>
    </section>
  )
}
