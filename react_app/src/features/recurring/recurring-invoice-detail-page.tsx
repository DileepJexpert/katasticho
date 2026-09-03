import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  ArrowLeft,
  Clock,
  FileText,
  Pause,
  Play,
  Zap,
} from 'lucide-react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import {
  generateRecurringInvoiceNow,
  getRecurringInvoice,
  listGeneratedInvoices,
  resumeRecurringInvoice,
  stopRecurringInvoice,
} from '@/features/recurring/recurring-api'

export function RecurringInvoiceDetailPage() {
  const { profileId = '' } = useParams<{ profileId: string }>()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [feedback, setFeedback] = useState<{ type: 'success' | 'error'; message: string } | null>(null)

  const query = useQuery({
    queryKey: ['recurring-invoice-detail', profileId],
    queryFn: () => getRecurringInvoice(profileId),
    enabled: Boolean(profileId),
  })

  const historyQuery = useQuery({
    queryKey: ['recurring-invoice-history', profileId],
    queryFn: () => listGeneratedInvoices(profileId),
    enabled: Boolean(profileId),
  })

  const profile = query.data
  const history = historyQuery.data ?? []

  // Mutations
  const stopMutation = useMutation({
    mutationFn: () => stopRecurringInvoice(profileId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['recurring-invoice-detail', profileId] })
      setFeedback({ type: 'success', message: 'Recurring schedule stopped / paused.' })
    },
  })

  const resumeMutation = useMutation({
    mutationFn: () => resumeRecurringInvoice(profileId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['recurring-invoice-detail', profileId] })
      setFeedback({ type: 'success', message: 'Recurring schedule resumed.' })
    },
  })

  const generateNowMutation = useMutation({
    mutationFn: () => generateRecurringInvoiceNow(profileId),
    onSuccess: (inv) => {
      queryClient.invalidateQueries({ queryKey: ['recurring-invoice-detail', profileId] })
      queryClient.invalidateQueries({ queryKey: ['recurring-invoice-history', profileId] })
      queryClient.invalidateQueries({ queryKey: ['invoices-list'] })
      setFeedback({ type: 'success', message: 'Invoice generated immediately.' })
      navigate(`/invoices/${inv.id}`)
    },
    onError: (err: unknown) => {
      setFeedback({
        type: 'error',
        message: err instanceof Error ? err.message : 'Immediate invoice generation failed.',
      })
    },
  })

  if (query.isLoading) {
    return (
      <section className="workspace-page">
        <div className="directory-state">Loading recurring profile...</div>
      </section>
    )
  }

  if (query.isError || !profile) {
    return (
      <section className="workspace-page">
        <div className="directory-state directory-state--error">
          <FileText size={24} />
          <strong>Recurring invoice schedule not found.</strong>
          <Link className="btn btn--secondary" to="/recurring-invoices">
            Back to recurring invoices
          </Link>
        </div>
      </section>
    )
  }

  const isActive = profile.status === 'ACTIVE'

  return (
    <section className="workspace-page">
      <div style={{ marginBottom: 'var(--space-sm)' }}>
        <Link className="table-row-action" to="/recurring-invoices">
          <ArrowLeft size={14} style={{ display: 'inline', marginRight: 4 }} />
          Back to all recurring schedules
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
        eyebrow="Recurring Invoice Profile"
        title={profile.profileName}
        description={`Customer: ${profile.contactName} • Frequency: ${profile.frequency}`}
        actions={
          <div style={{ display: 'flex', gap: 'var(--space-sm)' }}>
            <Button
              disabled={generateNowMutation.isPending}
              onClick={() => generateNowMutation.mutate()}
              variant="secondary"
            >
              <Zap size={14} style={{ marginRight: 6 }} />
              Generate Invoice Now
            </Button>
            {isActive ? (
              <Button
                disabled={stopMutation.isPending}
                onClick={() => stopMutation.mutate()}
                variant="destructive"
              >
                <Pause size={14} style={{ marginRight: 6 }} />
                Pause Schedule
              </Button>
            ) : (
              <Button
                disabled={resumeMutation.isPending}
                onClick={() => resumeMutation.mutate()}
                variant="primary"
              >
                <Play size={14} style={{ marginRight: 6 }} />
                Resume Schedule
              </Button>
            )}
          </div>
        }
      />

      {/* Summary Strip */}
      <div className="summary-strip">
        <div className="summary-card">
          <span className="summary-card__label">Next Run Date</span>
          <strong className="summary-card__value" style={{ fontSize: '1.1rem' }}>
            {profile.nextInvoiceDate || 'No future run'}
          </strong>
          <span className="summary-card__hint">Start: {profile.startDate}</span>
        </div>

        <div className="summary-card">
          <span className="summary-card__label">Cycle Frequency</span>
          <strong className="summary-card__value" style={{ fontSize: '1.1rem' }}>
            {profile.frequency}
          </strong>
          <span className="summary-card__hint">Terms: {profile.paymentTermsDays} days</span>
        </div>

        <div className="summary-card">
          <span className="summary-card__label">Schedule Status</span>
          <div style={{ marginTop: 4 }}>
            <StatusChip status={profile.status} />
          </div>
          <span className="summary-card__hint">{profile.totalGenerated} invoices generated</span>
        </div>

        <div className="summary-card summary-card--accent">
          <span className="summary-card__label">Amount per Invoice</span>
          <strong className="summary-card__value">
            <Money amount={profile.templateTotal} />
          </strong>
          <span className="summary-card__hint">Auto-minted bill value</span>
        </div>
      </div>

      {/* Line Items */}
      <div className="panel-card" style={{ padding: 'var(--space-md)', marginBottom: 'var(--space-md)' }}>
        <h3 style={{ fontSize: '1.05rem', margin: '0 0 var(--space-sm) 0' }}>Template Line Items</h3>
        <DataTable caption="Template line items">
          <thead>
            <tr>
              <th scope="col">Description</th>
              <th scope="col">HSN</th>
              <th className="numeric-cell" scope="col">Rate</th>
              <th className="numeric-cell" scope="col">Qty</th>
              <th className="numeric-cell" scope="col">Amount</th>
            </tr>
          </thead>
          <tbody>
            {profile.lineItems.map((l, idx) => (
              <tr key={idx}>
                <td>
                  <strong>{l.description || 'Service Line'}</strong>
                </td>
                <td>
                  <span className="table-code">{l.hsnCode || 'â€”'}</span>
                </td>
                <td className="numeric-cell">
                  <Money amount={l.rate} />
                </td>
                <td className="numeric-cell">
                  <Quantity value={l.quantity} /> {l.unit || ''}
                </td>
                <td className="numeric-cell">
                  <strong>
                    <Money amount={l.amount} />
                  </strong>
                </td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      </div>

      {/* History Log */}
      <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
        <h3 style={{ fontSize: '1.05rem', margin: '0 0 var(--space-sm) 0' }}>Generated Invoices History</h3>
        {history.length === 0 ? (
          <div className="directory-state" style={{ padding: 'var(--space-md)' }}>
            <Clock size={20} />
            <p>No invoices minted yet from this schedule.</p>
          </div>
        ) : (
          <DataTable caption="Minted invoices history">
            <thead>
              <tr>
                <th scope="col">Invoice #</th>
                <th scope="col">Invoice Date</th>
                <th scope="col">Generated At</th>
                <th className="numeric-cell" scope="col">Total Amount</th>
                <th className="numeric-cell" scope="col">Action</th>
              </tr>
            </thead>
            <tbody>
              {history.map((h) => (
                <tr key={h.invoiceId}>
                  <td>
                    <span className="table-code">
                      <Link className="table-row-link" to={`/invoices/${h.invoiceId}`}>
                        {h.invoiceNumber || h.invoiceId.slice(0, 8)}
                      </Link>
                    </span>
                  </td>
                  <td>
                    <span className="cell-muted">{h.invoiceDate}</span>
                  </td>
                  <td>
                    <span className="cell-muted">{new Date(h.generatedAt).toLocaleString()}</span>
                  </td>
                  <td className="numeric-cell">
                    <strong>
                      <Money amount={h.total} />
                    </strong>
                  </td>
                  <td className="numeric-cell">
                    <Link className="table-row-action" to={`/invoices/${h.invoiceId}`}>
                      View Invoice
                    </Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        )}
      </div>
    </section>
  )
}
