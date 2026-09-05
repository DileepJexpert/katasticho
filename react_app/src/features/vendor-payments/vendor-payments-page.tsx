import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { ArrowUpRight, Plus } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  DataTable,
  EmptyState,
  Money,
  PageHeader,
  TablePagination,
} from '@/design-system'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import { listVendorPayments, type VendorPayment } from '@/features/vendor-payments/vendor-payments-api'

export function VendorPaymentsPage() {
  const [page, setPage] = useState(0)
  const navigate = useNavigate()
  const payments = useQuery({
    queryKey: ['vendor-payments', { page }],
    queryFn: () => listVendorPayments({ page }),
  })
  const paymentPage = payments.data
  const createAction = <Button onClick={() => navigate(appRoutes.vendorPaymentCreate)} variant="primary"><Plus size={16} /> Record payment</Button>

  return (
    <section className="workspace-page">
      <PageHeader
        actions={createAction}
        description="Allocated cash, bank, cheque, and UPI disbursements that settle vendor bills and post AP journals."
        eyebrow="Purchases / Payables"
        title="Vendor Payments"
      />

      <section className="list-panel" aria-label="Vendor payment directory">
        {payments.isError ? (
          <div className="directory-state directory-state--error" role="alert"><strong>Vendor payments could not be loaded.</strong><p>Check your connection and permissions, then refresh the page.</p></div>
        ) : payments.isLoading ? (
          <div aria-live="polite" className="directory-state">Loading vendor payments...</div>
        ) : paymentPage?.content.length ? (
          <>
            <DataTable caption="Vendor payments">
              <thead>
                <tr>
                  <th scope="col">Payment</th>
                  <th scope="col">Vendor</th>
                  <th scope="col">Date</th>
                  <th scope="col">Mode</th>
                  <th scope="col">Reference</th>
                  <th className="numeric-cell" scope="col">TDS withheld</th>
                  <th className="numeric-cell" scope="col">Amount</th>
                </tr>
              </thead>
              <tbody>
                {paymentPage.content.map((payment) => <VendorPaymentRow key={payment.id} onOpen={() => navigate(appRoutes.vendorPaymentDetail(payment.id))} payment={payment} />)}
              </tbody>
            </DataTable>
            <TablePagination itemLabel="disbursement" onPageChange={setPage} page={paymentPage.page} totalElements={paymentPage.totalElements} totalPages={paymentPage.totalPages} />
          </>
        ) : (
          <EmptyState action={createAction} description="Record a payment with a vendor, paid-through account, and one or more bill allocations." icon={ArrowUpRight} title="No vendor payments yet" />
        )}
      </section>
    </section>
  )
}

function VendorPaymentRow({ payment, onOpen }: { payment: VendorPayment; onOpen: () => void }) {
  const currency = payment.currency ?? 'INR'
  return (
    <tr>
      <td><Button className="document-link" onClick={onOpen} variant="ghost"><code>{payment.paymentNumber}</code></Button></td>
      <td><strong>{payment.vendorName ?? 'Unknown vendor'}</strong></td>
      <td>{formatDate(payment.paymentDate)}</td>
      <td>{payment.paymentMode ? formatStatusLabel(payment.paymentMode) : '--'}</td>
      <td>{payment.referenceNumber ? <code>{payment.referenceNumber}</code> : <span className="cell-muted">--</span>}</td>
      <td className="numeric-cell">{payment.tdsAmount ? <Money amount={payment.tdsAmount} currency={currency} /> : <span className="cell-muted">--</span>}</td>
      <td className="numeric-cell"><strong><Money amount={payment.amount} currency={currency} /></strong></td>
    </tr>
  )
}
