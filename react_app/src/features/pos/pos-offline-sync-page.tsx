import { useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import {
  CheckCircle2,
  DownloadCloud,
  ShieldCheck,
  ShoppingBag,
  UploadCloud,
  Wifi,
  WifiOff,
} from 'lucide-react'
import { Link } from 'react-router-dom'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import {
  batchOfflineSync,
  syncPosCatalog,
  type BatchOfflineSyncResponse,
  type CreateSalesReceiptRequest,
} from '@/features/pos/pos-api'

const OFFLINE_STORAGE_KEY = 'katasticho_pos_offline_queue'
const CATALOG_CACHE_KEY = 'katasticho_pos_catalog_cache'

export function PosOfflineSyncPage() {
  const queryClient = useQueryClient()
  const [feedback, setFeedback] = useState<{ type: 'success' | 'error'; message: string } | null>(null)
  const [isOnline] = useState(navigator.onLine)

  // Local state for cached queue
  const [offlineQueue, setOfflineQueue] = useState<CreateSalesReceiptRequest[]>(() => {
    try {
      const raw = localStorage.getItem(OFFLINE_STORAGE_KEY)
      return raw ? JSON.parse(raw) : []
    } catch {
      return []
    }
  })

  const [cachedItemsCount, setCachedItemsCount] = useState<number>(() => {
    try {
      const raw = localStorage.getItem(CATALOG_CACHE_KEY)
      return raw ? JSON.parse(raw).length : 0
    } catch {
      return 0
    }
  })

  // Mutations
  const syncQueueMutation = useMutation({
    mutationFn: async () => {
      if (!offlineQueue.length) return null
      return batchOfflineSync(offlineQueue)
    },
    onSuccess: (res: BatchOfflineSyncResponse | null) => {
      if (!res) return
      // Clear offline queue
      localStorage.removeItem(OFFLINE_STORAGE_KEY)
      setOfflineQueue([])
      queryClient.invalidateQueries({ queryKey: ['sales-receipts-list'] })
      setFeedback({
        type: 'success',
        message: `Successfully synced ${res.syncedCount} offline receipts. ${res.duplicateCount} duplicates skipped.`,
      })
    },
    onError: (err: unknown) => {
      setFeedback({
        type: 'error',
        message: err instanceof Error ? err.message : 'Sync failed. Server unreachable.',
      })
    },
  })

  const refreshCatalogMutation = useMutation({
    mutationFn: async () => {
      const res = await syncPosCatalog(undefined, undefined, undefined, 1000)
      localStorage.setItem(CATALOG_CACHE_KEY, JSON.stringify(res.items))
      return res.items.length
    },
    onSuccess: (count: number) => {
      setCachedItemsCount(count)
      setFeedback({
        type: 'success',
        message: `Downloaded and cached ${count} catalog items for fast local offline lookup.`,
      })
    },
    onError: (err: unknown) => {
      setFeedback({
        type: 'error',
        message: err instanceof Error ? err.message : 'Failed to fetch catalog snapshot.',
      })
    },
  })

  const handleClearCache = () => {
    if (confirm('Clear local catalog cache? This does not delete any sales receipts.')) {
      localStorage.removeItem(CATALOG_CACHE_KEY)
      setCachedItemsCount(0)
      setFeedback({ type: 'success', message: 'Local catalog cache cleared.' })
    }
  }

  const queueTotalAmount = offlineQueue.reduce((sum, r) => {
    const linesTotal = r.lines.reduce((lsum, l) => lsum + l.rate * l.quantity, 0)
    return sum + linesTotal
  }, 0)

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Point of Sale"
        title="Offline Billing & Catalog Sync"
        description="Monitor local browser transaction buffer, force batch push of offline receipts, and cache product master catalog for zero-latency lookups."
        actions={
          <div style={{ display: 'flex', gap: 'var(--space-sm)' }}>
            <Link className="btn btn--secondary" to="/pos">
              <ShoppingBag aria-hidden="true" size={14} style={{ marginRight: 6 }} />
              Open POS Counter
            </Link>
            <Button
              disabled={syncQueueMutation.isPending || offlineQueue.length === 0}
              onClick={() => syncQueueMutation.mutate()}
              variant="primary"
            >
              <UploadCloud aria-hidden="true" size={14} style={{ marginRight: 6 }} />
              {syncQueueMutation.isPending ? 'Syncing...' : `Sync ${offlineQueue.length} Receipts`}
            </Button>
          </div>
        }
      />

      {feedback && (
        <div
          className={`banner ${feedback.type === 'success' ? 'banner--success' : 'banner--error'}`}
          role="status"
          style={{ marginBottom: 'var(--space-md)' }}
        >
          <span>{feedback.message}</span>
          <button className="banner-dismiss" onClick={() => setFeedback(null)} type="button">
            ×
          </button>
        </div>
      )}

      {/* Connectivity & Sync Strip */}
      <div className="summary-strip">
        <div className="summary-card">
          <span className="summary-card__label">Connectivity Status</span>
          <strong className="summary-card__value" style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            {isOnline ? (
              <>
                <Wifi size={20} color="var(--color-success)" /> Online
              </>
            ) : (
              <>
                <WifiOff size={20} color="var(--color-danger)" /> Offline
              </>
            )}
          </strong>
          <span className="summary-card__hint">{isOnline ? 'Connected to Katasticho Server' : 'Working offline locally'}</span>
        </div>

        <div className="summary-card">
          <span className="summary-card__label">Unsynced Receipts</span>
          <strong className="summary-card__value">
            <Quantity value={offlineQueue.length} />
          </strong>
          <span className="summary-card__hint">
            Buffered sales: <Money amount={queueTotalAmount} />
          </span>
        </div>

        <div className="summary-card">
          <span className="summary-card__label">Cached Catalog Items</span>
          <strong className="summary-card__value">
            <Quantity value={cachedItemsCount} />
          </strong>
          <span className="summary-card__hint">Available for instant scanning</span>
        </div>

        <div className="summary-card summary-card--accent">
          <span className="summary-card__label">Sync Reliability</span>
          <strong className="summary-card__value" style={{ color: 'var(--color-success)', display: 'flex', alignItems: 'center', gap: 6 }}>
            <ShieldCheck size={22} /> Idempotent
          </strong>
          <span className="summary-card__hint">Unique offline bill keys prevent duplicates</span>
        </div>
      </div>

      {/* Catalog Cache Panel */}
      <div className="panel-card" style={{ padding: 'var(--space-md)', marginBottom: 'var(--space-lg)' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 'var(--space-sm)' }}>
          <div>
            <h3 style={{ fontSize: '1.05rem', margin: '0 0 2px 0' }}>Local Item Master Cache</h3>
            <p className="cell-muted" style={{ margin: 0, fontSize: '0.85rem' }}>
              Download medicines, FMCG items, barcodes, and rates into browser memory so counter scanning works during internet outages.
            </p>
          </div>
          <div style={{ display: 'flex', gap: 'var(--space-sm)' }}>
            <Button onClick={handleClearCache} variant="ghost">
              Clear Cache
            </Button>
            <Button
              disabled={refreshCatalogMutation.isPending}
              onClick={() => refreshCatalogMutation.mutate()}
              variant="secondary"
            >
              <DownloadCloud aria-hidden="true" size={14} style={{ marginRight: 6 }} />
              {refreshCatalogMutation.isPending ? 'Downloading...' : 'Refresh Catalog Snapshot'}
            </Button>
          </div>
        </div>
      </div>

      {/* Offline Receipts Buffer Table */}
      <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 'var(--space-sm)' }}>
          <div>
            <h3 style={{ fontSize: '1.05rem', margin: '0 0 2px 0' }}>Offline Transaction Queue ({offlineQueue.length})</h3>
            <p className="cell-muted" style={{ margin: 0, fontSize: '0.85rem' }}>
              Sales generated when internet was disconnected. When you click Sync, these will be posted to the general ledger and inventory balances.
            </p>
          </div>
        </div>

        {offlineQueue.length === 0 ? (
          <div className="directory-state">
            <CheckCircle2 aria-hidden="true" size={24} color="var(--color-success)" />
            <strong>All sales receipts are synced with the server.</strong>
            <p>No offline receipts waiting in local storage.</p>
          </div>
        ) : (
          <DataTable caption="Offline transaction queue">
            <thead>
              <tr>
                <th scope="col">Offline Bill #</th>
                <th scope="col">Date</th>
                <th scope="col">Payment Mode</th>
                <th className="numeric-cell" scope="col">Lines</th>
                <th className="numeric-cell" scope="col">Amount</th>
                <th scope="col">Status</th>
              </tr>
            </thead>
            <tbody>
              {offlineQueue.map((req, idx) => {
                const total = req.lines.reduce((s, l) => s + l.rate * l.quantity, 0)
                return (
                  <tr key={req.offlineReceiptNumber || idx}>
                    <td>
                      <span className="table-code">{req.offlineReceiptNumber || `OFF-${idx + 1}`}</span>
                    </td>
                    <td>
                      <span className="cell-muted">{req.receiptDate}</span>
                    </td>
                    <td>
                      <StatusChip status={req.paymentMode} />
                    </td>
                    <td className="numeric-cell">
                      <Quantity value={req.lines.length} />
                    </td>
                    <td className="numeric-cell">
                      <strong>
                        <Money amount={total} />
                      </strong>
                    </td>
                    <td>
                      <StatusChip status="PENDING_SYNC" />
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </DataTable>
        )}
      </div>
    </section>
  )
}
