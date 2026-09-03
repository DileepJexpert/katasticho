import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, CheckCircle, Send } from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import { TextField } from '@/design-system/text-field'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import { applyVendorCredit, getVendorCredit, postVendorCredit, voidVendorCredit } from './vendor-credits-api'

export function VendorCreditDetailPage() {
  const { creditId } = useParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [applyModalOpen, setApplyModalOpen] = useState(false)
  const [billId, setBillId] = useState('')
  const [applyAmount, setApplyAmount] = useState(0)
  const [feedback, setFeedback] = useState<string | null>(null)

  const creditQuery = useQuery({
    queryKey: ['vendor-credits', creditId],
    queryFn: () => getVendorCredit(creditId!),
    enabled: Boolean(creditId),
  })

  const postMutation = useMutation({
    mutationFn: () => postVendorCredit(creditId!),
    onSuccess: () => {
      setFeedback('Vendor credit posted to ledger successfully.')
      queryClient.invalidateQueries({ queryKey: ['vendor-credits', creditId] })
    },
    onError: (err: Error) => setFeedback(`Post failed: ${err.message}`),
  })

  const voidMutation = useMutation({
    mutationFn: () => voidVendorCredit(creditId!, 'Voided by user'),
    onSuccess: () => {
      setFeedback('Vendor credit voided.')
      queryClient.invalidateQueries({ queryKey: ['vendor-credits', creditId] })
    },
    onError: (err: Error) => setFeedback(`Void failed: ${err.message}`),
  })

  const applyMutation = useMutation({
    mutationFn: () =>
      applyVendorCredit(creditId!, {
        billId,
        amount: Number(applyAmount),
        applyDate: new Date().toISOString().slice(0, 10),
      }),
    onSuccess: () => {
      setFeedback('Credit applied to bill successfully.')
      setApplyModalOpen(false)
      queryClient.invalidateQueries({ queryKey: ['vendor-credits', creditId] })
    },
    onError: (err: Error) => setFeedback(`Apply failed: ${err.message}`),
  })

  if (!creditId) return <div className="workspace-page">Invalid credit ID</div>
  if (creditQuery.isLoading) return <section className="workspace-page"><div aria-live="polite" className="directory-state">Loading vendor credit...</div></section>
  if (creditQuery.isError || !creditQuery.data) return <div className="workspace-page">Error loading vendor credit</div>

  const credit = creditQuery.data

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Purchases / Payables / Vendor Credit"
        title={credit.creditNumber}
        description={`${credit.vendorName ?? 'Vendor'} · Dated ${formatDate(credit.creditDate)}`}
        actions={
          <div style={{ display: 'flex', gap: '8px' }}>
            <StatusChip status={formatStatusLabel(credit.status)} />
            <Button onClick={() => navigate('/vendor-credits')} variant="secondary">
              <ArrowLeft size={16} />
              Back to Credits
            </Button>
          </div>
        }
      />

      {feedback ? (
        <div className="alert-banner" style={{ background: '#0F857615', border: '1px solid #0F8576', padding: '12px 16px', borderRadius: '6px', color: '#0F8576' }}>
          {feedback}
        </div>
      ) : null}

      <div className="document-layout">
        <section className="document-card">
          <h2>Credit Details</h2>
          <dl className="document-facts">
            <div>
              <dt>Vendor</dt>
              <dd>{credit.vendorName ?? credit.contactId}</dd>
            </div>
            <div>
              <dt>Credit Date</dt>
              <dd>{formatDate(credit.creditDate)}</dd>
            </div>
            <div>
              <dt>Reference Bill</dt>
              <dd>{credit.referenceBillId ?? 'General Supplier Credit'}</dd>
            </div>
            <div>
              <dt>Status</dt>
              <dd>
                <StatusChip status={formatStatusLabel(credit.status)} />
              </dd>
            </div>
          </dl>
        </section>

        <aside className="document-card document-card--summary">
          <h2>Balance & Actions</h2>
          <div className="progress-row">
            <span>Total Credit</span>
            <Money amount={credit.totalAmount} />
          </div>
          <div className="progress-row">
            <span>Applied to Bills</span>
            <Money amount={credit.appliedAmount ?? 0} />
          </div>
          <div className="progress-row progress-row--total">
            <strong>Unapplied Balance</strong>
            <Money amount={credit.unappliedAmount} />
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', marginTop: '16px' }}>
            {credit.status === 'DRAFT' ? (
              <Button
                disabled={postMutation.isPending}
                onClick={() => postMutation.mutate()}
                variant="primary"
              >
                <Send size={16} />
                {postMutation.isPending ? 'Posting...' : 'Post Credit to Ledger'}
              </Button>
            ) : null}

            {credit.status === 'POSTED' || credit.status === 'PARTIALLY_APPLIED' ? (
              <Button
                onClick={() => {
                  setApplyAmount(Number(credit.unappliedAmount));
                  setApplyModalOpen(true);
                }}
                variant="primary"
              >
                <CheckCircle size={16} />
                Apply to Unpaid Bill
              </Button>
            ) : null}

            {credit.status !== 'VOIDED' ? (
              <Button
                disabled={voidMutation.isPending}
                onClick={() => voidMutation.mutate()}
                variant="destructive"
              >
                Void Credit
              </Button>
            ) : null}
          </div>
        </aside>
      </div>

      <section className="document-card document-card--lines">
        <h2>Credit Items</h2>
        <DataTable caption="Vendor credit lines">
          <thead>
            <tr>
              <th scope="col">Description</th>
              <th className="numeric-cell" scope="col">Quantity</th>
              <th className="numeric-cell" scope="col">Unit Price</th>
              <th className="numeric-cell" scope="col">Tax</th>
              <th className="numeric-cell" scope="col">Line Total</th>
            </tr>
          </thead>
          <tbody>
            {credit.lines?.map((l) => (
              <tr key={l.id}>
                <td>{l.description}</td>
                <td className="numeric-cell">
                  <Quantity value={l.quantity} />
                </td>
                <td className="numeric-cell">
                  <Money amount={l.unitPrice} />
                </td>
                <td className="numeric-cell">
                  <Money amount={l.taxAmount ?? 0} />
                </td>
                <td className="numeric-cell">
                  <Money amount={l.lineTotal} />
                </td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      </section>

      {applyModalOpen ? (
        <div className="modal-backdrop" style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100 }}>
          <div className="modal-dialog" style={{ background: '#fff', borderRadius: '8px', padding: '24px', maxWidth: '480px', width: '100%' }}>
            <h3>Apply Vendor Credit to Bill</h3>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', marginTop: '16px' }}>
              <TextField
                label="Target Purchase Bill ID"
                onChange={(e) => setBillId(e.target.value)}
                placeholder="UUID of unpaid purchase bill"
                value={billId}
              />
              <TextField
                label="Amount to Offset (₹)"
                onChange={(e) => setApplyAmount(Number(e.target.value))}
                type="number"
                value={String(applyAmount)}
              />
              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px', marginTop: '8px' }}>
                <Button onClick={() => setApplyModalOpen(false)} variant="secondary">Cancel</Button>
                <Button
                  disabled={!billId || applyAmount <= 0 || applyMutation.isPending}
                  onClick={() => applyMutation.mutate()}
                  variant="primary"
                >
                  {applyMutation.isPending ? 'Applying...' : 'Confirm Allocation'}
                </Button>
              </div>
            </div>
          </div>
        </div>
      ) : null}
    </section>
  )
}
