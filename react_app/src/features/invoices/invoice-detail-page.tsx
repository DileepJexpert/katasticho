import { useQuery } from '@tanstack/react-query'
import { ArrowLeft } from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  DataTable,
  DocumentCard,
  DocumentError,
  Fact,
  FactList,
  Money,
  PageHeader,
  Quantity,
  StatusChip,
  SummaryRow,
} from '@/design-system'
import { getInvoice, getInvoicePayments } from '@/features/invoices/invoices-api'
import { formatDate, formatStatusLabel } from '@/shared/format/format'

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

  if (!invoiceId) return <DocumentError onBack={() => navigate(appRoutes.invoices)} />
  if (invoice.isLoading) {
    return (
      <section className="workspace-page">
        <div aria-live="polite" className="directory-state">
          Loading invoice...
        </div>
      </section>
    )
  }
  if (invoice.isError || !invoice.data) {
    return <DocumentError onBack={() => navigate(appRoutes.invoices)} />
  }

  const document = invoice.data
  const currency = document.currency ?? 'INR'

  return (
    <section className="workspace-page">
      <PageHeader
        actions={<StatusChip status={formatStatusLabel(document.status)} />}
        description={`${document.contactName ?? 'Unknown customer'} · invoiced ${formatDate(document.invoiceDate)}`}
        eyebrow="Sales / Receivables / Invoice"
        title={document.invoiceNumber}
      />

      <div className="document-actions">
        <Button onClick={() => navigate(appRoutes.invoices)} variant="secondary">
          <ArrowLeft aria-hidden="true" size={16} />
          Back to invoices
        </Button>
      </div>

      <div className="document-layout">
        <DocumentCard title="Invoice Information">
          <FactList columns={2}>
            <Fact label="Customer" value={document.contactName ?? '--'} />
            <Fact label="Invoice Date" value={formatDate(document.invoiceDate)} />
            <Fact label="Due Date" value={formatDate(document.dueDate)} />
            <Fact label="Place of Supply" value={document.placeOfSupply ?? '--'} />
            <Fact label="Reverse Charge" value={document.reverseCharge ? 'Yes' : 'No'} />
            <Fact label="Currency" mono value={currency} />
          </FactList>
        </DocumentCard>

        <DocumentCard title="Settlement" variant="summary">
          <SummaryRow label="Total Amount" value={<Money amount={document.totalAmount} currency={currency} />} />
          <SummaryRow label="Amount Paid" value={<Money amount={document.amountPaid} currency={currency} />} />
          <SummaryRow isTotal label="Balance Due" value={<Money amount={document.balanceDue} currency={currency} />} />
        </DocumentCard>
      </div>

      <DocumentCard title="Invoiced Items" variant="lines">
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
                <td>
                  <div className="cell-stack">
                    <strong>{line.description ?? '--'}</strong>
                    <code>
                      {line.hsnCode ? `HSN ${line.hsnCode}` : '--'}
                      {line.batchNumber ? ` · Batch ${line.batchNumber}` : ''}
                    </code>
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
                <td>{line.gstRate === null ? '--' : `${Number(line.gstRate)}%`}</td>
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
      </DocumentCard>

      <div className="document-layout">
        <DocumentCard title="Payment History">
          {payments.isLoading ? (
            <p aria-live="polite" className="document-loading">Loading payments...</p>
          ) : payments.isError ? (
            <p className="document-loading">Payment history could not be loaded.</p>
          ) : payments.data?.length ? (
            <div className="payment-list">
              {payments.data.map((payment) => (
                <div className="payment-entry" key={payment.id}>
                  <div>
                    <strong>{payment.paymentNumber}</strong>
                    <span>
                      {payment.paymentMethod ? formatStatusLabel(payment.paymentMethod) : 'Method unavailable'} · {formatDate(payment.paymentDate)}
                      {payment.referenceNumber ? ` · Ref ${payment.referenceNumber}` : ''}
                    </span>
                  </div>
                  <div className="payment-entry__amount">
                    <StatusChip status={formatStatusLabel(payment.status)} />
                    <Money amount={payment.amount} currency={payment.currency ?? currency} />
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <p className="document-loading">No payments have been recorded for this invoice.</p>
          )}
        </DocumentCard>

        <DocumentCard title="Invoice Total" variant="summary">
          <SummaryRow label="Subtotal" value={<Money amount={document.subtotal} currency={currency} />} />
          <SummaryRow label="Tax" value={<Money amount={document.taxAmount} currency={currency} />} />
          <SummaryRow label="Discount" value={<Money amount={document.discountAmount} currency={currency} />} />
          <SummaryRow label="Adjustment" value={<Money amount={document.adjustment} currency={currency} />} />
          <SummaryRow isTotal label="Grand Total" value={<Money amount={document.totalAmount} currency={currency} />} />
        </DocumentCard>
      </div>

      <DocumentCard title="Customer & Internal Remarks" variant="notes">
        <div className="document-notes">
          <span>Customer notes</span>
          <p>{document.customerNotes ?? '--'}</p>
        </div>
        <div className="document-notes">
          <span>Terms & conditions</span>
          <p>{document.termsAndConditions ?? '--'}</p>
        </div>
      </DocumentCard>
    </section>
  )
}
