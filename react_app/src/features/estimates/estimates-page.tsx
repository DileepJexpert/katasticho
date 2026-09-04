import { useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  ArrowRight,
  FileCheck,
  FileText,
  Plus,
  Send,
  Share2,
} from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import {
  Button,
  DataTable,
  DirectoryToolbar,
  EmptyState,
  FilterTabs,
  Money,
  PageHeader,
  Quantity,
  SearchInput,
  StatusChip,
} from '@/design-system'
import {
  convertEstimateToInvoice,
  getEstimateWhatsAppLink,
  listEstimates,
  sendEstimate,
  type Estimate,
} from '@/features/estimates/estimates-api'

export function EstimatesPage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [searchTerm, setSearchTerm] = useState('')
  const [statusFilter, setStatusFilter] = useState<string>('all')
  const [feedback, setFeedback] = useState<{ type: 'success' | 'error'; message: string } | null>(null)

  const query = useQuery({
    queryKey: ['estimates-list', statusFilter],
    queryFn: () => listEstimates(statusFilter === 'all' ? undefined : statusFilter),
  })

  const estimates: Estimate[] = query.data?.content ?? []

  const filtered = useMemo(() => {
    const term = searchTerm.trim().toLowerCase()
    if (!term) return estimates
    return estimates.filter(
      (e) =>
        e.estimateNumber.toLowerCase().includes(term) ||
        e.contactName.toLowerCase().includes(term) ||
        (e.referenceNumber && e.referenceNumber.toLowerCase().includes(term))
    )
  }, [estimates, searchTerm])

  const totalEstimates = estimates.length
  const pipelineValue = useMemo(() => {
    return estimates
      .filter((e) => e.status === 'DRAFT' || e.status === 'SENT')
      .reduce((sum, e) => sum + Number(e.total || 0), 0)
  }, [estimates])

  const acceptedValue = useMemo(() => {
    return estimates
      .filter((e) => e.status === 'ACCEPTED' || e.status === 'INVOICED')
      .reduce((sum, e) => sum + Number(e.total || 0), 0)
  }, [estimates])

  // Mutations
  const sendMutation = useMutation({
    mutationFn: (id: string) => sendEstimate(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['estimates-list'] })
      setFeedback({ type: 'success', message: 'Estimate marked as Sent to client.' })
    },
  })



  const convertMutation = useMutation({
    mutationFn: (id: string) => convertEstimateToInvoice(id),
    onSuccess: (inv) => {
      queryClient.invalidateQueries({ queryKey: ['estimates-list'] })
      queryClient.invalidateQueries({ queryKey: ['invoices-list'] })
      setFeedback({ type: 'success', message: 'Estimate successfully converted to Tax Invoice.' })
      navigate(`/invoices/${inv.id}`)
    },
    onError: (err: unknown) => {
      setFeedback({
        type: 'error',
        message: err instanceof Error ? err.message : 'Failed to convert estimate to invoice.',
      })
    },
  })

  const handleShareWhatsApp = async (est: Estimate) => {
    try {
      const res = await getEstimateWhatsAppLink(est.id)
      if (res.shareUrl) {
        window.open(res.shareUrl, '_blank')
      } else {
        const text = encodeURIComponent(
          `Quotation #${est.estimateNumber} for ${est.contactName}. Total: ₹${est.total}. Please review and approve.`
        )
        window.open(`https://wa.me/?text=${text}`, '_blank')
      }
    } catch {
      const text = encodeURIComponent(
        `Quotation #${est.estimateNumber} for ${est.contactName}. Total: ₹${est.total}. Please review and approve.`
      )
      window.open(`https://wa.me/?text=${text}`, '_blank')
    }
  }

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Sales & Proposals"
        title="Estimates & Quotations"
        description="Create commercial price proposals, track client approvals, and convert accepted quotes to GST Tax Invoices in one click."
        actions={
          <div style={{ display: 'flex', gap: 'var(--space-sm)' }}>
            <Link className="btn btn--primary" to="/estimates/new">
              <Plus aria-hidden="true" size={14} style={{ marginRight: 6 }} />
              New Estimate
            </Link>
          </div>
        }
      />

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

      {/* Summary Strip */}
      <div className="summary-strip">
        <div className="summary-card">
          <span className="summary-card__label">Total Quotations</span>
          <strong className="summary-card__value">
            <Quantity value={totalEstimates} />
          </strong>
          <span className="summary-card__hint">All issued proposals</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__label">Open Pipeline</span>
          <strong className="summary-card__value">
            <Money amount={pipelineValue} />
          </strong>
          <span className="summary-card__hint">Draft & Sent estimates</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__label">Won / Accepted</span>
          <strong className="summary-card__value" style={{ color: 'var(--color-success)' }}>
            <Money amount={acceptedValue} />
          </strong>
          <span className="summary-card__hint">Accepted & Converted</span>
        </div>
        <div className="summary-card summary-card--accent">
          <span className="summary-card__label">Conversion Rate</span>
          <strong className="summary-card__value">
            {totalEstimates > 0
              ? `${Math.round(
                  (estimates.filter((e) => e.status === 'ACCEPTED' || e.status === 'INVOICED').length /
                    totalEstimates) *
                    100
                )}%`
              : '0%'}
          </strong>
          <span className="summary-card__hint">Win ratio</span>
        </div>
      </div>

      {/* Toolbar */}
      <DirectoryToolbar ariaLabel="Filter estimates by status and keyword">
        <FilterTabs
          activeValue={statusFilter}
          ariaLabel="Filter estimates by status"
          items={[
            { value: 'all', label: 'All Statuses' },
            { value: 'DRAFT', label: 'Draft' },
            { value: 'SENT', label: 'Sent' },
            { value: 'ACCEPTED', label: 'Accepted' },
            { value: 'DECLINED', label: 'Declined' },
            { value: 'INVOICED', label: 'Invoiced' },
            { value: 'EXPIRED', label: 'Expired' },
          ]}
          onChange={setStatusFilter}
        />
        <SearchInput
          ariaLabel="Search estimates"
          onChange={setSearchTerm}
          onClear={() => setSearchTerm('')}
          placeholder="Search estimate #, customer, or ref..."
          value={searchTerm}
        />
      </DirectoryToolbar>

      {/* Data Table */}
      {query.isLoading ? (
        <div aria-live="polite" className="directory-state">
          Loading estimates...
        </div>
      ) : query.isError ? (
        <div className="directory-state directory-state--error" role="alert">
          <FileText aria-hidden="true" size={24} />
          <strong>Unable to load estimates.</strong>
          <Button onClick={() => query.refetch()} variant="secondary">
            Retry
          </Button>
        </div>
      ) : filtered.length === 0 ? (
        <EmptyState
          action={
            <Button onClick={() => setShowCreateModal(true)} variant="primary">
              <Plus aria-hidden="true" size={16} />
              <span>Create Estimate</span>
            </Button>
          }
          description={searchTerm ? 'Try a different search keyword.' : 'Draft a new quote proposal for a customer.'}
          icon={FileCheck}
          title="No estimates found"
        />
      ) : (
        <DataTable caption="Estimates and quotations list">
          <thead>
            <tr>
              <th scope="col">Estimate #</th>
              <th scope="col">Date</th>
              <th scope="col">Expiry</th>
              <th scope="col">Customer</th>
              <th scope="col">Status</th>
              <th className="numeric-cell" scope="col">Subtotal</th>
              <th className="numeric-cell" scope="col">Tax</th>
              <th className="numeric-cell" scope="col">Total</th>
              <th scope="col">Conversion</th>
              <th className="numeric-cell" scope="col">Actions</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((est) => (
              <tr key={est.id}>
                <td>
                  <span className="table-code">
                    <Link className="table-row-link" to={`/estimates/${est.id}`}>
                      {est.estimateNumber}
                    </Link>
                  </span>
                  {est.referenceNumber && (
                    <span className="cell-muted" style={{ display: 'block', fontSize: '0.75rem' }}>
                      Ref: {est.referenceNumber}
                    </span>
                  )}
                </td>
                <td>
                  <span className="cell-muted">{est.estimateDate}</span>
                </td>
                <td>
                  <span className="cell-muted">{est.expiryDate || 'â€”'}</span>
                </td>
                <td>
                  <strong>{est.contactName}</strong>
                </td>
                <td>
                  <StatusChip status={est.status} />
                </td>
                <td className="numeric-cell">
                  <Money amount={est.subtotal} />
                </td>
                <td className="numeric-cell">
                  <Money amount={est.taxAmount} />
                </td>
                <td className="numeric-cell">
                  <strong>
                    <Money amount={est.total} />
                  </strong>
                </td>
                <td>
                  {est.convertedInvoiceId ? (
                    <Link className="table-row-link" to={`/invoices/${est.convertedInvoiceId}`}>
                      Invoice View
                    </Link>
                  ) : est.status === 'ACCEPTED' ? (
                    <span style={{ color: 'var(--color-success)', fontSize: '0.8rem', fontWeight: 600 }}>
                      Ready to Invoice
                    </span>
                  ) : (
                    <span className="cell-muted">â€”</span>
                  )}
                </td>
                <td className="numeric-cell">
                  <div style={{ display: 'inline-flex', gap: 6, alignItems: 'center' }}>
                    <button
                      title="Share Quote on WhatsApp"
                      onClick={() => handleShareWhatsApp(est)}
                      type="button"
                      style={{ background: 'none', border: 'none', color: 'var(--color-primary)', cursor: 'pointer', padding: 4 }}
                    >
                      <Share2 size={15} />
                    </button>
                    {est.status === 'DRAFT' && (
                      <button
                        title="Send to Client"
                        onClick={() => sendMutation.mutate(est.id)}
                        type="button"
                        style={{ background: 'none', border: 'none', color: 'var(--color-primary)', cursor: 'pointer', padding: 4 }}
                      >
                        <Send size={15} />
                      </button>
                    )}
                    {(est.status === 'ACCEPTED' || est.status === 'SENT') && !est.convertedInvoiceId && (
                      <button
                        title="Convert to Tax Invoice"
                        onClick={() => convertMutation.mutate(est.id)}
                        type="button"
                        style={{ background: 'none', border: 'none', color: 'var(--color-success)', cursor: 'pointer', padding: 4 }}
                      >
                        <ArrowRight size={15} />
                      </button>
                    )}
                    <Link className="table-row-action" to={`/estimates/${est.id}`}>
                      View
                    </Link>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      )}
    </section>
  )
}
