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
import { StatusChip } from '@/design-system/status-chip'
import {
  generateRecurringJournalNow,
  getRecurringJournal,
  listGeneratedJournals,
  resumeRecurringJournal,
  stopRecurringJournal,
} from '@/features/recurring/recurring-api'

export function RecurringJournalDetailPage() {
  const { profileId = '' } = useParams<{ profileId: string }>()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [feedback, setFeedback] = useState<{ type: 'success' | 'error'; message: string } | null>(null)

  const query = useQuery({
    queryKey: ['recurring-journal-detail', profileId],
    queryFn: () => getRecurringJournal(profileId),
    enabled: Boolean(profileId),
  })

  const historyQuery = useQuery({
    queryKey: ['recurring-journal-history', profileId],
    queryFn: () => listGeneratedJournals(profileId),
    enabled: Boolean(profileId),
  })

  const profile = query.data
  const history = historyQuery.data ?? []

  // Mutations
  const stopMutation = useMutation({
    mutationFn: () => stopRecurringJournal(profileId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['recurring-journal-detail', profileId] })
      setFeedback({ type: 'success', message: 'Recurring journal schedule paused.' })
    },
  })

  const resumeMutation = useMutation({
    mutationFn: () => resumeRecurringJournal(profileId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['recurring-journal-detail', profileId] })
      setFeedback({ type: 'success', message: 'Recurring journal schedule resumed.' })
    },
  })

  const generateNowMutation = useMutation({
    mutationFn: () => generateRecurringJournalNow(profileId),
    onSuccess: (res) => {
      queryClient.invalidateQueries({ queryKey: ['recurring-journal-detail', profileId] })
      queryClient.invalidateQueries({ queryKey: ['recurring-journal-history', profileId] })
      queryClient.invalidateQueries({ queryKey: ['journals-list'] })
      if (res.journalEntryId) {
        navigate(`/journals/${res.journalEntryId}`)
      } else {
        setFeedback({ type: 'success', message: 'Journal entry created.' })
      }
    },
    onError: (err: unknown) => {
      setFeedback({
        type: 'error',
        message: err instanceof Error ? err.message : 'Journal generation failed.',
      })
    },
  })

  if (query.isLoading) {
    return (
      <section className="workspace-page">
        <div className="directory-state">Loading recurring journal...</div>
      </section>
    )
  }

  if (query.isError || !profile) {
    return (
      <section className="workspace-page">
        <div className="directory-state directory-state--error">
          <FileText size={24} />
          <strong>Recurring journal profile not found.</strong>
          <Link className="btn btn--secondary" to="/recurring-journals">
            Back to recurring journals
          </Link>
        </div>
      </section>
    )
  }

  return (
    <section className="workspace-page">
      <div style={{ marginBottom: 'var(--space-sm)' }}>
        <Link className="table-row-action" to="/recurring-journals">
          <ArrowLeft size={14} style={{ display: 'inline', marginRight: 4 }} />
          Back to all recurring journals
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
        eyebrow="Recurring GL Journal"
        title={profile.profileName}
        description={`Frequency: ${profile.frequency} • Next run: ${profile.nextRunDate || 'None'}`}
        actions={
          <div style={{ display: 'flex', gap: 'var(--space-sm)' }}>
            <Button
              disabled={generateNowMutation.isPending}
              onClick={() => generateNowMutation.mutate()}
              variant="secondary"
            >
              <Zap size={14} style={{ marginRight: 6 }} />
              Post Entry Now
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
          <span className="summary-card__label">Next Run Date</span>
          <strong className="summary-card__value" style={{ fontSize: '1.1rem' }}>
            {profile.nextRunDate || 'None'}
          </strong>
          <span className="summary-card__hint">Start: {profile.startDate}</span>
        </div>

        <div className="summary-card">
          <span className="summary-card__label">Cycle Frequency</span>
          <strong className="summary-card__value" style={{ fontSize: '1.1rem' }}>
            {profile.frequency}
          </strong>
          <span className="summary-card__hint">Periodic GL posting</span>
        </div>

        <div className="summary-card">
          <span className="summary-card__label">Status</span>
          <div style={{ marginTop: 4 }}>
            <StatusChip status={profile.status} />
          </div>
          <span className="summary-card__hint">{profile.totalGenerated} journals minted</span>
        </div>

        <div className="summary-card summary-card--accent">
          <span className="summary-card__label">Posting Mode</span>
          <strong className="summary-card__value" style={{ fontSize: '1.1rem' }}>
            {profile.autoPost ? 'Auto-Post GL' : 'Draft Entry'}
          </strong>
          <span className="summary-card__hint">Narration: {profile.narration}</span>
        </div>
      </div>

      {/* Line Items */}
      <div className="panel-card" style={{ padding: 'var(--space-md)', marginBottom: 'var(--space-md)' }}>
        <h3 style={{ fontSize: '1.05rem', margin: '0 0 var(--space-sm) 0' }}>Journal Debits & Credits Template</h3>
        <DataTable caption="Journal template lines">
          <thead>
            <tr>
              <th scope="col">Account Code</th>
              <th scope="col">Narration</th>
              <th className="numeric-cell" scope="col">Debit (DR)</th>
              <th className="numeric-cell" scope="col">Credit (CR)</th>
            </tr>
          </thead>
          <tbody>
            {profile.lines.map((l, idx) => (
              <tr key={idx}>
                <td>
                  <span className="table-code">{l.accountCode}</span>
                </td>
                <td>{l.narration || profile.narration}</td>
                <td className="numeric-cell">
                  {l.debitAmount ? <Money amount={l.debitAmount} /> : <span className="cell-muted">â€”</span>}
                </td>
                <td className="numeric-cell">
                  {l.creditAmount ? <Money amount={l.creditAmount} /> : <span className="cell-muted">â€”</span>}
                </td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      </div>

      {/* History */}
      <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
        <h3 style={{ fontSize: '1.05rem', margin: '0 0 var(--space-sm) 0' }}>Posted Journal Entries Log</h3>
        {history.length === 0 ? (
          <div className="directory-state" style={{ padding: 'var(--space-md)' }}>
            <Clock size={20} />
            <p>No journal entries generated yet from this schedule.</p>
          </div>
        ) : (
          <DataTable caption="Posted journal entries history">
            <thead>
              <tr>
                <th scope="col">Journal Entry ID</th>
                <th scope="col">Generated Timestamp</th>
                <th scope="col">Status</th>
                <th className="numeric-cell" scope="col">Action</th>
              </tr>
            </thead>
            <tbody>
              {history.map((h) => (
                <tr key={h.journalEntryId}>
                  <td>
                    <span className="table-code">
                      <Link className="table-row-link" to={`/journals/${h.journalEntryId}`}>
                        {h.journalEntryId.slice(0, 8)}
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
                    <Link className="table-row-action" to={`/journals/${h.journalEntryId}`}>
                      View Journal
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
