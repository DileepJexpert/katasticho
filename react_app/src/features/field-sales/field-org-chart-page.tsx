import { useState, useMemo } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import {
  Briefcase,
  CheckCircle2,
  ChevronRight,
  Network,
  RefreshCw,
  Search,
  Users,
} from 'lucide-react'
import {
  Button,
  DataTable,
  DocumentCard,
  PageHeader,
} from '@/design-system'
import {
  assignReportingManager,
  getFieldOrgChart,
  getMyFieldTeam,
  type MyTeamSummary,
  type OrgChartNode,
} from '@/features/field-sales/field-sales-api'

export function FieldOrgChartPage() {
  const queryClient = useQueryClient()
  const [searchTerm, setSearchTerm] = useState('')
  const [assignModalUser, setAssignModalUser] = useState<OrgChartNode | null>(null)
  const [selectedManagerId, setSelectedManagerId] = useState<string>('')
  const [actionSuccess, setActionSuccess] = useState<string | null>(null)

  const orgChartQuery = useQuery({
    queryKey: ['field-sales', 'org-chart'],
    queryFn: () => getFieldOrgChart(),
  })

  const myTeamQuery = useQuery({
    queryKey: ['field-sales', 'my-team'],
    queryFn: () => getMyFieldTeam(),
  })

  function handleRefresh() {
    queryClient.invalidateQueries({ queryKey: ['field-sales', 'org-chart'] })
    queryClient.invalidateQueries({ queryKey: ['field-sales', 'my-team'] })
  }

  const assignMutation = useMutation({
    mutationFn: ({ userId, managerId }: { userId: string; managerId: string | null }) =>
      assignReportingManager(userId, managerId),
    onSuccess: () => {
      setActionSuccess('Reporting manager updated successfully.')
      setAssignModalUser(null)
      queryClient.invalidateQueries({ queryKey: ['field-sales', 'org-chart'] })
      queryClient.invalidateQueries({ queryKey: ['field-sales', 'my-team'] })
    },
  })

  const rawNodes: OrgChartNode[] = useMemo(() => orgChartQuery.data ?? [], [orgChartQuery.data])
  const myTeam: Partial<MyTeamSummary> = myTeamQuery.data ?? {}

  const filteredNodes = useMemo(() => {
    if (!searchTerm.trim()) return rawNodes
    const term = searchTerm.trim().toLowerCase()
    return rawNodes.filter((n) => {
      const nameMatch = n.fullName.toLowerCase().includes(term)
      const roleMatch = n.role.toLowerCase().includes(term)
      const managerMatch = (n.reportsToName || '').toLowerCase().includes(term)
      return nameMatch || roleMatch || managerMatch
    })
  }, [rawNodes, searchTerm])

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <div className="flex items-center gap-2">
            <Button
              aria-label="Refresh hierarchy"
              onClick={handleRefresh}
              variant="secondary"
            >
              <RefreshCw size={15} aria-hidden="true" />
              <span>Refresh</span>
            </Button>
          </div>
        }
        eyebrow="Field Operations • Reporting Hierarchy"
        title="Field Sales Hierarchy & Org Chart"
        description="Territory reporting structures, manager downline sizes, and field force chain of command."
      />

      <div className="dashboard-workspace">
        {actionSuccess && (
          <div className="p-3 text-sm rounded bg-emerald-50 text-emerald-800 border border-emerald-200 flex items-center gap-2">
            <CheckCircle2 size={16} className="text-emerald-600 flex-none" />
            <span>{actionSuccess}</span>
          </div>
        )}

        {/* ── Downline Scope Metrics ── */}
        <section aria-label="Hierarchy summary metrics" className="metric-grid">
          <article className="metric-card metric-card--brand">
            <span className="metric-icon">
              <Users size={18} aria-hidden="true" />
            </span>
            <div className="metric-content">
              <span className="metric-label">Direct Reports</span>
              <span className="metric-value font-mono">
                {myTeamQuery.isLoading ? '—' : myTeam.directReports?.length ?? 0}
              </span>
              <span className="metric-footnote">Staff reporting directly to you</span>
            </div>
          </article>

          <article className="metric-card">
            <span className="metric-icon">
              <Network size={18} aria-hidden="true" />
            </span>
            <div className="metric-content">
              <span className="metric-label">Total Downline Force</span>
              <span className="metric-value font-mono">
                {myTeamQuery.isLoading ? '—' : myTeam.downlineCount ?? 0}
              </span>
              <span className="metric-footnote">Full field hierarchy footprint</span>
            </div>
          </article>

          <article className="metric-card metric-card--success">
            <span className="metric-icon">
              <Briefcase size={18} aria-hidden="true" />
            </span>
            <div className="metric-content">
              <span className="metric-label">Total Org Roster</span>
              <span className="metric-value font-mono">
                {orgChartQuery.isLoading ? '—' : rawNodes.length}
              </span>
              <span className="metric-footnote">Total active field personnel</span>
            </div>
          </article>
        </section>

        {/* ── Search Bar ── */}
        <section
          aria-label="Roster search"
          className="flex items-center justify-between gap-3 p-3 bg-surface border border-subtle rounded-lg"
        >
          <div className="relative" style={{ width: '280px' }}>
            <Search
              size={14}
              className="absolute left-3 top-1/2 -translate-y-1/2 text-muted pointer-events-none"
            />
            <input
              aria-label="Search personnel"
              className="dashboard-branch-select"
              placeholder="Search by name, role, manager..."
              style={{ width: '100%', paddingLeft: '32px' }}
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>

          <span className="text-xs text-muted font-mono">
            {filteredNodes.length} personnel matching
          </span>
        </section>

        {/* ── Hierarchy Directory Table ── */}
        <DocumentCard title="Field Reporting Directory">
          {orgChartQuery.isLoading ? (
            <div className="p-4 text-secondary text-sm">Loading field hierarchy...</div>
          ) : filteredNodes.length > 0 ? (
            <DataTable caption="Field sales personnel and reporting hierarchy relationships">
              <thead>
                <tr>
                  <th scope="col">Staff Member</th>
                  <th scope="col">Enterprise Role</th>
                  <th scope="col">Reporting Manager</th>
                  <th className="numeric-cell" scope="col">Team Size</th>
                  <th className="numeric-cell" scope="col">Action</th>
                </tr>
              </thead>
              <tbody>
                {filteredNodes.map((node) => (
                  <tr key={node.userId}>
                    <td>
                      <div className="flex items-center gap-2">
                        <div className="w-8 h-8 rounded-full bg-teal-50 text-teal-700 flex items-center justify-center font-bold text-xs">
                          {node.fullName.slice(0, 2).toUpperCase()}
                        </div>
                        <div>
                          <strong>{node.fullName}</strong>
                        </div>
                      </div>
                    </td>
                    <td>
                      <span className="font-mono text-xs text-secondary">{node.role}</span>
                    </td>
                    <td>
                      {node.reportsToName ? (
                        <div className="flex items-center gap-1 text-xs">
                          <ChevronRight size={12} className="text-muted flex-none" />
                          <span className="font-semibold text-primary">{node.reportsToName}</span>
                        </div>
                      ) : (
                        <span className="text-muted text-xs italic">Direct (No Manager)</span>
                      )}
                    </td>
                    <td className="numeric-cell">
                      <span className="font-mono text-xs">
                        {node.teamCount ? `${node.teamCount} reports` : 'Individual'}
                      </span>
                    </td>
                    <td className="numeric-cell">
                      <Button
                        onClick={() => {
                          setAssignModalUser(node)
                          setSelectedManagerId(node.reportsToUserId || '')
                        }}
                        variant="secondary"
                      >
                        <span>Change Manager</span>
                      </Button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          ) : (
            <div className="p-8 text-center text-secondary text-sm">
              <Network size={28} className="mx-auto mb-2 text-muted opacity-40" />
              <span>No personnel found.</span>
            </div>
          )}
        </DocumentCard>

        {/* ── Assign Manager Modal ── */}
        {assignModalUser && (
          <div
            className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40 backdrop-blur-sm"
            role="dialog"
            aria-modal="true"
          >
            <div className="bg-surface border border-subtle rounded-xl shadow-xl max-w-md w-full p-5 flex flex-col gap-4">
              <div className="flex items-center justify-between pb-3 border-b border-subtle">
                <strong className="text-base font-semibold text-primary">
                  Assign Reporting Manager
                </strong>
                <button
                  type="button"
                  onClick={() => setAssignModalUser(null)}
                  className="text-muted hover:text-primary text-sm p-1"
                >
                  ✕
                </button>
              </div>

              <div>
                <span className="text-xs text-muted block mb-1">Target Personnel:</span>
                <strong className="text-sm text-primary">{assignModalUser.fullName}</strong>
                <span className="text-xs text-secondary block font-mono">({assignModalUser.role})</span>
              </div>

              <div className="flex flex-col gap-1.5">
                <label htmlFor="manager-select" className="text-xs font-semibold text-secondary">
                  Select Reporting Manager:
                </label>
                <select
                  id="manager-select"
                  className="dashboard-branch-select"
                  value={selectedManagerId}
                  onChange={(e) => setSelectedManagerId(e.target.value)}
                >
                  <option value="">None (Top-Level Executive)</option>
                  {rawNodes
                    .filter((n) => n.userId !== assignModalUser.userId)
                    .map((n) => (
                      <option key={n.userId} value={n.userId}>
                        {n.fullName} ({n.role})
                      </option>
                    ))}
                </select>
              </div>

              <div className="pt-3 border-t border-subtle flex justify-end gap-2">
                <Button onClick={() => setAssignModalUser(null)} variant="secondary">
                  Cancel
                </Button>
                <Button
                  disabled={assignMutation.isPending}
                  onClick={() =>
                    assignMutation.mutate({
                      userId: assignModalUser.userId,
                      managerId: selectedManagerId || null,
                    })
                  }
                  variant="primary"
                >
                  <span>{assignMutation.isPending ? 'Saving...' : 'Save Assignment'}</span>
                </Button>
              </div>
            </div>
          </div>
        )}
      </div>
    </section>
  )
}
