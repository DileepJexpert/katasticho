import { useState, useMemo } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import {
  AlertTriangle,
  Award,
  Calendar,
  CheckCircle2,
  RefreshCw,
  Target,
  Users,
} from 'lucide-react'
import {
  Button,
  DataTable,
  DocumentCard,
  Money,
  PageHeader,
} from '@/design-system'
import {
  getFrequencyCompliance,
  getTeamCoverageDashboard,
} from '@/features/field-sales/field-sales-api'

function getCurrentMonthIso(): string {
  const now = new Date()
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`
}

function getMonthStartIso(): string {
  const now = new Date()
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`
}

function getTodayIso(): string {
  const now = new Date()
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`
}

export function FieldCoveragePage() {
  const queryClient = useQueryClient()
  const [selectedMonth, setSelectedMonth] = useState(getCurrentMonthIso())
  const [searchTerm, setSearchTerm] = useState('')

  const complianceQuery = useQuery({
    queryKey: ['field-sales', 'coverage-compliance', selectedMonth],
    queryFn: () => getFrequencyCompliance(selectedMonth),
  })

  const teamCoverageQuery = useQuery({
    queryKey: ['field-sales', 'team-coverage', getMonthStartIso(), getTodayIso()],
    queryFn: () => getTeamCoverageDashboard(getMonthStartIso(), getTodayIso()),
  })

  function handleRefresh() {
    queryClient.invalidateQueries({ queryKey: ['field-sales'] })
  }

  const compliance = complianceQuery.data
  const teamSummaries = useMemo(() => teamCoverageQuery.data ?? [], [teamCoverageQuery.data])

  const filteredTeam = useMemo(() => {
    if (!searchTerm.trim()) return teamSummaries
    const term = searchTerm.trim().toLowerCase()
    return teamSummaries.filter((s) => s.salespersonName.toLowerCase().includes(term))
  }, [teamSummaries, searchTerm])

  const totalPlanned = compliance?.totalPlannedVisits ?? 0
  const totalActual = compliance?.totalActualVisits ?? 0
  const compliancePct = compliance?.compliancePercentage ?? 0

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <div className="flex items-center gap-2">
            <Button
              aria-label="Refresh coverage metrics"
              onClick={handleRefresh}
              variant="secondary"
            >
              <RefreshCw size={15} aria-hidden="true" />
              <span>Refresh</span>
            </Button>
          </div>
        }
        eyebrow="Field Operations • Call Governance"
        title="Territory Coverage & Call Compliance"
        description="Surveillance of planned vs actual call frequencies across core doctor/retailer tiers and territory deviation tracking."
      />

      <div className="dashboard-workspace">
        {/* ── Month Controls ── */}
        <section
          aria-label="Coverage controls"
          className="flex flex-wrap items-center justify-between gap-3 p-3 bg-surface border border-subtle rounded-lg"
        >
          <div className="flex items-center gap-2">
            <Calendar size={15} className="text-muted" />
            <span className="text-xs font-semibold text-secondary uppercase tracking-wider">
              Coverage Month:
            </span>
            <input
              aria-label="Coverage month selector"
              type="month"
              className="dashboard-branch-select font-mono text-xs"
              value={selectedMonth}
              onChange={(e) => setSelectedMonth(e.target.value)}
            />
          </div>

          <div className="text-xs text-secondary font-mono">
            Period: {selectedMonth}
          </div>
        </section>

        {/* ── KPI Metric Cards ── */}
        <section aria-label="Coverage KPIs" className="metric-grid">
          <article className="metric-card metric-card--brand">
            <span className="metric-icon">
              <Target size={18} aria-hidden="true" />
            </span>
            <div className="metric-content">
              <span className="metric-label">Planned Calls</span>
              <span className="metric-value font-mono">
                {complianceQuery.isLoading ? '—' : totalPlanned}
              </span>
              <span className="metric-footnote">Targeted customer commitments</span>
            </div>
          </article>

          <article className="metric-card">
            <span className="metric-icon">
              <CheckCircle2 size={18} aria-hidden="true" />
            </span>
            <div className="metric-content">
              <span className="metric-label">Calls Delivered</span>
              <span className="metric-value font-mono">
                {complianceQuery.isLoading ? '—' : totalActual}
              </span>
              <span className="metric-footnote">Verified check-in visits</span>
            </div>
          </article>

          <article className={`metric-card ${compliancePct >= 80 ? 'metric-card--success' : 'metric-card--warning'}`}>
            <span className="metric-icon">
              <Award size={18} aria-hidden="true" />
            </span>
            <div className="metric-content">
              <span className="metric-label">Coverage Strike Rate</span>
              <span className="metric-value font-mono">
                {complianceQuery.isLoading ? '—' : `${compliancePct}%`}
              </span>
              <span className="metric-footnote">
                {compliancePct >= 80 ? 'Benchmark achieved' : 'Under governance target'}
              </span>
            </div>
          </article>

          <article className="metric-card">
            <span className="metric-icon">
              <AlertTriangle size={18} aria-hidden="true" />
            </span>
            <div className="metric-content">
              <span className="metric-label">Missed Calls</span>
              <span className="metric-value font-mono text-rose-700">
                {complianceQuery.isLoading ? '—' : Math.max(0, totalPlanned - totalActual)}
              </span>
              <span className="metric-footnote">Unvisited core contacts</span>
            </div>
          </article>
        </section>

        {/* ── Category Tier Breakdown ── */}
        {compliance?.categoryBreakdown && compliance.categoryBreakdown.length > 0 && (
          <DocumentCard title="Tier-Wise Call Frequency Compliance">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              {compliance.categoryBreakdown.map((cat) => (
                <div
                  key={cat.category}
                  className="p-3 bg-surface border border-subtle rounded-lg flex flex-col gap-2"
                >
                  <div className="flex items-center justify-between">
                    <strong className="text-sm text-primary">Class {cat.category} Accounts</strong>
                    <span className="text-xs font-mono font-bold text-brand">{cat.compliance}%</span>
                  </div>

                  <div className="flex items-center justify-between text-xs text-muted">
                    <span>Delivered: {cat.completed}</span>
                    <span>Planned: {cat.planned}</span>
                  </div>

                  <div className="w-full bg-subtle rounded-full h-2 overflow-hidden">
                    <div
                      className={`h-full ${cat.compliance >= 80 ? 'bg-emerald-600' : 'bg-teal-600'}`}
                      style={{ width: `${Math.min(cat.compliance, 100)}%` }}
                    />
                  </div>
                </div>
              ))}
            </div>
          </DocumentCard>
        )}

        {/* ── Team Coverage Summary Table ── */}
        <DocumentCard title="Representative Coverage Performance">
          <div className="mb-3">
            <input
              aria-label="Search representative coverage"
              className="dashboard-branch-select"
              placeholder="Search representative name..."
              style={{ width: '280px' }}
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>

          {teamCoverageQuery.isLoading ? (
            <div className="p-4 text-secondary text-sm">Loading coverage performance...</div>
          ) : filteredTeam.length > 0 ? (
            <DataTable caption="Team field coverage metrics and strike rates">
              <thead>
                <tr>
                  <th scope="col">Sales Representative</th>
                  <th className="numeric-cell" scope="col">Planned Calls</th>
                  <th className="numeric-cell" scope="col">Actual Calls</th>
                  <th className="numeric-cell" scope="col">Productive Calls</th>
                  <th className="numeric-cell" scope="col">Strike Rate</th>
                  <th className="numeric-cell" scope="col">Booked Value</th>
                </tr>
              </thead>
              <tbody>
                {filteredTeam.map((rep) => (
                  <tr key={rep.salespersonId}>
                    <td>
                      <strong>{rep.salespersonName}</strong>
                    </td>
                    <td className="numeric-cell">
                      <span className="font-mono">{rep.plannedCalls}</span>
                    </td>
                    <td className="numeric-cell">
                      <span className="font-mono">{rep.actualCalls}</span>
                    </td>
                    <td className="numeric-cell">
                      <span className="font-mono">{rep.productiveCalls}</span>
                    </td>
                    <td className="numeric-cell">
                      <span
                        className={`font-mono text-xs font-semibold px-2 py-0.5 rounded ${
                          rep.strikeRate >= 80
                            ? 'bg-emerald-100 text-emerald-800'
                            : rep.strikeRate >= 60
                            ? 'bg-teal-100 text-teal-800'
                            : 'bg-amber-100 text-amber-800'
                        }`}
                      >
                        {rep.strikeRate}%
                      </span>
                    </td>
                    <td className="numeric-cell">
                      <Money amount={rep.orderValue} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          ) : (
            <div className="p-6 text-center text-secondary text-sm">
              <Users size={24} className="mx-auto mb-1 text-muted opacity-40" />
              <span>No representative coverage reports for this period.</span>
            </div>
          )}
        </DocumentCard>
      </div>
    </section>
  )
}
