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
  listRoutes,
  listVans,
  startExecution,
  type RouteExecution,
  type RouteSummary,
  type Van,
} from '@/features/field-sales/field-sales-api'
import { listEmployees, type Employee } from '@/features/payroll/payroll-api'

export function RouteExecutionsPage() {
  const [isStartOpen, setIsStartOpen] = useState(false)
  const queryClient = useQueryClient()

  const { data: pageData, isLoading, isError } = useQuery({
    queryKey: ['field-sales', 'executions'],
    queryFn: () => listExecutions(),
  })

  const executions: RouteExecution[] = pageData?.content ?? []

  const startMutation = useMutation({
    mutationFn: (payload: { routeId: string; salespersonId: string; vanId?: string; executionDate: string }) => startExecution(payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['field-sales', 'executions'] })
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
          <span className="metric-label">Runs Recorded</span>
          <strong className="metric-value">{executions.length}</strong>
        </div>
        <div className="metric-cell">
          <span className="metric-label">Orders Value</span>
          <strong className="metric-value">
            <Money amount={executions.reduce((acc: number, e: RouteExecution) => acc + Number(e.totalOrderValue || 0), 0)} />
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
        ) : isError ? (
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
                  <td>{e.routeName || 'Direct Beat Run'}</td>
                  <td>{e.salespersonName || 'Assigned Agent'}</td>
                  <td>{e.vanCode || 'No Van'}</td>
                  <td style={{ textAlign: 'right' }}>
                    {e.completedVisits ?? 0} / {e.totalVisits ?? 0}
                  </td>
                  <td style={{ textAlign: 'right' }}>
                    <strong><Money amount={e.totalOrderValue ?? 0} /></strong>
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

      {isStartOpen ? (
        <StartExecutionModal
          isPending={startMutation.isPending}
          onClose={() => setIsStartOpen(false)}
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
}: {
  onClose: () => void
  onSubmit: (payload: { routeId: string; salespersonId: string; vanId?: string; executionDate: string }) => void
  isPending: boolean
}) {
  const [routeId, setRouteId] = useState('')
  const [salespersonId, setSalespersonId] = useState('')
  const [vanId, setVanId] = useState('')
  const [executionDate, setExecutionDate] = useState(new Date().toISOString().slice(0, 10))

  const routesQuery = useQuery({
    queryKey: ['field-sales', 'routes', 'picker'],
    queryFn: () => listRoutes(0, 100),
  })

  const vansQuery = useQuery({
    queryKey: ['field-sales', 'vans', 'picker'],
    queryFn: () => listVans(0, 100),
  })

  const employeesQuery = useQuery({
    queryKey: ['employees', 'picker'],
    queryFn: () => listEmployees(0, 100),
  })

  return (
    <Modal
      description="Dispatch a van or field rep on a scheduled route run."
      footer={
        <>
          <Button onClick={onClose} type="button" variant="secondary">Cancel</Button>
          <Button disabled={isPending || !routeId || !salespersonId} form="start-exec-form" type="submit" variant="primary">
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
          if (!routeId || !salespersonId) return
          onSubmit({
            routeId,
            salespersonId,
            vanId: vanId || undefined,
            executionDate,
          })
        }}
        style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}
      >
        <FormField label="Select Route" required>
          <EntityPicker<RouteSummary>
            value={routeId || null}
            onChange={(id) => setRouteId(id || '')}
            options={routesQuery.data?.content || []}
            getOptionId={(r) => r.id}
            getOptionLabel={(r) => r.name}
            getOptionDescription={(r) => r.code ? `Code: ${r.code}` : undefined}
            getOptionBadge={(r) => r.dayOfWeek || undefined}
            placeholder="Search scheduled route by name..."
          />
        </FormField>

        <FormField label="Assigned Salesperson" required>
          <EntityPicker<Employee>
            value={salespersonId || null}
            onChange={(id) => setSalespersonId(id || '')}
            options={employeesQuery.data?.content || []}
            getOptionId={(e) => e.id}
            getOptionLabel={(e) => `${e.fullName}${e.employeeCode ? ` (${e.employeeCode})` : ''}`}
            getOptionDescription={(e) => e.designation || e.department || undefined}
            placeholder="Search salesperson by name or code..."
          />
        </FormField>

        <FormField label="Assigned Van (Optional)">
          <EntityPicker<Van>
            value={vanId || null}
            onChange={(id) => setVanId(id || '')}
            options={vansQuery.data?.content || []}
            getOptionId={(v) => v.id}
            getOptionLabel={(v) => `${v.vehicleNumber} (${v.code})`}
            getOptionDescription={(v) => v.name || undefined}
            placeholder="Search delivery van by vehicle number..."
          />
        </FormField>

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
