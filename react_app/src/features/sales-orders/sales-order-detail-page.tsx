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
import { getSalesOrder } from '@/features/sales-orders/sales-orders-api'

export function SalesOrderDetailPage() {
  const { salesOrderId } = useParams()
  const navigate = useNavigate()
  const order = useQuery({
    queryKey: ['sales-orders', salesOrderId],
    queryFn: () => getSalesOrder(salesOrderId!),
    enabled: Boolean(salesOrderId),
  })

  if (!salesOrderId) return <DocumentError onBack={() => navigate('/sales-orders')} />
  if (order.isLoading) return <section className="workspace-page"><div aria-live="polite" className="directory-state">Loading sales order...</div></section>
  if (order.isError || !order.data) return <DocumentError onBack={() => navigate('/sales-orders')} />

  const salesOrder = order.data
  const currency = salesOrder.currency ?? 'INR'

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Sales / Sales order"
        title={salesOrder.salesOrderNumber}
        description={`${salesOrder.contactName ?? 'Unknown customer'} · ordered ${formatDate(salesOrder.orderDate)}`}
        actions={<StatusChip status={formatStatusLabel(salesOrder.status)} />}
      />

      <div className="document-actions">
        <Button onClick={() => navigate('/sales-orders')} variant="secondary"><ArrowLeft aria-hidden="true" size={16} />Back to orders</Button>
        <StatusChip status="Read-only pilot" />
      </div>

      <div className="document-layout">
        <section className="document-card">
          <h2>Order information</h2>
          <dl className="document-facts">
            <Fact label="Customer" value={salesOrder.contactName ?? '--'} />
            <Fact label="Order date" value={formatDate(salesOrder.orderDate)} />
            <Fact label="Expected shipment" value={formatDate(salesOrder.expectedShipmentDate)} />
            <Fact label="Warehouse" value={salesOrder.warehouseName ?? '--'} />
            <Fact label="Reference" value={salesOrder.referenceNumber ?? '--'} />
            <Fact label="Delivery method" value={salesOrder.deliveryMethod ?? '--'} />
            <Fact label="Place of supply" value={salesOrder.placeOfSupply ?? '--'} />
            <Fact label="Backorders" value={salesOrder.allowBackorder ? 'Allowed' : 'Not allowed'} />
          </dl>
        </section>

        <aside className="document-card document-card--summary">
          <h2>Progress</h2>
          <div className="progress-row"><span>Fulfilment</span><StatusChip status={formatStatusLabel(salesOrder.shippedStatus)} /></div>
          <div className="progress-row"><span>Invoicing</span><StatusChip status={formatStatusLabel(salesOrder.invoicedStatus)} /></div>
          <div className="progress-row"><span>Delivery challans</span><strong>{salesOrder.linkedChallanCount}</strong></div>
          <div className="progress-row"><span>Invoices</span><strong>{salesOrder.linkedInvoiceCount}</strong></div>
        </aside>
      </div>

      <section className="document-card document-card--lines">
        <h2>Ordered items</h2>
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
                <td><div className="cell-stack"><strong>{line.itemName ?? line.description ?? '--'}</strong><code>{line.hsnCode ? `HSN ${line.hsnCode}` : '--'}</code></div></td>
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
      </section>

      <section className="document-layout">
        <section className="document-card">
          <h2>Commercial notes</h2>
          <div className="document-notes"><span>Notes</span><p>{salesOrder.notes ?? '--'}</p></div>
          <div className="document-notes"><span>Terms</span><p>{salesOrder.terms ?? '--'}</p></div>
        </section>
        <aside className="document-card document-card--summary">
          <h2>Order total</h2>
          <div className="progress-row"><span>Subtotal</span><Money amount={salesOrder.subtotal} currency={currency} /></div>
          <div className="progress-row"><span>Tax</span><Money amount={salesOrder.taxAmount} currency={currency} /></div>
          <div className="progress-row"><span>Shipping</span><Money amount={salesOrder.shippingCharge} currency={currency} /></div>
          <div className="progress-row"><span>Adjustment</span><Money amount={salesOrder.adjustment} currency={currency} /></div>
          <div className="progress-row progress-row--total"><strong>Total</strong><Money amount={salesOrder.totalAmount} currency={currency} /></div>
        </aside>
      </section>

      <p className="directory-note">This page reflects the existing Sales Order record. Confirming, cancelling, dispatching, invoicing, and downloading documents remain in Flutter during the controlled migration.</p>
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
        <strong>Sales order details could not be loaded.</strong>
        <p>The order may no longer be available, or you may not have permission to view it.</p>
        <Button onClick={onBack} variant="secondary">Back to orders</Button>
      </div>
    </section>
  )
}
