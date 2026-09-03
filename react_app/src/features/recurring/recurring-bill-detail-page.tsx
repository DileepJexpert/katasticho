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
  generateRecurringBillNow,
  getRecurringBill,
  listGeneratedBills,
  resumeRecurringBill,
  stopRecurringBill,
} from '@/features/recurring/recurring-api'

export function RecurringBillDetailPage() {
  const { profileId = '' } = useParams<{ profileId: string }>()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [feedback, setFeedback] = useState<{ type: 'success' | 'error'; message: string } | null>(null)

  const query = useQuery({
    queryKey: ['recurring-bill-detail', profileId],
    queryFn: () => getRecurringBill(profileId),
    enabled: Boolean(profileId),
  })

  const historyQuery = useQuery({
    queryKey: ['recurring-bill-history', profileId],
    queryFn: () => listGeneratedBills(profileId),
    enabled: Boolean(profileId),
  })

  const profile = query.data
  const history = historyQuery.data ?? []

  // Mutations
  const stopMutation = useMutation({
    mutationFn: () => stopRecurringBill(profileId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['recurring-bill-detail', profileId] })
      setFeedback({ type: 'success', message: 'Recurring bill schedule paused.' })
    },
  })

  const resumeMutation = useMutation({
    mutationFn: () => resumeRecurringBill(profileId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['recurring-bill-detail', profileId] })
      setFeedback({ type: 'success', message: 'Recurring bill schedule resumed.' })
    },
  })

  const generateNowMutation = useMutation({
    mutationFn: () => generateRecurringBillNow(profileId),
    onSuccess: (res) => {
      queryClient.invalidateQueries({ queryKey: ['recurring-bill-detail', profileId] })
      queryClient.invalidateQueries({ queryKey: ['recurring-bill-history', profileId] })
      queryClient.invalidateQueries({ queryKey: ['bills-list'] })
      if (res.billId) {
        navigate(`/bills/${res.billId}`)
      } else {
        setFeedback({ type: 'success', message: 'Bill generated successfully.' })
      }
    },
    onError: (err: unknown) => {
      setFeedback({
        type: 'error',
        message: err instanceof Error ? err.message : 'Bill generation failed.',
      })
    },
  })

  if (query.isLoading) {
    return (
      <section className="workspace-page">
        <div className="directory-state">Loading recurring bill...</div>
      </section>
    )
  }

  if (query.isError || !profile) {
    return (
      <section className="workspace-page">
        <div className="directory-state directory-state--error">
          <FileText size={24} />
          <strong>Recurring bill profile not found.</strong>
          <Link className="btn btn--secondary" to="/recurring-bills">
            Back to recurring bills
          </Link>
        </div>
      </section>
    )
  }

  return (
    <section className="workspace-page">
      <div style={{ marginBottom: 'var(--space-sm)' }}>
        <Link className="table-row-action" to="/recurring-bills">
          <ArrowLeft size={14} style={{ display: 'inline', marginRight: 4 }} />
          Back to all recurring bills
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
        eyebrow="Recurring Bill Schedule"
        title={profile.profileName}
        description={`Frequency: ${profile.frequency} • Next run: ${profile.nextBillDate || 'None'}`}
        actions={
          <div style={{ display: 'flex', gap: 'var(--space-sm)' }}>
            <Button
              disabled={generateNowMutation.isPending}
              onClick={() => generateNowMutation.mutate()}
              variant="secondary"
            >
              <Zap size={14} style={{ marginRight: 6 }} />
              Generate Bill Now
            </Button>
            {profile.status === 'ACTIVE' ? (
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
          <span className="summary-card__label">Next Bill Date</span>
          <strong className="summary-card__value" style={{ fontSize: '1.1rem' }}>
            {profile.nextBillDate || 'None'}
          </strong>
          <span className="summary-card__hint">Cycle: {profile.frequency}</span>
        </div>

        <div className="summary-card">
          <span className="summary-card__label">Schedule Status</span>
          <div style={{ marginTop: 4 }}>
            <StatusChip status={profile.status} />
          </div>
          <span className="summary-card__hint">{profile.totalGenerated} bills generated</span>
        </div>

        <div className="summary-card summary-card--accent">
          <span className="summary-card__label">Auto-Post to GL</span>
          <strong className="summary-card__value" style={{ fontSize: '1.1rem' }}>
            {profile.autoPost ? 'Enabled' : 'Draft Only'}
          </strong>
          <span className="summary-card__hint">AP ledger impact</span>
        </div>
      </div>

      {/* Line Items */}
      <div className="panel-card" style={{ padding: 'var(--space-md)', marginBottom: 'var(--space-md)' }}>
        <h3 style={{ fontSize: '1.05rem', margin: '0 0 var(--space-sm) 0' }}>Bill Template Line Items</h3>
        <DataTable caption="Template bill lines">
          <thead>
            <tr>
              <th scope="col">Description</th>
              <th className="numeric-cell" scope="col">Rate</th>
              <th className="numeric-cell" scope="col">Qty</th>
              <th className="numeric-cell" scope="col">Amount</th>
            </tr>
          </thead>
          <tbody>
            {profile.lineItems.map((l, idx) => (
              <tr key={idx}>
                <td>
                  <strong>{l.description}</strong>
                </td>
                <td className="numeric-cell">
                  <Money amount={l.rate} />
                </td>
                <td className="numeric-cell">
                  <Quantity value={l.quantity} />
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

      {/* History */}
      <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
        <h3 style={{ fontSize: '1.05rem', margin: '0 0 var(--space-sm) 0' }}>Generated Bills Log</h3>
        {history.length === 0 ? (
          <div className="directory-state" style={{ padding: 'var(--space-md)' }}>
            <Clock size={20} />
            <p>No bills generated yet from this schedule.</p>
          </div>
        ) : (
          <DataTable caption="Minted bills history">
            <thead>
              <tr>
                <th scope="col">Bill ID</th>
                <th scope="col">Generated Timestamp</th>
                <th scope="col">Auto-Posted</th>
                <th className="numeric-cell" scope="col">Action</th>
              </tr>
            </thead>
            <tbody>
              {history.map((h) => (
                <tr key={h.billId}>
                  <td>
                    <span className="table-code">
                      <Link className="table-row-link" to={`/bills/${h.billId}`}>
                        {h.billId.slice(0, 8)}
                      </Link>
                    </span>
                  </td>
                  <td>
                    <span className="cell-muted">{new Date(h.generatedAt).toLocaleString()}</span>
                  </td>
                  <td>
                    <StatusChip status={h.autoPosted ? 'POSTED' : 'DRAFT'} />
                  </td>
                  <td className="numeric-cell">
                    <Link className="table-row-action" to={`/bills/${h.billId}`}>
                      View Bill
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
