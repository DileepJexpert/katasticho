import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, FileSpreadsheet, FileText, PackageCheck, Send, XCircle } from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import {
  cancelPurchaseOrder,
  createBillFromPo,
  createGrnFromPo,
  getPurchaseOrder,
  sendPurchaseOrder,
} from './purchase-orders-api'

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
      navigate('/stock-receipts')
    },
    onError: (err: Error) => setFeedback(`GRN creation failed: ${err.message}`),
  })

  const billMutation = useMutation({
    mutationFn: () => createBillFromPo(orderId!),
    onSuccess: () => {
      setFeedback('Draft Vendor Bill created from this PO.')
      navigate('/bills')
    },
    onError: (err: Error) => setFeedback(`Bill creation failed: ${err.message}`),
  })

  if (!orderId) return <DocumentError onBack={() => navigate('/purchase-orders')} />
  if (order.isLoading) return <section className="workspace-page"><div aria-live="polite" className="directory-state">Loading purchase order...</div></section>
  if (order.isError || !order.data) return <DocumentError onBack={() => navigate('/purchase-orders')} />

  const document = order.data

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Purchases / Procurement / Purchase order"
        title={document.poNumber}
        description={`${document.supplierName} · Ordered ${formatDate(document.orderDate)}`}
        actions={
          <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
            <StatusChip status={formatStatusLabel(document.status)} />
            <Button onClick={() => navigate('/purchase-orders')} variant="secondary">
              <ArrowLeft aria-hidden="true" size={16} />
              Back to POs
            </Button>
          </div>
        }
      />

      {feedback ? (
        <div className="alert-banner" style={{ background: '#0F857615', border: '1px solid #0F8576', padding: '12px 16px', borderRadius: '6px', color: '#0F8576', marginBottom: '16px' }}>
          {feedback}
        </div>
      ) : null}

      <div className="document-layout">
        <section className="document-card">
          <h2>Purchase order facts</h2>
          <dl className="document-facts">
            <Fact label="Supplier" value={document.supplierName} />
            <Fact label="Order date" value={formatDate(document.orderDate)} />
            <Fact label="Expected delivery" value={document.expectedDeliveryDate ? formatDate(document.expectedDeliveryDate) : 'Not specified'} />
            <Fact label="Total lines" value={`${document.lines?.length ?? 0} items`} />
            <Fact label="Status" value={formatStatusLabel(document.status)} />
          </dl>
        </section>

        <aside className="document-card document-card--summary">
          <h2>Order Actions</h2>
          <div className="progress-row">
            <span>Fulfilment status</span>
            <StatusChip status={formatStatusLabel(document.status)} />
          </div>
          <div className="summary-row summary-row--total">
            <span>Total order amount</span>
            <Money amount={document.totalAmount} />
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', marginTop: '16px' }}>
            {document.status === 'DRAFT' ? (
              <Button
                disabled={sendMutation.isPending}
                onClick={() => sendMutation.mutate()}
                variant="primary"
              >
                <Send size={16} />
                {sendMutation.isPending ? 'Sending...' : 'Send to Supplier'}
              </Button>
            ) : null}

            {document.status === 'SENT' || document.status === 'PARTIALLY_RECEIVED' ? (
              <>
                <Button
                  disabled={grnMutation.isPending}
                  onClick={() => grnMutation.mutate()}
                  variant="primary"
                >
                  <PackageCheck size={16} />
                  {grnMutation.isPending ? 'Generating...' : 'Receive Stock (Create GRN)'}
                </Button>
                <Button
                  disabled={billMutation.isPending}
                  onClick={() => billMutation.mutate()}
                  variant="secondary"
                >
                  <FileSpreadsheet size={16} />
                  {billMutation.isPending ? 'Generating...' : 'Create Vendor Bill'}
                </Button>
              </>
            ) : null}

            {document.status !== 'CANCELLED' && document.status !== 'RECEIVED' ? (
              <Button
                disabled={cancelMutation.isPending}
                onClick={() => cancelMutation.mutate()}
                variant="destructive"
              >
                <XCircle size={16} />
                Cancel Order
              </Button>
            ) : null}
          </div>
        </aside>
      </div>

      <section className="document-card document-card--lines">
        <h2>Ordered items & fulfilment</h2>
        {document.lines?.length ? (
          <DataTable caption="Purchase order lines">
            <thead>
              <tr>
                <th scope="col">Item / Description</th>
                <th className="numeric-cell" scope="col">Ordered qty</th>
                <th className="numeric-cell" scope="col">Received qty</th>
                <th className="numeric-cell" scope="col">Unit price</th>
                <th className="numeric-cell" scope="col">Line total</th>
              </tr>
            </thead>
            <tbody>
              {document.lines.map((line) => (
                <tr key={line.id}>
                  <td>
                    <div className="cell-stack">
                      <strong>{line.itemName ?? '--'}</strong>
                      {line.description ? <span className="cell-muted">{line.description}</span> : null}
                    </div>
                  </td>
                  <td className="numeric-cell">
                    <Quantity value={line.quantity} />
                  </td>
                  <td className="numeric-cell">
                    <Quantity value={line.receivedQuantity ?? 0} />
                  </td>
                  <td className="numeric-cell">
                    <Money amount={line.unitPrice} />
                  </td>
                  <td className="numeric-cell">
                    <Money amount={line.lineTotal} />
                  </td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        ) : (
          <p className="document-loading">No line items recorded for this purchase order.</p>
        )}
      </section>

      <section className="document-card document-card--notes">
        <h2>Order instructions</h2>
        <div className="document-notes">
          <span>Notes</span>
          <p>{document.notes ?? 'No remarks recorded.'}</p>
        </div>
      </section>
    </section>
  )
}

function Fact({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt>{label}</dt>
      <dd>{value}</dd>
    </div>
  )
}

function DocumentError({ onBack }: { onBack: () => void }) {
  return (
    <section className="workspace-page">
      <div className="directory-state directory-state--error" role="alert">
        <FileText aria-hidden="true" size={24} />
        <strong>Purchase order details could not be loaded.</strong>
        <p>The purchase order record may no longer be available, or you may not have permission to view it.</p>
        <Button onClick={onBack} variant="secondary">Back to purchase orders</Button>
      </div>
    </section>
  )
}
