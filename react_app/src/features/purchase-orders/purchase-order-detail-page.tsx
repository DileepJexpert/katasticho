import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, FileSpreadsheet, PackageCheck, Send, XCircle } from 'lucide-react'
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
import {
  cancelPurchaseOrder,
  createBillFromPo,
  createGrnFromPo,
  getPurchaseOrder,
  sendPurchaseOrder,
} from './purchase-orders-api'
import { formatDate, formatStatusLabel } from '@/shared/format/format'

export function PurchaseOrderDetailPage() {
  const { orderId } = useParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [feedback, setFeedback] = useState<string | null>(null)

  const order = useQuery({
    queryKey: ['purchase-orders', orderId],
    queryFn: () => getPurchaseOrder(orderId!),
    enabled: Boolean(orderId),
  })

  const sendMutation = useMutation({
    mutationFn: () => sendPurchaseOrder(orderId!),
    onSuccess: () => {
      setFeedback('Purchase order sent to supplier.')
      queryClient.invalidateQueries({ queryKey: ['purchase-orders', orderId] })
    },
    onError: (err: Error) => setFeedback(`Send failed: ${err.message}`),
  })

  const cancelMutation = useMutation({
    mutationFn: () => cancelPurchaseOrder(orderId!),
    onSuccess: () => {
      setFeedback('Purchase order cancelled.')
      queryClient.invalidateQueries({ queryKey: ['purchase-orders', orderId] })
    },
    onError: (err: Error) => setFeedback(`Cancel failed: ${err.message}`),
  })

  const grnMutation = useMutation({
    mutationFn: () => createGrnFromPo(orderId!),
    onSuccess: () => {
      setFeedback('Draft Goods Receipt Note (GRN) generated from this PO.')
      navigate(appRoutes.stockReceipts)
    },
    onError: (err: Error) => setFeedback(`GRN creation failed: ${err.message}`),
  })

  const billMutation = useMutation({
    mutationFn: () => createBillFromPo(orderId!),
    onSuccess: () => {
      setFeedback('Draft Vendor Bill created from this PO.')
      navigate(appRoutes.bills)
    },
    onError: (err: Error) => setFeedback(`Bill creation failed: ${err.message}`),
  })

  if (!orderId) return <DocumentError onBack={() => navigate(appRoutes.purchaseOrders)} />
  if (order.isLoading) {
    return (
      <section className="workspace-page">
        <div aria-live="polite" className="directory-state">
          Loading purchase order...
        </div>
      </section>
    )
  }
  if (order.isError || !order.data) {
    return <DocumentError onBack={() => navigate(appRoutes.purchaseOrders)} />
  }

  const document = order.data

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <div style={{ display: 'flex', gap: 'var(--space-2)', alignItems: 'center' }}>
            <StatusChip status={formatStatusLabel(document.status)} />
            <Button onClick={() => navigate(appRoutes.purchaseOrders)} variant="secondary">
              <ArrowLeft aria-hidden="true" size={16} />
              Back to POs
            </Button>
          </div>
        }
        description={`${document.supplierName} · Ordered ${formatDate(document.orderDate)}`}
        eyebrow="Purchases / Procurement / Purchase order"
        title={document.poNumber}
      />

      {feedback && (
        <div
          className="banner banner--success"
          role="status"
          style={{ marginBottom: 'var(--space-4)' }}
        >
          <span>{feedback}</span>
          <button className="banner-dismiss" onClick={() => setFeedback(null)} type="button">✕</button>
        </div>
      )}

      <div className="document-layout">
        <DocumentCard title="Purchase Order Facts">
          <FactList columns={2}>
            <Fact label="Supplier" value={document.supplierName} />
            <Fact label="Order Date" value={formatDate(document.orderDate)} />
            <Fact label="Expected Delivery" value={document.expectedDeliveryDate ? formatDate(document.expectedDeliveryDate) : 'Not specified'} />
            <Fact label="Total Lines" value={`${document.lines?.length ?? 0} items`} />
            <Fact label="Status" value={formatStatusLabel(document.status)} />
          </FactList>
        </DocumentCard>

        <DocumentCard title="Order Actions" variant="summary">
          <SummaryRow label="Fulfilment Status" value={<StatusChip status={formatStatusLabel(document.status)} />} />
          <SummaryRow isTotal label="Total Order Amount" value={<Money amount={document.totalAmount} />} />

          <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-2)', marginTop: 'var(--space-3)' }}>
            {document.status === 'DRAFT' && (
              <Button
                disabled={sendMutation.isPending}
                onClick={() => sendMutation.mutate()}
                variant="primary"
              >
                <Send size={16} />
                {sendMutation.isPending ? 'Sending...' : 'Send to Supplier'}
              </Button>
            )}

            {document.status === 'ISSUED' && (
              <>
                <Button
                  disabled={grnMutation.isPending}
                  onClick={() => grnMutation.mutate()}
                  variant="primary"
                >
                  <PackageCheck size={16} />
                  {grnMutation.isPending ? 'Creating GRN...' : 'Receive Stock (GRN)'}
                </Button>
                <Button
                  disabled={billMutation.isPending}
                  onClick={() => billMutation.mutate()}
                  variant="secondary"
                >
                  <FileSpreadsheet size={16} />
                  {billMutation.isPending ? 'Creating Bill...' : 'Create Vendor Bill'}
                </Button>
              </>
            )}

            {document.status !== 'CANCELLED' && document.status !== 'FULFILLED' && (
              <Button
                disabled={cancelMutation.isPending}
                onClick={() => cancelMutation.mutate()}
                variant="destructive"
              >
                <XCircle size={16} />
                Cancel Order
              </Button>
            )}
          </div>
        </DocumentCard>
      </div>

      <DocumentCard title="Ordered Items" variant="lines">
        {document.lines?.length ? (
          <DataTable caption="Purchase order lines">
            <thead>
              <tr>
                <th scope="col">#</th>
                <th scope="col">Item Description</th>
                <th className="numeric-cell" scope="col">Quantity</th>
                <th className="numeric-cell" scope="col">Unit Cost</th>
                <th className="numeric-cell" scope="col">Line Total</th>
              </tr>
            </thead>
            <tbody>
              {document.lines.map((line) => (
                <tr key={line.id}>
                  <td>{line.lineNumber}</td>
                  <td>
                    <div className="cell-stack">
                      <strong>{line.itemName || line.description}</strong>
                      {line.description && line.itemName ? (
                        <span className="cell-muted">{line.description}</span>
                      ) : null}
                    </div>
                  </td>
                  <td className="numeric-cell">
                    <Quantity value={line.quantity} />
                  </td>
                  <td className="numeric-cell">
                    <Money amount={line.unitPrice} />
                  </td>
                  <td className="numeric-cell">
                    <strong>
                      <Money amount={line.lineTotal} />
                    </strong>
                  </td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        ) : (
          <div className="directory-state" style={{ minHeight: 120 }}>
            No line items recorded for this purchase order.
          </div>
        )}
      </DocumentCard>

      {document.notes && (
        <DocumentCard title="Delivery Notes & Remarks" variant="notes">
          <div className="document-notes">
            <span>Special instructions</span>
            <p>{document.notes}</p>
          </div>
        </DocumentCard>
      )}
    </section>
  )
}
