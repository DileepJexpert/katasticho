import { useQuery } from '@tanstack/react-query'
import { ArrowLeft, FileText } from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import { getInvoice, getInvoicePayments } from '@/features/invoices/invoices-api'

export function InvoiceDetailPage() {
  const { invoiceId } = useParams()
  const navigate = useNavigate()
  const invoice = useQuery({
    queryKey: ['invoices', invoiceId],
    queryFn: () => getInvoice(invoiceId!),
    enabled: Boolean(invoiceId),
  })
  const payments = useQuery({
    queryKey: ['invoices', invoiceId, 'payments'],
    queryFn: () => getInvoicePayments(invoiceId!),
    enabled: Boolean(invoiceId),
  })

  if (!invoiceId) return <DocumentError onBack={() => navigate('/invoices')} />
  if (invoice.isLoading) return <section className="workspace-page"><div aria-live="polite" className="directory-state">Loading invoice...</div></section>
  if (invoice.isError || !invoice.data) return <DocumentError onBack={() => navigate('/invoices')} />

  const document = invoice.data
  const currency = document.currency ?? 'INR'

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Sales / Receivables / Invoice"
        title={document.invoiceNumber}
        description={`${document.contactName ?? 'Unknown customer'} · invoiced ${formatDate(document.invoiceDate)}`}
        actions={<StatusChip status={formatStatusLabel(document.status)} />}
      />

      <div className="document-actions">
        <Button onClick={() => navigate('/invoices')} variant="secondary"><ArrowLeft aria-hidden="true" size={16} />Back to invoices</Button>
        <StatusChip status="Read-only pilot" />
      </div>

      <div className="document-layout">
        <section className="document-card">
          <h2>Invoice information</h2>
          <dl className="document-facts">
            <Fact label="Customer" value={document.contactName ?? '--'} />
            <Fact label="Invoice date" value={formatDate(document.invoiceDate)} />
            <Fact label="Due date" value={formatDate(document.dueDate)} />
            <Fact label="Place of supply" value={document.placeOfSupply ?? '--'} />
            <Fact label="Reverse charge" value={document.reverseCharge ? 'Yes' : 'No'} />
            <Fact label="Currency" value={currency} />
          </dl>
        </section>

        <aside className="document-card document-card--summary">
          <h2>Settlement</h2>
          <div className="progress-row"><span>Total</span><Money amount={document.totalAmount} currency={currency} /></div>
          <div className="progress-row"><span>Amount paid</span><Money amount={document.amountPaid} currency={currency} /></div>
          <div className="progress-row progress-row--total"><strong>Balance due</strong><Money amount={document.balanceDue} currency={currency} /></div>
        </aside>
      </div>

      <section className="document-card document-card--lines">
        <h2>Invoiced items</h2>
        <DataTable caption="Invoice line items">
          <thead>
            <tr>
              <th scope="col">Item</th>
              <th className="numeric-cell" scope="col">Quantity</th>
              <th className="numeric-cell" scope="col">Rate</th>
              <th className="numeric-cell" scope="col">Discount</th>
              <th scope="col">GST</th>
              <th className="numeric-cell" scope="col">Tax</th>
              <th className="numeric-cell" scope="col">Line total</th>
            </tr>
          </thead>
          <tbody>
            {document.lines.map((line) => (
              <tr key={line.id}>
                <td><div className="cell-stack"><strong>{line.description ?? '--'}</strong><code>{line.hsnCode ? `HSN ${line.hsnCode}` : '--'}{line.batchNumber ? ` · Batch ${line.batchNumber}` : ''}</code></div></td>
                <td className="numeric-cell"><Quantity value={line.quantity} /></td>
                <td className="numeric-cell"><Money amount={line.unitPrice} currency={currency} /></td>
                <td className="numeric-cell">{line.discountPercent === null ? '--' : `${Number(line.discountPercent)}%`}</td>
                <td>{line.gstRate === null ? '--' : `${Number(line.gstRate)}%`}</td>
                <td className="numeric-cell"><Money amount={line.taxAmount} currency={currency} /></td>
                <td className="numeric-cell"><Money amount={line.lineTotal} currency={currency} /></td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      </section>

      <div className="document-layout">
        <section className="document-card">
          <h2>Payment history</h2>
          {payments.isLoading ? (
            <p className="document-loading" aria-live="polite">Loading payments...</p>
          ) : payments.isError ? (
            <p className="document-loading">Payment history could not be loaded.</p>
          ) : payments.data?.length ? (
            <div className="payment-list">
              {payments.data.map((payment) => (
                <div className="payment-entry" key={payment.id}>
                  <div><strong>{payment.paymentNumber}</strong><span>{payment.paymentMethod ? formatStatusLabel(payment.paymentMethod) : 'Method unavailable'} · {formatDate(payment.paymentDate)}{payment.referenceNumber ? ` · Ref ${payment.referenceNumber}` : ''}</span></div>
                  <div className="payment-entry__amount"><StatusChip status={formatStatusLabel(payment.status)} /><Money amount={payment.amount} currency={payment.currency ?? currency} /></div>
                </div>
              ))}
            </div>
          ) : (
            <p className="document-loading">No payments have been recorded for this invoice.</p>
          )}
        </section>
        <aside className="document-card document-card--summary">
          <h2>Invoice total</h2>
          <div className="progress-row"><span>Subtotal</span><Money amount={document.subtotal} currency={currency} /></div>
          <div className="progress-row"><span>GST</span><Money amount={document.taxAmount} currency={currency} /></div>
          <div className="progress-row"><span>TCS</span><Money amount={document.tcsAmount} currency={currency} /></div>
          <div className="progress-row progress-row--total"><strong>Total</strong><Money amount={document.totalAmount} currency={currency} /></div>
        </aside>
      </div>

      <section className="document-card document-card--notes">
        <h2>Commercial notes</h2>
        <div className="document-notes"><span>Notes</span><p>{document.notes ?? '--'}</p></div>
        <div className="document-notes"><span>Terms</span><p>{document.termsAndConditions ?? '--'}</p></div>
      </section>

      <p className="directory-note">This page uses the existing invoice and invoice-payment records. Sending, cancelling, payment collection, sharing, and exports remain in Flutter during the controlled migration.</p>
    </section>
  )
}

function Fact({ label, value }: { label: string; value: string }) {
  return <div><dt>{label}</dt><dd>{value}</dd></div>
}

function DocumentError({ onBack }: { onBack: () => void }) {
  return (
    <section className="workspace-page">
      <div className="directory-state directory-state--error" role="alert">
        <FileText aria-hidden="true" size={24} />
        <strong>Invoice details could not be loaded.</strong>
        <p>The invoice may no longer be available, or you may not have permission to view it.</p>
        <Button onClick={onBack} variant="secondary">Back to invoices</Button>
      </div>
    </section>
  )
}
