import { useEffect, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { ChevronLeft, ChevronRight, FileText } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { DataTable } from '@/design-system/data-table'
import { Button } from '@/design-system/button'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import { listSalesOrders, type SalesOrder } from '@/features/sales-orders/sales-orders-api'

const salesOrderFilters = [
  { label: 'All', value: null },
  { label: 'Draft', value: 'DRAFT' },
  { label: 'Pending approval', value: 'PENDING_APPROVAL' },
  { label: 'Confirmed', value: 'CONFIRMED' },
  { label: 'Backorder', value: 'BACKORDER' },
  { label: 'Partial ship', value: 'PARTIALLY_SHIPPED' },
  { label: 'Shipped', value: 'SHIPPED' },
  { label: 'Partial invoice', value: 'PARTIALLY_INVOICED' },
  { label: 'Invoiced', value: 'INVOICED' },
  { label: 'Completed', value: 'COMPLETED' },
  { label: 'Cancelled', value: 'CANCELLED' },
  { label: 'Void', value: 'VOID' },
] as const

type SalesOrderFilter = typeof salesOrderFilters[number]['value']

export function SalesOrdersPage() {
  const [filter, setFilter] = useState<SalesOrderFilter>(null)
  const [page, setPage] = useState(0)
  const navigate = useNavigate()

  useEffect(() => {
    setPage(0)
  }, [filter])

  const orders = useQuery({
    queryKey: ['sales-orders', { page, status: filter }],
    queryFn: () => listSalesOrders({ page, status: filter }),
  })
  const orderPage = orders.data

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Sales"
        title="Sales Orders"
        description="Customer commitments, fulfilment progress, and invoicing progress from the existing sales workflow."
        actions={<StatusChip status="Read-only pilot" />}
      />

      <section className="list-panel" aria-label="Sales order directory">
        <div className="list-toolbar list-toolbar--stacked">
          <div className="role-tabs" aria-label="Filter sales orders by status" role="tablist">
            {salesOrderFilters.map((option) => (
              <button
                aria-selected={filter === option.value}
                className={filter === option.value ? 'role-tab role-tab--active' : 'role-tab'}
                key={option.label}
                onClick={() => setFilter(option.value)}
                role="tab"
                type="button"
              >
                {option.label}
              </button>
            ))}
          </div>
          <p className="list-toolbar-note">Status filters and dates are served by the current Sales Order API. Search is intentionally unavailable because the existing list contract does not support it.</p>
        </div>

        {orders.isError ? (
          <div className="directory-state directory-state--error" role="alert">
            <strong>Sales orders could not be loaded.</strong>
            <p>Check your connection and permissions, then refresh the page.</p>
          </div>
        ) : orders.isLoading ? (
          <div aria-live="polite" className="directory-state">Loading sales orders...</div>
        ) : orderPage?.content.length ? (
          <>
            <DataTable caption="Sales orders">
              <thead>
                <tr>
                  <th scope="col">Order</th>
                  <th scope="col">Customer</th>
                  <th scope="col">Ordered</th>
                  <th scope="col">Ship by</th>
                  <th scope="col">Fulfilment</th>
                  <th scope="col">Documents</th>
                  <th className="numeric-cell" scope="col">Total</th>
                  <th scope="col">Status</th>
                </tr>
              </thead>
              <tbody>
                {orderPage.content.map((order) => <SalesOrderRow key={order.id} onOpen={() => navigate(appRoutes.salesOrderDetail(order.id))} order={order} />)}
              </tbody>
            </DataTable>
            <footer className="table-footer">
              <span>{orderPage.totalElements} order{orderPage.totalElements === 1 ? '' : 's'} {filter ? `with ${formatStatusLabel(filter).toLowerCase()} status` : 'in this organisation'}</span>
              <div className="pagination-actions">
                <button aria-label="Previous page" disabled={orderPage.page === 0} onClick={() => setPage((current) => current - 1)} type="button"><ChevronLeft aria-hidden="true" size={16} /></button>
                <span>Page {orderPage.page + 1} of {Math.max(orderPage.totalPages, 1)}</span>
                <button aria-label="Next page" disabled={orderPage.last} onClick={() => setPage((current) => current + 1)} type="button"><ChevronRight aria-hidden="true" size={16} /></button>
              </div>
            </footer>
          </>
        ) : (
          <div className="directory-state">
            <FileText aria-hidden="true" size={24} />
            <strong>No {filter ? formatStatusLabel(filter).toLowerCase() : ''} sales orders found.</strong>
            <p>{filter ? 'Choose another status to review other orders.' : 'Create sales orders in the existing Flutter workflow while this React module remains read-only.'}</p>
          </div>
        )}
      </section>

      <p className="directory-note">Open an order to review the server-returned commercial, fulfilment, and invoicing data. All workflow actions remain in Flutter during migration.</p>
    </section>
  )
}

function SalesOrderRow({ onOpen, order }: { onOpen: () => void; order: SalesOrder }) {
  return (
    <tr>
      <td><div className="cell-stack"><Button className="document-link" onClick={onOpen} variant="ghost"><code>{order.salesOrderNumber}</code></Button>{order.referenceNumber && <span>Ref: {order.referenceNumber}</span>}</div></td>
      <td><strong>{order.contactName ?? '--'}</strong></td>
      <td>{formatDate(order.orderDate)}</td>
      <td>{formatDate(order.expectedShipmentDate)}</td>
      <td><div className="document-statuses"><StatusChip status={formatStatusLabel(order.shippedStatus)} /><StatusChip status={formatStatusLabel(order.invoicedStatus)} /></div></td>
      <td><span className="cell-muted">{order.linkedChallanCount} challan{order.linkedChallanCount === 1 ? '' : 's'} · {order.linkedInvoiceCount} invoice{order.linkedInvoiceCount === 1 ? '' : 's'}</span></td>
      <td className="numeric-cell"><Money amount={order.totalAmount} currency={order.currency ?? 'INR'} /></td>
      <td><StatusChip status={formatStatusLabel(order.status)} /></td>
    </tr>
  )
}
