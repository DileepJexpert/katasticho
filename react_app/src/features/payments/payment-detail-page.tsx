import { useQuery } from '@tanstack/react-query'
import { ArrowLeft } from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  DocumentCard,
  DocumentError,
  Fact,
  FactList,
  Money,
  PageHeader,
  StatusChip,
  SummaryRow,
} from '@/design-system'
import { getPayment } from '@/features/payments/payments-api'
import { formatDate, formatStatusLabel } from '@/shared/format/format'

export function PaymentDetailPage() {
  const { paymentId } = useParams()
  const navigate = useNavigate()
  const payment = useQuery({
    queryKey: ['payments', paymentId],
    queryFn: () => getPayment(paymentId!),
    enabled: Boolean(paymentId),
  })

  if (!paymentId) return <DocumentError onBack={() => navigate(appRoutes.payments)} />
  if (payment.isLoading) {
    return (
      <section className="workspace-page">
        <div aria-live="polite" className="directory-state">
          Loading payment...
        </div>
      </section>
    )
  }
  if (payment.isError || !payment.data) {
    return <DocumentError onBack={() => navigate(appRoutes.payments)} />
  }

  const document = payment.data
  const currency = document.currency ?? 'INR'

  return (
    <section className="workspace-page">
      <PageHeader
        actions={<StatusChip status={formatStatusLabel(document.status)} />}
        description={`${document.contactName ?? 'Unknown customer'} · received ${formatDate(document.paymentDate)}`}
        eyebrow="Sales / Receivables / Payment receipt"
        title={document.paymentNumber}
      />

      <div className="document-actions">
        <Button onClick={() => navigate(appRoutes.payments)} variant="secondary">
          <ArrowLeft aria-hidden="true" size={16} />
          Back to payments
        </Button>
      </div>

      <div className="document-layout">
        <DocumentCard title="Payment Information">
          <FactList columns={2}>
            <Fact label="Customer" value={document.contactName ?? '--'} />
            <Fact label="Payment Date" value={formatDate(document.paymentDate)} />
            <Fact label="Applied Invoice" mono value={document.invoiceNumber ?? 'Unallocated advance'} />
            <Fact label="Payment Method" value={document.paymentMethod ? formatStatusLabel(document.paymentMethod) : '--'} />
            <Fact label="Reference / UTR" mono value={document.referenceNumber ?? '--'} />
            <Fact label="Bank Account" value={document.bankAccount ?? '--'} />
            <Fact label="Currency" mono value={currency} />
            <Fact label="Journal Entry" mono value={document.journalEntryId ? `Journal #${document.journalEntryId.slice(0, 8)}` : 'Posted'} />
          </FactList>
        </DocumentCard>

        <DocumentCard title="Receipt Amount" variant="summary">
          <SummaryRow isTotal label="Total Collected" value={<Money amount={document.amount} currency={currency} />} />
          <SummaryRow label="Status" value={<StatusChip status={formatStatusLabel(document.status)} />} />
        </DocumentCard>
      </div>

      <DocumentCard title="Payment Remarks" variant="notes">
        <div className="document-notes">
          <span>Notes & Reference</span>
          <p>{document.notes ?? 'No remarks recorded for this payment receipt.'}</p>
        </div>
      </DocumentCard>
    </section>
  )
}
