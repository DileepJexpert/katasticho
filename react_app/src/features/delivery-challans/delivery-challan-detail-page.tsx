import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, CheckCircle2, FileText, Send, Trash2 } from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  DataTable,
  DocumentCard,
  DocumentError,
  Fact,
  FactList,
  PageHeader,
  Quantity,
  StatusChip,
  SummaryRow,
} from '@/design-system'
import {
  cancelDeliveryChallan,
  dispatchDeliveryChallan,
  getDeliveryChallan,
  markDeliveryChallanDelivered,
} from '@/features/delivery-challans/delivery-challans-api'
import { formatDate, formatStatusLabel } from '@/shared/format/format'

export function DeliveryChallanDetailPage() {
  const { challanId } = useParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [feedback, setFeedback] = useState<{ kind: 'error' | 'success'; message: string } | null>(null)
  const challan = useQuery({ queryKey: ['delivery-challans', challanId], queryFn: () => getDeliveryChallan(challanId!), enabled: Boolean(challanId) })

  const refreshChallan = () => {
    queryClient.invalidateQueries({ queryKey: ['delivery-challans'] })
    queryClient.invalidateQueries({ queryKey: ['delivery-challans', challanId] })
  }
  const dispatchMutation = useMutation({
    mutationFn: () => dispatchDeliveryChallan(challanId!),
    onSuccess: () => { setFeedback({ kind: 'success', message: 'Challan dispatched. The server recorded the warehouse stock movement.' }); refreshChallan() },
    onError: (error: Error) => setFeedback({ kind: 'error', message: error.message }),
  })
  const deliveredMutation = useMutation({
    mutationFn: () => markDeliveryChallanDelivered(challanId!),
    onSuccess: () => { setFeedback({ kind: 'success', message: 'Challan marked as delivered.' }); refreshChallan() },
    onError: (error: Error) => setFeedback({ kind: 'error', message: error.message }),
  })
  const cancelMutation = useMutation({
    mutationFn: () => cancelDeliveryChallan(challanId!),
    onSuccess: () => { setFeedback({ kind: 'success', message: 'Draft challan cancelled. No stock was moved.' }); refreshChallan() },
    onError: (error: Error) => setFeedback({ kind: 'error', message: error.message }),
  })

  if (!challanId) return <DocumentError onBack={() => navigate(appRoutes.deliveryChallans)} />
  if (challan.isLoading) return <section className="workspace-page"><div aria-live="polite" className="directory-state">Loading delivery challan...</div></section>
  if (challan.isError || !challan.data) return <DocumentError onBack={() => navigate(appRoutes.deliveryChallans)} />

  const document = challan.data

  return (
    <section className="workspace-page">
      <PageHeader
        actions={<><StatusChip status={formatStatusLabel(document.status)} /><Button onClick={() => navigate(appRoutes.deliveryChallans)} variant="secondary"><ArrowLeft size={16} /> Back to challans</Button></>}
        description={`${document.contactName ?? 'Unknown customer'} / created ${formatDate(document.challanDate)}`}
        eyebrow="Sales / Fulfilment / Delivery challan"
        title={document.challanNumber}
      />
      {feedback ? <div className={`banner ${feedback.kind === 'error' ? 'banner--error' : 'banner--success'}`} role="status">{feedback.message}</div> : null}

      <div className="document-layout">
        <DocumentCard title="Logistics and dispatch information">
          <FactList columns={2}>
            <Fact label="Customer" value={document.contactName ?? '--'} />
            <Fact label="Challan date" value={formatDate(document.challanDate)} />
            <Fact label="Dispatch date" value={formatDate(document.dispatchDate)} />
            <Fact label="Warehouse" value={document.warehouseName ?? '--'} />
            <Fact label="Sales order" mono value={document.salesOrderNumber ?? '--'} />
            <Fact label="Delivery method" value={document.deliveryMethod ?? '--'} />
            <Fact label="Vehicle number" mono value={document.vehicleNumber ?? '--'} />
            <Fact label="Tracking number" mono value={document.trackingNumber ?? '--'} />
            <Fact label="Shipping address" value={document.shippingAddress ?? '--'} />
          </FactList>
        </DocumentCard>

        <DocumentCard title="Dispatch actions" variant="summary">
          <SummaryRow label="Dispatch status" value={<StatusChip status={formatStatusLabel(document.status)} />} />
          <SummaryRow label="Invoicing status" value={<StatusChip status={formatStatusLabel(document.salesOrderInvoicedStatus ?? 'Pending')} />} />
          <SummaryRow label="Line items" value={<strong>{document.lines.length}</strong>} />
          <div className="document-card__actions">
            {document.status === 'DRAFT' ? <Button disabled={dispatchMutation.isPending} onClick={() => dispatchMutation.mutate()} variant="primary"><Send size={16} />{dispatchMutation.isPending ? 'Dispatching...' : 'Dispatch challan'}</Button> : null}
            {document.status === 'DISPATCHED' ? <Button disabled={deliveredMutation.isPending} onClick={() => deliveredMutation.mutate()} variant="secondary"><CheckCircle2 size={16} />{deliveredMutation.isPending ? 'Updating...' : 'Mark delivered'}</Button> : null}
            {document.salesOrderId && ['DISPATCHED', 'DELIVERED'].includes(document.status) ? <Button onClick={() => navigate(appRoutes.salesOrderDetail(document.salesOrderId!))} variant="primary"><FileText size={16} /> Create invoice from order</Button> : null}
            {document.status === 'DRAFT' ? <Button disabled={cancelMutation.isPending} onClick={() => cancelMutation.mutate()} variant="destructive"><Trash2 size={16} /> Cancel draft</Button> : null}
          </div>
        </DocumentCard>
      </div>

      <DocumentCard title="Dispatch line items" variant="lines">
        <DataTable caption="Delivery challan lines">
          <thead><tr><th scope="col">#</th><th scope="col">Item</th><th scope="col">Batch number</th><th className="numeric-cell" scope="col">Dispatch quantity</th></tr></thead>
          <tbody>{document.lines.map((line) => <tr key={line.id}>
            <td>{line.lineNumber}</td>
            <td><div className="cell-stack"><strong>{line.itemName ?? line.description ?? '--'}</strong>{line.description && line.itemName ? <span className="cell-muted">{line.description}</span> : null}</div></td>
            <td>{line.batchNumber ? <code>{line.batchNumber}</code> : <span className="cell-muted">Overall item stock</span>}</td>
            <td className="numeric-cell"><Quantity unit={line.unit} value={line.quantity} /></td>
          </tr>)}</tbody>
        </DataTable>
      </DocumentCard>

      <DocumentCard title="Dispatch notes" variant="notes"><div className="document-notes"><span>Notes and remarks</span><p>{document.notes ?? 'No dispatch notes recorded for this delivery challan.'}</p></div></DocumentCard>
    </section>
  )
}
