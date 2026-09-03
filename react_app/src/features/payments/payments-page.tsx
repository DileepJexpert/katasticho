import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { ChevronLeft, ChevronRight, Landmark } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import { listPayments, type Payment } from '@/features/payments/payments-api'

export function PaymentsPage() {
  const [page, setPage] = useState(0)
  const navigate = useNavigate()

  const payments = useQuery({
    queryKey: ['payments', { page }],
    queryFn: () => listPayments({ page }),
  })
  const paymentPage = payments.data

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Sales / Receivables"
        title="Customer Payments"
        description="Cash, bank, UPI, and cheque collections against customer invoices."
        actions={<StatusChip status="Read-only pilot" />}
      />

      <section className="list-panel" aria-label="Customer payment directory">
        <div className="list-toolbar list-toolbar--stacked">
          <p className="list-toolbar-note">Payment records show customer receipts posted to ledger accounts. Payment recording and voiding remain in Flutter during the controlled migration.</p>
        </div>

        {payments.isError ? (
          <div className="directory-state directory-state--error" role="alert">
            <strong>Customer payments could not be loaded.</strong>
            <p>Check your connection and permissions, then refresh the page.</p>
          </div>
        ) : payments.isLoading ? (
          <div aria-live="polite" className="directory-state">Loading customer payments...</div>
        ) : paymentPage?.content.length ? (
          <>
            <DataTable caption="Customer payments">
              <thead>
                <tr>
                  <th scope="col">Payment #</th>
                  <th scope="col">Customer</th>
                  <th scope="col">Date</th>
                  <th scope="col">Invoice</th>
                  <th scope="col">Payment method</th>
                  <th scope="col">Reference</th>
                  <th scope="col">Status</th>
                  <th className="numeric-cell" scope="col">Amount</th>
                </tr>
              </thead>
              <tbody>
                {paymentPage.content.map((payment) => (
                  <PaymentRow
                    key={payment.id}
                    onOpen={() => navigate(appRoutes.paymentDetail(payment.id))}
                    payment={payment}
                  />
                ))}
              </tbody>
            </DataTable>
            <footer className="table-footer">
              <span>Showing {paymentPage.content.length} of {paymentPage.totalElements} payments · Page {paymentPage.page + 1} of {Math.max(paymentPage.totalPages, 1)}</span>
              <div className="pagination-actions">
                <Button
                  aria-label="Previous page"
                  disabled={page === 0}
                  onClick={() => setPage((current) => Math.max(0, current - 1))}
                  variant="secondary"
                >
                  <ChevronLeft aria-hidden="true" size={16} />
                </Button>
                <Button
                  aria-label="Next page"
                  disabled={paymentPage.last || page + 1 >= paymentPage.totalPages}
                  onClick={() => setPage((current) => current + 1)}
                  variant="secondary"
                >
                  <ChevronRight aria-hidden="true" size={16} />
                </Button>
              </div>
            </footer>
          </>
        ) : (
          <div className="directory-state">
            <Landmark aria-hidden="true" size={24} />
            <strong>No customer payments found</strong>
            <p>Recorded payments and receipts applied to customer invoices will appear here.</p>
          </div>
        )}
      </section>

      <p className="directory-note">Customer receipts credit Accounts Receivable and debit Cash/Bank accounts. Receipt creation, approvals, and reversal workflows remain in Flutter during the controlled migration.</p>
    </section>
  )
}

function PaymentRow({ payment, onOpen }: { payment: Payment; onOpen: () => void }) {
  const currency = payment.currency ?? 'INR'

  return (
    <tr>
      <td>
        <Button className="document-link" onClick={onOpen} variant="ghost">
          <code>{payment.paymentNumber}</code>
        </Button>
      </td>
      <td>
        <div className="cell-stack">
          <strong>{payment.contactName ?? 'Unknown customer'}</strong>
          {payment.bankAccount ? <span className="cell-muted">{payment.bankAccount}</span> : null}
        </div>
      </td>
      <td>{formatDate(payment.paymentDate)}</td>
      <td>
        {payment.invoiceNumber ? (
          <code>{payment.invoiceNumber}</code>
        ) : (
          <span className="cell-muted">Unallocated / Advance</span>
        )}
      </td>
      <td>{payment.paymentMethod ? formatStatusLabel(payment.paymentMethod) : 'Unspecified'}</td>
      <td>
        {payment.referenceNumber ? <code>{payment.referenceNumber}</code> : <span className="cell-muted">--</span>}
      </td>
      <td>
        <StatusChip status={formatStatusLabel(payment.status)} />
      </td>
      <td className="numeric-cell">
        <strong><Money amount={payment.amount} currency={currency} /></strong>
      </td>
    </tr>
  )
}
