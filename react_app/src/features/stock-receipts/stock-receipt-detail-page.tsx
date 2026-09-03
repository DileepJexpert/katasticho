import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, FileText, PackageCheck, XCircle } from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import { cancelStockReceipt, getStockReceipt, receiveStockReceipt } from './stock-receipts-api'

export function StockReceiptDetailPage() {
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

  if (!receiptId) return <DocumentError onBack={() => navigate('/stock-receipts')} />
  if (receipt.isLoading) return <section className="workspace-page"><div aria-live="polite" className="directory-state">Loading stock receipt...</div></section>
  if (receipt.isError || !receipt.data) return <DocumentError onBack={() => navigate('/stock-receipts')} />

  const document = receipt.data
  const currency = document.currency ?? 'INR'

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Purchases / Inbound Logistics / Stock receipt"
        title={document.receiptNumber}
        description={`${document.supplierName} · Received ${formatDate(document.receiptDate)}`}
        actions={
          <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
            <StatusChip status={formatStatusLabel(document.status)} />
            <Button onClick={() => navigate('/stock-receipts')} variant="secondary">
              <ArrowLeft aria-hidden="true" size={16} />
              Back to receipts
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
          <h2>Receipt information</h2>
          <dl className="document-facts">
            <Fact label="Supplier" value={document.supplierName} />
            <Fact label="Warehouse" value={document.warehouseName} />
            <Fact label="Supplier invoice #" value={document.supplierInvoiceNo ?? 'Not recorded'} />
            <Fact label="Supplier invoice date" value={formatDate(document.supplierInvoiceDate)} />
            <Fact label="GSTIN" value={document.supplierGstin ?? 'Not recorded'} />
            <Fact label="Status" value={formatStatusLabel(document.status)} />
          </dl>
        </section>

        <aside className="document-card document-card--summary">
          <h2>Valuation summary</h2>
          <div className="progress-row">
            <span>Material value</span>
            <Money amount={document.subtotal} currency={currency} />
          </div>
          <div className="progress-row">
            <span>GST input tax</span>
            <Money amount={document.taxAmount} currency={currency} />
          </div>
          <div className="progress-row progress-row--total">
            <strong>Total invoice value</strong>
            <Money amount={document.totalAmount} currency={currency} />
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', marginTop: '16px' }}>
            {document.status === 'DRAFT' ? (
              <Button
                disabled={receiveMutation.isPending}
                onClick={() => receiveMutation.mutate()}
                variant="primary"
              >
                <PackageCheck size={16} />
                {receiveMutation.isPending ? 'Receiving...' : 'Receive Stock into Ledger'}
              </Button>
            ) : null}

            {document.status !== 'CANCELLED' && document.status !== 'RECEIVED' ? (
              <Button
                disabled={cancelMutation.isPending}
                onClick={() => cancelMutation.mutate()}
                variant="destructive"
              >
                <XCircle size={16} />
                Cancel Receipt
              </Button>
            ) : null}
          </div>
        </aside>
      </div>

      <section className="document-card document-card--lines">
        <h2>Received items & batches</h2>
        <DataTable caption="Stock receipt lines">
          <thead>
            <tr>
              <th scope="col">#</th>
              <th scope="col">Item / Batch</th>
              <th className="numeric-cell" scope="col">Quantity</th>
              <th className="numeric-cell" scope="col">Unit price</th>
              <th className="numeric-cell" scope="col">Landed cost</th>
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
                    <strong>{line.description ?? line.itemId}</strong>
                    {line.batchNumber ? (
                      <span className="cell-muted">Batch: {line.batchNumber}</span>
                    ) : null}
                  </div>
                </td>
                <td className="numeric-cell">
                  <Quantity unit={line.unitOfMeasure} value={line.quantity} />
                </td>
                <td className="numeric-cell">
                  <Money amount={line.unitPrice} currency={currency} />
                </td>
                <td className="numeric-cell">
                  <Money amount={line.landedUnitCost} currency={currency} />
                </td>
                <td>{formatDate(line.expiryDate)}</td>
                <td className="numeric-cell">
                  <Money amount={line.lineTotal} currency={currency} />
                </td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      </section>

      <section className="document-card document-card--notes">
        <h2>Receipt notes</h2>
        <div className="document-notes">
          <span>Notes</span>
          <p>{document.notes ?? 'No notes recorded.'}</p>
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
        <strong>Stock receipt details could not be loaded.</strong>
        <p>The receipt record may no longer be available, or you may not have permission to view it.</p>
        <Button onClick={onBack} variant="secondary">Back to receipts</Button>
      </div>
    </section>
  )
}
