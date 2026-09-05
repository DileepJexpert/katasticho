import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, PackageCheck, XCircle } from 'lucide-react'
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
import { cancelStockReceipt, getStockReceipt, receiveStockReceipt } from './stock-receipts-api'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import { useInventoryAccess } from '@/features/inventory/inventory-access'

export function StockReceiptDetailPage() {
  const inventoryAccess = useInventoryAccess()
  const { receiptId } = useParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [feedback, setFeedback] = useState<string | null>(null)

  const receipt = useQuery({
    queryKey: ['stock-receipts', receiptId],
    queryFn: () => getStockReceipt(receiptId!),
    enabled: Boolean(receiptId),
  })

  const receiveMutation = useMutation({
    mutationFn: () => receiveStockReceipt(receiptId!),
    onSuccess: () => {
      setFeedback('Stock successfully received into warehouse inventory balance.')
      queryClient.invalidateQueries({ queryKey: ['stock-receipts', receiptId] })
    },
    onError: (err: Error) => setFeedback(`Receive error: ${err.message}`),
  })

  const cancelMutation = useMutation({
    mutationFn: () => cancelStockReceipt(receiptId!, 'Cancelled by user'),
    onSuccess: () => {
      setFeedback('Stock receipt cancelled.')
      queryClient.invalidateQueries({ queryKey: ['stock-receipts', receiptId] })
    },
    onError: (err: Error) => setFeedback(`Cancel error: ${err.message}`),
  })

  if (!receiptId) return <DocumentError onBack={() => navigate(appRoutes.stockReceipts)} />
  if (receipt.isLoading) {
    return (
      <section className="workspace-page">
        <div aria-live="polite" className="directory-state">
          Loading stock receipt...
        </div>
      </section>
    )
  }
  if (receipt.isError || !receipt.data) {
    return <DocumentError onBack={() => navigate(appRoutes.stockReceipts)} />
  }

  const document = receipt.data
  const currency = document.currency ?? 'INR'

  return (
    <section className="workspace-page">
      <PageHeader
        actions={<>
          <StatusChip status={formatStatusLabel(document.status)} />
          {document.status === 'RECEIVED' && inventoryAccess.operate && <Button variant="secondary" onClick={() => navigate(`${appRoutes.putawayCreate}?receiptId=${encodeURIComponent(document.id)}`)}>Create putaway task</Button>}
          <Button onClick={() => navigate(appRoutes.stockReceipts)} variant="secondary">
            <ArrowLeft aria-hidden="true" size={16} />
            Back to receipts
          </Button>
        </>}
        description={`${document.supplierName} · Received ${formatDate(document.receiptDate)}`}
        eyebrow="Purchases / Inbound Logistics / Stock receipt"
        title={document.receiptNumber}
      />

      {feedback && (
        <div className="banner banner--success" role="status">
          <span>{feedback}</span>
          <button className="banner-dismiss" onClick={() => setFeedback(null)} type="button">✕</button>
        </div>
      )}

      <div className="document-layout">
        <DocumentCard title="Receipt Information">
          <FactList columns={2}>
            <Fact label="Supplier" value={document.supplierName} />
            <Fact label="Warehouse" value={document.warehouseName} />
            <Fact label="Source purchase order" mono value={document.purchaseOrderId ? 'Linked PO' : 'Direct receipt'} />
            <Fact label="Supplier Invoice #" mono value={document.supplierInvoiceNo ?? 'Not recorded'} />
            <Fact label="Supplier Invoice Date" value={formatDate(document.supplierInvoiceDate)} />
            <Fact label="GSTIN" mono value={document.supplierGstin ?? 'Not recorded'} />
            <Fact label="Status" value={formatStatusLabel(document.status)} />
          </FactList>
        </DocumentCard>

        <DocumentCard title="Valuation Summary" variant="summary">
          <SummaryRow label="Material Value" value={<Money amount={document.subtotal} currency={currency} />} />
          <SummaryRow label="GST Input Tax" value={<Money amount={document.taxAmount} currency={currency} />} />
          <SummaryRow label="Freight" value={<Money amount={document.freightAmount} currency={currency} />} />
          <SummaryRow label="Duty" value={<Money amount={document.dutyAmount} currency={currency} />} />
          <SummaryRow label="Insurance" value={<Money amount={document.insuranceAmount} currency={currency} />} />
          <SummaryRow label="Other charges" value={<Money amount={document.otherCharges} currency={currency} />} />
          <SummaryRow isTotal label="Total Invoice Value" value={<Money amount={document.totalAmount} currency={currency} />} />

          <div className="document-card__actions">
            {document.status === 'DRAFT' && (
              <Button
                disabled={receiveMutation.isPending}
                onClick={() => receiveMutation.mutate()}
                variant="primary"
              >
                <PackageCheck size={16} />
                {receiveMutation.isPending ? 'Receiving...' : 'Receive Stock into Ledger'}
              </Button>
            )}

            {document.status !== 'CANCELLED' && document.status !== 'RECEIVED' && (
              <Button
                disabled={cancelMutation.isPending}
                onClick={() => cancelMutation.mutate()}
                variant="destructive"
              >
                <XCircle size={16} />
                Cancel Receipt
              </Button>
            )}
          </div>
        </DocumentCard>
      </div>

      <DocumentCard title="Received Items & Batches" variant="lines">
        <DataTable caption="Stock receipt lines">
          <thead>
            <tr>
              <th scope="col">#</th>
              <th scope="col">Item / Batch</th>
              <th className="numeric-cell" scope="col">Quantity</th>
              <th className="numeric-cell" scope="col">Unit price</th>
              <th className="numeric-cell" scope="col">Discount</th>
              <th className="numeric-cell" scope="col">Landed cost</th>
              <th scope="col">Mfg</th>
              <th scope="col">Expiry</th>
              <th className="numeric-cell" scope="col">Line total</th>
            </tr>
          </thead>
          <tbody>
            {document.lines.map((line) => (
              <tr key={line.id}>
                <td>{line.lineNumber}</td>
                <td>
                  <div className="cell-stack">
                    <strong>{line.itemName}</strong>
                    {line.batchNumber ? <code>Batch {line.batchNumber}</code> : null}
                  </div>
                </td>
                <td className="numeric-cell"><Quantity value={line.quantity} /></td>
                <td className="numeric-cell"><Money amount={line.unitPrice} currency={currency} /></td>
                <td className="numeric-cell">{line.discountPercent ?? 0}%</td>
                <td className="numeric-cell"><Money amount={line.landedUnitCost} currency={currency} /></td>
                <td>{line.manufacturingDate ? formatDate(line.manufacturingDate) : '--'}</td>
                <td>{line.expiryDate ? formatDate(line.expiryDate) : '--'}</td>
                <td className="numeric-cell"><strong><Money amount={line.lineTotal} currency={currency} /></strong></td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      </DocumentCard>
    </section>
  )
}
