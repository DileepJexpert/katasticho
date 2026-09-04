import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import {
  FileSpreadsheet,
  Search,
  Sparkles,
  RefreshCw,
  } from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { getFluxReport } from '@/features/analytics/analytics-api'

export function FluxCommentaryPage() {
  const [periodType, setPeriodType] = useState('MOM')
  const [minAmount] = useState('10000')
  const [minPercent] = useState('10')
  const [search, setSearch] = useState('')
  const [onlyMaterial, setOnlyMaterial] = useState(false)

  const query = useQuery({
    queryKey: ['flux-report', periodType, minAmount, minPercent],
    queryFn: () => getFluxReport({
      periodType,
      minMaterialAmount: Number(minAmount),
      minMaterialPercent: Number(minPercent),
    }),
  })

  const report = query.data
  const items = report?.items ?? []
  const filteredItems = items.filter((it) => {
    if (onlyMaterial && !it.isMaterial) return false
    if (!search.trim()) return true
    const q = search.toLowerCase()
    return it.accountCode.toLowerCase().includes(q) || it.accountName.toLowerCase().includes(q)
  })

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Financial Intelligence / Audit"
        title="Flux Commentary & Balance Sheet Variance"
        description="Month-over-Month (MoM) and Year-over-Year (YoY) variance detection with automated management commentary."
        actions={
          <div className="table-actions">
            <Button onClick={() => query.refetch()} variant="secondary">
              <RefreshCw size={15} />
              Re-analyze Flux
            </Button>
          </div>
        }
      />

      {/* Top Variance KPI strip */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '16px', marginBottom: '16px' }}>
        <div style={{ background: 'var(--bg-card)', padding: '14px 16px', borderRadius: '6px', border: '1px solid var(--border-subtle)' }}>
          <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Base Period Revenue</span>
          <div style={{ fontSize: '20px', fontWeight: 600, color: 'var(--color-primary)', marginTop: '4px' }}>
            <Money amount={report?.totalBaseRevenue ?? 0} />
          </div>
        </div>

        <div style={{ background: 'var(--bg-card)', padding: '14px 16px', borderRadius: '6px', border: '1px solid var(--border-subtle)' }}>
          <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Comparative Revenue</span>
          <div style={{ fontSize: '20px', fontWeight: 600, marginTop: '4px' }}>
            <Money amount={report?.totalCompRevenue ?? 0} />
          </div>
        </div>

        <div style={{ background: 'var(--bg-card)', padding: '14px 16px', borderRadius: '6px', border: '1px solid var(--border-subtle)' }}>
          <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Material Variances Detected</span>
          <div style={{ fontSize: '20px', fontWeight: 600, color: 'var(--color-warning)', marginTop: '4px' }}>
            {items.filter((i) => i.isMaterial).length} Accounts
          </div>
        </div>
      </div>

      {/* Automated Executive Summary */}
      {report?.summaryCommentary && (
        <div style={{ background: 'var(--bg-subtle)', border: '1px solid var(--border-subtle)', borderRadius: '6px', padding: '14px 16px', marginBottom: '16px', display: 'flex', gap: '12px', alignItems: 'flex-start' }}>
          <Sparkles color="var(--color-primary)" size={20} style={{ flexShrink: 0, marginTop: '2px' }} />
          <div>
            <strong>Automated Management Flux Commentary:</strong>
            <p style={{ margin: '4px 0 0 0', fontSize: '13px', lineHeight: 1.5 }}>
              {report.summaryCommentary}
            </p>
          </div>
        </div>
      )}

      {/* Filter Toolbar */}
      <div className="list-toolbar">
        <label className="directory-search">
          <Search aria-hidden="true" size={18} />
          <span className="sr-only">Search accounts</span>
          <input
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search by account code or name..."
            type="search"
            value={search}
          />
        </label>
        <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
          <select
            className="search-input"
            onChange={(e) => setPeriodType(e.target.value)}
            style={{ width: '140px' }}
            value={periodType}
          >
            <option value="MOM">Month-on-Month</option>
            <option value="YOY">Year-on-Year</option>
            <option value="QOQ">Quarter-on-Quarter</option>
          </select>

          <label style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '13px', cursor: 'pointer' }}>
            <input
              checked={onlyMaterial}
              onChange={(e) => setOnlyMaterial(e.target.checked)}
              type="checkbox"
            />
            <span>Material Only</span>
          </label>
        </div>
      </div>

      {query.isLoading ? (
        <div className="directory-state">Analyzing financial balance flux...</div>
      ) : filteredItems.length === 0 ? (
        <div className="directory-state">
          <FileSpreadsheet size={24} />
          <strong>No account balance variances match your filter.</strong>
        </div>
      ) : (
        <DataTable caption="Balance sheet and P&L flux items">
          <thead>
            <tr>
              <th scope="col">Account Code</th>
              <th scope="col">Account Name</th>
              <th scope="col">Type</th>
              <th className="numeric-cell" scope="col">{report?.basePeriodLabel || 'Base Period'}</th>
              <th className="numeric-cell" scope="col">{report?.compPeriodLabel || 'Comparative Period'}</th>
              <th className="numeric-cell" scope="col">Absolute Δ</th>
              <th className="numeric-cell" scope="col">Percentage Δ</th>
              <th scope="col">Variance Commentary</th>
            </tr>
          </thead>
          <tbody>
            {filteredItems.map((it) => (
              <tr key={it.accountCode} style={it.isMaterial ? { background: 'var(--bg-warning-subtle)' } : undefined}>
                <td className="font-mono"><strong>{it.accountCode}</strong></td>
                <td>{it.accountName}</td>
                <td><span className="status-badge status-badge--info">{it.accountType}</span></td>
                <td className="numeric-cell"><Money amount={it.baseBalance} /></td>
                <td className="numeric-cell"><Money amount={it.compBalance} /></td>
                <td className="numeric-cell" style={{ fontWeight: 600, color: it.absoluteChange >= 0 ? 'var(--color-success)' : 'var(--color-danger)' }}>
                  <Money amount={it.absoluteChange} />
                </td>
                <td className="numeric-cell" style={{ fontWeight: 600 }}>
                  {it.percentageChange > 0 ? `+${it.percentageChange.toFixed(1)}` : it.percentageChange.toFixed(1)}%
                </td>
                <td>
                  <span style={{ fontSize: '13px' }}>{it.commentary || (it.isMaterial ? 'Material balance swing.' : 'Normal periodic flux.')}</span>
                </td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      )}
    </section>
  )
}
