import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Landmark, Plus } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  DataTable,
  EmptyState,
  Money,
  PageHeader,
  StatusChip,
  TablePagination,
} from '@/design-system'
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
        actions={
          <Button onClick={() => navigate(appRoutes.paymentCreate)} variant="primary">
            <Plus aria-hidden="true" size={16} />
            <span>Record Payment</span>
          </Button>
        }
      />

      <section className="list-panel" aria-label="Customer payment directory">

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
            <TablePagination
              itemLabel="payment"
              onPageChange={(p) => setPage(p)}
              page={paymentPage.page}
              totalElements={paymentPage.totalElements}
              totalPages={paymentPage.totalPages}
            />
          </>
        ) : (
          <EmptyState
            action={
              <Button onClick={() => navigate(appRoutes.paymentCreate)} variant="primary">
                <Plus aria-hidden="true" size={16} />
                <span>Record Payment</span>
              </Button>
            }
            description="Recorded payments and receipts applied to customer invoices will appear here."
            icon={Landmark}
            title="No customer payments found"
          />
        )}
      </section>
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
