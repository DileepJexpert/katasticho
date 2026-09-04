import { useState } from 'react'
import { useQuery, useMutation } from '@tanstack/react-query'
import {
    AlertTriangle,
  Calendar,
  Sparkles,
  ShieldCheck,
  RefreshCw,
} from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate } from '@/shared/format/format'
import {
  get13WeekCashRunway,
  simulateCashRunway,
} from '@/features/analytics/analytics-api'

export function CashRunwayPage() {
  const [asOfDate, setAsOfDate] = useState(new Date().toISOString().slice(0, 10))
  const [isSimulateOpen, setIsSimulateOpen] = useState(false)
  const [inflowPct, setInflowPct] = useState('100')
  const [outflowPct, setOutflowPct] = useState('100')

  const query = useQuery({
    queryKey: ['cash-runway', asOfDate],
    queryFn: () => get13WeekCashRunway(asOfDate),
  })

  const simulateMutation = useMutation({
    mutationFn: () => simulateCashRunway({
      asOfDate,
      inflowMultiplier: Number(inflowPct) / 100,
      outflowMultiplier: Number(outflowPct) / 100,
    }),
  })

  const report = simulateMutation.data || query.data

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Treasury / Liquidity Intelligence"
        title="13-Week Rolling Cash Runway"
        description="Predictive cash flow modeling, working capital stress testing, deficit week alerts, and liquidity buffer analytics."
        actions={
          <div className="table-actions">
            <Button onClick={() => setIsSimulateOpen(true)} variant="secondary">
              <Sparkles size={15} />
              Stress Test Scenario
            </Button>
            <Button onClick={() => query.refetch()} variant="secondary">
              <RefreshCw size={15} />
              Refresh
            </Button>
          </div>
        }
      />

      {/* Top Metrics Cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '16px', marginBottom: '16px' }}>
        <div style={{ background: 'var(--bg-card)', padding: '14px 16px', borderRadius: '6px', border: '1px solid var(--border-subtle)' }}>
          <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Current Liquid Cash</span>
          <div style={{ fontSize: '22px', fontWeight: 600, color: 'var(--color-primary)', marginTop: '4px' }}>
            <Money amount={report?.currentLiquidCash ?? 0} />
          </div>
        </div>

        <div style={{ background: 'var(--bg-card)', padding: '14px 16px', borderRadius: '6px', border: '1px solid var(--border-subtle)' }}>
          <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Estimated Runway</span>
          <div style={{ fontSize: '22px', fontWeight: 600, marginTop: '4px', color: (report?.runwayWeeks ?? 13) < 4 ? 'var(--color-danger)' : 'var(--color-success)' }}>
            {(report?.runwayWeeks ?? 13).toFixed(1)} Weeks
          </div>
        </div>

        <div style={{ background: 'var(--bg-card)', padding: '14px 16px', borderRadius: '6px', border: '1px solid var(--border-subtle)' }}>
          <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>13-Week Net Cash Flow</span>
          <div style={{ fontSize: '22px', fontWeight: 600, marginTop: '4px', color: (report?.netChange13W ?? 0) >= 0 ? 'var(--color-success)' : 'var(--color-danger)' }}>
            <Money amount={report?.netChange13W ?? 0} />
          </div>
        </div>

        <div style={{ background: 'var(--bg-card)', padding: '14px 16px', borderRadius: '6px', border: '1px solid var(--border-subtle)' }}>
          <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Safety Buffer Target</span>
          <div style={{ fontSize: '22px', fontWeight: 600, marginTop: '4px' }}>
            <Money amount={report?.safetyBufferAmount ?? 0} />
          </div>
        </div>
      </div>

      {/* Deficit Alert Banner */}
      {report?.deficitAlerts && report.deficitAlerts.length > 0 && (
        <div style={{ background: 'var(--bg-danger-subtle)', border: '1px solid var(--border-danger)', borderRadius: '6px', padding: '12px 16px', marginBottom: '16px', display: 'flex', gap: '12px', alignItems: 'center' }}>
          <AlertTriangle color="var(--color-danger)" size={20} />
          <div>
            <strong style={{ color: 'var(--color-danger)' }}>Liquidity Deficit Warning:</strong>
            <span style={{ marginLeft: '6px', fontSize: '13px' }}>
              {report.deficitAlerts.join(' · ')}
            </span>
          </div>
        </div>
      )}

      {/* 13-Week Table */}
      <section className="document-card">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '14px' }}>
          <div>
            <h2>Weekly Liquidity Schedule</h2>
            <p style={{ fontSize: '13px', color: 'var(--text-muted)' }}>
              Week-by-week cash receipts vs disbursements breakdown.
            </p>
          </div>
          <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
            <Calendar size={16} />
            <span style={{ fontSize: '13px', color: 'var(--text-muted)' }}>As of:</span>
            <input
              className="search-input"
              onChange={(e) => setAsOfDate(e.target.value)}
              style={{ width: '130px' }}
              type="date"
              value={asOfDate}
            />
          </div>
        </div>

        {query.isLoading ? (
          <div className="directory-state">Computing 13-week cash runway...</div>
        ) : !report?.weeklyBuckets || report.weeklyBuckets.length === 0 ? (
          <div className="directory-state">
            <ShieldCheck size={24} />
            <strong>No cash transactions recorded for projection.</strong>
          </div>
        ) : (
          <DataTable caption="13-week cash runway schedule">
            <thead>
              <tr>
                <th scope="col">Week</th>
                <th scope="col">Date Range</th>
                <th className="numeric-cell" scope="col">Opening Cash</th>
                <th className="numeric-cell" scope="col">Projected Inflows</th>
                <th className="numeric-cell" scope="col">Projected Outflows</th>
                <th className="numeric-cell" scope="col">Net Weekly Δ</th>
                <th className="numeric-cell" scope="col">Closing Cash Balance</th>
                <th scope="col">Status</th>
              </tr>
            </thead>
            <tbody>
              {report.weeklyBuckets.map((b) => (
                <tr key={b.weekNumber} style={b.isDeficit ? { background: 'var(--bg-danger-subtle)' } : undefined}>
                  <td className="cell-id"><strong>Week {b.weekNumber}</strong></td>
                  <td>{formatDate(b.startDate)} → {formatDate(b.endDate)}</td>
                  <td className="numeric-cell"><Money amount={b.openingCash} /></td>
                  <td className="numeric-cell" style={{ color: 'var(--color-success)' }}>
                    +<Money amount={b.totalInflow} />
                  </td>
                  <td className="numeric-cell" style={{ color: 'var(--color-danger)' }}>
                    -<Money amount={b.totalOutflow} />
                  </td>
                  <td className="numeric-cell" style={{ fontWeight: 600, color: b.netChange >= 0 ? 'var(--color-success)' : 'var(--color-danger)' }}>
                    <Money amount={b.netChange} />
                  </td>
                  <td className="numeric-cell" style={{ fontWeight: 600, color: b.closingCash < (report.safetyBufferAmount || 0) ? 'var(--color-warning)' : undefined }}>
                    <Money amount={b.closingCash} />
                  </td>
                  <td>
                    <StatusChip status={b.isDeficit ? 'DEFICIT' : 'SURPLUS'} />
                  </td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        )}
      </section>

      {/* Scenario Simulation Modal */}
      {isSimulateOpen && (
        <div className="modal-backdrop">
          <div className="modal-card">
            <h3>Simulate Stress Test Scenario</h3>
            <p style={{ fontSize: '13px', color: 'var(--text-muted)' }}>
              Test how changes in collection velocity or increased vendor expenditures impact total runway.
            </p>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '14px', marginTop: '14px' }}>
              <label>
                <span style={{ fontSize: '13px', fontWeight: 600 }}>Inflow Realization Rate (%):</span>
                <input
                  className="search-input"
                  onChange={(e) => setInflowPct(e.target.value)}
                  style={{ width: '100%', marginTop: '4px' }}
                  type="number"
                  value={inflowPct}
                />
                <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>e.g. 80% if collections slow down.</span>
              </label>

              <label>
                <span style={{ fontSize: '13px', fontWeight: 600 }}>Outflow Expense Multiplier (%):</span>
                <input
                  className="search-input"
                  onChange={(e) => setOutflowPct(e.target.value)}
                  style={{ width: '100%', marginTop: '4px' }}
                  type="number"
                  value={outflowPct}
                />
                <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>e.g. 115% for unplanned overhead spikes.</span>
              </label>
            </div>

            <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end', marginTop: '18px' }}>
              <Button onClick={() => setIsSimulateOpen(false)} variant="secondary">Cancel</Button>
              <Button
                disabled={simulateMutation.isPending}
                onClick={() => {
                  simulateMutation.mutate()
                  setIsSimulateOpen(false)
                }}
                variant="primary"
              >
                Run Simulation
              </Button>
            </div>
          </div>
        </div>
      )}
    </section>
  )
}
