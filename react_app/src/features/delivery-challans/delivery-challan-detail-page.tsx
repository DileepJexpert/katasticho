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
  PageHeader,
  Quantity,
  StatusChip,
  SummaryRow,
} from '@/design-system'
import { getDeliveryChallan } from '@/features/delivery-challans/delivery-challans-api'
import { formatDate, formatStatusLabel } from '@/shared/format/format'

export function DeliveryChallanDetailPage() {
  const { challanId } = useParams()
  const navigate = useNavigate()
  const challan = useQuery({
    queryKey: ['delivery-challans', challanId],
    queryFn: () => getDeliveryChallan(challanId!),
    enabled: Boolean(challanId),
  })

  if (!challanId) return <DocumentError onBack={() => navigate(appRoutes.deliveryChallans)} />
  if (challan.isLoading) {
    return (
      <section className="workspace-page">
        <div aria-live="polite" className="directory-state">
          Loading delivery challan...
        </div>
      </section>
    )
  }
  if (challan.isError || !challan.data) {
    return <DocumentError onBack={() => navigate(appRoutes.deliveryChallans)} />
  }

  const document = challan.data

  return (
    <section className="workspace-page">
      <PageHeader
        actions={<StatusChip status={formatStatusLabel(document.status)} />}
        description={`${document.contactName ?? 'Walk-in / Unknown'} · created ${formatDate(document.challanDate)}`}
        eyebrow="Sales / Fulfilment / Delivery challan"
        title={document.challanNumber}
      />

      <div className="document-actions">
        <Button onClick={() => navigate(appRoutes.deliveryChallans)} variant="secondary">
          <ArrowLeft aria-hidden="true" size={16} />
          Back to challans
        </Button>
      </div>

      <div className="document-layout">
        <DocumentCard title="Logistics & Dispatch Information">
          <FactList columns={2}>
            <Fact label="Customer" value={document.contactName ?? '--'} />
            <Fact label="Challan Date" value={formatDate(document.challanDate)} />
            <Fact label="Dispatch Date" value={formatDate(document.dispatchDate)} />
            <Fact label="Warehouse" value={document.warehouseName ?? '--'} />
            <Fact label="Sales Order" mono value={document.salesOrderNumber ?? 'Direct challan'} />
            <Fact label="Delivery Method" value={document.deliveryMethod ?? '--'} />
            <Fact label="Vehicle Number" mono value={document.vehicleNumber ?? '--'} />
            <Fact label="Tracking Number" mono value={document.trackingNumber ?? '--'} />
            <Fact label="Shipping Address" value={document.shippingAddress ?? '--'} />
          </FactList>
        </DocumentCard>

        <DocumentCard title="Fulfilment Summary" variant="summary">
          <SummaryRow label="Dispatch Status" value={<StatusChip status={formatStatusLabel(document.status)} />} />
          <SummaryRow label="Invoicing Status" value={<StatusChip status={formatStatusLabel(document.salesOrderInvoicedStatus ?? 'Pending')} />} />
          <SummaryRow label="Line Items" value={<strong>{document.lines.length}</strong>} />
        </DocumentCard>
      </div>

      <DocumentCard title="Dispatched Line Items" variant="lines">
        <DataTable caption="Delivery challan lines">
          <thead>
            <tr>
              <th scope="col">#</th>
              <th scope="col">Item</th>
              <th scope="col">Batch number</th>
              <th className="numeric-cell" scope="col">Dispatched quantity</th>
            </tr>
          </thead>
          <tbody>
            {document.lines.map((line) => (
              <tr key={line.id}>
                <td>{line.lineNumber}</td>
                <td>
                  <div className="cell-stack">
                    <strong>{line.itemName ?? line.description ?? '--'}</strong>
                    {line.description && line.itemName ? (
                      <span className="cell-muted">{line.description}</span>
                    ) : null}
                  </div>
                </td>
                <td>
                  {line.batchNumber ? (
                    <code>{line.batchNumber}</code>
                  ) : (
                    <span className="cell-muted">Non-batch item</span>
                  )}
                </td>
                <td className="numeric-cell">
                  <Quantity unit={line.unit} value={line.quantity} />
                </td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      </DocumentCard>

      <DocumentCard title="Dispatch Notes" variant="notes">
        <div className="document-notes">
          <span>Notes & Remarks</span>
          <p>{document.notes ?? 'No dispatch notes recorded for this delivery challan.'}</p>
        </div>
      </DocumentCard>
    </section>
  )
}
