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
import { MonthlyPostingDialog } from '@/features/accounting/monthly-posting-dialog'
import { useSessionStore } from '@/shared/session/session-store'
import { Modal } from '@/design-system/modal'
import { TextField } from '@/design-system/text-field'
import { EntityPicker } from '@/design-system/entity-picker'
import { listAccounts, type Account } from '@/features/accounts/accounts-api'
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
  const user = useSessionStore((s) => s.user)
  return <FixedAssetDetailPageWorkspace key={`${user?.orgId}:${user?.role}:${assetId}`} />
}

function FixedAssetDetailPageWorkspace() {
  const orgId = useSessionStore((s) => s.user?.orgId)
  const { assetId } = useParams<{ assetId: string }>()
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const role = useSessionStore((s) => s.user?.role)
  const canPost = ['OWNER', 'ADMIN', 'ACCOUNTANT'].includes(role ?? '')
  const [isRunDepModalOpen, setIsRunDepModalOpen] = useState(false)

  const [isDisposeModalOpen, setIsDisposeModalOpen] = useState(false)
  const [disposalDate, setDisposalDate] = useState(new Date().toISOString().split('T')[0] || '')
  const [proceedsAmount, setProceedsAmount] = useState('0')
  const [proceedsAccount, setProceedsAccount] = useState<Account | null>(null)
  const [gainLossAccount, setGainLossAccount] = useState<Account | null>(null)
  const accountsQuery = useQuery({ queryKey: ['disposal-accounts', orgId], queryFn: listAccounts, enabled: canPost })
  const accounts = (accountsQuery.data ?? []).filter((a) => a.isActive && !a.hasChildren)


  const assetQuery = useQuery({
    queryKey: ['fixed-assets', orgId, assetId],
    queryFn: () => getFixedAsset(assetId!),
    enabled: Boolean(assetId),
  })

  const previewQuery = useQuery({
    queryKey: ['fixed-assets', orgId, assetId, 'schedule-preview'],
    queryFn: () => getFixedAssetSchedulePreview(assetId!),
    enabled: Boolean(assetId),
  })

  const disposeMutation = useMutation({
    mutationFn: (req: DisposeAssetRequest) => disposeFixedAsset(assetId!, req),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['fixed-assets'] })
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

            {canPost && !isDisposed && (
              <>
                <Button onClick={() => setIsRunDepModalOpen(true)} variant="primary">
                  <Play aria-hidden="true" size={14} style={{ marginRight: 6 }} />
                  Run organisation depreciation
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
                      <Money amount={entry.closingWdv} />
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
                    <Money amount={p.depreciation} />
                  </td>
                  <td className="numeric-cell">
                    <strong style={{ color: 'var(--color-success)' }}>
                      <Money amount={p.closing} />
                    </strong>
                  </td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        </div>
      )}

      {isRunDepModalOpen && <MonthlyPostingDialog title="Run organisation depreciation" scope="fixed assets" run={runDepreciation} onClose={() => setIsRunDepModalOpen(false)} />}

      <Modal isOpen={isDisposeModalOpen} onClose={() => { if (!disposeMutation.isPending) setIsDisposeModalOpen(false) }} title="Dispose fixed asset" description="This removes the asset from the register and posts disposal proceeds and gain/loss to the general ledger." error={disposeMutation.error?.message || accountsQuery.error?.message}
        footer={<><Button variant="secondary" disabled={disposeMutation.isPending} onClick={() => setIsDisposeModalOpen(false)}>Cancel</Button><Button variant="destructive"
          disabled={!canPost || disposeMutation.isPending || !disposalDate || disposalDate < asset.acquisitionDate || !Number.isFinite(Number(proceedsAmount)) || Number(proceedsAmount) < 0 || !gainLossAccount || (Number(proceedsAmount) > 0 && !proceedsAccount)}
          onClick={() => disposeMutation.mutate({ disposalDate, proceeds: Number(proceedsAmount), proceedsAccountCode: proceedsAccount?.code, gainLossAccountCode: gainLossAccount!.code })}>Confirm Disposal</Button></>}>
        <TextField label="Disposal date" type="date" min={asset.acquisitionDate} value={disposalDate} onChange={(e) => setDisposalDate(e.target.value)} />
        <TextField label="Disposal proceeds" type="number" min="0" step="0.01" value={proceedsAmount} onChange={(e) => setProceedsAmount(e.target.value)} />
        <div className="field"><span>Proceeds account</span><EntityPicker<Account> ariaLabel="Proceeds account" options={accounts} getOptionId={(a) => a.id} getOptionLabel={(a) => a.code + ' - ' + a.name} value={proceedsAccount?.id ?? null} selectedEntity={proceedsAccount} onChange={(_id, a) => setProceedsAccount(a ?? null)} /></div>
        <div className="field"><span>Gain/loss account</span><EntityPicker<Account> ariaLabel="Gain/loss account" options={accounts} getOptionId={(a) => a.id} getOptionLabel={(a) => a.code + ' - ' + a.name} value={gainLossAccount?.id ?? null} selectedEntity={gainLossAccount} onChange={(_id, a) => setGainLossAccount(a ?? null)} /></div>
      </Modal>
    </section>
  )
}
