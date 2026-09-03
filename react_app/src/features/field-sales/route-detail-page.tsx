import { useNavigate, useParams } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import {
  ArrowLeft,
  Navigation,
} from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import {
  getRoute,
  getRouteBeats,
  type RouteBeat,
} from '@/features/field-sales/field-sales-api'

export function RouteDetailPage() {
  const { routeId = '' } = useParams()
  const navigate = useNavigate()

  const { data: route, isLoading, isError } = useQuery({
    queryKey: ['field-sales', 'routes', routeId],
    queryFn: () => getRoute(routeId),
    enabled: !!routeId,
  })

  const { data: beats = [] } = useQuery({
    queryKey: ['field-sales', 'routes', routeId, 'beats'],
    queryFn: () => getRouteBeats(routeId),
    enabled: !!routeId,
  })

  if (isLoading) return <div className="directory-state">Loading sales route details...</div>
  if (isError || !route) return <DocumentError onBack={() => navigate('/routes')} />

  return (
    <section className="workspace-page">
      <PageHeader
        actions={null}
        description={`Day: ${route.dayOfWeek || 'All Days'} | Frequency: ${route.frequency || 'WEEKLY'}`}
        eyebrow="Sales Route Profile"
        title={`${route.code} â€” ${route.name}`}
      />

      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 16 }}>
        <button className="button button--ghost" onClick={() => navigate('/routes')} type="button">
          <ArrowLeft aria-hidden="true" size={16} />
          <span>Back to Routes</span>
        </button>
      </div>

      <div className="summary-strip">
        <div className="metric-cell">
          <span className="metric-label">Route Code</span>
          <strong className="metric-value">{route.code}</strong>
        </div>
        <div className="metric-cell">
          <span className="metric-label">Included Beats</span>
          <strong className="metric-value">{beats.length}</strong>
        </div>
        <div className="metric-cell">
          <span className="metric-label">Status</span>
          <strong className="metric-value"><StatusChip status={route.active ? 'ACTIVE' : 'INACTIVE'} /></strong>
        </div>
      </div>

      <div className="table-card">
        <div className="card-header" style={{ padding: '16px 20px', borderBottom: '1px solid var(--k-color-border)' }}>
          <h3 style={{ margin: 0, fontSize: '1rem', fontWeight: 600 }}>Scheduled Beats in Route Sequence</h3>
        </div>

        {beats.length === 0 ? (
          <div className="directory-state">
            <Navigation aria-hidden="true" size={32} />
            <p>No beats mapped to this route line.</p>
          </div>
        ) : (
          <DataTable caption="Route Scheduled Beats">
            <thead>
              <tr>
                <th scope="col" style={{ width: 80 }}>Seq #</th>
                <th scope="col">Beat Code</th>
                <th scope="col">Beat Name</th>
              </tr>
            </thead>
            <tbody>
              {beats.map((b: RouteBeat) => (
                <tr key={b.id}>
                  <td><strong>#{b.sequence}</strong></td>
                  <td><strong>{b.beatCode || 'BEAT'}</strong></td>
                  <td>{b.beatName || 'Beat Run'}</td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        )}
      </div>
    </section>
  )
}

function DocumentError({ onBack }: { onBack: () => void }) {
  return (
    <section className="workspace-page">
      <div className="directory-state directory-state--error" role="alert">
        <Navigation aria-hidden="true" size={24} />
        <p>Sales route could not be found or loaded.</p>
        <Button onClick={onBack} type="button" variant="secondary">Return to Routes</Button>
      </div>
    </section>
  )
}
