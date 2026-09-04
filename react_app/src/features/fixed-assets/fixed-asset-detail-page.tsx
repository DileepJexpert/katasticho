import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  ArrowLeft,
  Building,
  Play,
  Trash2,
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
  disposeFixedAsset,
  getFixedAsset,
  getFixedAssetSchedulePreview,
  runDepreciation,
  type DisposeAssetRequest,
} from '@/features/fixed-assets/fixed-assets-api'

export function FixedAssetDetailPage() {
  const { assetId } = useParams<{ assetId: string }>()
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const currentYear = new Date().getFullYear()
  const currentMonth = new Date().getMonth() + 1

  const [isRunDepModalOpen, setIsRunDepModalOpen] = useState(false)
  const [depYear, setDepYear] = useState(currentYear)
  const [depMonth, setDepMonth] = useState(currentMonth)

  const [isDisposeModalOpen, setIsDisposeModalOpen] = useState(false)
  const [disposalDate, setDisposalDate] = useState(new Date().toISOString().split('T')[0] || '')
  const [proceedsAmount, setProceedsAmount] = useState('0')
  const [disposalNotes, setDisposalNotes] = useState('')

  const assetQuery = useQuery({
    queryKey: ['fixed-assets', assetId],
    queryFn: () => getFixedAsset(assetId!),
    enabled: Boolean(assetId),
  })

  const previewQuery = useQuery({
    queryKey: ['fixed-assets', assetId, 'schedule-preview'],
    queryFn: () => getFixedAssetSchedulePreview(assetId!),
    enabled: Boolean(assetId),
  })

  const runDepMutation = useMutation({
    mutationFn: () => runDepreciation(assetId!, depYear, depMonth),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['fixed-assets', assetId] })
      setIsRunDepModalOpen(false)
    },
  })

  const disposeMutation = useMutation({
    mutationFn: (req: DisposeAssetRequest) => disposeFixedAsset(assetId!, req),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['fixed-assets', assetId] })
      setIsDisposeModalOpen(false)
    },
  })

  if (!assetId || assetQuery.isLoading) {
    return (
      <section className="workspace-page">
        <div className="directory-state">Loading fixed asset workbench...</div>
      </section>
    )
  }

  if (assetQuery.isError || !assetQuery.data) {
    return (
      <section className="workspace-page">
        <div className="directory-state directory-state--error" role="alert">
          <Building aria-hidden="true" size={24} />
          <strong>Fixed asset record not found.</strong>
          <Button onClick={() => navigate(appRoutes.fixedAssets)} variant="secondary">
            <ArrowLeft aria-hidden="true" size={14} style={{ marginRight: 6 }} />
            Back to Fixed Assets Register
          </Button>
        </div>
      </section>
    )
  }

  const { asset, bookValue, schedule } = assetQuery.data
  const futureSchedule = previewQuery.data ?? []

  const grossCost = Number(asset.cost || 0)
  const accDep = Number(asset.accumulatedDepreciation || 0)
  const nbv = bookValue !== undefined ? Number(bookValue) : Math.max(0, grossCost - accDep)
  const isDisposed = asset.status === 'DISPOSED' || asset.status === 'WRITTEN_OFF'

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Financial / Fixed Assets"
        title={asset.name}
        description={`Code: ${asset.assetCode} · Category: ${asset.category || 'General'} · Method: ${asset.bookMethod}`}
        actions={
          <div style={{ display: 'flex', gap: 'var(--space-sm)' }}>
            <Button onClick={() => navigate(appRoutes.fixedAssets)} variant="secondary">
              <ArrowLeft aria-hidden="true" size={14} style={{ marginRight: 6 }} />
              Back
            </Button>

            {!isDisposed && (
              <>
                <Button onClick={() => setIsRunDepModalOpen(true)} variant="primary">
                  <Play aria-hidden="true" size={14} style={{ marginRight: 6 }} />
                  Run Depreciation
                </Button>
                <Button onClick={() => setIsDisposeModalOpen(true)} variant="destructive">
                  <Trash2 aria-hidden="true" size={14} style={{ marginRight: 6 }} />
                  Dispose / Scrap
                </Button>
              </>
            )}

            <StatusChip status={asset.status} />
          </div>
        }
      />

      {/* KPI Summary Strip */}
      <div className="summary-strip">
        <div className="summary-card">
          <span className="summary-card__label">Capitalized Gross Cost</span>
          <strong className="summary-card__value">
            <Money amount={grossCost} />
          </strong>
          <span className="summary-card__hint">Acquired on {formatDate(asset.acquisitionDate)}</span>
        </div>

        <div className="summary-card">
          <span className="summary-card__label">Accumulated Depreciation</span>
          <strong className="summary-card__value" style={{ color: 'var(--color-error)' }}>
            <Money amount={accDep} />
          </strong>
          <span className="summary-card__hint">Total amortized to P&L</span>
        </div>

        <div className="summary-card summary-card--accent">
          <span className="summary-card__label">Net Carrying Book Value</span>
          <strong className="summary-card__value" style={{ color: 'var(--color-success)' }}>
            <Money amount={nbv} />
          </strong>
          <span className="summary-card__hint">Balance sheet valuation</span>
        </div>

        <div className="summary-card">
          <span className="summary-card__label">Useful Life Plan</span>
          <strong className="summary-card__value">
            <Quantity value={asset.bookUsefulLifeMonths || 60} /> Mo.
          </strong>
          <span className="summary-card__hint">Residual: <Money amount={asset.residualValue || 0} /></span>
        </div>
      </div>

      {/* Posted Schedule Table */}
      <div className="panel-card" style={{ padding: 'var(--space-md)', marginBottom: 'var(--space-md)' }}>
        <h3 style={{ fontSize: '1.05rem', fontWeight: 600, marginBottom: 'var(--space-sm)' }}>
          Posted Depreciation History ({schedule.length} Periods)
        </h3>

        {schedule.length === 0 ? (
          <div className="directory-state" style={{ padding: 'var(--space-md)' }}>
            No depreciation postings have been executed yet for this asset.
          </div>
        ) : (
          <DataTable caption="Posted Depreciation Entries">
            <thead>
              <tr>
                <th scope="col">Period</th>
                <th className="numeric-cell" scope="col">Depreciation Expense</th>
                <th className="numeric-cell" scope="col">Ending Book Value</th>
                <th scope="col">GL Journal Voucher</th>
              </tr>
            </thead>
            <tbody>
              {schedule.map((entry) => (
                <tr key={entry.id}>
                  <td>
                    <span className="table-code">{entry.periodYear}-{String(entry.periodMonth).padStart(2, '0')}</span>
                  </td>
                  <td className="numeric-cell">
                    <strong style={{ color: 'var(--color-error)' }}>
                      <Money amount={entry.depreciationAmount} />
                    </strong>
                  </td>
                  <td className="numeric-cell">
                    <strong style={{ color: 'var(--color-success)' }}>
                      <Money amount={entry.closingBookValue} />
                    </strong>
                  </td>
                  <td>
                    {entry.journalEntryId ? (
                      <span className="table-code" style={{ color: 'var(--color-primary)' }}>
                        GL-{entry.journalEntryId.substring(0, 8)}
                      </span>
                    ) : (
                      <span className="cell-muted">â€”</span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        )}
      </div>

      {/* Projected Schedule Preview */}
      {futureSchedule.length > 0 && (
        <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
          <h3 style={{ fontSize: '1.05rem', fontWeight: 600, marginBottom: 'var(--space-sm)' }}>
            Future Projected Amortization Schedule (Upcoming {futureSchedule.length} Periods)
          </h3>
          <DataTable caption="Future Projected Depreciation Schedule">
            <thead>
              <tr>
                <th scope="col">Period</th>
                <th className="numeric-cell" scope="col">Projected Expense</th>
                <th className="numeric-cell" scope="col">Projected Ending Book Value</th>
              </tr>
            </thead>
            <tbody>
              {futureSchedule.slice(0, 12).map((p, idx) => (
                <tr key={idx}>
                  <td>
                    <span className="table-code">{p.periodYear}-{String(p.periodMonth).padStart(2, '0')}</span>
                  </td>
                  <td className="numeric-cell">
                    <Money amount={p.depreciationAmount} />
                  </td>
                  <td className="numeric-cell">
                    <strong style={{ color: 'var(--color-success)' }}>
                      <Money amount={p.closingBookValue} />
                    </strong>
                  </td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        </div>
      )}

      {/* MODAL: RUN DEPRECIATION */}
      {isRunDepModalOpen && (
        <div
          role="dialog"
          aria-modal="true"
          style={{
            position: 'fixed',
            inset: 0,
            backgroundColor: 'rgba(0,0,0,0.5)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 1000,
            padding: 'var(--space-md)',
          }}
        >
          <div
            className="panel-card"
            style={{
              width: '100%',
              maxWidth: 440,
              backgroundColor: 'var(--color-surface)',
              borderRadius: 'var(--radius-lg)',
              padding: 'var(--space-lg)',
              border: '1px solid var(--color-border)',
            }}
          >
            <h3 style={{ fontSize: '1.2rem', fontWeight: 600, marginBottom: 'var(--space-xs)' }}>
              Run Monthly Depreciation
            </h3>
            <p className="cell-muted" style={{ fontSize: '0.85rem', marginBottom: 'var(--space-md)' }}>
              Post depreciation journal voucher for {asset.name} to the General Ledger.
            </p>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 'var(--space-sm)', marginBottom: 'var(--space-md)' }}>
              <div>
                <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                  Year
                </label>
                <input
                  style={{
                    width: '100%',
                    padding: '8px 12px',
                    borderRadius: 'var(--radius-md)',
                    border: '1px solid var(--color-border)',
                  }}
                  onChange={(e) => setDepYear(Number(e.target.value))}
                  type="number"
                  value={depYear}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                  Month (1-12)
                </label>
                <input
                  style={{
                    width: '100%',
                    padding: '8px 12px',
                    borderRadius: 'var(--radius-md)',
                    border: '1px solid var(--color-border)',
                  }}
                  max={12}
                  min={1}
                  onChange={(e) => setDepMonth(Number(e.target.value))}
                  type="number"
                  value={depMonth}
                />
              </div>
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
              <Button onClick={() => setIsRunDepModalOpen(false)} variant="secondary">
                Cancel
              </Button>
              <Button
                disabled={runDepMutation.isPending}
                onClick={() => runDepMutation.mutate()}
                variant="primary"
              >
                {runDepMutation.isPending ? 'Posting...' : 'Post to Ledger'}
              </Button>
            </div>
          </div>
        </div>
      )}

      {/* MODAL: DISPOSE ASSET */}
      {isDisposeModalOpen && (
        <div
          role="dialog"
          aria-modal="true"
          style={{
            position: 'fixed',
            inset: 0,
            backgroundColor: 'rgba(0,0,0,0.5)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 1000,
            padding: 'var(--space-md)',
          }}
        >
          <div
            className="panel-card"
            style={{
              width: '100%',
              maxWidth: 480,
              backgroundColor: 'var(--color-surface)',
              borderRadius: 'var(--radius-lg)',
              padding: 'var(--space-lg)',
              border: '1px solid var(--color-border)',
            }}
          >
            <h3 style={{ fontSize: '1.2rem', fontWeight: 600, marginBottom: 'var(--space-xs)' }}>
              Dispose or Scrap Fixed Asset
            </h3>
            <p className="cell-muted" style={{ fontSize: '0.85rem', marginBottom: 'var(--space-md)' }}>
              De-capitalize {asset.name} and record salvage recovery proceeds or write-off loss in General Ledger.
            </p>

            <div style={{ marginBottom: 'var(--space-sm)' }}>
              <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                Disposal Date
              </label>
              <input
                style={{
                  width: '100%',
                  padding: '8px 12px',
                  borderRadius: 'var(--radius-md)',
                  border: '1px solid var(--color-border)',
                }}
                onChange={(e) => setDisposalDate(e.target.value)}
                type="date"
                value={disposalDate}
              />
            </div>

            <div style={{ marginBottom: 'var(--space-sm)' }}>
              <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                Realized Sale / Salvage Proceeds (₹)
              </label>
              <input
                style={{
                  width: '100%',
                  padding: '8px 12px',
                  borderRadius: 'var(--radius-md)',
                  border: '1px solid var(--color-border)',
                }}
                onChange={(e) => setProceedsAmount(e.target.value)}
                placeholder="0.00"
                type="number"
                value={proceedsAmount}
              />
            </div>

            <div style={{ marginBottom: 'var(--space-md)' }}>
              <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                Disposal Rationale / Notes
              </label>
              <textarea
                rows={2}
                style={{
                  width: '100%',
                  padding: '8px 12px',
                  borderRadius: 'var(--radius-md)',
                  border: '1px solid var(--color-border)',
                }}
                onChange={(e) => setDisposalNotes(e.target.value)}
                placeholder="e.g. Scrapped due to obsolescence or sold to third-party..."
                value={disposalNotes}
              />
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
              <Button onClick={() => setIsDisposeModalOpen(false)} variant="secondary">
                Cancel
              </Button>
              <Button
                disabled={disposeMutation.isPending}
                onClick={() =>
                  disposeMutation.mutate({
                    disposalDate,
                    disposalProceeds: Number(proceedsAmount) || 0,
                    notes: disposalNotes,
                  })
                }
                variant="destructive"
              >
                {disposeMutation.isPending ? 'Processing...' : 'Confirm Disposal'}
              </Button>
            </div>
          </div>
        </div>
      )}
    </section>
  )
}