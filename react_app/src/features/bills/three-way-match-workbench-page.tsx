import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, FileSpreadsheet, RefreshCw, ShieldAlert, ShieldCheck } from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import { TextField } from '@/design-system/text-field'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import { getThreeWayMatch, overrideThreeWayMatch, runThreeWayMatch } from './three-way-match-api'

export function ThreeWayMatchWorkbenchPage() {
  const { billId } = useParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [overrideModalOpen, setOverrideModalOpen] = useState(false)
  const [overrideReason, setOverrideReason] = useState('')
  const [feedback, setFeedback] = useState<string | null>(null)

  const matchQuery = useQuery({
    queryKey: ['three-way-match', billId],
    queryFn: () => getThreeWayMatch(billId!),
    enabled: Boolean(billId),
  })

  const runMutation = useMutation({
    mutationFn: () => runThreeWayMatch(billId!),
    onSuccess: (status) => {
      setFeedback(`Match complete: ${status}`)
      queryClient.invalidateQueries({ queryKey: ['three-way-match', billId] })
      queryClient.invalidateQueries({ queryKey: ['bills', billId] })
    },
    onError: (err: Error) => {
      setFeedback(`Match failed: ${err.message}`)
    },
  })

  const overrideMutation = useMutation({
    mutationFn: () => overrideThreeWayMatch(billId!, overrideReason),
    onSuccess: () => {
      setFeedback('3-way match variance successfully overridden by administrator.')
      setOverrideModalOpen(false)
      setOverrideReason('')
      queryClient.invalidateQueries({ queryKey: ['three-way-match', billId] })
      queryClient.invalidateQueries({ queryKey: ['bills', billId] })
    },
    onError: (err: Error) => {
      setFeedback(`Override error: ${err.message}`)
    },
  })

  if (!billId) return <div className="workspace-page">Invalid bill ID</div>
  if (matchQuery.isLoading) return <section className="workspace-page"><div aria-live="polite" className="directory-state">Loading 3-way match data...</div></section>
  if (matchQuery.isError || !matchQuery.data) {
    return (
      <section className="workspace-page">
        <div className="directory-state directory-state--error">
          <ShieldAlert size={28} />
          <p>No 3-way match record found for this bill.</p>
          <Button onClick={() => runMutation.mutate()} variant="primary">
            <RefreshCw size={16} />
            Run initial 3-way match
          </Button>
          <Button onClick={() => navigate(`/bills/${billId}`)} variant="secondary">
            Back to Bill
          </Button>
        </div>
      </section>
    )
  }

  const snapshot = matchQuery.data
  const lines = snapshot.lines || []
  const isOverridden = snapshot.status === 'OVERRIDDEN'
    const isException = snapshot.status === 'EXCEPTION'

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Purchases / AP Controls / 3-Way Match"
        title={`3-Way Match: Bill ${snapshot.billNumber}`}
        description={`Audit verification of PO lines ↔ GRN receipts ↔ Vendor bill lines`}
        actions={
          <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
            <StatusChip status={formatStatusLabel(snapshot.status ?? 'PENDING')} />
            <Button onClick={() => navigate(`/bills/${billId}`)} variant="secondary">
              <ArrowLeft size={16} />
              View Bill
            </Button>
          </div>
        }
      />

      {feedback ? (
        <div className="alert-banner" style={{ background: '#0F857615', border: '1px solid #0F8576', padding: '12px 16px', borderRadius: '6px', color: '#0F8576' }}>
          {feedback}
        </div>
      ) : null}

      {isOverridden ? (
        <div className="alert-banner" style={{ background: '#FFF7ED', border: '1px solid #FDBA74', padding: '12px 16px', borderRadius: '6px', color: '#9A3412' }}>
          <strong>Variance Overridden:</strong> {snapshot.overrideReason || 'Administrative approval granted.'}
        </div>
      ) : null}

      <div className="document-layout">
        <section className="document-card">
          <h2>Reconciliation Summary</h2>
          <dl className="document-facts">
            <div>
              <dt>Bill Number</dt>
              <dd>{snapshot.billNumber}</dd>
            </div>
            <div>
              <dt>Match Status</dt>
              <dd>
                <StatusChip status={formatStatusLabel(snapshot.status ?? 'PENDING')} />
              </dd>
            </div>
            <div>
              <dt>Last Evaluated</dt>
              <dd>{snapshot.matchedAt ? formatDate(snapshot.matchedAt) : 'Never'}</dd>
            </div>
            <div>
              <dt>Checked Lines</dt>
              <dd>{lines.length} items evaluated</dd>
            </div>
          </dl>
        </section>

        <aside className="document-card document-card--summary">
          <h2>Verification Actions</h2>
          <p style={{ fontSize: '13px', color: 'var(--k-color-text-secondary)', marginBottom: '16px' }}>
            Re-evaluate links against latest PO order quantities and GRN gatehouse receipts.
          </p>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
            <Button
              disabled={runMutation.isPending}
              onClick={() => runMutation.mutate()}
              variant="primary"
            >
              <RefreshCw size={16} />
              {runMutation.isPending ? 'Evaluating...' : 'Re-run 3-Way Match'}
            </Button>

            {isException && !isOverridden ? (
              <Button
                onClick={() => setOverrideModalOpen(true)}
                variant="secondary"
              >
                <ShieldCheck size={16} />
                Approve Variance Override
              </Button>
            ) : null}

            <Button
              onClick={() => navigate('/debit-notes')}
              variant="ghost"
            >
              <FileSpreadsheet size={16} />
              Draft Debit Note for Variance
            </Button>
          </div>
        </aside>
      </div>

      <section className="document-card document-card--lines">
        <h2>Line-by-Line Match Comparison</h2>
        <DataTable caption="3-Way Match line-level comparisons">
          <thead>
            <tr>
              <th scope="col">Status</th>
              <th scope="col">Item ID</th>
              <th className="numeric-cell" scope="col">Ordered Qty</th>
              <th className="numeric-cell" scope="col">Received Qty</th>
              <th className="numeric-cell" scope="col">Billed Qty</th>
              <th className="numeric-cell" scope="col">Qty Var</th>
              <th className="numeric-cell" scope="col">PO Unit Price</th>
              <th className="numeric-cell" scope="col">Bill Unit Price</th>
              <th className="numeric-cell" scope="col">Price Var</th>
              <th className="numeric-cell" scope="col">Amount Var</th>
            </tr>
          </thead>
          <tbody>
            {lines.map((l) => {
              const lineMatched = l.status === 'MATCHED' || l.status === 'BYPASSED'
              return (
                <tr key={l.id} style={{ background: lineMatched ? 'transparent' : 'rgba(190, 58, 52, 0.04)' }}>
                  <td>
                    <StatusChip status={formatStatusLabel(l.status)} />
                  </td>
                  <td>
                    <span style={{ fontFamily: 'monospace', fontSize: '12px' }}>{l.itemId.slice(0, 8)}...</span>
                  </td>
                  <td className="numeric-cell">
                    <Quantity value={l.orderedQty ?? 0} />
                  </td>
                  <td className="numeric-cell">
                    <Quantity value={l.receivedQty ?? 0} />
                  </td>
                  <td className="numeric-cell">
                    <Quantity value={l.billedQty} />
                  </td>
                  <td className="numeric-cell" style={{ color: Number(l.qtyVariance) > 0 ? '#BE3A34' : 'inherit', fontWeight: Number(l.qtyVariance) > 0 ? 600 : 400 }}>
                    {l.qtyVariance ? Number(l.qtyVariance) : '0'}
                  </td>
                  <td className="numeric-cell">
                    <Money amount={l.poUnitPrice ?? 0} />
                  </td>
                  <td className="numeric-cell">
                    <Money amount={l.billUnitPrice} />
                  </td>
                  <td className="numeric-cell" style={{ color: Number(l.priceVariance) > 0 ? '#BE3A34' : 'inherit', fontWeight: Number(l.priceVariance) > 0 ? 600 : 400 }}>
                    <Money amount={l.priceVariance ?? 0} />
                  </td>
                  <td className="numeric-cell" style={{ color: Number(l.amountVariance) > 0 ? '#BE3A34' : 'inherit', fontWeight: Number(l.amountVariance) > 0 ? 600 : 400 }}>
                    <Money amount={l.amountVariance ?? 0} />
                  </td>
                </tr>
              )
            })}
          </tbody>
        </DataTable>
      </section>

      {overrideModalOpen ? (
        <div className="modal-backdrop" style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100 }}>
          <div className="modal-dialog" style={{ background: '#fff', borderRadius: '8px', padding: '24px', maxWidth: '480px', width: '100%' }}>
            <h3>Approve 3-Way Match Override</h3>
            <p style={{ fontSize: '13px', color: 'var(--k-color-text-secondary)', margin: '8px 0 16px' }}>
              Overriding allows AP disbursement despite detected quantity or price variances. An audit log entry will be preserved.
            </p>
            <TextField
              label="Override Reason (Mandatory)"
              onChange={(e) => setOverrideReason(e.target.value)}
              placeholder="e.g. Price hike approved by procurement head on 2026-09-01"
              value={overrideReason}
            />
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px', marginTop: '16px' }}>
              <Button onClick={() => setOverrideModalOpen(false)} variant="secondary">Cancel</Button>
              <Button
                disabled={!overrideReason.trim() || overrideMutation.isPending}
                onClick={() => overrideMutation.mutate()}
                variant="primary"
              >
                {overrideMutation.isPending ? 'Saving...' : 'Confirm Override'}
              </Button>
            </div>
          </div>
        </div>
      ) : null}
    </section>
  )
}
