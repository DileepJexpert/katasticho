import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, FileText, Printer, XCircle } from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import { getChequePrint, getVendorPayment, voidVendorPayment } from './vendor-payments-api'

export function VendorPaymentDetailPage() {
  const { paymentId } = useParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [chequeModalOpen, setChequeModalOpen] = useState(false)
  const [feedback, setFeedback] = useState<string | null>(null)

  const payment = useQuery({
    queryKey: ['vendor-payments', paymentId],
    queryFn: () => getVendorPayment(paymentId!),
    enabled: Boolean(paymentId),
  })

  const cheque = useQuery({
    queryKey: ['vendor-payments', paymentId, 'cheque'],
    queryFn: () => getChequePrint(paymentId!),
    enabled: Boolean(paymentId) && chequeModalOpen,
  })

  const voidMutation = useMutation({
    mutationFn: () => voidVendorPayment(paymentId!),
    onSuccess: () => {
      setFeedback('Payment voided and journal entry reversed.')
      queryClient.invalidateQueries({ queryKey: ['vendor-payments', paymentId] })
    },
    onError: (err: Error) => setFeedback(`Void failed: ${err.message}`),
  })

  if (!paymentId) return <DocumentError onBack={() => navigate('/vendor-payments')} />
  if (payment.isLoading) return <section className="workspace-page"><div aria-live="polite" className="directory-state">Loading vendor disbursement...</div></section>
  if (payment.isError || !payment.data) return <DocumentError onBack={() => navigate('/vendor-payments')} />

  const document = payment.data
  const currency = document.currency ?? 'INR'

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Purchases / Payables / Vendor disbursement"
        title={document.paymentNumber}
        description={`${document.vendorName ?? 'Vendor'} · Disbursed ${formatDate(document.paymentDate)}`}
        actions={
          <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
            <StatusChip status="Posted" />
            <Button onClick={() => navigate('/vendor-payments')} variant="secondary">
              <ArrowLeft aria-hidden="true" size={16} />
              Back to payments
            </Button>
          </div>
        }
      />

      {feedback ? (
        <div className="alert-banner" style={{ background: '#0F857615', border: '1px solid #0F8576', padding: '12px 16px', borderRadius: '6px', color: '#0F8576', marginBottom: '16px' }}>
          {feedback}
        </div>
      ) : null}

      <div className="document-layout">
        <section className="document-card">
          <h2>Disbursement facts</h2>
          <dl className="document-facts">
            <Fact label="Vendor" value={document.vendorName ?? '--'} />
            <Fact label="Payment date" value={formatDate(document.paymentDate)} />
            <Fact label="Payment mode" value={document.paymentMode ? formatStatusLabel(document.paymentMode) : '--'} />
            <Fact label="Reference / UTR #" value={document.referenceNumber ?? '--'} />
            <Fact label="GL Journal #" value={document.journalEntryId ? `JE-${document.journalEntryId.slice(0, 8)}` : 'Auto-posted'} />
            <Fact label="Currency" value={currency} />
          </dl>
        </section>

        <aside className="document-card document-card--summary">
          <h2>Disbursement amount</h2>
          <div className="summary-row summary-row--total">
            <span>Amount paid</span>
            <Money amount={document.amount} currency={currency} />
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', marginTop: '16px' }}>
            <Button onClick={() => setChequeModalOpen(true)} variant="secondary">
              <Printer size={16} />
              Payment Advice / Cheque Print
            </Button>
            <Button
              disabled={voidMutation.isPending}
              onClick={() => voidMutation.mutate()}
              variant="destructive"
            >
              <XCircle size={16} />
              Void & Reverse Ledger
            </Button>
          </div>
        </aside>
      </div>

      <section className="document-card document-card--lines">
        <h2>Settled purchase bills</h2>
        <DataTable caption="Bill settlements for vendor payment">
          <thead>
            <tr>
              <th scope="col">Bill Number</th>
              <th className="numeric-cell" scope="col">Amount Allocated</th>
            </tr>
          </thead>
          <tbody>
            {document.allocations?.map((alloc) => (
              <tr key={alloc.id || alloc.billId}>
                <td>
                  <strong>{alloc.billNumber || alloc.billId}</strong>
                </td>
                <td className="numeric-cell">
                  <Money amount={alloc.amountApplied} currency={currency} />
                </td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      </section>

      {chequeModalOpen ? (
        <div className="modal-backdrop" style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100 }}>
          <div className="modal-dialog" style={{ background: '#fff', borderRadius: '8px', padding: '24px', maxWidth: '520px', width: '100%' }}>
            <h3>Cheque Print & Payment Advice</h3>
            {cheque.isLoading ? (
              <p>Loading advice details...</p>
            ) : cheque.data ? (
              <div style={{ background: '#f8fafc', padding: '16px', borderRadius: '6px', marginTop: '12px', border: '1px solid #cbd5e1' }}>
                <p><strong>Payee:</strong> {cheque.data.payeeName}</p>
                <p><strong>Amount:</strong> ₹{cheque.data.amount}</p>
                <p><strong>In Words:</strong> <em>{cheque.data.amountInWords}</em></p>
                <p><strong>Cheque/Ref #:</strong> {cheque.data.chequeNumber || document.referenceNumber}</p>
                <p><strong>Bank Account:</strong> {cheque.data.bankAccountName}</p>
              </div>
            ) : (
              <p>No cheque template mapped.</p>
            )}
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px', marginTop: '16px' }}>
              <Button onClick={() => setChequeModalOpen(false)} variant="secondary">Close</Button>
              <Button onClick={() => window.print()} variant="primary">Print Advice</Button>
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
        <strong>Vendor payment details could not be loaded.</strong>
        <p>The payment record may no longer be available, or you may not have permission to view it.</p>
        <Button onClick={onBack} variant="secondary">Back to payments</Button>
      </div>
    </section>
  )
}
