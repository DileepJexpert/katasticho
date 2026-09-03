import { useMemo, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { CheckCircle2, FileText, Search } from 'lucide-react'
import { Link } from 'react-router-dom'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import {
  getExpirySummary,
  getNearExpiryBatches,
} from '@/features/pharmacy/pharmacy-api'

export function NearExpiryPage() {
  const [daysThreshold, setDaysThreshold] = useState(90)
  const [urgencyFilter, setUrgencyFilter] = useState<string>('all')
  const [searchTerm, setSearchTerm] = useState('')

  const summaryQuery = useQuery({
    queryKey: ['expiry-summary'],
    queryFn: () => getExpirySummary(),
  })

  const batchesQuery = useQuery({
    queryKey: ['near-expiry-batches', daysThreshold],
    queryFn: () => getNearExpiryBatches(daysThreshold),
  })

  const summary = summaryQuery.data ?? {
    expired: 0,
    within7Days: 0,
    within30Days: 0,
    within90Days: 0,
  }

  const batches = batchesQuery.data ?? []

  const filteredBatches = useMemo(() => {
    let list = batches
    if (urgencyFilter !== 'all') {
      list = list.filter((b) => b.urgency === urgencyFilter)
    }
    const term = searchTerm.trim().toLowerCase()
    if (term) {
      list = list.filter(
        (b) =>
          b.itemName.toLowerCase().includes(term) ||
          b.batchNumber.toLowerCase().includes(term)
      )
    }
    return list
  }, [batches, urgencyFilter, searchTerm])

  const totalAtRiskUnits = useMemo(() => {
    return filteredBatches.reduce((sum, b) => sum + Number(b.quantityOnHand || 0), 0)
  }, [filteredBatches])

  const getUrgencyBadge = (urgency: string, days: number) => {
    switch (urgency) {
      case 'EXPIRED':
        return <StatusChip status="Expired" />
      case 'CRITICAL':
        return <StatusChip status={`Critical (${days}d)`} />
      case 'WARNING':
        return <StatusChip status={`Warning (${days}d)`} />
      case 'OK':
      default:
        return <StatusChip status={`Expiring in ${days}d`} />
    }
  }

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Inventory / Expiry Control"
        title="Near-Expiry Batches & Risk Dashboard"
        description="Monitor shelf life, lot expiry thresholds, and early supplier return settlements across all warehouses."
        actions={<StatusChip status="FEFO Control" />}
      />

      {/* Metric Summary Cards */}
      <div className="summary-strip">
        <div
          className={`summary-card ${urgencyFilter === 'EXPIRED' ? 'summary-card--active' : ''}`}
          onClick={() => setUrgencyFilter(urgencyFilter === 'EXPIRED' ? 'all' : 'EXPIRED')}
          style={{ cursor: 'pointer' }}
        >
          <span className="summary-card__label" style={{ color: 'var(--color-error)' }}>
            Already Expired
          </span>
          <strong className="summary-card__value" style={{ color: 'var(--color-error)' }}>
            <Quantity value={summary.expired} />
          </strong>
          <span className="summary-card__hint">Requires immediate quarantine / return</span>
        </div>

        <div
          className={`summary-card ${urgencyFilter === 'CRITICAL' ? 'summary-card--active' : ''}`}
          onClick={() => setUrgencyFilter(urgencyFilter === 'CRITICAL' ? 'all' : 'CRITICAL')}
          style={{ cursor: 'pointer' }}
        >
          <span className="summary-card__label" style={{ color: '#ea580c' }}>
            &lt; 7 Days Critical
          </span>
          <strong className="summary-card__value" style={{ color: '#ea580c' }}>
            <Quantity value={summary.within7Days} />
          </strong>
          <span className="summary-card__hint">Urgent clearance or debit note return</span>
        </div>

        <div
          className={`summary-card ${urgencyFilter === 'WARNING' ? 'summary-card--active' : ''}`}
          onClick={() => setUrgencyFilter(urgencyFilter === 'WARNING' ? 'all' : 'WARNING')}
          style={{ cursor: 'pointer' }}
        >
          <span className="summary-card__label" style={{ color: '#d97706' }}>
            &lt; 30 Days Warning
          </span>
          <strong className="summary-card__value" style={{ color: '#d97706' }}>
            <Quantity value={summary.within30Days} />
          </strong>
          <span className="summary-card__hint">Prioritize in FEFO auto-pick dispatches</span>
        </div>

        <div
          className={`summary-card summary-card--accent ${urgencyFilter === 'OK' ? 'summary-card--active' : ''}`}
          onClick={() => setUrgencyFilter(urgencyFilter === 'OK' ? 'all' : 'OK')}
          style={{ cursor: 'pointer' }}
        >
          <span className="summary-card__label">&lt; 90 Days Monitoring</span>
          <strong className="summary-card__value">
            <Quantity value={summary.within90Days} />
          </strong>
          <span className="summary-card__hint">Active inventory window</span>
        </div>
      </div>

      {/* Review window chips and search */}
      <div className="list-toolbar" style={{ justifyContent: 'space-between', flexWrap: 'wrap', gap: 'var(--space-sm)' }}>
        <div style={{ display: 'flex', gap: 'var(--space-sm)', alignItems: 'center', flexWrap: 'wrap' }}>
          <span style={{ fontSize: '0.85rem', fontWeight: 600, color: 'var(--color-text-secondary)' }}>
            Review Window:
          </span>
          {[30, 60, 90, 180].map((d) => (
            <button
              key={d}
              className={`filter-chip ${daysThreshold === d ? 'filter-chip--active' : ''}`}
              onClick={() => setDaysThreshold(d)}
              type="button"
            >
              {d} days
            </button>
          ))}
        </div>

        <div className="search-field" style={{ maxWidth: 360 }}>
          <Search aria-hidden="true" size={16} />
          <input
            aria-label="Search by item name or batch number"
            onChange={(e) => setSearchTerm(e.target.value)}
            placeholder="Search item or batch..."
            type="search"
            value={searchTerm}
          />
        </div>
      </div>

      {/* Overview Card */}
      <div
        className="panel-card"
        style={{
          marginBottom: 'var(--space-md)',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          flexWrap: 'wrap',
          gap: 'var(--space-sm)',
        }}
      >
        <div>
          <strong>
            {filteredBatches.length} batch{filteredBatches.length === 1 ? '' : 'es'} requiring attention
          </strong>
          <p className="cell-muted" style={{ margin: 0, fontSize: '0.85rem' }}>
            <Quantity value={totalAtRiskUnits} /> total on-hand units within {daysThreshold}-day risk horizon
          </p>
        </div>
        {urgencyFilter !== 'all' && (
          <Button onClick={() => setUrgencyFilter('all')} variant="secondary">
            Clear filter ({urgencyFilter})
          </Button>
        )}
      </div>

      {batchesQuery.isLoading ? (
        <div aria-live="polite" className="directory-state">
          Scanning inventory batches for near-expiry alerts...
        </div>
      ) : batchesQuery.isError ? (
        <div className="directory-state directory-state--error" role="alert">
          <FileText aria-hidden="true" size={24} />
          <strong>Unable to load near-expiry batches.</strong>
          <Button onClick={() => batchesQuery.refetch()} variant="secondary">
            Retry
          </Button>
        </div>
      ) : filteredBatches.length === 0 ? (
        <div className="directory-state">
          <CheckCircle2 aria-hidden="true" size={24} color="var(--color-success)" />
          <strong>No batches expiring within {daysThreshold} days.</strong>
          <p>All on-hand lots have healthy shelf-life buffers.</p>
        </div>
      ) : (
        <DataTable caption="Perishable item batch lots approaching expiry date">
          <thead>
            <tr>
              <th scope="col">Item Name</th>
              <th scope="col">Batch Number</th>
              <th scope="col">Expiry Date</th>
              <th className="numeric-cell" scope="col">On-Hand Qty</th>
              <th scope="col">Urgency & Timeline</th>
              <th className="numeric-cell" scope="col">Item Link</th>
            </tr>
          </thead>
          <tbody>
            {filteredBatches.map((batch) => (
              <tr key={batch.batchId}>
                <td>
                  <div className="cell-stack">
                    <strong>{batch.itemName}</strong>
                  </div>
                </td>
                <td>
                  <span className="table-code">{batch.batchNumber}</span>
                </td>
                <td>
                  <div className="cell-stack">
                    <strong>{batch.expiryDate}</strong>
                    <span className="cell-muted">
                      {batch.daysUntilExpiry < 0
                        ? `${Math.abs(batch.daysUntilExpiry)} days overdue`
                        : `${batch.daysUntilExpiry} days left`}
                    </span>
                  </div>
                </td>
                <td className="numeric-cell">
                  <strong>
                    <Quantity value={batch.quantityOnHand} />
                  </strong>
                </td>
                <td>
                  {getUrgencyBadge(batch.urgency, batch.daysUntilExpiry)}
                </td>
                <td className="numeric-cell">
                  <Link
                    className="table-row-action"
                    to={`/items/${batch.itemId}`}
                  >
                    View item
                  </Link>
                </td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      )}
    </section>
  )
}
