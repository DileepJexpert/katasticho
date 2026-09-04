import { useQuery } from '@tanstack/react-query'
import { ArrowLeft, FileText } from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import { getDeliveryChallan } from '@/features/delivery-challans/delivery-challans-api'

export function DeliveryChallanDetailPage() {
  const { challanId } = useParams()
  const navigate = useNavigate()
  const challan = useQuery({
    queryKey: ['delivery-challans', challanId],
    queryFn: () => getDeliveryChallan(challanId!),
    enabled: Boolean(challanId),
  })

  if (!challanId) return <DocumentError onBack={() => navigate('/delivery-challans')} />
  if (challan.isLoading) return <section className="workspace-page"><div aria-live="polite" className="directory-state">Loading delivery challan...</div></section>
  if (challan.isError || !challan.data) return <DocumentError onBack={() => navigate('/delivery-challans')} />

  const document = challan.data

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Sales / Fulfilment / Delivery challan"
        title={document.challanNumber}
        description={`${document.contactName ?? 'Walk-in / Unknown'} · created ${formatDate(document.challanDate)}`}
        actions={<StatusChip status={formatStatusLabel(document.status)} />}
      />

      <div className="document-actions">
        <Button onClick={() => navigate('/delivery-challans')} variant="secondary">
          <ArrowLeft aria-hidden="true" size={16} />
          Back to challans
        </Button>
      </div>

      <div className="document-layout">
        <section className="document-card">
          <h2>Logistics & Dispatch Information</h2>
          <dl className="document-facts">
            <Fact label="Customer" value={document.contactName ?? '--'} />
            <Fact label="Challan date" value={formatDate(document.challanDate)} />
            <Fact label="Dispatch date" value={formatDate(document.dispatchDate)} />
            <Fact label="Warehouse" value={document.warehouseName ?? '--'} />
            <Fact label="Sales order" value={document.salesOrderNumber ?? 'Direct challan'} />
            <Fact label="Delivery method" value={document.deliveryMethod ?? '--'} />
            <Fact label="Vehicle number" value={document.vehicleNumber ?? '--'} />
            <Fact label="Tracking number" value={document.trackingNumber ?? '--'} />
            <Fact label="Shipping address" value={document.shippingAddress ?? '--'} />
          </dl>
        </section>

        <aside className="document-card document-card--summary">
          <h2>Fulfilment summary</h2>
          <div className="progress-row">
            <span>Dispatch status</span>
            <StatusChip status={formatStatusLabel(document.status)} />
          </div>
          <div className="progress-row">
            <span>Invoicing status</span>
            <StatusChip status={formatStatusLabel(document.salesOrderInvoicedStatus ?? 'Pending')} />
          </div>
          <div className="progress-row">
            <span>Line items</span>
            <strong>{document.lines.length}</strong>
          </div>
        </aside>
      </div>

      <section className="document-card document-card--lines">
        <h2>Dispatched line items</h2>
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
      </section>

      <section className="document-card document-card--notes">
        <h2>Dispatch notes</h2>
        <div className="document-notes">
          <span>Notes & Remarks</span>
          <p>{document.notes ?? 'No dispatch notes recorded for this delivery challan.'}</p>
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
        <strong>Delivery challan details could not be loaded.</strong>
        <p>The challan may no longer be available, or you may not have permission to view it.</p>
        <Button onClick={onBack} variant="secondary">Back to challans</Button>
      </div>
    </section>
  )
}
