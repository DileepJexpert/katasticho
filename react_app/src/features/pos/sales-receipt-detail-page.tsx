import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  ArrowLeft,
  FileText,
  Layers,
  Printer,
  RotateCcw,
  Share2,
  User,
} from 'lucide-react'
import { Link, useParams } from 'react-router-dom'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import {
  getReceiptWhatsAppLink,
  getSalesReceipt,
  loadPosReceiptSettings,
  returnSalesReceipt,
} from '@/features/pos/pos-api'

export function SalesReceiptDetailPage() {
  const { receiptId = '' } = useParams<{ receiptId: string }>()
  const queryClient = useQueryClient()
  const [returnReason, setReturnReason] = useState('')
  const [isReturnModalOpen, setIsReturnModalOpen] = useState(false)
  const [feedback, setFeedback] = useState<{ type: 'success' | 'error'; message: string } | null>(null)

  const query = useQuery({
    queryKey: ['sales-receipt', receiptId],
    queryFn: () => getSalesReceipt(receiptId),
    enabled: Boolean(receiptId),
  })

  const returnMutation = useMutation({
    mutationFn: (reason: string) => returnSalesReceipt(receiptId, reason),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['sales-receipt', receiptId] })
      queryClient.invalidateQueries({ queryKey: ['sales-receipts-list'] })
      setIsReturnModalOpen(false)
      setFeedback({
        type: 'success',
        message: 'Sales receipt has been returned/voided. General ledger reversed and stock restored.',
      })
    },
    onError: (err: unknown) => {
      setFeedback({
        type: 'error',
        message: err instanceof Error ? err.message : 'Failed to return receipt.',
      })
    },
  })

  const receipt = query.data
  const settings = loadPosReceiptSettings()

  const handlePrint = () => {
    window.print()
  }

  const handleShareWhatsApp = async () => {
    if (!receipt) return
    try {
      const res = await getReceiptWhatsAppLink(receipt.id)
      if (res.shareUrl) {
        window.open(res.shareUrl, '_blank')
      } else {
        const text = encodeURIComponent(
          `Receipt #${receipt.receiptNumber} from ${settings.storeName}. Total: ₹${receipt.total}. Thank you!`
        )
        window.open(`https://wa.me/?text=${text}`, '_blank')
      }
    } catch {
      const text = encodeURIComponent(
        `Receipt #${receipt.receiptNumber} from ${settings.storeName}. Total: ₹${receipt.total}. Thank you!`
      )
      window.open(`https://wa.me/?text=${text}`, '_blank')
    }
  }

  if (query.isLoading) {
    return (
      <section className="workspace-page">
        <div aria-live="polite" className="directory-state">
          Loading receipt details...
        </div>
      </section>
    )
  }

  if (query.isError || !receipt) {
    return (
      <section className="workspace-page">
        <div className="directory-state directory-state--error" role="alert">
          <FileText aria-hidden="true" size={24} />
          <strong>Receipt not found or inaccessible.</strong>
          <Link className="btn btn--secondary" to="/pos/receipts">
            Back to receipts
          </Link>
        </div>
      </section>
    )
  }

  const isVoided = receipt.status === 'VOIDED' || receipt.status === 'RETURNED'

  return (
    <section className="workspace-page">
      <div style={{ marginBottom: 'var(--space-sm)' }}>
        <Link className="table-row-action" to="/pos/receipts">
          <ArrowLeft aria-hidden="true" size={14} style={{ display: 'inline', marginRight: 4 }} />
          Back to all receipts
        </Link>
      </div>

      {feedback && (
        <div
          className={`banner ${feedback.type === 'success' ? 'banner--success' : 'banner--error'}`}
          role="status"
          style={{ marginBottom: 'var(--space-md)' }}
        >
          <span>{feedback.message}</span>
          <button className="banner-dismiss" onClick={() => setFeedback(null)} type="button">
            ×
          </button>
        </div>
      )}

      <PageHeader
        eyebrow="Sales Receipt Record"
        title={`Receipt #${receipt.receiptNumber}`}
        description={`POS Counter Sale on ${receipt.receiptDate} for ${receipt.contactName || 'Walk-in Cash Customer'}`}
        actions={
          <div style={{ display: 'flex', gap: 'var(--space-sm)' }}>
            <Button onClick={handlePrint} variant="secondary">
              <Printer aria-hidden="true" size={14} style={{ marginRight: 6 }} />
              Print Thermal Slip
            </Button>
            <Button onClick={handleShareWhatsApp} variant="secondary">
              <Share2 aria-hidden="true" size={14} style={{ marginRight: 6 }} />
              Share on WhatsApp
            </Button>
            <StatusChip status={receipt.status || 'POSTED'} />
            {!isVoided && (
              <Button onClick={() => setIsReturnModalOpen(true)} variant="destructive">
                <RotateCcw aria-hidden="true" size={14} style={{ marginRight: 6 }} />
                Return / Void Sale
              </Button>
            )}
          </div>
        }
      />

      <div className="summary-strip">
        <div className="summary-card">
          <span className="summary-card__label">Receipt Date</span>
          <strong className="summary-card__value" style={{ fontSize: '1.1rem' }}>
            {receipt.receiptDate}
          </strong>
          <span className="summary-card__hint">Cash counter checkout</span>
        </div>

        <div className="summary-card">
          <span className="summary-card__label">Payment Tender</span>
          <strong className="summary-card__value" style={{ fontSize: '1.1rem' }}>
            {receipt.paymentMode}
          </strong>
          <span className="summary-card__hint">
            {receipt.upiReference ? `Ref: ${receipt.upiReference}` : 'Counter collection'}
          </span>
        </div>

        <div className="summary-card">
          <span className="summary-card__label">Tendered & Change</span>
          <strong className="summary-card__value" style={{ fontSize: '1.1rem' }}>
            <Money amount={receipt.amountReceived} />
          </strong>
          <span className="summary-card__hint">
            Change Returned: <Money amount={receipt.changeReturned} />
          </span>
        </div>

        <div className="summary-card">
          <span className="summary-card__label">GST Tax Breakup</span>
          <strong className="summary-card__value" style={{ fontSize: '1.1rem' }}>
            <Money amount={receipt.taxAmount} />
          </strong>
          <span className="summary-card__hint">
            CGST: <Money amount={receipt.cgst ?? 0} /> • SGST: <Money amount={receipt.sgst ?? 0} />
          </span>
        </div>

        <div className="summary-card summary-card--accent">
          <span className="summary-card__label">Total Invoice Amount</span>
          <strong className="summary-card__value">
            <Money amount={receipt.total} />
          </strong>
          <span className="summary-card__hint">Net payable</span>
        </div>
      </div>

      {/* Customer & Accounting Context */}
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(2, 1fr)',
          gap: 'var(--space-md)',
          marginBottom: 'var(--space-md)',
        }}
      >
        <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
          <h3 style={{ fontSize: '0.95rem', margin: '0 0 var(--space-xs) 0', display: 'flex', alignItems: 'center', gap: 6 }}>
            <User size={16} /> Customer Information
          </h3>
          <div style={{ fontSize: '0.85rem' }}>
            <strong>{receipt.contactName || 'Walk-in Cash Customer'}</strong>
            {receipt.contactId && (
              <span className="cell-muted" style={{ display: 'block', marginTop: 2 }}>
                ID: <span className="table-code">{receipt.contactId}</span>
              </span>
            )}
            {receipt.notes && (
              <p style={{ marginTop: 6, fontStyle: 'italic' }}>
                Note: {receipt.notes}
              </p>
            )}
          </div>
        </div>

        <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
          <h3 style={{ fontSize: '0.95rem', margin: '0 0 var(--space-xs) 0', display: 'flex', alignItems: 'center', gap: 6 }}>
            <Layers size={16} /> Accounting & Audit Link
          </h3>
          <div style={{ fontSize: '0.85rem' }}>
            <div>
              Journal Entry:{' '}
              {receipt.journalEntryId ? (
                <Link className="table-row-link" to={`/journals/${receipt.journalEntryId}`}>
                  Posted Journal #{receipt.journalEntryId.slice(0, 8)}
                </Link>
              ) : (
                <span className="cell-muted">Auto-posted to Cash/Revenue</span>
              )}
            </div>
            <div style={{ marginTop: 4 }}>
              Offline Sync Ref: {receipt.offlineReceiptNumber || <span className="cell-muted">None (Live counter bill)</span>}
            </div>
          </div>
        </div>
      </div>

      {/* Line Items */}
      <div className="panel-card" style={{ padding: 'var(--space-md)', marginBottom: 'var(--space-md)' }}>
        <h3 style={{ fontSize: '1.05rem', fontWeight: 600, marginBottom: 'var(--space-sm)' }}>
          Line Items ({receipt.lines.length})
        </h3>

        <DataTable caption="Receipt line items">
          <thead>
            <tr>
              <th scope="col">#</th>
              <th scope="col">Item Description</th>
              <th scope="col">HSN</th>
              <th scope="col">Batch & Expiry</th>
              <th className="numeric-cell" scope="col">MRP</th>
              <th className="numeric-cell" scope="col">Rate</th>
              <th className="numeric-cell" scope="col">Qty</th>
              <th className="numeric-cell" scope="col">Discount</th>
              <th className="numeric-cell" scope="col">Amount</th>
            </tr>
          </thead>
          <tbody>
            {receipt.lines.map((line) => (
              <tr key={line.id}>
                <td>{line.lineNumber}</td>
                <td>
                  <div className="cell-stack">
                    <strong>{line.itemName}</strong>
                    {line.itemSku ? <span className="cell-muted">SKU: {line.itemSku}</span> : null}
                  </div>
                </td>
                <td>
                  <span className="table-code">{line.hsnCode || 'â€”'}</span>
                </td>
                <td>
                  {line.batchNumber ? (
                    <div>
                      <span className="cell-muted">B: {line.batchNumber}</span>
                      {line.batchExpiry && (
                        <span className="cell-muted" style={{ display: 'block', fontSize: '0.75rem' }}>
                          Exp: {line.batchExpiry}
                        </span>
                      )}
                    </div>
                  ) : (
                    <span className="cell-muted">â€”</span>
                  )}
                </td>
                <td className="numeric-cell">
                  {line.mrp ? <Money amount={line.mrp} /> : <span className="cell-muted">â€”</span>}
                </td>
                <td className="numeric-cell">
                  <Money amount={line.rate} />
                </td>
                <td className="numeric-cell">
                  <Quantity value={line.quantity} /> {line.unit || ''}
                </td>
                <td className="numeric-cell">
                  {line.discountAmount ? (
                    <Money amount={line.discountAmount} />
                  ) : (
                    <span className="cell-muted">â€”</span>
                  )}
                </td>
                <td className="numeric-cell">
                  <strong>
                    <Money amount={line.amount} />
                  </strong>
                </td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      </div>

      {/* Return Modal */}
      {isReturnModalOpen && (
        <div className="modal-backdrop" role="dialog" aria-modal="true">
          <div className="modal-card">
            <header className="modal-header">
              <h2>Confirm Return / Void Receipt</h2>
              <button className="modal-close" onClick={() => setIsReturnModalOpen(false)} type="button">
                ×
              </button>
            </header>
            <div className="modal-body form-grid">
              <p className="cell-muted" style={{ fontSize: '0.85rem' }}>
                This will reverse the GL journal entry, restore item stock balances in inventory, and deduct the cash/revenue from register totals.
              </p>
              <div className="form-field form-field--full">
                <label htmlFor="returnReason">Return Reason *</label>
                <input
                  id="returnReason"
                  type="text"
                  required
                  value={returnReason}
                  onChange={(e) => setReturnReason(e.target.value)}
                  placeholder="e.g. Customer returned damaged strips, billing error"
                />
              </div>
            </div>
            <footer className="modal-footer">
              <Button onClick={() => setIsReturnModalOpen(false)} variant="secondary">
                Cancel
              </Button>
              <Button
                disabled={returnMutation.isPending || !returnReason.trim()}
                onClick={() => returnMutation.mutate(returnReason.trim())}
                variant="destructive"
              >
                {returnMutation.isPending ? 'Processing Return...' : 'Confirm Return & Restore Stock'}
              </Button>
            </footer>
          </div>
        </div>
      )}
    </section>
  )
}
