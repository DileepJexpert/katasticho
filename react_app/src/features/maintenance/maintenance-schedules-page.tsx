import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { CalendarClock, Search, Play } from 'lucide-react'
import { Link } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate } from '@/shared/format/format'
import { listMaintenanceSchedules, generateDueMaintenanceWorkOrders } from '@/features/maintenance/maintenance-api'

export function MaintenanceSchedulesPage() {
  const queryClient = useQueryClient()
  const [search, setSearch] = useState('')

  const query = useQuery({
    queryKey: ['maintenance-schedules'],
    queryFn: () => listMaintenanceSchedules(),
  })

  const generateMutation = useMutation({
    mutationFn: () => generateDueMaintenanceWorkOrders(),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['maintenance-schedules'] })
      queryClient.invalidateQueries({ queryKey: ['maintenance-work-orders'] })
    },
  })

  const rawList = query.data ?? []
  const filtered = rawList.filter((s) => {
    if (!search.trim()) return true
    const q = search.toLowerCase()
    return s.code.toLowerCase().includes(q) || s.title.toLowerCase().includes(q) || (s.workstationName && s.workstationName.toLowerCase().includes(q))
  })

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Manufacturing / Equipment"
        title="Preventive Maintenance Schedules"
        description="Automated PM schedules, recurring machinery routines, and work order generation triggers."
        actions={
          <div className="table-actions">
            <Button
              disabled={generateMutation.isPending}
              onClick={() => generateMutation.mutate()}
              variant="primary"
            >
              <Play aria-hidden="true" size={16} />
              Generate Due Maintenance Orders
            </Button>
          </div>
        }
      />

      <div className="list-toolbar">
        <label className="directory-search">
          <Search aria-hidden="true" size={18} />
          <span className="sr-only">Search schedules</span>
          <input
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search by code, title, or workstation..."
            type="search"
            value={search}
          />
        </label>
      </div>

      {query.isLoading ? (
        <div className="directory-state">Loading maintenance schedules...</div>
      ) : filtered.length === 0 ? (
        <div className="directory-state">
          <CalendarClock size={24} />
          <strong>No maintenance schedules found.</strong>
        </div>
      ) : (
        <DataTable caption="Preventive maintenance routines">
          <thead>
            <tr>
              <th scope="col">Code</th>
              <th scope="col">Work Center</th>
              <th scope="col">Routine Title</th>
              <th className="numeric-cell" scope="col">Frequency</th>
              <th scope="col">Last Completed</th>
              <th scope="col">Next Due Date</th>
              <th scope="col">Status</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((s) => (
              <tr key={s.id}>
                <td><code>{s.code}</code></td>
                <td>
                  <Link className="table-row-link" to={appRoutes.workCenterDetail(s.workstationId)}>
                    {s.workstationName || s.workstationId.slice(0, 8)}
                  </Link>
                </td>
                <td><strong>{s.title}</strong></td>
                <td className="numeric-cell">Every {s.frequencyDays} days</td>
                <td>{s.lastCompletedDate ? formatDate(s.lastCompletedDate) : '--'}</td>
                <td><strong>{formatDate(s.nextDueDate)}</strong></td>
                <td><StatusChip status={s.active ? 'Active' : 'Paused'} /></td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      )}
    </section>
  )
}