import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import {
  getWipValuation,
  getWorkstationLoad,
  getTopBottlenecks,
  getScrapRateDashboard,
} from '@/features/manufacturing/manufacturing-reports-api'

export function ManufacturingReportsPage() {
  const [fromDate] = useState('2026-01-01')
  const [toDate] = useState('2026-12-31')

  const wipQuery = useQuery({
    queryKey: ['report-wip-valuation'],
    queryFn: getWipValuation,
  })

  const loadQuery = useQuery({
    queryKey: ['report-workstation-load'],
    queryFn: getWorkstationLoad,
  })

  const bottlenecksQuery = useQuery({
    queryKey: ['report-bottlenecks'],
    queryFn: () => getTopBottlenecks(5),
  })

  const scrapQuery = useQuery({
    queryKey: ['report-scrap', fromDate, toDate],
    queryFn: () => getScrapRateDashboard(fromDate, toDate),
  })

  const wip = wipQuery.data
  const loads = loadQuery.data ?? []
  const bottlenecks = bottlenecksQuery.data ?? []
  const scrap = scrapQuery.data

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Manufacturing / Analytics"
        title="Shop Floor & Production Analytics"
        description="WIP inventory valuation, workstation capacity utilization, production bottleneck identification, and scrap rates."
      />

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: '16px', marginBottom: '24px' }}>
        <div className="document-card document-card--summary">
          <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Total WIP Valuation</span>
          <h3 style={{ fontSize: '22px', margin: '6px 0' }}>
            {wip ? <Money amount={wip.totalWipValue} /> : '--'}
          </h3>
          <span className="cell-muted">{wip?.openWorkOrdersCount ?? 0} active work orders in flight</span>
        </div>

        <div className="document-card document-card--summary">
          <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Average Workstation Load</span>
          <h3 style={{ fontSize: '22px', margin: '6px 0' }}>
            {loads.length > 0
              ? `${Math.round(loads.reduce((acc, l) => acc + Number(l.utilizationPercent), 0) / loads.length)}%`
              : '--'}
          </h3>
          <span className="cell-muted">{loads.length} machine centers monitored</span>
        </div>

        <div className="document-card document-card--summary">
          <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Overall Scrap Loss</span>
          <h3 style={{ fontSize: '22px', margin: '6px 0', color: 'var(--color-danger)' }}>
            {scrap ? <Money amount={scrap.totalScrapCost} /> : '--'}
          </h3>
          <span className="cell-muted">{scrap?.overallScrapPercent ?? 0}% of raw materials scrapped</span>
        </div>
      </div>

      <div className="document-layout">
        <section className="document-card" style={{ flex: 1.5 }}>
          <h2>Machine Capacity Utilization & Load</h2>
          {loadQuery.isLoading ? (
            <div className="directory-state">Loading workstation loads...</div>
          ) : loads.length > 0 ? (
            <DataTable caption="Workstation capacity utilization">
              <thead>
                <tr>
                  <th scope="col">Station</th>
                  <th className="numeric-cell" scope="col">Capacity (h/day)</th>
                  <th className="numeric-cell" scope="col">Allocated Hours</th>
                  <th className="numeric-cell" scope="col">Utilization</th>
                </tr>
              </thead>
              <tbody>
                {loads.map((l) => (
                  <tr key={l.workstationId}>
                    <td>
                      <strong>{l.workstationName}</strong> (<code>{l.workstationCode}</code>)
                    </td>
                    <td className="numeric-cell">{l.dailyCapacityHours}h</td>
                    <td className="numeric-cell">{l.allocatedHours}h</td>
                    <td className="numeric-cell">
                      <span className={Number(l.utilizationPercent) > 90 ? 'text-danger' : undefined}>
                        {l.utilizationPercent}%
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          ) : (
            <div className="directory-state">No load telemetry.</div>
          )}
        </section>

        <section className="document-card" style={{ flex: 1 }}>
          <h2>Production Bottlenecks</h2>
          {bottlenecksQuery.isLoading ? (
            <div className="directory-state">Analyzing bottlenecks...</div>
          ) : bottlenecks.length > 0 ? (
            <DataTable caption="Top bottleneck workstations">
              <thead>
                <tr>
                  <th scope="col">Workstation</th>
                  <th className="numeric-cell" scope="col">Backlog Hours</th>
                </tr>
              </thead>
              <tbody>
                {bottlenecks.map((b) => (
                  <tr key={b.workstationId}>
                    <td><strong>{b.workstationName}</strong></td>
                    <td className="numeric-cell">
                      <span className="text-danger">{b.totalBacklogHours}h</span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          ) : (
            <div className="directory-state">No bottleneck constraints detected.</div>
          )}
        </section>
      </div>
    </section>
  )
}