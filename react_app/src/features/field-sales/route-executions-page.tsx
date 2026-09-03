import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Link } from 'react-router-dom'
import {
  Navigation,
  Play,
  X,
} from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate } from '@/shared/format/format'
import {
  listExecutions,
  startExecution,
  type RouteExecution,
} from '@/features/field-sales/field-sales-api'

export function RouteExecutionsPage() {
  const [isStartOpen, setIsStartOpen] = useState(false)
  const queryClient = useQueryClient()

  const { data: pageData, isLoading, isError } = useQuery({
    queryKey: ['field-sales', 'executions'],
    queryFn: () => listExecutions(),
  })

  const executions: RouteExecution[] = pageData?.content ?? []

  const startMutation = useMutation({
    mutationFn: startExecution,
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

  return (
    <div className="modal-backdrop">
      <div className="modal-card" style={{ maxWidth: 440 }}>
        <div className="modal-header">
          <h2 className="modal-title">Start Route Execution</h2>
          <button aria-label="Close" className="button button--ghost" onClick={onClose} type="button">
            <X aria-hidden="true" size={18} />
          </button>
        </div>

        <form
          onSubmit={(e) => {
            e.preventDefault()
            onSubmit({
              routeId,
              salespersonId,
              vanId: vanId || undefined,
              executionDate,
            })
          }}
        >
          <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            <div>
              <label className="form-label" htmlFor="exec-route-id">Route ID *</label>
              <input
                className="form-input"
                id="exec-route-id"
                onChange={(e) => setRouteId(e.target.value)}
                placeholder="Route UUID"
                required
                type="text"
                value={routeId}
              />
            </div>

            <div>
              <label className="form-label" htmlFor="exec-salesperson">Salesperson ID *</label>
              <input
                className="form-input"
                id="exec-salesperson"
                onChange={(e) => setSalespersonId(e.target.value)}
                placeholder="Salesperson User UUID"
                required
                type="text"
                value={salespersonId}
              />
            </div>

            <div>
              <label className="form-label" htmlFor="exec-van">Van ID (Optional)</label>
              <input
                className="form-input"
                id="exec-van"
                onChange={(e) => setVanId(e.target.value)}
                placeholder="Assigned Van UUID"
                type="text"
                value={vanId}
              />
            </div>

            <div>
              <label className="form-label" htmlFor="exec-date">Execution Date</label>
              <input
                className="form-input"
                id="exec-date"
                onChange={(e) => setExecutionDate(e.target.value)}
                type="date"
                value={executionDate}
              />
            </div>
          </div>

          <div className="modal-footer" style={{ display: 'flex', justifyContent: 'flex-end', gap: 8, marginTop: 16 }}>
            <Button onClick={onClose} type="button" variant="secondary">Cancel</Button>
            <Button disabled={isPending || !routeId || !salespersonId} type="submit" variant="primary">
              {isPending ? 'Starting...' : 'Launch Execution'}
            </Button>
          </div>
        </form>
      </div>
    </div>
  )
}
