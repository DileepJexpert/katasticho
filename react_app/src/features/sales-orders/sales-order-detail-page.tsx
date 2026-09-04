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
import { getSalesOrder } from '@/features/sales-orders/sales-orders-api'
import { formatDate, formatStatusLabel } from '@/shared/format/format'

export function SalesOrderDetailPage() {
  const { salesOrderId } = useParams()
  const navigate = useNavigate()
  const order = useQuery({
    queryKey: ['sales-orders', salesOrderId],
    queryFn: () => getSalesOrder(salesOrderId!),
    enabled: Boolean(salesOrderId),
  })

  if (!salesOrderId) return <DocumentError onBack={() => navigate(appRoutes.salesOrders)} />
  if (order.isLoading) {
    return (
      <section className="workspace-page">
        <div aria-live="polite" className="directory-state">
          Loading sales order...
        </div>
      </section>
    )
  }
  if (order.isError || !order.data) {
    return <DocumentError onBack={() => navigate(appRoutes.salesOrders)} />
  }

  const salesOrder = order.data
  const currency = salesOrder.currency ?? 'INR'

  return (
    <section className="workspace-page">
      <PageHeader
        actions={<StatusChip status={formatStatusLabel(salesOrder.status)} />}
        description={`${salesOrder.contactName ?? 'Unknown customer'} · ordered ${formatDate(salesOrder.orderDate)}`}
        eyebrow="Sales / Sales order"
        title={salesOrder.salesOrderNumber}
      />

      <div className="document-actions">
        <Button onClick={() => navigate(appRoutes.salesOrders)} variant="secondary">
          <ArrowLeft aria-hidden="true" size={16} />
          Back to orders
        </Button>
      </div>

      <div className="document-layout">
        <DocumentCard title="Order Information">
          <FactList columns={2}>
            <Fact label="Customer" value={salesOrder.contactName ?? '--'} />
            <Fact label="Order Date" value={formatDate(salesOrder.orderDate)} />
            <Fact label="Expected Shipment" value={formatDate(salesOrder.expectedShipmentDate)} />
            <Fact label="Warehouse" value={salesOrder.warehouseName ?? '--'} />
            <Fact label="Reference" mono value={salesOrder.referenceNumber ?? '--'} />
            <Fact label="Delivery Method" value={salesOrder.deliveryMethod ?? '--'} />
            <Fact label="Place of Supply" value={salesOrder.placeOfSupply ?? '--'} />
            <Fact label="Backorders" value={salesOrder.allowBackorder ? 'Allowed' : 'Not allowed'} />
          </FactList>
        </DocumentCard>

        <DocumentCard title="Progress" variant="summary">
          <SummaryRow label="Fulfilment" value={<StatusChip status={formatStatusLabel(salesOrder.shippedStatus)} />} />
          <SummaryRow label="Invoicing" value={<StatusChip status={formatStatusLabel(salesOrder.invoicedStatus)} />} />
          <SummaryRow label="Delivery Challans" value={<strong>{salesOrder.linkedChallanCount}</strong>} />
          <SummaryRow label="Invoices" value={<strong>{salesOrder.linkedInvoiceCount}</strong>} />
        </DocumentCard>
      </div>

      <DocumentCard title="Ordered Items" variant="lines">
        <DataTable caption="Sales order line items">
          <thead>
            <tr>
              <th scope="col">Item</th>
              <th className="numeric-cell" scope="col">Ordered</th>
              <th className="numeric-cell" scope="col">Shipped</th>
              <th className="numeric-cell" scope="col">Invoiced</th>
              <th className="numeric-cell" scope="col">Backordered</th>
              <th className="numeric-cell" scope="col">Rate</th>
              <th scope="col">GST</th>
              <th className="numeric-cell" scope="col">Line total</th>
            </tr>
          </thead>
          <tbody>
            {salesOrder.lines.map((line) => (
              <tr key={line.id}>
                <td>
                  <div className="cell-stack">
                    <strong>{line.itemName ?? line.description ?? '--'}</strong>
                    <code>{line.hsnCode ? `HSN ${line.hsnCode}` : '--'}</code>
                  </div>
                </td>
                <td className="numeric-cell"><Quantity unit={line.unit} value={line.quantity} /></td>
                <td className="numeric-cell"><Quantity unit={line.unit} value={line.quantityShipped} /></td>
                <td className="numeric-cell"><Quantity unit={line.unit} value={line.quantityInvoiced} /></td>
                <td className="numeric-cell"><Quantity unit={line.unit} value={line.quantityBackordered} /></td>
                <td className="numeric-cell"><Money amount={line.rate} currency={currency} /></td>
                <td>{line.taxRate === null ? '--' : `${Number(line.taxRate)}%`}</td>
                <td className="numeric-cell"><Money amount={line.amount} currency={currency} /></td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      </DocumentCard>

      <section className="document-layout">
        <DocumentCard title="Commercial Notes">
          <div className="document-notes"><span>Notes</span><p>{salesOrder.notes ?? '--'}</p></div>
          <div className="document-notes"><span>Terms</span><p>{salesOrder.terms ?? '--'}</p></div>
        </DocumentCard>

        <DocumentCard title="Order Total" variant="summary">
          <SummaryRow label="Subtotal" value={<Money amount={salesOrder.subtotal} currency={currency} />} />
          <SummaryRow label="Tax" value={<Money amount={salesOrder.taxAmount} currency={currency} />} />
          <SummaryRow label="Shipping" value={<Money amount={salesOrder.shippingCharge} currency={currency} />} />
          <SummaryRow label="Adjustment" value={<Money amount={salesOrder.adjustment} currency={currency} />} />
          <SummaryRow isTotal label="Total" value={<Money amount={salesOrder.totalAmount} currency={currency} />} />
        </DocumentCard>
      </section>
    </section>
  )
}
