import { useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import {
  AlertTriangle,
  ExternalLink,
  GitFork,
  RefreshCw,
} from 'lucide-react'
import {
  Button,
  DataTable,
  DocumentCard,
  EmptyState,
  FilterTabs,
  PageHeader,
  Quantity,
  SearchInput,
  SelectInput,
  StatusChip,
  DirectoryToolbar,
} from '@/design-system'
import { appRoutes } from '@/app/navigation'
import { formatDate, formatQuantity } from '@/shared/format/format'
import {
  getExpirySummary,
  getNearExpiryBatches,
  type ExpiryBatch,
} from '@/features/inventory/batches-api'

type UrgencyFilter = 'ALL' | 'EXPIRED' | 'CRITICAL' | 'WARNING' | 'OK'

function errorMessage(error: unknown, fallback: string) {
  return error instanceof Error && error.message ? error.message : fallback
}

function expiryTimeline(daysUntilExpiry: number) {
  if (daysUntilExpiry < 0) return `Expired ${Math.abs(daysUntilExpiry)} days ago`
  if (daysUntilExpiry === 0) return 'Expires today'
  if (daysUntilExpiry === 1) return 'Expires tomorrow'
  return `${daysUntilExpiry} days remaining`
}

export function BatchesPage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const [searchTerm, setSearchTerm] = useState('')
  const [urgencyFilter, setUrgencyFilter] = useState<UrgencyFilter>('ALL')
  const [daysThreshold, setDaysThreshold] = useState<number>(90)

  const summaryQuery = useQuery({
    queryKey: ['batches', 'expiry-summary'],
    queryFn: () => getExpirySummary(),
  })

  const batchesQuery = useQuery({
    queryKey: ['batches', 'near-expiry', daysThreshold],
    queryFn: () => getNearExpiryBatches(daysThreshold),
  })

  function handleRefresh() {
    queryClient.invalidateQueries({ queryKey: ['batches'] })
  }

  const summary = summaryQuery.data
  const batches = useMemo(() => batchesQuery.data ?? [], [batchesQuery.data])

  const filteredBatches = useMemo(() => {
    return batches.filter((batch: ExpiryBatch) => {
      if (urgencyFilter !== 'ALL' && batch.urgency !== urgencyFilter) {
        return false
      }
      if (searchTerm.trim()) {
        const term = searchTerm.trim().toLowerCase()
        const batchMatch = batch.batchNumber.toLowerCase().includes(term)
        const itemMatch = batch.itemName.toLowerCase().includes(term)
        if (!batchMatch && !itemMatch) return false
      }
      return true
    })
  }, [batches, urgencyFilter, searchTerm])

  const urgencyCounts = useMemo(() => ({
    EXPIRED: batches.filter((batch) => batch.urgency === 'EXPIRED').length,
    CRITICAL: batches.filter((batch) => batch.urgency === 'CRITICAL').length,
    WARNING: batches.filter((batch) => batch.urgency === 'WARNING').length,
    OK: batches.filter((batch) => batch.urgency === 'OK').length,
  }), [batches])

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <>
            <Button aria-label="Refresh batch data" onClick={handleRefresh} variant="secondary">
              <RefreshCw size={15} aria-hidden="true" />
              Refresh
            </Button>
            <Button onClick={() => navigate(appRoutes.batchTrace)} variant="secondary">
              <GitFork size={15} aria-hidden="true" />
              Batch trace
            </Button>
          </>
        }
        eyebrow="Inventory / Expiry control"
        title="Batch & Expiry Watch"
        description="Review on-hand batches approaching expiry. Batches are created through goods receipt workflows; review their allocation when stock is issued."
      />

      <section aria-label="Expiry risk summary" className="expiry-summary-grid">
        <ExpirySummaryCard label="Expired" value={summary?.expired} loading={summaryQuery.isLoading} tone="negative" />
        <ExpirySummaryCard label="Critical (0-7 days)" value={summary?.within7Days} loading={summaryQuery.isLoading} tone="warning" />
        <ExpirySummaryCard label="Watch (8-30 days)" value={summary?.within30Days} loading={summaryQuery.isLoading} tone="warning" />
        <ExpirySummaryCard label="Monitor (31-90 days)" value={summary?.within90Days} loading={summaryQuery.isLoading} tone="info" />
      </section>

      <DocumentCard className="expiry-watch-card" title="Expiry watch register">
        <DirectoryToolbar
          ariaLabel="Batch expiry filters"
          actions={
            <label className="filter-label">
              Horizon
              <SelectInput
                aria-label="Horizon days selector"
                onChange={(event) => setDaysThreshold(Number(event.target.value))}
                options={[
                  { value: 30, label: '30 days' },
                  { value: 60, label: '60 days' },
                  { value: 90, label: '90 days' },
                  { value: 180, label: '180 days' },
                  { value: 365, label: '1 year' },
                ]}
                value={daysThreshold}
              />
            </label>
          }
        >
          <SearchInput
            ariaLabel="Search by batch number or item name"
            onChange={setSearchTerm}
            onClear={() => setSearchTerm('')}
            placeholder="Search batch or item"
            value={searchTerm}
          />
          <FilterTabs
            activeValue={urgencyFilter}
            ariaLabel="Expiry urgency filters"
            items={[
              { value: 'ALL', label: 'All', count: batches.length },
              { value: 'EXPIRED', label: 'Expired', count: urgencyCounts.EXPIRED },
              { value: 'CRITICAL', label: 'Critical', count: urgencyCounts.CRITICAL },
              { value: 'WARNING', label: 'Watch', count: urgencyCounts.WARNING },
              { value: 'OK', label: 'Monitor', count: urgencyCounts.OK },
            ]}
            onChange={(value) => setUrgencyFilter(value as UrgencyFilter)}
          />
        </DirectoryToolbar>

        {summaryQuery.isError && (
          <p className="expiry-watch-card__notice" role="status">
            Summary unavailable: {errorMessage(summaryQuery.error, 'try refreshing the page.')}
          </p>
        )}

        {batchesQuery.isError ? (
          <EmptyState
            action={<Button onClick={() => batchesQuery.refetch()} variant="secondary">Retry</Button>}
            className="directory-state--error"
            description={errorMessage(batchesQuery.error, 'Check your connection and permissions, then retry.')}
            title="Expiry batches could not be loaded"
          />
        ) : batchesQuery.isLoading ? (
          <div aria-live="polite" className="directory-state">Loading expiring batches...</div>
        ) : filteredBatches.length ? (
          <DataTable caption="Near-expiry batch register">
            <thead>
              <tr>
                <th scope="col">Batch</th>
                <th scope="col">Item</th>
                <th scope="col">Expiry date</th>
                <th scope="col">Shelf life</th>
                <th className="numeric-cell" scope="col">On hand</th>
                <th scope="col">Urgency</th>
                <th scope="col"><span className="visually-hidden">Actions</span></th>
              </tr>
            </thead>
            <tbody>
              {filteredBatches.map((batch) => (
                <tr key={batch.batchId}>
                  <td><code>{batch.batchNumber}</code></td>
                  <td><strong>{batch.itemName}</strong></td>
                  <td>{formatDate(batch.expiryDate)}</td>
                  <td>{expiryTimeline(batch.daysUntilExpiry)}</td>
                  <td className="numeric-cell"><Quantity value={batch.quantityOnHand} /></td>
                  <td><StatusChip status={batch.urgency} /></td>
                  <td>
                    <div className="table-row-actions">
                      <Button
                        aria-label={`Open trace for ${batch.batchNumber}`}
                        onClick={() => navigate(`${appRoutes.batchTrace}?batchId=${encodeURIComponent(batch.batchId)}`)}
                        variant="ghost"
                      >
                        Trace <ExternalLink aria-hidden="true" size={14} />
                      </Button>
                      <Button onClick={() => navigate(appRoutes.itemDetail(batch.itemId))} variant="ghost">View item</Button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        ) : (
          <EmptyState
            action={searchTerm || urgencyFilter !== 'ALL' ? <Button onClick={() => { setSearchTerm(''); setUrgencyFilter('ALL') }} variant="secondary">Clear filters</Button> : undefined}
            description={searchTerm || urgencyFilter !== 'ALL' ? 'Try a different batch number, item name, or urgency filter.' : `No on-hand batches expire within the next ${formatQuantity(daysThreshold)} days.`}
            icon={AlertTriangle}
            title={searchTerm || urgencyFilter !== 'ALL' ? 'No batches match these filters' : 'No batches need expiry attention'}
          />
        )}
      </DocumentCard>
    </section>
  )
}

function ExpirySummaryCard({
  label,
  value,
  loading,
  tone,
}: {
  label: string
  value: number | undefined
  loading: boolean
  tone: 'negative' | 'warning' | 'info'
}) {
  return (
    <DocumentCard className={`expiry-summary-card expiry-summary-card--${tone}`}>
      <span>{label}</span>
      <strong>{loading ? '—' : formatQuantity(value)}</strong>
      <small>On-hand batches</small>
    </DocumentCard>
  )
}
