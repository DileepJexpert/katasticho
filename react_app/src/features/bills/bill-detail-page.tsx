import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  ArrowLeft,
  FileText,
  Landmark,
  Layers,
  Send,
  ShieldAlert,
  ShieldCheck,
  XCircle,
} from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import { TextField } from '@/design-system/text-field'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import { getBill, getBillPayments, postBill, voidBill } from '@/features/bills/bills-api'
import { recordVendorPayment } from '@/features/vendor-payments/vendor-payments-api'

export function BillDetailPage() {
  const { billId } = useParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [paymentModalOpen, setPaymentModalOpen] = useState(false)
  const [paymentAmount, setPaymentAmount] = useState(0)
  const [paymentMode, setPaymentMode] = useState('BANK_TRANSFER')
  const [referenceNumber, setReferenceNumber] = useState('')
  const [feedback, setFeedback] = useState<string | null>(null)

  const bill = useQuery({
    queryKey: ['bills', billId],
    queryFn: () => getBill(billId!),
    enabled: Boolean(billId),
  })

  const payments = useQuery({
    queryKey: ['bills', billId, 'payments'],
    queryFn: () => getBillPayments(billId!),
    enabled: Boolean(billId),
  })

  const postMutation = useMutation({
    mutationFn: () => postBill(billId!),
    onSuccess: () => {
      setFeedback('Bill posted to ledger — journal entry and AP liability created.')
      queryClient.invalidateQueries({ queryKey: ['bills', billId] })
    },
    onError: (err: Error) => setFeedback(`Post failed: ${err.message}`),
  })

  const voidMutation = useMutation({
    mutationFn: () => voidBill(billId!, 'Voided by user'),
    onSuccess: () => {
      setFeedback('Bill voided.')
      queryClient.invalidateQueries({ queryKey: ['bills', billId] })
    },
    onError: (err: Error) => setFeedback(`Void failed: ${err.message}`),
  })

  const payMutation = useMutation({
    mutationFn: () =>
      recordVendorPayment({
        contactId: bill.data?.contactId || '',
        paymentDate: new Date().toISOString().slice(0, 10),
        amount: Number(paymentAmount),
        paymentMode,
        referenceNumber,
        allocations: [
          {
            billId: billId!,
            amountApplied: Number(paymentAmount),
          },
        ],
      }),
    onSuccess: () => {
      setFeedback('Payment disbursement recorded successfully.')
      setPaymentModalOpen(false)
      queryClient.invalidateQueries({ queryKey: ['bills', billId] })
      queryClient.invalidateQueries({ queryKey: ['bills', billId, 'payments'] })
    },
    onError: (err: Error) => setFeedback(`Payment recording failed: ${err.message}`),
  })

  if (!billId) return <DocumentError onBack={() => navigate('/bills')} />
  if (bill.isLoading) return <section className="workspace-page"><div aria-live="polite" className="directory-state">Loading vendor bill...</div></section>
  if (bill.isError || !bill.data) return <DocumentError onBack={() => navigate('/bills')} />

  const document = bill.data
  const currency = document.currency ?? 'INR'
  const is3wmException = document.threeWayMatchStatus === 'EXCEPTION'

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Purchases / Payables / Vendor bill"
        title={document.billNumber}
        description={`${document.vendorName ?? 'Unknown vendor'} · billed ${formatDate(document.billDate)}`}
        actions={
          <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
            <StatusChip status={formatStatusLabel(document.status)} />
            <Button onClick={() => navigate('/bills')} variant="secondary">
              <ArrowLeft aria-hidden="true" size={16} />
              Back to bills
            </Button>
          </div>
        }
      />

      {feedback ? (
        <div className="alert-banner" style={{ background: '#0F857615', border: '1px solid #0F8576', padding: '12px 16px', borderRadius: '6px', color: '#0F8576', marginBottom: '16px' }}>
          {feedback}
        </div>
      ) : null}

      <div
        className="match-banner"
        style={{
          background: is3wmException ? '#FEF2F2' : '#F0FDF4',
          border: `1px solid ${is3wmException ? '#FCA5A5' : '#86EFAC'}`,
          padding: '12px 16px',
          borderRadius: '8px',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginBottom: '16px',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          {is3wmException ? (
            <ShieldAlert color="#DC2626" size={20} />
          ) : (
            <ShieldCheck color="#16A34A" size={20} />
          )}
          <div>
            <strong>3-Way Match Status: {formatStatusLabel(document.threeWayMatchStatus ?? 'NOT_RUN')}</strong>
            <span style={{ display: 'block', fontSize: '12px', color: 'var(--k-color-text-secondary)' }}>
              {is3wmException
                ? 'Quantity or price variances detected against purchase order / GRN.'
                : 'All PO lines and GRN quantities match within configured tolerances.'}
            </span>
          </div>
        </div>
        <Button
          onClick={() => navigate(`/bills/${billId}/three-way-match`)}
          variant="secondary"
        >
          <Layers size={14} />
          Inspect 3-Way Match
        </Button>
      </div>

      <div className="document-layout">
        <section className="document-card">
          <h2>Bill information</h2>
          <dl className="document-facts">
            <Fact label="Vendor" value={document.vendorName ?? '--'} />
            <Fact label="Vendor invoice #" value={document.vendorBillNumber ?? '--'} />
            <Fact label="Bill date" value={formatDate(document.billDate)} />
            <Fact label="Due date" value={formatDate(document.dueDate)} />
            <Fact label="Place of supply" value={document.placeOfSupply ?? '--'} />
            <Fact label="Reverse charge" value={document.reverseCharge ? 'Yes' : 'No'} />
            <Fact label="Currency" value={currency} />
          </dl>
        </section>

        <aside className="document-card document-card--summary">
          <h2>Settlement status</h2>
          <div className="progress-row">
            <span>Total bill</span>
            <Money amount={document.totalAmount} currency={currency} />
          </div>
          <div className="progress-row">
            <span>Amount paid</span>
            <Money amount={document.amountPaid} currency={currency} />
          </div>
          <div className="progress-row progress-row--total">
            <strong>Balance due</strong>
            <Money amount={document.balanceDue} currency={currency} />
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', marginTop: '16px' }}>
            {document.status === 'DRAFT' ? (
              <Button
                disabled={postMutation.isPending}
                onClick={() => postMutation.mutate()}
                variant="primary"
              >
                <Send size={16} />
                {postMutation.isPending ? 'Posting...' : 'Post Bill'}
              </Button>
            ) : null}

            {Number(document.balanceDue) > 0 && document.status !== 'VOIDED' ? (
              <Button
                onClick={() => {
                  setPaymentAmount(Number(document.balanceDue));
                  setPaymentModalOpen(true);
                }}
                variant="primary"
              >
                <Landmark size={16} />
                Record Payment
              </Button>
            ) : null}

            {document.status !== 'VOIDED' ? (
              <Button
                disabled={voidMutation.isPending}
                onClick={() => voidMutation.mutate()}
                variant="destructive"
              >
                <XCircle size={16} />
                Void Bill
              </Button>
            ) : null}
          </div>
        </aside>
      </div>

      <section className="document-card document-card--lines">
        <h2>Billed line items</h2>
        <DataTable caption="Vendor bill line items">
          <thead>
            <tr>
              <th scope="col">#</th>
              <th scope="col">Item / Description</th>
              <th className="numeric-cell" scope="col">Quantity</th>
              <th className="numeric-cell" scope="col">Unit price</th>
              <th className="numeric-cell" scope="col">Discount</th>
              <th scope="col">GST</th>
              <th className="numeric-cell" scope="col">Tax</th>
              <th className="numeric-cell" scope="col">Line total</th>
            </tr>
          </thead>
          <tbody>
            {document.lines.map((line) => (
              <tr key={line.id}>
                <td>{line.lineNumber}</td>
                <td>
                  <div className="cell-stack">
                    <strong>{line.description ?? '--'}</strong>
                    <code>{line.hsnCode ? `HSN ${line.hsnCode}` : '--'}</code>
                  </div>
                </td>
                <td className="numeric-cell">
                  <Quantity value={line.quantity} />
                </td>
                <td className="numeric-cell">
                  <Money amount={line.unitPrice} currency={currency} />
                </td>
                <td className="numeric-cell">
                  {line.discountPercent === null ? '--' : `${Number(line.discountPercent)}%`}
                </td>
                <td>
                  {line.gstRate === null ? '--' : `${Number(line.gstRate)}%`}
                </td>
                <td className="numeric-cell">
                  <Money amount={line.taxAmount} currency={currency} />
                </td>
                <td className="numeric-cell">
                  <Money amount={line.lineTotal} currency={currency} />
                </td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      </section>

      <div className="document-layout">
        <section className="document-card">
          <h2>Vendor payment history</h2>
          {payments.isLoading ? (
            <p className="document-loading" aria-live="polite">Loading payment history...</p>
          ) : payments.isError ? (
            <p className="document-loading">Payment history could not be loaded.</p>
          ) : payments.data?.length ? (
            <div className="payment-list">
              {payments.data.map((payment) => (
                <div className="payment-entry" key={payment.id}>
                  <div>
                    <strong>{payment.paymentNumber}</strong>
                    <span>
                      {payment.paymentMode ? formatStatusLabel(payment.paymentMode) : 'Payment'} · {formatDate(payment.paymentDate)}
                      {payment.referenceNumber ? ` · Ref ${payment.referenceNumber}` : ''}
                    </span>
                  </div>
                  <div className="payment-entry__amount">
                    <StatusChip status="Posted" />
                    <Money amount={payment.amount} currency={payment.currency ?? currency} />
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <p className="document-loading">No vendor disbursements have been recorded for this bill.</p>
          )}
        </section>

        <aside className="document-card document-card--summary">
          <h2>Financial summary</h2>
          <div className="progress-row">
            <span>Subtotal</span>
            <Money amount={document.subtotal} currency={currency} />
          </div>
          <div className="progress-row">
            <span>GST input tax</span>
            <Money amount={document.taxAmount} currency={currency} />
          </div>
          {document.tdsAmount ? (
            <div className="progress-row">
              <span>TDS withheld</span>
              <Money amount={document.tdsAmount} currency={currency} />
            </div>
          ) : null}
          <div className="progress-row progress-row--total">
            <strong>Total liability</strong>
            <Money amount={document.totalAmount} currency={currency} />
          </div>
        </aside>
      </div>

      <section className="document-card document-card--notes">
        <h2>Commercial remarks</h2>
        <div className="document-notes">
          <span>Notes</span>
          <p>{document.notes ?? 'No notes recorded.'}</p>
        </div>
      </section>

      {paymentModalOpen ? (
        <div className="modal-backdrop" style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100 }}>
          <div className="modal-dialog" style={{ background: '#fff', borderRadius: '8px', padding: '24px', maxWidth: '480px', width: '100%' }}>
            <h3>Record Vendor Disbursement</h3>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', marginTop: '16px' }}>
              <TextField
                label="Amount to Disburse (₹)"
                onChange={(e) => setPaymentAmount(Number(e.target.value))}
                type="number"
                value={String(paymentAmount)}
              />
              <div>
                <label style={{ display: 'block', fontSize: '13px', marginBottom: '4px' }}>Payment Mode</label>
                <select
                  onChange={(e) => setPaymentMode(e.target.value)}
                  style={{ width: '100%', padding: '8px', borderRadius: '6px', border: '1px solid #ccc' }}
                  value={paymentMode}
                >
                  <option value="BANK_TRANSFER">Bank Transfer (NEFT/RTGS/IMPS)</option>
                  <option value="CHEQUE">Cheque</option>
                  <option value="UPI">UPI</option>
                  <option value="CASH">Cash</option>
                </select>
              </div>
              <TextField
                label="Reference # / UTR / Cheque #"
                onChange={(e) => setReferenceNumber(e.target.value)}
                placeholder="e.g. UTR1238910"
                value={referenceNumber}
              />
              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px', marginTop: '8px' }}>
                <Button onClick={() => setPaymentModalOpen(false)} variant="secondary">Cancel</Button>
                <Button
                  disabled={paymentAmount <= 0 || payMutation.isPending}
                  onClick={() => payMutation.mutate()}
                  variant="primary"
                >
                  {payMutation.isPending ? 'Recording...' : 'Disburse Payment'}
                </Button>
              </div>
            </div>
          </div>
        </div>
      ) : null}
    </section>
  )
}

function Fact({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt>{label}</dt>
      <dd>{value}</dd>
    </div>
  )
}

function DocumentError({ onBack }: { onBack: () => void }) {
  return (
    <section className="workspace-page">
      <div className="directory-state directory-state--error" role="alert">
        <FileText aria-hidden="true" size={24} />
        <strong>Vendor bill details could not be loaded.</strong>
        <p>The bill may no longer be available, or you may not have permission to view it.</p>
        <Button onClick={onBack} variant="secondary">Back to bills</Button>
      </div>
    </section>
  )
}
