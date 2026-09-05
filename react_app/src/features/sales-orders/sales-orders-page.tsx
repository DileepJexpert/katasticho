import { useEffect, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { FileText, Plus } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  DataTable,
  DirectoryToolbar,
  EmptyState,
  FilterTabs,
  Money,
  PageHeader,
  StatusChip,
  TablePagination,
} from '@/design-system'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import { listSalesOrders, type SalesOrder } from '@/features/sales-orders/sales-orders-api'

const salesOrderFilters = [
  { label: 'All', value: '' },
  { label: 'Draft', value: 'DRAFT' },
  { label: 'Confirmed', value: 'CONFIRMED' },
  { label: 'Backorder', value: 'BACKORDER' },
  { label: 'Partially shipped', value: 'PARTIALLY_SHIPPED' },
  { label: 'Shipped', value: 'SHIPPED' },
  { label: 'Partially invoiced', value: 'PARTIALLY_INVOICED' },
  { label: 'Invoiced', value: 'INVOICED' },
  { label: 'Cancelled', value: 'CANCELLED' },
] as const

type SalesOrderFilter = typeof salesOrderFilters[number]['value']

export function SalesOrdersPage() {
  const [filter, setFilter] = useState<SalesOrderFilter>('')
  const [page, setPage] = useState(0)
  const navigate = useNavigate()

  useEffect(() => {
    setPage(0)
  }, [filter])

  const effectiveStatus = filter === '' ? null : filter
  const orders = useQuery({
    queryKey: ['sales-orders', { page, status: effectiveStatus }],
    queryFn: () => listSalesOrders({ page, status: effectiveStatus }),
  })
  const orderPage = orders.data

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Sales / Fulfilment"
        title="Sales Orders"
        description="Customer commitments, fulfilment progress, and invoicing progress from the existing sales workflow."
        actions={
          <Button onClick={() => navigate(appRoutes.salesOrderCreate)} variant="primary">
            <Plus aria-hidden="true" size={16} />
            <span>New Sales Order</span>
          </Button>
        }
      />

      <section className="list-panel" aria-label="Sales order directory">
        <DirectoryToolbar ariaLabel="Filter sales orders by status">
          <FilterTabs
            activeValue={filter}
            ariaLabel="Filter sales orders by status"
            items={salesOrderFilters}
            onChange={(val) => setFilter(val as SalesOrderFilter)}
          />
        </DirectoryToolbar>

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
            <TablePagination
              filterDescription={filter ? `with ${formatStatusLabel(filter).toLowerCase()} status` : 'in this organisation'}
              isFiltered={Boolean(filter)}
              itemLabel="sales order"
              onPageChange={setPage}
              page={orderPage.page}
              totalElements={orderPage.totalElements}
              totalPages={orderPage.totalPages}
            />
          </>
        ) : (
          <EmptyState
            action={
              <Button onClick={() => navigate(appRoutes.salesOrderCreate)} variant="primary">
                <Plus aria-hidden="true" size={16} />
                <span>New Sales Order</span>
              </Button>
            }
            description={filter ? 'Choose another status to review other orders.' : 'Create your first sales order to begin commercial tracking.'}
            icon={FileText}
            title={`No ${filter ? formatStatusLabel(filter).toLowerCase() : ''} sales orders found.`}
          />
        )}
      </section>
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
