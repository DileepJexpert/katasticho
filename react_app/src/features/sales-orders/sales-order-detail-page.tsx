import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, FileText, PackageCheck, Send, Trash2 } from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  CheckboxInput,
  DataTable,
  DocumentCard,
  DocumentError,
  Fact,
  FactList,
  Modal,
  Money,
  NumberInput,
  PageHeader,
  Quantity,
  StatusChip,
  SummaryRow,
} from '@/design-system'
import {
  cancelSalesOrder,
  confirmSalesOrder,
  convertSalesOrderToInvoice,
  getSalesOrder,
} from '@/features/sales-orders/sales-orders-api'
import { formatDate, formatStatusLabel } from '@/shared/format/format'

type InvoiceLineForm = {
  soLineId: string
  label: string
  unit: string | null
  availableQuantity: number
  quantity: number
  included: boolean
}

export function SalesOrderDetailPage() {
  const { salesOrderId } = useParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [feedback, setFeedback] = useState<{ kind: 'error' | 'success'; message: string } | null>(null)
  const [invoiceLines, setInvoiceLines] = useState<InvoiceLineForm[]>([])
  const [isInvoiceModalOpen, setIsInvoiceModalOpen] = useState(false)
  const order = useQuery({
    queryKey: ['sales-orders', salesOrderId],
    queryFn: () => getSalesOrder(salesOrderId!),
    enabled: Boolean(salesOrderId),
  })

  const refreshOrder = () => {
    queryClient.invalidateQueries({ queryKey: ['sales-orders'] })
    queryClient.invalidateQueries({ queryKey: ['sales-orders', salesOrderId] })
    queryClient.invalidateQueries({ queryKey: ['delivery-challans'] })
    queryClient.invalidateQueries({ queryKey: ['invoices'] })
  }

  const confirmMutation = useMutation({
    mutationFn: () => confirmSalesOrder(salesOrderId!),
    onSuccess: (updated) => {
      setFeedback({ kind: 'success', message: `Order confirmed as ${formatStatusLabel(updated.status)}. Available stock is now reserved.` })
      refreshOrder()
    },
    onError: (error: Error) => setFeedback({ kind: 'error', message: error.message }),
  })
  const cancelMutation = useMutation({
    mutationFn: () => cancelSalesOrder(salesOrderId!),
    onSuccess: () => {
      setFeedback({ kind: 'success', message: 'Order cancelled and active stock reservations released.' })
      refreshOrder()
    },
    onError: (error: Error) => setFeedback({ kind: 'error', message: error.message }),
  })
  const invoiceMutation = useMutation({
    mutationFn: () => convertSalesOrderToInvoice(salesOrderId!, {
      lines: invoiceLines.filter((line) => line.included && line.quantity > 0).map((line) => ({
        soLineId: line.soLineId,
        quantity: line.quantity,
      })),
    }),
    onSuccess: (invoice) => {
      queryClient.invalidateQueries({ queryKey: ['invoices'] })
      refreshOrder()
      navigate(appRoutes.invoiceDetail(invoice.id))
    },
    onError: (error: Error) => setFeedback({ kind: 'error', message: error.message }),
  })

  if (!salesOrderId) return <DocumentError onBack={() => navigate(appRoutes.salesOrders)} />
  if (order.isLoading) return <section className="workspace-page"><div aria-live="polite" className="directory-state">Loading sales order...</div></section>
  if (order.isError || !order.data) return <DocumentError onBack={() => navigate(appRoutes.salesOrders)} />

  const salesOrder = order.data
  const currency = salesOrder.currency ?? 'INR'
  const canCreateChallan = ['CONFIRMED', 'PARTIALLY_SHIPPED', 'BACKORDER'].includes(salesOrder.status)
  const canCancel = ['DRAFT', 'CONFIRMED', 'BACKORDER'].includes(salesOrder.status)
  const invoiceableCount = salesOrder.lines.filter((line) => Number(line.quantityShipped) > Number(line.quantityInvoiced)).length

  const openInvoiceModal = () => {
    setFeedback(null)
    setInvoiceLines(salesOrder.lines
      .map((line) => {
        const availableQuantity = Math.max(0, Number(line.quantityShipped) - Number(line.quantityInvoiced))
        return {
          soLineId: line.id,
          label: line.itemName ?? line.description ?? 'Order line',
          unit: line.unit,
          availableQuantity,
          quantity: availableQuantity,
          included: availableQuantity > 0,
        }
      })
      .filter((line) => line.availableQuantity > 0))
    setIsInvoiceModalOpen(true)
  }

  const updateInvoiceLine = (soLineId: string, updates: Partial<InvoiceLineForm>) => {
    setInvoiceLines((previous) => previous.map((line) => line.soLineId === soLineId ? { ...line, ...updates } : line))
  }

  const readyInvoiceLineCount = invoiceLines.filter((line) => line.included && line.quantity > 0).length

  return (
    <section className="workspace-page">
      <PageHeader
        actions={<><StatusChip status={formatStatusLabel(salesOrder.status)} /><Button onClick={() => navigate(appRoutes.salesOrders)} variant="secondary"><ArrowLeft size={16} /> Back to orders</Button></>}
        description={`${salesOrder.contactName ?? 'Unknown customer'} / ordered ${formatDate(salesOrder.orderDate)}`}
        eyebrow="Sales / Sales order"
        title={salesOrder.salesOrderNumber}
      />
      {feedback ? <div className={`banner ${feedback.kind === 'error' ? 'banner--error' : 'banner--success'}`} role="status">{feedback.message}</div> : null}

      <div className="document-layout">
        <DocumentCard title="Order information">
          <FactList columns={2}>
            <Fact label="Customer" value={salesOrder.contactName ?? '--'} />
            <Fact label="Order date" value={formatDate(salesOrder.orderDate)} />
            <Fact label="Expected shipment" value={formatDate(salesOrder.expectedShipmentDate)} />
            <Fact label="Warehouse" value={salesOrder.warehouseName ?? '--'} />
            <Fact label="Reference" mono value={salesOrder.referenceNumber ?? '--'} />
            <Fact label="Delivery method" value={salesOrder.deliveryMethod ?? '--'} />
            <Fact label="Place of supply" value={salesOrder.placeOfSupply ?? '--'} />
            <Fact label="Backorders" value={salesOrder.allowBackorder ? 'Allowed' : 'Not allowed'} />
          </FactList>
        </DocumentCard>

        <DocumentCard title="Fulfilment actions" variant="summary">
          <SummaryRow label="Fulfilment" value={<StatusChip status={formatStatusLabel(salesOrder.shippedStatus)} />} />
          <SummaryRow label="Invoicing" value={<StatusChip status={formatStatusLabel(salesOrder.invoicedStatus)} />} />
          <SummaryRow label="Delivery challans" value={<strong>{salesOrder.linkedChallanCount}</strong>} />
          <SummaryRow label="Invoices" value={<strong>{salesOrder.linkedInvoiceCount}</strong>} />
          <div className="document-card__actions">
            {salesOrder.status === 'DRAFT' ? <Button disabled={confirmMutation.isPending} onClick={() => confirmMutation.mutate()} variant="primary"><PackageCheck size={16} />{confirmMutation.isPending ? 'Confirming...' : 'Confirm order'}</Button> : null}
            {canCreateChallan ? <Button onClick={() => navigate(`${appRoutes.deliveryChallanCreate}?salesOrderId=${encodeURIComponent(salesOrder.id)}`)} variant="primary"><Send size={16} /> Create delivery challan</Button> : null}
            {invoiceableCount > 0 ? <Button onClick={openInvoiceModal} variant="secondary"><FileText size={16} /> Create invoice</Button> : null}
            {canCancel ? <Button disabled={cancelMutation.isPending} onClick={() => cancelMutation.mutate()} variant="destructive"><Trash2 size={16} /> Cancel order</Button> : null}
          </div>
        </DocumentCard>
      </div>

      <DocumentCard title="Ordered items" variant="lines">
        <DataTable caption="Sales order line items">
          <thead>
            <tr><th scope="col">Item</th><th className="numeric-cell" scope="col">Ordered</th><th className="numeric-cell" scope="col">Shipped</th><th className="numeric-cell" scope="col">Invoiced</th><th className="numeric-cell" scope="col">Backordered</th><th className="numeric-cell" scope="col">Rate</th><th scope="col">GST</th><th className="numeric-cell" scope="col">Line total</th></tr>
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
      </DocumentCard>

      <section className="document-layout">
        <DocumentCard title="Commercial notes"><div className="document-notes"><span>Notes</span><p>{salesOrder.notes ?? '--'}</p></div><div className="document-notes"><span>Terms</span><p>{salesOrder.terms ?? '--'}</p></div></DocumentCard>
        <DocumentCard title="Order total" variant="summary"><SummaryRow label="Subtotal" value={<Money amount={salesOrder.subtotal} currency={currency} />} /><SummaryRow label="Tax" value={<Money amount={salesOrder.taxAmount} currency={currency} />} /><SummaryRow label="Shipping" value={<Money amount={salesOrder.shippingCharge} currency={currency} />} /><SummaryRow label="Adjustment" value={<Money amount={salesOrder.adjustment} currency={currency} />} /><SummaryRow isTotal label="Total" value={<Money amount={salesOrder.totalAmount} currency={currency} />} /></DocumentCard>
      </section>

      <Modal
        description="Only dispatched quantities are eligible. This linked conversion posts the invoice without deducting stock a second time."
        footer={<><Button onClick={() => setIsInvoiceModalOpen(false)} type="button" variant="secondary">Cancel</Button><Button disabled={invoiceMutation.isPending || readyInvoiceLineCount === 0} onClick={() => invoiceMutation.mutate()} type="button" variant="primary">{invoiceMutation.isPending ? 'Creating invoice...' : 'Create posted invoice'}</Button></>}
        isOpen={isInvoiceModalOpen}
        onClose={() => setIsInvoiceModalOpen(false)}
        size="lg"
        title="Create customer invoice"
      >
        <DataTable caption="Dispatched order lines to invoice">
          <thead><tr><th scope="col">Include</th><th scope="col">Item</th><th className="numeric-cell" scope="col">Available</th><th className="numeric-cell" scope="col">Invoice quantity</th></tr></thead>
          <tbody>
            {invoiceLines.map((line) => <tr key={line.soLineId}>
              <td><CheckboxInput aria-label={`Include ${line.label}`} checked={line.included} onChange={(event) => updateInvoiceLine(line.soLineId, { included: event.target.checked })} /></td>
              <td><strong>{line.label}</strong></td>
              <td className="numeric-cell"><Quantity unit={line.unit} value={line.availableQuantity} /></td>
              <td className="numeric-cell"><NumberInput disabled={!line.included} max={line.availableQuantity} min={0.001} onChange={(event) => updateInvoiceLine(line.soLineId, { quantity: Math.min(line.availableQuantity, Number(event.target.value) || 0) })} step="0.001" value={line.quantity} /></td>
            </tr>)}
          </tbody>
        </DataTable>
      </Modal>
    </section>
  )
}
