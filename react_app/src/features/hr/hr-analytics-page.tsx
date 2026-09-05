import { useQuery } from '@tanstack/react-query'
import { Link } from 'react-router-dom'
import {
  Users,
  CalendarCheck,
  CalendarClock,
  FileSpreadsheet,
  LifeBuoy,
  AlertTriangle,
  ArrowRight,
} from 'lucide-react'
import {
  PageHeader,
  Button,
  DataTable,
} from '@/design-system'
import { getHrAnalyticsDashboard } from '@/features/hr/hr-api'
import { appRoutes } from '@/app/navigation'

export function HrAnalyticsPage() {
  const { data, isLoading, refetch } = useQuery({
    queryKey: ['hr-analytics-dashboard'],
    queryFn: () => getHrAnalyticsDashboard(),
  })

  const departmentList = Object.entries(data?.byDepartment ?? {}).map(([dept, count]) => ({
    department: dept,
    headcount: count,
    percentage: data?.headcount ? Math.round((count / data.headcount) * 100) : 0,
  }))

  return (
    <div className="space-y-6">
      <PageHeader
        title="HR Analytics & Workforce Pulse"
        description="Real-time workforce snapshot, daily attendance, pending compliance requests, and expiring KYC records."
        actions={
          <Button variant="secondary" onClick={() => refetch()}>
            Refresh Analytics
          </Button>
        }
      />

      {/* KPI Cards Grid */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] p-4 shadow-sm">
          <div className="flex items-center justify-between">
            <span className="text-xs font-medium uppercase tracking-wider text-[var(--color-text-muted)]">
              Total Headcount
            </span>
            <div className="rounded-md bg-[var(--color-brand)]/10 p-2 text-[var(--color-brand)]">
              <Users className="h-5 w-5" />
            </div>
          </div>
          <div className="mt-2 text-2xl font-bold text-[var(--color-text-default)]">
            {isLoading ? '--' : data?.headcount ?? 0}
          </div>
          <span className="mt-1 block text-xs text-[var(--color-text-muted)]">Active registered employees</span>
        </div>

        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] p-4 shadow-sm">
          <div className="flex items-center justify-between">
            <span className="text-xs font-medium uppercase tracking-wider text-[var(--color-text-muted)]">
              On Leave Today
            </span>
            <div className="rounded-md bg-[var(--color-brand)]/10 p-2 text-[var(--color-brand)]">
              <CalendarCheck className="h-5 w-5" />
            </div>
          </div>
          <div className="mt-2 text-2xl font-bold text-[var(--color-brand)]">
            {isLoading ? '--' : data?.onLeaveToday ?? 0}
          </div>
          <span className="mt-1 block text-xs text-[var(--color-text-muted)]">Approved day-off / leaves</span>
        </div>

        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] p-4 shadow-sm">
          <div className="flex items-center justify-between">
            <span className="text-xs font-medium uppercase tracking-wider text-[var(--color-text-muted)]">
              Pending Leaves
            </span>
            <div className="rounded-md bg-[var(--color-warning)]/10 p-2 text-[var(--color-warning)]">
              <CalendarClock className="h-5 w-5" />
            </div>
          </div>
          <div className="mt-2 text-2xl font-bold text-[var(--color-warning)]">
            {isLoading ? '--' : data?.pendingLeaves ?? 0}
          </div>
          <Link
            to={appRoutes.leaves}
            className="mt-1 inline-flex items-center text-xs font-medium text-[var(--color-brand)] hover:underline"
          >
            Review applications <ArrowRight className="ml-1 h-3 w-3" />
          </Link>
        </div>

        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] p-4 shadow-sm">
          <div className="flex items-center justify-between">
            <span className="text-xs font-medium uppercase tracking-wider text-[var(--color-text-muted)]">
              Pending Timesheets
            </span>
            <div className="rounded-md bg-[var(--color-warning)]/10 p-2 text-[var(--color-warning)]">
              <FileSpreadsheet className="h-5 w-5" />
            </div>
          </div>
          <div className="mt-2 text-2xl font-bold text-[var(--color-warning)]">
            {isLoading ? '--' : data?.pendingTimesheets ?? 0}
          </div>
          <Link
            to={appRoutes.timesheets}
            className="mt-1 inline-flex items-center text-xs font-medium text-[var(--color-brand)] hover:underline"
          >
            Review timesheets <ArrowRight className="ml-1 h-3 w-3" />
          </Link>
        </div>

        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] p-4 shadow-sm">
          <div className="flex items-center justify-between">
            <span className="text-xs font-medium uppercase tracking-wider text-[var(--color-text-muted)]">
              Pending Regularizations
            </span>
            <div className="rounded-md bg-[var(--color-warning)]/10 p-2 text-[var(--color-warning)]">
              <CalendarClock className="h-5 w-5" />
            </div>
          </div>
          <div className="mt-2 text-2xl font-bold text-[var(--color-warning)]">
            {isLoading ? '--' : data?.pendingRegularizations ?? 0}
          </div>
          <Link
            to={appRoutes.attendance}
            className="mt-1 inline-flex items-center text-xs font-medium text-[var(--color-brand)] hover:underline"
          >
            Review punch fixes <ArrowRight className="ml-1 h-3 w-3" />
          </Link>
        </div>

        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] p-4 shadow-sm">
          <div className="flex items-center justify-between">
            <span className="text-xs font-medium uppercase tracking-wider text-[var(--color-text-muted)]">
              Open HR Tickets
            </span>
            <div className="rounded-md bg-[var(--color-brand)]/10 p-2 text-[var(--color-brand)]">
              <LifeBuoy className="h-5 w-5" />
            </div>
          </div>
          <div className="mt-2 text-2xl font-bold text-[var(--color-text-default)]">
            {isLoading ? '--' : data?.openTickets ?? 0}
          </div>
          <Link
            to={appRoutes.hrTickets}
            className="mt-1 inline-flex items-center text-xs font-medium text-[var(--color-brand)] hover:underline"
          >
            View helpdesk queue <ArrowRight className="ml-1 h-3 w-3" />
          </Link>
        </div>

        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] p-4 shadow-sm">
          <div className="flex items-center justify-between">
            <span className="text-xs font-medium uppercase tracking-wider text-[var(--color-text-muted)]">
              Docs Expiring (30d)
            </span>
            <div className="rounded-md bg-[var(--color-error)]/10 p-2 text-[var(--color-error)]">
              <AlertTriangle className="h-5 w-5" />
            </div>
          </div>
          <div className="mt-2 text-2xl font-bold text-[var(--color-error)]">
            {isLoading ? '--' : data?.documentsExpiringIn30Days ?? 0}
          </div>
          <Link
            to={appRoutes.hrDocuments}
            className="mt-1 inline-flex items-center text-xs font-medium text-[var(--color-brand)] hover:underline"
          >
            Check watchlist <ArrowRight className="ml-1 h-3 w-3" />
          </Link>
        </div>
      </div>

      {/* Department Breakdown Section */}
      <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] p-6 shadow-sm">
        <div className="mb-4 flex items-center justify-between">
          <div>
            <h3 className="text-base font-semibold text-[var(--color-text-default)]">
              Workforce Distribution by Department
            </h3>
            <p className="text-xs text-[var(--color-text-muted)]">
              Staff allocation across organizational units and divisions.
            </p>
          </div>
          <div className="rounded-md bg-[var(--color-bg-subtle)] px-3 py-1 text-xs font-medium text-[var(--color-text-muted)]">
            {departmentList.length} Departments
          </div>
        </div>

        <DataTable caption="Staff distribution across organizational departments">
          <thead>
            <tr>
              <th scope="col">Department</th>
              <th scope="col">Active Headcount</th>
              <th scope="col">Share of Workforce</th>
            </tr>
          </thead>
          <tbody>
            {departmentList.length === 0 ? (
              <tr>
                <td colSpan={3} className="text-center text-sm text-[var(--color-text-muted)]">
                  No departments recorded yet.
                </td>
              </tr>
            ) : (
              departmentList.map((item) => (
                <tr key={item.department}>
                  <td>
                    <span className="font-medium text-[var(--color-text-default)]">{item.department}</span>
                  </td>
                  <td>
                    <span className="font-mono text-sm font-semibold text-[var(--color-text-default)]">
                      {item.headcount}
                    </span>
                  </td>
                  <td>
                    <div className="flex items-center space-x-3">
                      <div className="h-2 w-32 overflow-hidden rounded-full bg-[var(--color-border)]">
                        <div
                          className="h-full bg-[var(--color-brand)]"
                          style={{ width: item.percentage + '%' }}
                        />
                      </div>
                      <span className="font-mono text-xs text-[var(--color-text-muted)]">{item.percentage}%</span>
                    </div>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </DataTable>
      </div>
    </div>
  )
}
