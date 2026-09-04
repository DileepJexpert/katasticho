import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import {
  Calendar,
  DollarSign,
  PlayCircle,
  RefreshCw,
  ShoppingBag,
  Target,
  TrendingUp,
  Truck,
  Users,
} from 'lucide-react'
import {
  Button,
  DataTable,
  DocumentCard,
  Money,
  PageHeader,
  StatusChip,
} from '@/design-system'
import {
  getSecondaryDashboard,
  listExecutions,
  listSalesmanTargets,
  type SecondaryDashboardData,
  type RouteExecution,
  type SalesmanTarget,
} from '@/features/field-sales/field-sales-api'

function getMonthStartIso(): string {
  const now = new Date()
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`
}

function getTodayIso(): string {
  const now = new Date()
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`
}

export function SalesmanDashboardPage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const [fromDate, setFromDate] = useState(getMonthStartIso())
  const [toDate, setToDate] = useState(getTodayIso())

  const dashboardQuery = useQuery({
    queryKey: ['field-sales', 'dashboard', fromDate, toDate],
    queryFn: () => getSecondaryDashboard(fromDate, toDate),
  })

  const targetsQuery = useQuery({
    queryKey: ['field-sales', 'targets'],
    queryFn: () => listSalesmanTargets(0, 10),
  })

  const executionsQuery = useQuery({
    queryKey: ['field-sales', 'executions', 'recent'],
    queryFn: () => listExecutions(0, 10),
  })

  function handleRefresh() {
    queryClient.invalidateQueries({ queryKey: ['field-sales'] })
  }

  const d: Partial<SecondaryDashboardData> = dashboardQuery.data ?? {}
  const targets: SalesmanTarget[] = targetsQuery.data?.content ?? []
  const executions: RouteExecution[] = executionsQuery.data?.content ?? []

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <div className="flex items-center gap-2">
            <Button
              aria-label="Refresh dashboard data"
              onClick={handleRefresh}
              variant="secondary"
            >
              <RefreshCw size={15} aria-hidden="true" />
              <span>Refresh</span>
            </Button>
            <Button
              onClick={() => navigate('/field-sales/executions')}
              variant="primary"
            >
              <PlayCircle size={15} aria-hidden="true" />
              <span>Today's Routes</span>
            </Button>
          </div>
        }
        eyebrow="Field Operations • Performance & Execution"
        title="Field Sales Dashboard"
        description="Secondary sales performance, call productivity, collection runs, and salesman quota tracking."
      />

      <div className="dashboard-workspace">
        {/* ── Date Range Controls ── */}
        <section
          aria-label="Date range filter"
          className="flex flex-wrap items-center justify-between gap-3 p-3 bg-surface border border-subtle rounded-lg"
        >
          <div className="flex items-center gap-2">
            <Calendar size={15} className="text-muted" />
            <span className="text-xs font-semibold text-secondary uppercase tracking-wider">
              Analytics Horizon:
            </span>
          </div>

          <div className="flex flex-wrap items-center gap-3">
            <div className="flex items-center gap-1.5 text-xs">
              <span className="text-muted">From:</span>
              <input
                aria-label="From date"
                type="date"
                className="dashboard-branch-select font-mono"
                value={fromDate}
                onChange={(e) => setFromDate(e.target.value)}
              />
            </div>

            <div className="flex items-center gap-1.5 text-xs">
              <span className="text-muted">To:</span>
              <input
                aria-label="To date"
                type="date"
                className="dashboard-branch-select font-mono"
                value={toDate}
                onChange={(e) => setToDate(e.target.value)}
              />
            </div>
          </div>
        </section>

        {/* ── KPI Metric Cards ── */}
        <section aria-label="Field sales KPIs" className="metric-grid">
          <article className="metric-card metric-card--brand">
            <span className="metric-icon">
              <Users size={18} aria-hidden="true" />
            </span>
            <div className="metric-content">
              <span className="metric-label">Active Field Reps</span>
              <span className="metric-value font-mono">
                {dashboardQuery.isLoading ? '—' : d.totalSalespersons ?? 0}
              </span>
              <span className="metric-footnote">On active beat assignment</span>
            </div>
          </article>

          <article className="metric-card">
            <span className="metric-icon">
              <TrendingUp size={18} aria-hidden="true" />
            </span>
            <div className="metric-content">
              <span className="metric-label">Call Productivity</span>
              <span className="metric-value font-mono">
                {dashboardQuery.isLoading ? '—' : `${d.productiveVisitPct ?? 0}%`}
              </span>
              <span className="metric-footnote">
                {d.totalVisitsCompleted ?? 0} of {d.totalVisitsPlanned ?? 0} visits completed
              </span>
            </div>
          </article>

          <article className="metric-card">
            <span className="metric-icon">
              <ShoppingBag size={18} aria-hidden="true" />
            </span>
            <div className="metric-content">
              <span className="metric-label">Orders Booked</span>
              <span className="metric-value font-mono">
                {dashboardQuery.isLoading ? '—' : <Money amount={d.totalOrdersValue ?? 0} />}
              </span>
              <span className="metric-footnote">
                Avg order: <Money amount={d.averageOrderValue ?? 0} />
              </span>
            </div>
          </article>

          <article className="metric-card metric-card--success">
            <span className="metric-icon">
              <DollarSign size={18} aria-hidden="true" />
            </span>
            <div className="metric-content">
              <span className="metric-label">Collections Logged</span>
              <span className="metric-value font-mono">
                {dashboardQuery.isLoading ? '—' : <Money amount={d.totalCollections ?? 0} />}
              </span>
              <span className="metric-footnote">Cash & digital field collections</span>
            </div>
          </article>
        </section>

        {/* ── Active Quota Targets Strip ── */}
        <DocumentCard title="Target Achievement Matrix">
          {targets.length > 0 ? (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {targets.map((target) => {
                const targetVal = Number(target.targetValue || 0)
                const achievedVal = Number(target.achievedValue || 0)
                const pct = targetVal > 0 ? Math.min(Math.round((achievedVal / targetVal) * 100), 100) : 0

                return (
                  <div
                    key={target.id}
                    className="p-3 bg-surface border border-subtle rounded-lg flex flex-col gap-2"
                  >
                    <div className="flex items-center justify-between">
                      <strong className="text-sm text-primary">{target.salespersonName || 'Field Rep'}</strong>
                      <span className="text-xs font-mono text-muted">{target.targetPeriod}</span>
                    </div>

                    <div className="flex items-center justify-between text-xs text-secondary">
                      <span>Target: <Money amount={targetVal} /></span>
                      <span className="font-semibold text-primary">Achieved: <Money amount={achievedVal} /></span>
                    </div>

                    <div className="w-full bg-subtle rounded-full h-2 overflow-hidden">
                      <div
                        className={`h-full transition-all ${pct >= 100 ? 'bg-emerald-600' : pct >= 70 ? 'bg-teal-600' : 'bg-amber-600'}`}
                        style={{ width: `${pct}%` }}
                      />
                    </div>

                    <div className="flex items-center justify-between text-xs text-muted">
                      <span>{target.metricType}</span>
                      <span className="font-mono font-semibold">{pct}%</span>
                    </div>
                  </div>
                )
              })}
            </div>
          ) : (
            <div className="p-4 text-center text-secondary text-sm">
              <Target size={24} className="mx-auto mb-1 text-muted opacity-40" />
              <span>No target quotas set for the current period.</span>
            </div>
          )}
        </DocumentCard>

        {/* ── Recent Field Executions Register ── */}
        <DocumentCard title="Recent Route Executions">
          {executions.length > 0 ? (
            <DataTable caption="Recent field sales route execution dispatches">
              <thead>
                <tr>
                  <th scope="col">Execution #</th>
                  <th scope="col">Date</th>
                  <th scope="col">Salesperson</th>
                  <th scope="col">Route</th>
                  <th className="numeric-cell" scope="col">Progress</th>
                  <th className="numeric-cell" scope="col">Orders Booked</th>
                  <th scope="col">Status</th>
                  <th className="numeric-cell" scope="col">Action</th>
                </tr>
              </thead>
              <tbody>
                {executions.map((exec) => (
                  <tr key={exec.id}>
                    <td>
                      <span className="font-mono font-semibold text-brand">
                        {exec.executionNumber || exec.id.slice(0, 8)}
                      </span>
                    </td>
                    <td>
                      <span className="font-mono text-xs">{exec.executionDate}</span>
                    </td>
                    <td>
                      <strong>{exec.salespersonName || 'Rep'}</strong>
                    </td>
                    <td>
                      <span className="text-secondary">{exec.routeName || '—'}</span>
                    </td>
                    <td className="numeric-cell">
                      <span className="font-mono text-xs">
                        {exec.completedVisits} / {exec.plannedVisits} visits
                      </span>
                    </td>
                    <td className="numeric-cell">
                      <Money amount={exec.totalOrdersValue || 0} />
                    </td>
                    <td>
                      <StatusChip status={exec.status} />
                    </td>
                    <td className="numeric-cell">
                      <Button
                        onClick={() => navigate(`/field-sales/executions/${exec.id}`)}
                        variant="secondary"
                      >
                        <span>View</span>
                      </Button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          ) : (
            <div className="p-6 text-center text-secondary text-sm">
              <Truck size={24} className="mx-auto mb-1 text-muted opacity-40" />
              <span>No route executions recorded yet.</span>
            </div>
          )}
        </DocumentCard>
      </div>
    </section>
  )
}
