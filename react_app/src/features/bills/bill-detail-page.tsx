import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  ArrowLeft,
  DollarSign,
  Send,
  ShieldAlert,
  ShieldCheck,
  XCircle,
} from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  DataTable,
  DocumentCard,
  DocumentError,
  Fact,
  FactList,
  FormField,
  FormGrid,
  Modal,
  Money,
  NumberInput,
  PageHeader,
  Quantity,
  SelectInput,
  StatusChip,
  SummaryRow,
  TextInput,
} from '@/design-system'
import { getBill, getBillPayments, postBill, voidBill } from '@/features/bills/bills-api'
import { recordVendorPayment } from '@/features/vendor-payments/vendor-payments-api'
import { formatDate, formatStatusLabel } from '@/shared/format/format'

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

  if (!billId) return <DocumentError onBack={() => navigate(appRoutes.bills)} />
  if (bill.isLoading) {
    return (
      <section className="workspace-page">
        <div aria-live="polite" className="directory-state">
          Loading vendor bill...
        </div>
      </section>
    )
  }
  if (bill.isError || !bill.data) {
    return <DocumentError onBack={() => navigate(appRoutes.bills)} />
  }

  const document = bill.data
  const currency = document.currency ?? 'INR'
  const is3wmException = document.threeWayMatchStatus === 'EXCEPTION'

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <div style={{ display: 'flex', gap: 'var(--space-2)', alignItems: 'center' }}>
            <StatusChip status={formatStatusLabel(document.status)} />
            <Button onClick={() => navigate(appRoutes.bills)} variant="secondary">
              <ArrowLeft aria-hidden="true" size={16} />
              Back to bills
            </Button>
          </div>
        }
        description={`${document.vendorName ?? 'Unknown vendor'} · billed ${formatDate(document.billDate)}`}
        eyebrow="Purchases / Payables / Vendor bill"
        title={document.billNumber}
      />

      {feedback && (
        <div
          className="banner banner--success"
          role="status"
          style={{ marginBottom: 'var(--space-4)' }}
        >
          <span>{feedback}</span>
          <button className="banner-dismiss" onClick={() => setFeedback(null)} type="button">✕</button>
        </div>
      )}

      <div
        style={{
          background: is3wmException ? 'var(--color-danger-subtle, #FEF2F2)' : 'var(--color-success-subtle, #F0FDF4)',
          border: `1px solid ${is3wmException ? 'var(--color-danger, #EF4444)' : 'var(--color-success, #22C55E)'}`,
          padding: 'var(--space-3) var(--space-4)',
          borderRadius: 'var(--radius-md)',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginBottom: 'var(--space-4)',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-2)' }}>
          {is3wmException ? (
            <ShieldAlert color="var(--color-danger, #DC2626)" size={20} />
          ) : (
            <ShieldCheck color="var(--color-success, #16A34A)" size={20} />
          )}
          <div>
            <strong>3-Way Match Status: {formatStatusLabel(document.threeWayMatchStatus ?? 'NOT_RUN')}</strong>
            <span style={{ display: 'block', fontSize: 'var(--text-xs)', color: 'var(--text-secondary)' }}>
              PO commitment vs GRN inward delivery vs Vendor billed rate & quantity
            </span>
          </div>
        </div>
        <Button onClick={() => navigate(`/bills/${billId}/three-way-match`)} variant="secondary">
          Review Match
        </Button>
      </div>

      <div className="document-layout">
        <DocumentCard title="Bill Information">
          <FactList columns={2}>
            <Fact label="Vendor" value={document.vendorName ?? '--'} />
            <Fact label="Bill Date" value={formatDate(document.billDate)} />
            <Fact label="Due Date" value={formatDate(document.dueDate)} />
            <Fact label="Vendor Invoice #" mono value={document.vendorBillNumber ?? '--'} />
            <Fact label="Place of Supply" value={document.placeOfSupply ?? '--'} />
            <Fact label="Reverse Charge (RCM)" value={document.reverseCharge ? 'Yes' : 'No'} />
          </FactList>
        </DocumentCard>

        <DocumentCard title="Settlement Status" variant="summary">
          <SummaryRow label="Bill Amount" value={<Money amount={document.totalAmount} currency={currency} />} />
          <SummaryRow label="Amount Paid" value={<Money amount={document.paidAmount} currency={currency} />} />
          <SummaryRow isTotal label="Balance Due" value={<Money amount={document.balanceDue} currency={currency} />} />

          <div className="document-card__actions">
            {document.status === 'DRAFT' && (
              <Button
                disabled={postMutation.isPending}
                onClick={() => postMutation.mutate()}
                variant="primary"
              >
                <Send size={16} />
                {postMutation.isPending ? 'Posting...' : 'Post to Ledger'}
              </Button>
            )}

            {document.status === 'POSTED' && Number(document.balanceDue) > 0 && (
              <Button
                onClick={() => {
                  setPaymentAmount(Number(document.balanceDue))
                  setPaymentModalOpen(true)
                }}
                variant="primary"
              >
                <DollarSign size={16} />
                Record Payment
              </Button>
            )}

            {document.status === 'DRAFT' && (
              <Button
                disabled={voidMutation.isPending}
                onClick={() => voidMutation.mutate()}
                variant="destructive"
              >
                <XCircle size={16} />
                Void Bill
              </Button>
            )}
          </div>
        </DocumentCard>
      </div>

      <DocumentCard title="Billed Line Items" variant="lines">
        <DataTable caption="Bill lines">
          <thead>
            <tr>
              <th scope="col">#</th>
              <th scope="col">Description</th>
              <th scope="col">HSN</th>
              <th className="numeric-cell" scope="col">Qty</th>
              <th className="numeric-cell" scope="col">Unit Cost</th>
              <th className="numeric-cell" scope="col">GST %</th>
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
                    <strong>{line.description || line.itemName || '--'}</strong>
                    {line.itemName && line.description ? <span className="cell-muted">{line.itemName}</span> : null}
                  </div>
                </td>
                <td>{line.hsnCode ? <code>{line.hsnCode}</code> : '--'}</td>
                <td className="numeric-cell"><Quantity value={line.quantity} /></td>
                <td className="numeric-cell"><Money amount={line.unitPrice} currency={currency} /></td>
                <td className="numeric-cell">{line.gstRate ?? 0}%</td>
                <td className="numeric-cell"><Money amount={line.lineTax} currency={currency} /></td>
                <td className="numeric-cell"><strong><Money amount={line.lineTotal} currency={currency} /></strong></td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      </DocumentCard>

      <div className="document-layout">
        <DocumentCard title="Disbursement History">
          {payments.isLoading ? (
            <p aria-live="polite" className="document-loading">Loading disbursements...</p>
          ) : payments.data?.length ? (
            <div className="payment-list">
              {payments.data.map((p) => (
                <div className="payment-entry" key={p.id}>
                  <div>
                    <strong>{p.paymentNumber}</strong>
                    <span>{p.paymentMode} · {formatDate(p.paymentDate)}{p.referenceNumber ? ` · Ref ${p.referenceNumber}` : ''}</span>
                  </div>
                  <div className="payment-entry__amount">
                    <Money amount={p.amount} currency={currency} />
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <p className="document-loading">No payment disbursements recorded for this bill.</p>
          )}
        </DocumentCard>

        <DocumentCard title="Bill Total" variant="summary">
          <SummaryRow label="Taxable Subtotal" value={<Money amount={document.subtotal} currency={currency} />} />
          <SummaryRow label="Input GST (ITC)" value={<Money amount={document.taxAmount} currency={currency} />} />
          <SummaryRow isTotal label="Bill Amount" value={<Money amount={document.totalAmount} currency={currency} />} />
        </DocumentCard>
      </div>

      <Modal
        footer={
          <>
            <Button onClick={() => setPaymentModalOpen(false)} variant="secondary">Cancel</Button>
            <Button
              disabled={payMutation.isPending || paymentAmount <= 0}
              onClick={() => payMutation.mutate()}
              variant="primary"
            >
              {payMutation.isPending ? 'Recording...' : 'Record Payment'}
            </Button>
          </>
        }
        isOpen={paymentModalOpen}
        onClose={() => setPaymentModalOpen(false)}
        size="md"
        title="Record Vendor Payment Disbursement"
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-4)' }}>
          <FormGrid columns={2}>
            <FormField label="Disbursement Amount" required>
              <NumberInput
                currencyPrefix="₹"
                max={Number(document.balanceDue)}
                min={0.01}
                onChange={(e) => setPaymentAmount(Number(e.target.value))}
                step="0.01"
                value={paymentAmount}
              />
            </FormField>

            <FormField label="Payment Channel" required>
              <SelectInput
                onChange={(e) => setPaymentMode(e.target.value)}
                options={[
                  { value: 'BANK_TRANSFER', label: 'NEFT / RTGS / Transfer' },
                  { value: 'CHEQUE', label: 'Cheque' },
                  { value: 'CASH', label: 'Cash' },
                  { value: 'UPI', label: 'UPI' },
                ]}
                value={paymentMode}
              />
            </FormField>
          </FormGrid>

          <FormField label="Bank Reference / UTR Number">
            <TextInput
              onChange={(e) => setReferenceNumber(e.target.value)}
              placeholder="e.g. UTR-2026-9908"
              value={referenceNumber}
            />
          </FormField>
        </div>
      </Modal>
    </section>
  )
}
