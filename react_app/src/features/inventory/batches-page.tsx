import { useState, useMemo } from 'react'
import { useNavigate } from 'react-router-dom'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import {
  AlertCircle,
  AlertTriangle,
  Clock,
  ExternalLink,
  GitFork,
  Package,
  RefreshCw,
  Search,
  ShieldAlert,
  Undo2,
} from 'lucide-react'
import {
  Button,
  DataTable,
  DocumentCard,
  FilterTabs,
  PageHeader,
  Quantity,
  StatusChip,
} from '@/design-system'
import {
  getExpirySummary,
  getNearExpiryBatches,
  type ExpiryBatch,
} from '@/features/inventory/batches-api'

type UrgencyFilter = 'ALL' | 'EXPIRED' | 'CRITICAL' | 'WARNING' | 'OK'

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

  const totalActionable = (summary?.expired ?? 0) + (summary?.within7Days ?? 0)

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <div className="flex items-center gap-2">
            <Button
              aria-label="Refresh batch data"
              onClick={handleRefresh}
              variant="secondary"
            >
              <RefreshCw size={15} aria-hidden="true" />
              <span>Refresh</span>
            </Button>
            <Button
              onClick={() => navigate('/batch-trace')}
              variant="secondary"
            >
              <GitFork size={15} aria-hidden="true" />
              <span>Batch Genealogy</span>
            </Button>
            <Button
              onClick={() => navigate('/debit-notes/new')}
              variant="primary"
            >
              <Undo2 size={15} aria-hidden="true" />
              <span>Draft Return</span>
            </Button>
          </div>
        }
        eyebrow="Inventory & Compliance • Shelf-Life Watch"
        title="Batch & Expiry Watch"
        description="Real-time surveillance of product shelf-life, near-expiry lots, FEFO prioritisation, and supplier debit note returns."
      />

      <div className="dashboard-workspace">
        {/* ── Expiry Urgency Metric Cards ── */}
        <section aria-label="Expiry urgency metrics" className="metric-grid">
          <article className="metric-card metric-card--danger">
            <span className="metric-icon">
              <ShieldAlert size={18} aria-hidden="true" />
            </span>
            <div className="metric-content">
              <span className="metric-label">Expired Stock</span>
              <span className="metric-value font-mono">
                {summaryQuery.isLoading ? '—' : summary?.expired ?? 0}
              </span>
              <span className="metric-footnote">Quarantine immediately</span>
            </div>
          </article>

          <article className="metric-card metric-card--warning">
            <span className="metric-icon">
              <AlertCircle size={18} aria-hidden="true" />
            </span>
            <div className="metric-content">
              <span className="metric-label">Critical (≤ 7 Days)</span>
              <span className="metric-value font-mono">
                {summaryQuery.isLoading ? '—' : summary?.within7Days ?? 0}
              </span>
              <span className="metric-footnote">Urgent liquidation or return</span>
            </div>
          </article>

          <article className="metric-card">
            <span className="metric-icon">
              <AlertTriangle size={18} aria-hidden="true" />
            </span>
            <div className="metric-content">
              <span className="metric-label">Expiring (≤ 30 Days)</span>
              <span className="metric-value font-mono">
                {summaryQuery.isLoading ? '—' : summary?.within30Days ?? 0}
              </span>
              <span className="metric-footnote">FEFO dispatch priority</span>
            </div>
          </article>

          <article className="metric-card metric-card--brand">
            <span className="metric-icon">
              <Clock size={18} aria-hidden="true" />
            </span>
            <div className="metric-content">
              <span className="metric-label">Watchlist (≤ 90 Days)</span>
              <span className="metric-value font-mono">
                {summaryQuery.isLoading ? '—' : summary?.within90Days ?? 0}
              </span>
              <span className="metric-footnote">Active shelf-life monitoring</span>
            </div>
          </article>
        </section>

        {/* ── Critical Advisory Banner ── */}
        {totalActionable > 0 && (
          <section
            aria-label="Expiry action advisory"
            className="p-4 rounded-lg bg-amber-50 border border-amber-200 text-amber-900 flex items-center justify-between gap-4"
          >
            <div className="flex items-center gap-3">
              <AlertTriangle size={20} className="text-amber-600 flex-none" />
              <div>
                <strong className="font-semibold block text-sm">
                  {totalActionable} batch{totalActionable > 1 ? 'es' : ''} require immediate management
                </strong>
                <span className="text-xs text-amber-800">
                  Expired lots must not be dispensed or sold. Initiate supplier debit notes or quarantine transfer orders.
                </span>
              </div>
            </div>
            <Button
              onClick={() => navigate('/debit-notes/new')}
              variant="secondary"
            >
              <span>Initiate Vendor Return</span>
            </Button>
          </section>
        )}

        {/* ── Filter Bar & Horizon Selector ── */}
        <section
          aria-label="Batch filters"
          className="flex flex-wrap items-center justify-between gap-3 p-3 bg-surface border border-subtle rounded-lg"
        >
          <div className="flex flex-wrap items-center gap-3">
            <div className="relative" style={{ width: '260px' }}>
              <Search
                size={14}
                className="absolute left-3 top-1/2 -translate-y-1/2 text-muted pointer-events-none"
              />
              <input
                aria-label="Search by batch number or item name"
                className="dashboard-branch-select"
                placeholder="Search batch # or item name..."
                style={{ width: '100%', paddingLeft: '32px' }}
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
              />
            </div>

            <FilterTabs
              activeValue={urgencyFilter}
              ariaLabel="Urgency filter tabs"
              items={[
                { value: 'ALL', label: 'All Lots' },
                { value: 'EXPIRED', label: 'Expired' },
                { value: 'CRITICAL', label: '≤ 7 Days' },
                { value: 'WARNING', label: '≤ 30 Days' },
                { value: 'OK', label: 'Safe' },
              ]}
              onChange={(val) => setUrgencyFilter(val as UrgencyFilter)}
            />
          </div>

          <div className="flex items-center gap-2">
            <span className="text-xs text-muted font-medium">Horizon:</span>
            <select
              aria-label="Horizon days selector"
              className="dashboard-branch-select"
              value={daysThreshold}
              onChange={(e) => setDaysThreshold(Number(e.target.value))}
            >
              <option value={30}>Next 30 Days</option>
              <option value={60}>Next 60 Days</option>
              <option value={90}>Next 90 Days</option>
              <option value={180}>Next 180 Days</option>
              <option value={365}>Next 1 Year</option>
            </select>
          </div>
        </section>

        {/* ── Batches Table ── */}
        <DocumentCard title={`Expiring Batches Register (${filteredBatches.length})`}>
          {batchesQuery.isLoading ? (
            <div className="p-4 text-secondary text-sm">Loading near-expiry batches...</div>
          ) : filteredBatches.length > 0 ? (
            <DataTable caption="Directory of near-expiry inventory batches">
              <thead>
                <tr>
                  <th scope="col">Batch #</th>
                  <th scope="col">Item Description</th>
                  <th scope="col">Expiry Date</th>
                  <th scope="col">Days Remaining</th>
                  <th className="numeric-cell" scope="col">On-Hand Stock</th>
                  <th scope="col">Urgency</th>
                  <th className="numeric-cell" scope="col">Actions</th>
                </tr>
              </thead>
              <tbody>
                {filteredBatches.map((batch) => {
                  const isExpired = batch.daysUntilExpiry < 0
                  const isCritical = batch.daysUntilExpiry >= 0 && batch.daysUntilExpiry <= 7
                  const isWarning = batch.daysUntilExpiry > 7 && batch.daysUntilExpiry <= 30

                  return (
                    <tr key={batch.batchId}>
                      <td>
                        <button
                          type="button"
                          onClick={() => navigate(`/batch-trace?batch=${batch.batchNumber}`)}
                          className="font-mono font-semibold text-brand hover:underline flex items-center gap-1 text-left"
                        >
                          <span>{batch.batchNumber}</span>
                          <ExternalLink size={12} className="opacity-60" />
                        </button>
                      </td>
                      <td>
                        <strong>{batch.itemName}</strong>
                      </td>
                      <td>
                        <span className="font-mono text-xs">{batch.expiryDate}</span>
                      </td>
                      <td>
                        <span
                          className={`font-mono text-xs font-semibold px-2 py-0.5 rounded ${
                            isExpired
                              ? 'bg-rose-100 text-rose-800'
                              : isCritical
                              ? 'bg-amber-100 text-amber-800'
                              : isWarning
                              ? 'bg-yellow-100 text-yellow-800'
                              : 'bg-emerald-50 text-emerald-800'
                          }`}
                        >
                          {isExpired
                            ? `Expired ${Math.abs(batch.daysUntilExpiry)}d ago`
                            : batch.daysUntilExpiry === 0
                            ? 'Expires Today'
                            : `${batch.daysUntilExpiry} days left`}
                        </span>
                      </td>
                      <td className="numeric-cell">
                        <Quantity amount={batch.quantityOnHand} />
                      </td>
                      <td>
                        <StatusChip status={batch.urgency} />
                      </td>
                      <td className="numeric-cell">
                        <div className="flex items-center justify-end gap-1.5">
                          <Button
                            onClick={() => navigate(`/batch-trace?batch=${batch.batchNumber}`)}
                            variant="secondary"
                            aria-label={`Trace genealogy for ${batch.batchNumber}`}
                          >
                            <span>Trace</span>
                          </Button>
                          <Button
                            onClick={() => navigate(`/debit-notes/new?batchId=${batch.batchId}`)}
                            variant="secondary"
                            aria-label={`Draft debit return for ${batch.batchNumber}`}
                          >
                            <span>Return</span>
                          </Button>
                        </div>
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </DataTable>
          ) : (
            <div className="p-8 text-center text-secondary text-sm">
              <Package size={28} className="mx-auto mb-2 text-muted opacity-40" />
              <strong>No batches matching the criteria.</strong>
              <p className="text-xs text-muted mt-1">
                All inventory within the selected horizon is within safe shelf-life limits.
              </p>
            </div>
          )}
        </DocumentCard>
      </div>
    </section>
  )
}
