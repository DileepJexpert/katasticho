import { useMemo, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import {
  ArrowLeft,
  Calendar,
  FileSpreadsheet,
  FileText,
  RefreshCw,
  Search,
} from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate } from '@/shared/format/format'
import {
  getOperationalReport,
  reportCatalog,
  type ColumnDef,
} from '@/features/reports/reports-api'

export function ReportViewerPage() {
  const { reportKey } = useParams<{ reportKey: string }>()
  const navigate = useNavigate()

  const catalogEntry = useMemo(
    () => reportCatalog.find((r) => r.key === reportKey),
    [reportKey]
  )

  const defaultDates = useMemo(() => {
    const now = new Date()
    const firstDay = new Date(now.getFullYear(), now.getMonth(), 1)
    return {
      start: firstDay.toISOString().split('T')[0] || '',
      end: now.toISOString().split('T')[0] || '',
      asOf: now.toISOString().split('T')[0] || '',
    }
  }, [])

  const [startDate, setStartDate] = useState(defaultDates.start)
  const [endDate, setEndDate] = useState(defaultDates.end)
  const [asOfDate, setAsOfDate] = useState(defaultDates.asOf)
  const [searchTerm, setSearchTerm] = useState('')

  const query = useQuery({
    queryKey: [
      'report-data',
      reportKey,
      catalogEntry?.hasDateRange ? startDate : undefined,
      catalogEntry?.hasDateRange ? endDate : undefined,
      catalogEntry?.hasAsOfDate ? asOfDate : undefined,
    ],
    queryFn: () => {
      if (!catalogEntry) throw new Error('Report not found')
      return getOperationalReport(
        catalogEntry.endpoint,
        catalogEntry.hasDateRange ? startDate : undefined,
        catalogEntry.hasDateRange ? endDate : undefined,
        catalogEntry.hasAsOfDate ? asOfDate : undefined
      )
    },
    enabled: Boolean(catalogEntry),
  })

  const reportData = query.data
  const columns: ColumnDef[] = reportData?.columns ?? []
  const rows = reportData?.rows ?? []
  const metrics = reportData?.metrics ?? []

  const filteredRows = useMemo(() => {
    if (!searchTerm.trim()) return rows
    const term = searchTerm.toLowerCase().trim()
    return rows.filter((row) =>
      Object.values(row).some((val) =>
        String(val ?? '').toLowerCase().includes(term)
      )
    )
  }, [rows, searchTerm])

  if (!catalogEntry) {
    return (
      <section className="workspace-page">
        <div className="directory-state directory-state--error" role="alert">
          <FileText aria-hidden="true" size={24} />
          <strong>Report definition not found.</strong>
          <p>The requested report key is not recognized in the standard catalog.</p>
          <Button onClick={() => navigate(appRoutes.reports)} variant="secondary">
            <ArrowLeft aria-hidden="true" size={16} />
            Back to Reports Hub
          </Button>
        </div>
      </section>
    )
  }

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Intelligence / Report Viewer"
        title={reportData?.title || catalogEntry.title}
        description={reportData?.description || catalogEntry.description}
        actions={
          <div className="table-actions">
            <span className="status-badge">Key: {catalogEntry.key}</span>
            <StatusChip status="Live Query" />
          </div>
        }
      />

      <div className="document-actions">
        <Button onClick={() => navigate(appRoutes.reports)} variant="secondary">
          <ArrowLeft aria-hidden="true" size={16} />
          Back to Reports Hub
        </Button>
      </div>

      {/* Filter / Date Parameter Controls */}
      <div
        style={{
          display: 'flex',
          flexWrap: 'wrap',
          alignItems: 'center',
          gap: '1rem',
          padding: '1rem',
          backgroundColor: 'var(--k-color-surface-card)',
          border: '1px solid var(--k-color-border-subtle)',
          borderRadius: '8px',
        }}
      >
        {catalogEntry.hasDateRange ? (
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            <Calendar aria-hidden="true" size={16} />
            <label style={{ fontSize: '0.85rem', fontWeight: 500 }}>
              From:
              <input
                onChange={(e) => setStartDate(e.target.value)}
                style={{
                  marginLeft: 6,
                  padding: '0.35rem 0.6rem',
                  borderRadius: 4,
                  border: '1px solid var(--k-color-border-subtle)',
                  background: 'inherit',
                  color: 'inherit',
                }}
                type="date"
                value={startDate}
              />
            </label>
            <label style={{ fontSize: '0.85rem', fontWeight: 500, marginLeft: 8 }}>
              To:
              <input
                onChange={(e) => setEndDate(e.target.value)}
                style={{
                  marginLeft: 6,
                  padding: '0.35rem 0.6rem',
                  borderRadius: 4,
                  border: '1px solid var(--k-color-border-subtle)',
                  background: 'inherit',
                  color: 'inherit',
                }}
                type="date"
                value={endDate}
              />
            </label>
          </div>
        ) : null}

        {catalogEntry.hasAsOfDate ? (
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            <Calendar aria-hidden="true" size={16} />
            <label style={{ fontSize: '0.85rem', fontWeight: 500 }}>
              As of Date:
              <input
                onChange={(e) => setAsOfDate(e.target.value)}
                style={{
                  marginLeft: 6,
                  padding: '0.35rem 0.6rem',
                  borderRadius: 4,
                  border: '1px solid var(--k-color-border-subtle)',
                  background: 'inherit',
                  color: 'inherit',
                }}
                type="date"
                value={asOfDate}
              />
            </label>
          </div>
        ) : null}

        <Button onClick={() => query.refetch()} variant="secondary">
          <RefreshCw aria-hidden="true" size={14} /> Refresh
        </Button>

        <div style={{ marginLeft: 'auto' }}>
          <div className="search-field" style={{ minWidth: 240 }}>
            <Search aria-hidden="true" size={16} />
            <input
              aria-label="Filter report results"
              onChange={(e) => setSearchTerm(e.target.value)}
              placeholder="Search table rows..."
              type="search"
              value={searchTerm}
            />
          </div>
        </div>
      </div>

      {/* Summary Metrics */}
      {metrics.length > 0 ? (
        <div className="summary-strip">
          {metrics.map((metric) => (
            <div className="summary-card" key={metric.key}>
              <span className="summary-card__label">{metric.label}</span>
              <strong className="summary-card__value">
                {metric.format === 'MONEY' || metric.format === 'CURRENCY' ? (
                  <Money amount={metric.value} />
                ) : (
                  <Quantity value={metric.value} />
                )}
              </strong>
            </div>
          ))}
        </div>
      ) : null}

      {/* Main Report Table */}
      {query.isLoading ? (
        <div aria-live="polite" className="directory-state">
          Executing database ledger query...
        </div>
      ) : query.isError ? (
        <div className="directory-state directory-state--error" role="alert">
          <FileText aria-hidden="true" size={24} />
          <strong>Unable to load report data.</strong>
          <p>Please verify your date parameters or organizational permissions.</p>
          <Button onClick={() => query.refetch()} variant="secondary">
            Retry
          </Button>
        </div>
      ) : filteredRows.length === 0 ? (
        <div className="directory-state">
          <FileSpreadsheet aria-hidden="true" size={24} />
          <strong>No matching records found for this period.</strong>
          <p>Try adjusting date range or removing search filters.</p>
        </div>
      ) : (
        <DataTable caption={reportData?.title || catalogEntry.title}>
          <thead>
            <tr>
              {columns.map((col) => (
                <th
                  className={
                    col.type === 'MONEY' || col.type === 'NUMBER' || col.type === 'PERCENT'
                      ? 'numeric-cell'
                      : undefined
                  }
                  key={col.key}
                  scope="col"
                >
                  {col.label}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {filteredRows.map((row, rowIdx) => (
              <tr key={rowIdx}>
                {columns.map((col) => {
                  const val = row[col.key]
                  return (
                    <td
                      className={
                        col.type === 'MONEY' || col.type === 'NUMBER' || col.type === 'PERCENT'
                          ? 'numeric-cell'
                          : undefined
                      }
                      key={col.key}
                    >
                      {renderCellContent(val, col.type)}
                    </td>
                  )
                })}
              </tr>
            ))}
          </tbody>
        </DataTable>
      )}
    </section>
  )
}

function renderCellContent(val: unknown, type?: string) {
  if (val === null || val === undefined || val === '') {
    return <span className="cell-muted">—</span>
  }
  if (type === 'MONEY') {
    return <Money amount={val as number | string} />
  }
  if (type === 'DATE') {
    return formatDate(String(val))
  }
  if (type === 'PERCENT') {
    return `${val}%`
  }
  if (type === 'NUMBER') {
    return <Quantity value={val as number} />
  }
  return String(val)
}
