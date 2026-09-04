import { useQuery } from '@tanstack/react-query'
import { ArrowLeft, FileText } from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { Button } from '@/design-system/button'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import { getPayment } from '@/features/payments/payments-api'

export function PaymentDetailPage() {
  const { paymentId } = useParams()
  const navigate = useNavigate()
  const payment = useQuery({
    queryKey: ['payments', paymentId],
    queryFn: () => getPayment(paymentId!),
    enabled: Boolean(paymentId),
  })

  if (!paymentId) return <DocumentError onBack={() => navigate('/payments')} />
  if (payment.isLoading) return <section className="workspace-page"><div aria-live="polite" className="directory-state">Loading payment...</div></section>
  if (payment.isError || !payment.data) return <DocumentError onBack={() => navigate('/payments')} />

  const document = payment.data
  const currency = document.currency ?? 'INR'

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Sales / Receivables / Payment receipt"
        title={document.paymentNumber}
        description={`${document.contactName ?? 'Unknown customer'} · received ${formatDate(document.paymentDate)}`}
        actions={<StatusChip status={formatStatusLabel(document.status)} />}
      />

      <div className="document-actions">
        <Button onClick={() => navigate('/payments')} variant="secondary">
          <ArrowLeft aria-hidden="true" size={16} />
          Back to payments
        </Button>
      </div>

      <div className="document-layout">
        <section className="document-card">
          <h2>Payment information</h2>
          <dl className="document-facts">
            <Fact label="Customer" value={document.contactName ?? '--'} />
            <Fact label="Payment date" value={formatDate(document.paymentDate)} />
            <Fact label="Applied invoice" value={document.invoiceNumber ?? 'Unallocated advance'} />
            <Fact label="Payment method" value={document.paymentMethod ? formatStatusLabel(document.paymentMethod) : '--'} />
            <Fact label="Reference / UTR" value={document.referenceNumber ?? '--'} />
            <Fact label="Bank account" value={document.bankAccount ?? '--'} />
            <Fact label="Currency" value={currency} />
            <Fact label="Journal entry" value={document.journalEntryId ? `Journal #${document.journalEntryId.slice(0, 8)}` : 'Posted'} />
          </dl>
        </section>

        <aside className="document-card document-card--summary">
          <h2>Receipt amount</h2>
          <div className="progress-row progress-row--total">
            <strong>Total collected</strong>
            <Money amount={document.amount} currency={currency} />
          </div>
          <div className="progress-row">
            <span>Status</span>
            <StatusChip status={formatStatusLabel(document.status)} />
          </div>
        </aside>
      </div>

      <section className="document-card document-card--notes">
        <h2>Payment remarks</h2>
        <div className="document-notes">
          <span>Notes & Reference</span>
          <p>{document.notes ?? 'No remarks recorded for this payment receipt.'}</p>
        </div>
      </section>
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
        <strong>Payment details could not be loaded.</strong>
        <p>The payment record may no longer be available, or you may not have permission to view it.</p>
        <Button onClick={onBack} variant="secondary">Back to payments</Button>
      </div>
    </section>
  )
}
