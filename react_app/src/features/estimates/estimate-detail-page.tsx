import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  ArrowLeft,
  ArrowRight,
  CheckCircle2,
  Download,
  FileText,
  Send,
  Share2,
  Trash2,
  XCircle,
} from 'lucide-react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import {
  acceptEstimate,
  convertEstimateToInvoice,
  declineEstimate,
  deleteEstimate,
  getEstimate,
  getEstimateWhatsAppLink,
  sendEstimate,
} from '@/features/estimates/estimates-api'

export function EstimateDetailPage() {
  const { estimateId = '' } = useParams<{ estimateId: string }>()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [feedback, setFeedback] = useState<{ type: 'success' | 'error'; message: string } | null>(null)

  const query = useQuery({
    queryKey: ['estimate-detail', estimateId],
    queryFn: () => getEstimate(estimateId),
    enabled: Boolean(estimateId),
  })

  const estimate = query.data

  // Mutations
  const sendMutation = useMutation({
    mutationFn: () => sendEstimate(estimateId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['estimate-detail', estimateId] })
      queryClient.invalidateQueries({ queryKey: ['estimates-list'] })
      setFeedback({ type: 'success', message: 'Quotation sent to client.' })
    },
  })

  const acceptMutation = useMutation({
    mutationFn: () => acceptEstimate(estimateId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['estimate-detail', estimateId] })
      queryClient.invalidateQueries({ queryKey: ['estimates-list'] })
      setFeedback({ type: 'success', message: 'Quotation marked as Accepted by customer.' })
    },
  })

  const declineMutation = useMutation({
    mutationFn: () => declineEstimate(estimateId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['estimate-detail', estimateId] })
      queryClient.invalidateQueries({ queryKey: ['estimates-list'] })
      setFeedback({ type: 'success', message: 'Quotation marked as Declined.' })
    },
  })

  const convertMutation = useMutation({
    mutationFn: () => convertEstimateToInvoice(estimateId),
    onSuccess: (inv) => {
      queryClient.invalidateQueries({ queryKey: ['estimate-detail', estimateId] })
      queryClient.invalidateQueries({ queryKey: ['estimates-list'] })
      queryClient.invalidateQueries({ queryKey: ['invoices-list'] })
      navigate(`/invoices/${inv.id}`)
    },
    onError: (err: unknown) => {
      setFeedback({
        type: 'error',
        message: err instanceof Error ? err.message : 'Conversion to tax invoice failed.',
      })
    },
  })

  const deleteMutation = useMutation({
    mutationFn: () => deleteEstimate(estimateId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['estimates-list'] })
      navigate('/estimates')
    },
  })

  const handleShareWhatsApp = async () => {
    if (!estimate) return
    try {
      const res = await getEstimateWhatsAppLink(estimate.id)
      if (res.shareUrl) {
        window.open(res.shareUrl, '_blank')
      } else {
        const text = encodeURIComponent(
          `Quotation #${estimate.estimateNumber} for ${estimate.contactName}. Total: ₹${estimate.total}. Please review.`
        )
        window.open(`https://wa.me/?text=${text}`, '_blank')
      }
    } catch {
      const text = encodeURIComponent(
        `Quotation #${estimate.estimateNumber} for ${estimate.contactName}. Total: ₹${estimate.total}. Please review.`
      )
      window.open(`https://wa.me/?text=${text}`, '_blank')
    }
  }

  const handleDownloadPdf = () => {
    window.open(`/api/v1/estimates/${estimateId}/pdf`, '_blank')
  }

  if (query.isLoading) {
    return (
      <section className="workspace-page">
        <div aria-live="polite" className="directory-state">
          Loading quotation details...
        </div>
      </section>
    )
  }

  if (query.isError || !estimate) {
    return (
      <section className="workspace-page">
        <div className="directory-state directory-state--error" role="alert">
          <FileText aria-hidden="true" size={24} />
          <strong>Quotation not found or inaccessible.</strong>
          <Link className="btn btn--secondary" to="/estimates">
            Back to estimates
          </Link>
        </div>
      </section>
    )
  }

  return (
    <section className="workspace-page">
      <div style={{ marginBottom: 'var(--space-sm)' }}>
        <Link className="table-row-action" to="/estimates">
          <ArrowLeft aria-hidden="true" size={14} style={{ display: 'inline', marginRight: 4 }} />
          Back to all estimates
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
        eyebrow="Commercial Quotation"
        title={`Estimate #${estimate.estimateNumber}`}
        description={`Prepared for ${estimate.contactName} on ${estimate.estimateDate}`}
        actions={
          <div style={{ display: 'flex', gap: 'var(--space-sm)', flexWrap: 'wrap' }}>
            <Button onClick={handleDownloadPdf} variant="secondary">
              <Download aria-hidden="true" size={14} style={{ marginRight: 6 }} />
              Download PDF
            </Button>
            <Button onClick={handleShareWhatsApp} variant="secondary">
              <Share2 aria-hidden="true" size={14} style={{ marginRight: 6 }} />
              Share WhatsApp
            </Button>
            {estimate.status === 'DRAFT' && (
              <Button
                disabled={sendMutation.isPending}
                onClick={() => sendMutation.mutate()}
                variant="secondary"
              >
                <Send aria-hidden="true" size={14} style={{ marginRight: 6 }} />
                Mark as Sent
              </Button>
            )}
            {estimate.status === 'SENT' && (
              <>
                <Button
                  disabled={acceptMutation.isPending}
                  onClick={() => acceptMutation.mutate()}
                  variant="primary"
                >
                  <CheckCircle2 aria-hidden="true" size={14} style={{ marginRight: 6 }} />
                  Accept
                </Button>
                <Button
                  disabled={declineMutation.isPending}
                  onClick={() => declineMutation.mutate()}
                  variant="destructive"
                >
                  <XCircle aria-hidden="true" size={14} style={{ marginRight: 6 }} />
                  Decline
                </Button>
              </>
            )}
            {(estimate.status === 'ACCEPTED' || estimate.status === 'SENT') && !estimate.convertedInvoiceId && (
              <Button
                disabled={convertMutation.isPending}
                onClick={() => convertMutation.mutate()}
                variant="primary"
              >
                <ArrowRight aria-hidden="true" size={14} style={{ marginRight: 6 }} />
                Convert to Invoice
              </Button>
            )}
            {estimate.status === 'DRAFT' && (
              <Button
                disabled={deleteMutation.isPending}
                onClick={() => {
                  if (confirm('Delete this draft estimate?')) {
                    deleteMutation.mutate()
                  }
                }}
                variant="destructive"
              >
                <Trash2 aria-hidden="true" size={14} />
              </Button>
            )}
          </div>
        }
      />

      {/* Summary Strip */}
      <div className="summary-strip">
        <div className="summary-card">
          <span className="summary-card__label">Estimate Date</span>
          <strong className="summary-card__value" style={{ fontSize: '1.1rem' }}>
            {estimate.estimateDate}
          </strong>
          <span className="summary-card__hint">Expiry: {estimate.expiryDate || 'No expiry'}</span>
        </div>

        <div className="summary-card">
          <span className="summary-card__label">Customer</span>
          <strong className="summary-card__value" style={{ fontSize: '1.1rem' }}>
            {estimate.contactName}
          </strong>
          <span className="summary-card__hint">Ref: {estimate.referenceNumber || 'None'}</span>
        </div>

        <div className="summary-card">
          <span className="summary-card__label">Proposal Status</span>
          <div style={{ marginTop: 4 }}>
            <StatusChip status={estimate.status} />
          </div>
          <span className="summary-card__hint">
            {estimate.convertedInvoiceId ? 'Invoiced' : 'Commercial offer'}
          </span>
        </div>

        <div className="summary-card summary-card--accent">
          <span className="summary-card__label">Total Proposal Value</span>
          <strong className="summary-card__value">
            <Money amount={estimate.total} />
          </strong>
          <span className="summary-card__hint">Tax: <Money amount={estimate.taxAmount} /></span>
        </div>
      </div>

      {/* Converted Invoice Notice Banner */}
      {estimate.convertedInvoiceId && (
        <div className="banner banner--success" style={{ marginBottom: 'var(--space-md)' }}>
          <CheckCircle2 size={16} />
          <span>
            This estimate was converted into a Tax Invoice.{' '}
            <Link to={`/invoices/${estimate.convertedInvoiceId}`} style={{ textDecoration: 'underline', fontWeight: 600 }}>
              View Invoice
            </Link>
          </span>
        </div>
      )}

      {/* Line Items Table */}
      <div className="panel-card" style={{ padding: 'var(--space-md)', marginBottom: 'var(--space-md)' }}>
        <h3 style={{ fontSize: '1.05rem', fontWeight: 600, marginBottom: 'var(--space-sm)' }}>
          Line Items ({estimate.lines.length})
        </h3>

        <DataTable caption="Estimate quotation line items">
          <thead>
            <tr>
              <th scope="col">#</th>
              <th scope="col">Item Description</th>
              <th scope="col">HSN</th>
              <th className="numeric-cell" scope="col">Rate</th>
              <th className="numeric-cell" scope="col">Qty</th>
              <th className="numeric-cell" scope="col">Discount</th>
              <th className="numeric-cell" scope="col">Amount</th>
            </tr>
          </thead>
          <tbody>
            {estimate.lines.map((line, idx) => (
              <tr key={line.id || idx}>
                <td>{idx + 1}</td>
                <td>
                  <div className="cell-stack">
                    <strong>{line.itemName}</strong>
                    {line.description && <span className="cell-muted">{line.description}</span>}
                  </div>
                </td>
                <td>
                  <span className="table-code">{line.hsnCode || 'â€”'}</span>
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

        {/* Totals Box */}
        <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: 'var(--space-md)' }}>
          <div
            style={{
              width: 280,
              display: 'flex',
              flexDirection: 'column',
              gap: 6,
              padding: 'var(--space-md)',
              background: 'var(--color-surface-subtle)',
              borderRadius: 'var(--radius-md)',
            }}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
              <span className="cell-muted">Subtotal:</span>
              <Money amount={estimate.subtotal} />
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
              <span className="cell-muted">Total Tax:</span>
              <Money amount={estimate.taxAmount} />
            </div>
            <div
              style={{
                display: 'flex',
                justifyContent: 'space-between',
                borderTop: '1px solid var(--color-border)',
                paddingTop: 6,
                marginTop: 4,
                fontWeight: 'bold',
                fontSize: '1.05rem',
              }}
            >
              <span>Grand Total:</span>
              <Money amount={estimate.total} />
            </div>
          </div>
        </div>
      </div>

      {/* Notes & Terms */}
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(2, 1fr)',
          gap: 'var(--space-md)',
        }}
      >
        <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
          <h3 style={{ fontSize: '0.95rem', margin: '0 0 var(--space-xs) 0' }}>Customer Notes</h3>
          <p style={{ margin: 0, fontSize: '0.85rem' }} className="cell-muted">
            {estimate.notes || 'No customer notes specified.'}
          </p>
        </div>

        <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
          <h3 style={{ fontSize: '0.95rem', margin: '0 0 var(--space-xs) 0' }}>Terms & Conditions</h3>
          <p style={{ margin: 0, fontSize: '0.85rem' }} className="cell-muted">
            {estimate.terms || 'Standard business terms apply.'}
          </p>
        </div>
      </div>
    </section>
  )
}
