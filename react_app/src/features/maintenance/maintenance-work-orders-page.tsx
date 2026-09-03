import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Wrench, Search } from 'lucide-react'
import { Link } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import { listMaintenanceWorkOrders } from '@/features/maintenance/maintenance-api'

export function MaintenanceWorkOrdersPage() {
  const [search, setSearch] = useState('')

  const query = useQuery({
    queryKey: ['maintenance-work-orders'],
    queryFn: () => listMaintenanceWorkOrders(),
  })

  const rawList = query.data ?? []
  const filtered = rawList.filter((m) => {
    if (!search.trim()) return true
    const q = search.toLowerCase()
    return m.mwoNumber.toLowerCase().includes(q) || m.title.toLowerCase().includes(q)
  })

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Manufacturing / Equipment"
        title="Maintenance Work Orders"
        description="Corrective breakdown tickets, preventive maintenance executions, and machine downtime tracking."
      />

      <div className="list-toolbar">
        <label className="directory-search">
          <Search aria-hidden="true" size={18} />
          <span className="sr-only">Search maintenance orders</span>
          <input
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search by MWO # or title..."
            type="search"
            value={search}
          />
        </label>
      </div>

      {query.isLoading ? (
        <div className="directory-state">Loading maintenance work orders...</div>
      ) : filtered.length === 0 ? (
        <div className="directory-state">
          <Wrench size={24} />
          <strong>No maintenance work orders found.</strong>
        </div>
      ) : (
        <DataTable caption="Maintenance and breakdown work orders">
          <thead>
            <tr>
              <th scope="col">MWO #</th>
              <th scope="col">Type</th>
              <th scope="col">Work Center</th>
              <th scope="col">Title</th>
              <th scope="col">Reported Date</th>
              <th scope="col">Priority</th>
              <th scope="col">Status</th>
              <th className="numeric-cell" scope="col">Cost</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((mwo) => (
              <tr key={mwo.id}>
                <td>
                  <Link className="table-row-link" to={appRoutes.maintenanceWorkOrderDetail(mwo.id)}>
                    <code>{mwo.mwoNumber}</code>
                  </Link>
                </td>
                <td>
                  <span className={mwo.maintenanceType === 'BREAKDOWN' ? 'status-badge status-badge--danger' : 'status-badge status-badge--info'}>
                    {mwo.maintenanceType}
                  </span>
                </td>
                <td><strong>{mwo.workstationName || mwo.workstationId.slice(0, 8)}</strong></td>
                <td>{mwo.title}</td>
                <td>{formatDate(mwo.reportedAt)}</td>
                <td>
                  <span className={mwo.priority === 'URGENT' ? 'status-badge status-badge--danger' : 'cell-muted'}>
                    {mwo.priority}
                  </span>
                </td>
                <td><StatusChip status={formatStatusLabel(mwo.status)} /></td>
                <td className="numeric-cell"><Money amount={mwo.cost} /></td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      )}
    </section>
  )
}