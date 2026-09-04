import { useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import {
  ArrowLeft,
  Calendar,
  CheckCircle2,
  Clock,
  Package,
  RefreshCw,
  Truck,
  Warehouse,
  XCircle,
} from 'lucide-react'
import {
  Button,
  DataTable,
  DocumentCard,
  PageHeader,
  Quantity,
  StatusChip,
} from '@/design-system'
import {
  getTransferOrder,
  shipTransferOrder,
  receiveTransferOrder,
  cancelTransferOrder,
} from '@/features/inventory/transfer-orders-api'

export function TransferOrderDetailPage() {
  const { transferOrderId } = useParams<{ transferOrderId: string }>()
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const [actionError, setActionError] = useState<string | null>(null)
  const [actionSuccess, setActionSuccess] = useState<string | null>(null)

  const {
    data: order,
    isLoading,
    isError,
    error,
    refetch,
  } = useQuery({
    queryKey: ['inventory', 'transfer-order', transferOrderId],
    queryFn: () => getTransferOrder(transferOrderId!),
    enabled: Boolean(transferOrderId),
  })

  const shipMutation = useMutation({
    mutationFn: () => shipTransferOrder(transferOrderId!),
    onSuccess: () => {
      setActionSuccess('Transfer order dispatched successfully.')
      setActionError(null)
      queryClient.invalidateQueries({ queryKey: ['inventory', 'transfer-order', transferOrderId] })
      queryClient.invalidateQueries({ queryKey: ['inventory', 'transfer-orders'] })
    },
    onError: (err: Error) => {
      setActionError(err.message || 'Failed to dispatch transfer order.')
      setActionSuccess(null)
    },
  })

  const receiveMutation = useMutation({
    mutationFn: () => receiveTransferOrder(transferOrderId!),
    onSuccess: () => {
      setActionSuccess('Transfer order goods received and inventory updated.')
      setActionError(null)
      queryClient.invalidateQueries({ queryKey: ['inventory', 'transfer-order', transferOrderId] })
      queryClient.invalidateQueries({ queryKey: ['inventory', 'transfer-orders'] })
    },
    onError: (err: Error) => {
      setActionError(err.message || 'Failed to receive transfer order.')
      setActionSuccess(null)
    },
  })

  const cancelMutation = useMutation({
    mutationFn: () => cancelTransferOrder(transferOrderId!),
    onSuccess: () => {
      setActionSuccess('Transfer order cancelled.')
      setActionError(null)
      queryClient.invalidateQueries({ queryKey: ['inventory', 'transfer-order', transferOrderId] })
      queryClient.invalidateQueries({ queryKey: ['inventory', 'transfer-orders'] })
    },
    onError: (err: Error) => {
      setActionError(err.message || 'Failed to cancel transfer order.')
      setActionSuccess(null)
    },
  })

  if (isLoading) {
    return (
      <section className="workspace-page">
        <PageHeader
          eyebrow="Inventory & Logistics"
          title="Stock Transfer Order"
          description="Loading transfer order details..."
        />
        <div className="p-8 text-secondary">Loading transfer order...</div>
      </section>
    )
  }

  if (isError || !order) {
    return (
      <section className="workspace-page">
        <PageHeader
          actions={
            <Button onClick={() => navigate('/transfer-orders')} variant="secondary">
              <ArrowLeft size={15} aria-hidden="true" />
              <span>Back to Transfers</span>
            </Button>
          }
          eyebrow="Inventory & Logistics"
          title="Transfer Not Found"
          description={(error as Error)?.message || 'The requested transfer order could not be located.'}
        />
        <div className="p-8 text-danger">Transfer order not found.</div>
      </section>
    )
  }

  const isDraft = order.status === 'DRAFT'
  const isShipped = order.status === 'SHIPPED'
  const isReceived = order.status === 'RECEIVED'
  const isCancelled = order.status === 'CANCELLED'

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <div className="flex items-center gap-2">
            <Button onClick={() => navigate('/transfer-orders')} variant="secondary">
              <ArrowLeft size={15} aria-hidden="true" />
              <span>All Transfers</span>
            </Button>

            <Button onClick={() => refetch()} variant="secondary" aria-label="Refresh order">
              <RefreshCw size={15} aria-hidden="true" />
            </Button>

            {isDraft && (
              <>
                <Button
                  disabled={shipMutation.isPending || cancelMutation.isPending}
                  onClick={() => shipMutation.mutate()}
                  variant="primary"
                >
                  <Truck size={15} aria-hidden="true" />
                  <span>{shipMutation.isPending ? 'Dispatching...' : 'Dispatch Shipment'}</span>
                </Button>
                <Button
                  disabled={cancelMutation.isPending || shipMutation.isPending}
                  onClick={() => cancelMutation.mutate()}
                  variant="secondary"
                >
                  <XCircle size={15} aria-hidden="true" />
                  <span>{cancelMutation.isPending ? 'Cancelling...' : 'Cancel'}</span>
                </Button>
              </>
            )}

            {isShipped && (
              <>
                <Button
                  disabled={receiveMutation.isPending || cancelMutation.isPending}
                  onClick={() => receiveMutation.mutate()}
                  variant="primary"
                >
                  <CheckCircle2 size={15} aria-hidden="true" />
                  <span>{receiveMutation.isPending ? 'Receiving...' : 'Confirm Receipt'}</span>
                </Button>
                <Button
                  disabled={cancelMutation.isPending || receiveMutation.isPending}
                  onClick={() => cancelMutation.mutate()}
                  variant="secondary"
                >
                  <XCircle size={15} aria-hidden="true" />
                  <span>{cancelMutation.isPending ? 'Cancelling...' : 'Cancel'}</span>
                </Button>
              </>
            )}
          </div>
        }
        eyebrow="Inventory & Logistics • Transfer Execution"
        title={order.transferNumber}
        description={`Internal inventory transfer between ${order.fromWarehouseName} and ${order.toWarehouseName}.`}
      />

      <div className="dashboard-workspace">
        {/* Feedback alerts */}
        {actionSuccess && (
          <div
            className="p-3 text-sm rounded bg-emerald-50 text-emerald-800 border border-emerald-200 flex items-center gap-2"
            role="status"
          >
            <CheckCircle2 size={16} className="text-emerald-600 flex-none" />
            <span>{actionSuccess}</span>
          </div>
        )}

        {actionError && (
          <div
            className="p-3 text-sm rounded bg-rose-50 text-rose-800 border border-rose-200 flex items-center gap-2"
            role="alert"
          >
            <XCircle size={16} className="text-rose-600 flex-none" />
            <span>{actionError}</span>
          </div>
        )}

        {/* ── Transfer Route & Milestone Strip ── */}
        <div className="metric-grid">
          <article className="metric-card">
            <span className="metric-icon">
              <Warehouse size={18} aria-hidden="true" />
            </span>
            <div className="metric-content">
              <span className="metric-label">Source Location (From)</span>
              <span className="text-base font-semibold text-primary">{order.fromWarehouseName}</span>
              <span className="metric-footnote">Origin warehouse</span>
            </div>
          </article>

          <article className="metric-card">
            <span className="metric-icon">
              <Truck size={18} aria-hidden="true" />
            </span>
            <div className="metric-content">
              <span className="metric-label">Destination Location (To)</span>
              <span className="text-base font-semibold text-primary">{order.toWarehouseName}</span>
              <span className="metric-footnote">Target warehouse</span>
            </div>
          </article>

          <article className="metric-card">
            <span className="metric-icon">
              <Calendar size={18} aria-hidden="true" />
            </span>
            <div className="metric-content">
              <span className="metric-label">Transfer Date</span>
              <span className="text-base font-semibold font-mono text-primary">{order.transferDate}</span>
              <span className="metric-footnote">Scheduled order date</span>
            </div>
          </article>

          <article className="metric-card metric-card--brand">
            <span className="metric-icon">
              {isReceived ? (
                <CheckCircle2 size={18} aria-hidden="true" />
              ) : isShipped ? (
                <Truck size={18} aria-hidden="true" />
              ) : isCancelled ? (
                <XCircle size={18} aria-hidden="true" />
              ) : (
                <Clock size={18} aria-hidden="true" />
              )}
            </span>
            <div className="metric-content">
              <span className="metric-label">Fulfillment Status</span>
              <div className="mt-1">
                <StatusChip status={order.status} />
              </div>
              <span className="metric-footnote">
                {isDraft && 'Pending dispatch'}
                {isShipped && 'In transit between sites'}
                {isReceived && 'Received & stocked'}
                {isCancelled && 'Cancelled order'}
              </span>
            </div>
          </article>
        </div>

        {/* ── Order Metadata & Transit Log ── */}
        <DocumentCard title="Order Specifications & Audit">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm">
            <div>
              <span className="text-xs font-semibold text-muted uppercase tracking-wider block mb-1">
                Transfer Reference
              </span>
              <span className="font-mono font-bold text-primary">{order.transferNumber}</span>
            </div>

            <div>
              <span className="text-xs font-semibold text-muted uppercase tracking-wider block mb-1">
                Shipped Timestamp
              </span>
              <span className="font-mono text-primary">
                {order.shippedAt ? new Date(order.shippedAt).toLocaleString('en-IN') : '—'}
              </span>
            </div>

            <div>
              <span className="text-xs font-semibold text-muted uppercase tracking-wider block mb-1">
                Received Timestamp
              </span>
              <span className="font-mono text-primary">
                {order.receivedAt ? new Date(order.receivedAt).toLocaleString('en-IN') : '—'}
              </span>
            </div>

            {order.notes && (
              <div className="md:col-span-3 pt-2 border-t border-subtle">
                <span className="text-xs font-semibold text-muted uppercase tracking-wider block mb-1">
                  Transfer Instructions & Remarks
                </span>
                <p className="text-secondary text-sm">{order.notes}</p>
              </div>
            )}
          </div>
        </DocumentCard>

        {/* ── Transfer Line Items Table ── */}
        <DocumentCard title={`Manifest Items (${order.lines?.length ?? order.lineCount ?? 0})`}>
          {order.lines && order.lines.length > 0 ? (
            <DataTable caption="Transfer order line items and quantities">
              <thead>
                <tr>
                  <th scope="col" style={{ width: '40px' }}>#</th>
                  <th scope="col">Item Details</th>
                  <th scope="col">SKU</th>
                  <th scope="col">Batch Number</th>
                  <th className="numeric-cell" scope="col">Transferred Qty</th>
                  {order.lines.some((l) => l.receivedQuantity !== undefined) && (
                    <th className="numeric-cell" scope="col">Received Qty</th>
                  )}
                  <th scope="col">Notes</th>
                </tr>
              </thead>
              <tbody>
                {order.lines.map((line, index) => (
                  <tr key={line.id || index}>
                    <td className="text-muted font-mono text-xs">{index + 1}</td>
                    <td>
                      <strong>{line.itemName || 'Catalog Item'}</strong>
                    </td>
                    <td>
                      <span className="font-mono text-xs text-muted">{line.sku || '—'}</span>
                    </td>
                    <td>
                      {line.batchNumber ? (
                        <span className="font-mono text-xs font-semibold text-brand">
                          {line.batchNumber}
                        </span>
                      ) : (
                        <span className="text-muted text-xs">Standard Lot</span>
                      )}
                    </td>
                    <td className="numeric-cell">
                      <Quantity amount={line.quantity} />
                    </td>
                    {order.lines?.some((l) => l.receivedQuantity !== undefined) && (
                      <td className="numeric-cell">
                        <Quantity amount={line.receivedQuantity ?? 0} />
                      </td>
                    )}
                    <td>
                      <span className="text-xs text-secondary">{line.notes || '—'}</span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          ) : (
            <div className="p-6 text-center text-secondary text-sm">
              <Package size={28} className="mx-auto mb-2 text-muted opacity-40" />
              <span>No item lines recorded on this transfer order.</span>
            </div>
          )}
        </DocumentCard>
      </div>
    </section>
  )
}
