import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  ArrowLeft,
  ArrowRight,
  CheckCircle2,
  Download,
  Send,
  Share2,
  Trash2,
  XCircle,
} from 'lucide-react'
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
  StatusChip,
  SummaryRow,
} from '@/design-system'
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
      navigate(appRoutes.estimates)
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
    return <DocumentError onBack={() => navigate(appRoutes.estimates)} title="Quotation not found or inaccessible" />
  }

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <div style={{ display: 'flex', gap: 'var(--space-2)', flexWrap: 'wrap' }}>
            <Button onClick={handleDownloadPdf} variant="secondary">
              <Download aria-hidden="true" size={14} />
              PDF
            </Button>
            <Button onClick={handleShareWhatsApp} variant="secondary">
              <Share2 aria-hidden="true" size={14} />
              WhatsApp
            </Button>
            {estimate.status === 'DRAFT' && (
              <Button
                disabled={sendMutation.isPending}
                onClick={() => sendMutation.mutate()}
                variant="secondary"
              >
                <Send aria-hidden="true" size={14} />
                Send
              </Button>
            )}
            {estimate.status === 'SENT' && (
              <>
                <Button
                  disabled={acceptMutation.isPending}
                  onClick={() => acceptMutation.mutate()}
                  variant="primary"
                >
                  <CheckCircle2 aria-hidden="true" size={14} />
                  Accept
                </Button>
                <Button
                  disabled={declineMutation.isPending}
                  onClick={() => declineMutation.mutate()}
                  variant="destructive"
                >
                  <XCircle aria-hidden="true" size={14} />
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
                <ArrowRight aria-hidden="true" size={14} />
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
        description={`Prepared for ${estimate.contactName} on ${estimate.estimateDate}`}
        eyebrow="Commercial Quotation"
        title={`Estimate #${estimate.estimateNumber}`}
      />

      <div className="document-actions">
        <Button onClick={() => navigate(appRoutes.estimates)} variant="secondary">
          <ArrowLeft aria-hidden="true" size={16} />
          Back to all estimates
        </Button>
      </div>

      {feedback && (
        <div
          className={`banner ${feedback.type === 'success' ? 'banner--success' : 'banner--error'}`}
          role="status"
          style={{ marginBottom: 'var(--space-4)' }}
        >
          <span>{feedback.message}</span>
          <button className="banner-dismiss" onClick={() => setFeedback(null)} type="button">
            ✕
          </button>
        </div>
      )}

      <div className="document-layout">
        <DocumentCard title="Proposal Information">
          <FactList columns={2}>
            <Fact label="Customer" value={estimate.contactName} />
            <Fact label="Estimate Date" value={estimate.estimateDate} />
            <Fact label="Expiry Date" value={estimate.expiryDate || 'No expiry'} />
            <Fact label="Reference Number" mono value={estimate.referenceNumber || 'None'} />
            <Fact label="Converted Invoice" mono value={estimate.convertedInvoiceId || 'Not converted'} />
            <Fact label="Status" value={<StatusChip status={estimate.status} />} />
          </FactList>
        </DocumentCard>

        <DocumentCard title="Quotation Total" variant="summary">
          <SummaryRow label="Subtotal" value={<Money amount={estimate.subtotal} />} />
          <SummaryRow label="Estimated Tax" value={<Money amount={estimate.taxAmount} />} />
          <SummaryRow isTotal label="Grand Total" value={<Money amount={estimate.total} />} />
        </DocumentCard>
      </div>

      <DocumentCard title="Proposed Line Items" variant="lines">
        <DataTable caption="Estimate line items">
          <thead>
            <tr>
              <th scope="col">Product / Service</th>
              <th scope="col">HSN</th>
              <th className="numeric-cell" scope="col">Rate</th>
              <th className="numeric-cell" scope="col">Qty</th>
              <th className="numeric-cell" scope="col">Disc %</th>
              <th className="numeric-cell" scope="col">Amount</th>
            </tr>
          </thead>
          <tbody>
            {estimate.lines.map((l) => (
              <tr key={l.id}>
                <td>
                  <div className="cell-stack">
                    <strong>{l.itemName}</strong>
                    {l.description ? <span className="cell-muted">{l.description}</span> : null}
                  </div>
                </td>
                <td>{l.hsnCode ? <code>{l.hsnCode}</code> : '--'}</td>
                <td className="numeric-cell"><Money amount={l.rate} /></td>
                <td className="numeric-cell">{l.quantity} {l.unit || 'pcs'}</td>
                <td className="numeric-cell">{l.discountPercentage || 0}%</td>
                <td className="numeric-cell"><strong><Money amount={l.amount} /></strong></td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      </DocumentCard>

      <DocumentCard title="Commercial Terms & Notes" variant="notes">
        <div className="document-notes">
          <span>Customer notes</span>
          <p>{estimate.notes || 'No customer notes specified.'}</p>
        </div>
        <div className="document-notes">
          <span>Terms & conditions</span>
          <p>{estimate.terms || 'No terms & conditions specified.'}</p>
        </div>
      </DocumentCard>
    </section>
  )
}
