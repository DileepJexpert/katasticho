import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Link } from 'react-router-dom'
import {
  Navigation,
  Play,
} from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { EntityPicker } from '@/design-system/entity-picker'
import { FormField } from '@/design-system/form-field'
import { Modal } from '@/design-system/modal'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { TextInput } from '@/design-system/text-input'
import { formatDate } from '@/shared/format/format'
import {
  listExecutions,
  getMyAssignments,
  startExecution,
  type RouteExecution,
  type RouteSummary,
  type Van,
} from '@/features/field-sales/field-sales-api'
import { listOrgUsers, type OrgUser } from '@/features/settings/settings-api'
import { useSessionStore } from '@/shared/session/session-store'
import { WorkspaceBoundary } from '@/shared/workflows/workspace-boundary'
import { TablePagination } from '@/design-system'
import { planningRoutes, planningVans } from './field-planning-lookups'

export function RouteExecutionsPage() {
  return <WorkspaceBoundary roles={['OWNER', 'ADMIN', 'OPERATOR']}><ExecutionsDirectory /></WorkspaceBoundary>
}
function ExecutionsDirectory() {
  const user = useSessionStore((s) => s.user!)
  const [page, setPage] = useState(0)
  const [isStartOpen, setIsStartOpen] = useState(false)
  const queryClient = useQueryClient()

  const { data: pageData, isLoading, isError } = useQuery({
    queryKey: ['field-sales', user.orgId, 'executions', page],
    queryFn: () => listExecutions(page),
  })
  const routesQuery = useQuery({ queryKey: ['field-sales', user.orgId, 'routes', 'picker'], queryFn: planningRoutes })
  const vansQuery = useQuery({ queryKey: ['field-sales', user.orgId, 'vans', 'picker'], queryFn: planningVans })
  const usersQuery = useQuery({
    queryKey: ['field-sales', user.orgId, 'users', 'picker'],
    queryFn: listOrgUsers,
    enabled: ['OWNER', 'ADMIN'].includes(user.role),
  })

  const executions: RouteExecution[] = pageData?.content ?? []
  const routeLabel = (execution: RouteExecution) => execution.routeName
    || routesQuery.data?.find((route) => route.id === execution.routeId)?.name
    || 'Route name unavailable'
  const salespersonLabel = (execution: RouteExecution) => execution.salespersonName
    || (execution.salespersonId === user.id ? user.fullName || user.email : usersQuery.data?.find((entry) => entry.id === execution.salespersonId)?.fullName)
    || 'Salesperson name unavailable'
  const vanLabel = (execution: RouteExecution) => execution.vanCode
    || vansQuery.data?.find((van) => van.id === execution.vanId)?.code
    || (execution.vanId ? 'Van name unavailable' : 'No van')

  const startMutation = useMutation({
    mutationFn: (payload: { routeId: string; salespersonId: string; vanId?: string; executionDate: string; overrideReason?: string }) => startExecution(payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['field-sales'] })
      setIsStartOpen(false)
    },
  })

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <Button onClick={() => setIsStartOpen(true)} type="button" variant="primary">
            <Play aria-hidden="true" size={16} />
            <span>Start Route Run</span>
          </Button>
        }
        description="Daily van sales & salesperson route runs, customer stop progression, and on-spot orders."
        eyebrow="Field Sales Execution"
        title="Route Executions"
      />

      <div className="summary-strip">
        <div className="metric-cell">
          <span className="metric-label">Runs on this page</span>
          <strong className="metric-value">{executions.length}</strong>
        </div>
        <div className="metric-cell">
          <span className="metric-label">Orders Value</span>
          <strong className="metric-value">
            <Money amount={executions.reduce((acc: number, e: RouteExecution) => acc + Number(e.totalOrdersValue || 0), 0)} />
          </strong>
        </div>
        <div className="metric-cell">
          <span className="metric-label">Collections</span>
          <strong className="metric-value">
            <Money amount={executions.reduce((acc: number, e: RouteExecution) => acc + Number(e.totalCollections || 0), 0)} />
          </strong>
        </div>
      </div>

      <div className="table-card">
        {isLoading ? (
          <div className="directory-state">Loading route executions...</div>
        ) : isError || routesQuery.isError || vansQuery.isError || usersQuery.isError ? (
          <div className="directory-state directory-state--error">Failed to load route executions.</div>
        ) : executions.length === 0 ? (
          <div className="directory-state">
            <Navigation aria-hidden="true" size={32} />
            <p>No route runs executed yet. Start a route execution run for today.</p>
          </div>
        ) : (
          <DataTable caption="Route Executions Log">
            <thead>
              <tr>
                <th scope="col">Execution Date</th>
                <th scope="col">Route & Beat</th>
                <th scope="col">Salesperson</th>
                <th scope="col">Van</th>
                <th scope="col" style={{ textAlign: 'right' }}>Stops Visited</th>
                <th scope="col" style={{ textAlign: 'right' }}>Orders Value</th>
                <th scope="col" style={{ textAlign: 'right' }}>Cash / UPI</th>
                <th scope="col">Status</th>
              </tr>
            </thead>
            <tbody>
              {executions.map((e: RouteExecution) => (
                <tr key={e.id}>
                  <td>
                    <Link className="table-link" to={`/field-sales/executions/${e.id}`}>
                      <strong>{formatDate(e.executionDate)}</strong>
                    </Link>
                  </td>
                  <td>{routeLabel(e)}</td>
                  <td>{salespersonLabel(e)}</td>
                  <td>{vanLabel(e)}</td>
                  <td style={{ textAlign: 'right' }}>
                    {e.completedVisits ?? 0} / {e.plannedVisits ?? 0}
                  </td>
                  <td style={{ textAlign: 'right' }}>
                    <strong><Money amount={e.totalOrdersValue ?? 0} /></strong>
                  </td>
                  <td style={{ textAlign: 'right' }}>
                    <Money amount={e.totalCollections ?? 0} />
                  </td>
                  <td><StatusChip status={e.status} /></td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        )}
      </div>

      {pageData && <TablePagination page={page} totalPages={pageData.totalPages} totalElements={pageData.totalElements} onPageChange={setPage} itemLabel="execution" />}
      {isStartOpen ? (
        <StartExecutionModal
          error={startMutation.error?.message}
          isPending={startMutation.isPending}
          onClose={() => { if (!startMutation.isPending) setIsStartOpen(false) }}
          onSubmit={(payload) => startMutation.mutate(payload)}
        />
      ) : null}
    </section>
  )
}

function StartExecutionModal({
  onClose,
  onSubmit,
  isPending,
  error,
}: {
  onClose: () => void
  onSubmit: (payload: { routeId: string; salespersonId: string; vanId?: string; executionDate: string; overrideReason?: string }) => void
  isPending: boolean
  error?: string
}) {
  const user = useSessionStore((s) => s.user!)
  const admin = ['OWNER', 'ADMIN'].includes(user.role)
  const [routeId, setRouteId] = useState('')
  const [salespersonId, setSalespersonId] = useState(admin ? '' : user.id)
  const [vanId, setVanId] = useState('')
  const [executionDate, setExecutionDate] = useState(() => { const now = new Date(); return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}` })
  const [overrideReason, setOverrideReason] = useState('')

  const routesQuery = useQuery({
    queryKey: ['field-sales', user.orgId, 'routes', 'picker'],
    queryFn: planningRoutes,
  })

  const vansQuery = useQuery({
    queryKey: ['field-sales', user.orgId, 'vans', 'picker'],
    queryFn: planningVans,
  })

  const usersQuery = useQuery({
    queryKey: ['field-sales', user.orgId, 'users', 'picker'],
    queryFn: listOrgUsers,
    enabled: admin,
  })
  const assignments = useQuery({ queryKey: ['field-sales', user.orgId, 'my-assignments', executionDate], queryFn: () => getMyAssignments(executionDate), enabled: !admin && !!executionDate })
  const allowedRoutes = admin ? routesQuery.data ?? [] : (routesQuery.data ?? []).filter((route) => assignments.data?.some((assignment) => assignment.routeId === route.id))
  const eligible = !!routeId && !!salespersonId && !!executionDate && (admin || allowedRoutes.some((route) => route.id === routeId))

  return (
    <Modal
      error={error ?? routesQuery.error?.message ?? vansQuery.error?.message ?? usersQuery.error?.message ?? assignments.error?.message}
      description="Create a planned run. Starting the route is a separate action on its detail page."
      footer={
        <>
          <Button disabled={isPending} onClick={onClose} type="button" variant="secondary">Cancel</Button>
          <Button disabled={isPending || !eligible} form="start-exec-form" type="submit" variant="primary">
            {isPending ? 'Starting Run...' : 'Start Execution Run'}
          </Button>
        </>
      }
      isOpen
      onClose={onClose}
      size="md"
      title="Start Route Execution"
    >
      <form
        id="start-exec-form"
        onSubmit={(e) => {
          e.preventDefault()
          if (!eligible || isPending) return
          onSubmit({
            routeId,
            salespersonId,
            vanId: vanId || undefined,
            executionDate,
            ...(admin && overrideReason.trim() ? { overrideReason: overrideReason.trim() } : {}),
          })
        }}
        style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}
      >
        <FormField label="Select Route" required>
          <EntityPicker<RouteSummary>
            value={routeId || null}
            onChange={(id) => { setRouteId(id || ''); setVanId(!admin ? assignments.data?.find((a) => a.routeId === id)?.vanId ?? '' : '') }}
            options={allowedRoutes}
            getOptionId={(r) => r.id}
            getOptionLabel={(r) => r.name}
            getOptionDescription={(r) => r.code ? `Code: ${r.code}` : undefined}
            getOptionBadge={(r) => r.dayOfWeek || undefined}
            placeholder="Search scheduled route by name..."
          />
        </FormField>

        {admin ? <FormField label="Assigned Salesperson" required>
          <EntityPicker<OrgUser>
            value={salespersonId || null}
            onChange={(id) => setSalespersonId(id || '')}
            options={(usersQuery.data ?? []).filter((entry) => entry.active)}
            getOptionId={(e) => e.id}
            getOptionLabel={(e) => e.fullName || e.email}
            getOptionDescription={(e) => `${e.email} / ${e.role}`}
            placeholder="Search salesperson by name or code..."
          />
        </FormField> : <p>Assigned salesperson: {user.fullName || user.email}</p>}

        <FormField label="Assigned Van (Optional)">
          <EntityPicker<Van>
            value={vanId || null}
            onChange={(id) => setVanId(id || '')}
            options={admin ? vansQuery.data ?? [] : (vansQuery.data ?? []).filter((van) => assignments.data?.some((a) => a.routeId === routeId && a.vanId === van.id))}
            getOptionId={(v) => v.id}
            getOptionLabel={(v) => `${v.vehicleNumber} (${v.code})`}
            getOptionDescription={(v) => v.name || undefined}
            placeholder="Search delivery van by vehicle number..."
          />
        </FormField>
        {admin && <FormField label="Admin override reason (only if unassigned or using a different van)"><TextInput value={overrideReason} onChange={(e) => setOverrideReason(e.target.value)} /></FormField>}

        <FormField label="Execution Date" required>
          <TextInput
            onChange={(e) => setExecutionDate(e.target.value)}
            required
            type="date"
            value={executionDate}
          />
        </FormField>
      </form>
    </Modal>
  )
}
