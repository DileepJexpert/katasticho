import { useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  Pause,
  Play,
  Plus,
  Repeat,
  Search,
} from 'lucide-react'
import { Link } from 'react-router-dom'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import { listAccounts } from '@/features/accounts/accounts-api'
import {
  createRecurringJournal,
  listRecurringJournals,
  resumeRecurringJournal,
  stopRecurringJournal,
  type CreateRecurringJournalRequest,
  type RecurringJournal,
} from '@/features/recurring/recurring-api'

export function RecurringJournalsPage() {
  const queryClient = useQueryClient()
  const [searchTerm, setSearchTerm] = useState('')
  const [statusFilter, setStatusFilter] = useState<string>('all')
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false)
  const [feedback, setFeedback] = useState<{ type: 'success' | 'error'; message: string } | null>(null)

  // Form State
  const [profileName, setProfileName] = useState('')
  const [frequency, setFrequency] = useState('MONTHLY')
  const [startDate, setStartDate] = useState(() => new Date().toISOString().split('T')[0] || '')
  const [endDate] = useState('')
  const [narration, setNarration] = useState('Monthly depreciation / prepaid expense amortisation')
  const [autoPost] = useState(true)
  const [debitAccountCode, setDebitAccountCode] = useState('')
  const [creditAccountCode, setCreditAccountCode] = useState('')
  const [journalAmount, setJournalAmount] = useState('2500')

  const query = useQuery({
    queryKey: ['recurring-journals-list', statusFilter],
    queryFn: () => listRecurringJournals(statusFilter === 'all' ? undefined : statusFilter),
  })

  const accountsQuery = useQuery({
    queryKey: ['accounts-select-list'],
    queryFn: () => listAccounts(),
  })

  const profiles: RecurringJournal[] = query.data?.content ?? []
  const accounts = accountsQuery.data ?? []

  const filtered = useMemo(() => {
    const term = searchTerm.trim().toLowerCase()
    if (!term) return profiles
    return profiles.filter(
      (p) =>
        p.profileName.toLowerCase().includes(term) ||
        (p.narration && p.narration.toLowerCase().includes(term))
    )
  }, [profiles, searchTerm])

  // Mutations
  const stopMutation = useMutation({
    mutationFn: (id: string) => stopRecurringJournal(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['recurring-journals-list'] })
      setFeedback({ type: 'success', message: 'Recurring journal schedule paused.' })
    },
  })

  const resumeMutation = useMutation({
    mutationFn: (id: string) => resumeRecurringJournal(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['recurring-journals-list'] })
      setFeedback({ type: 'success', message: 'Recurring journal schedule resumed.' })
    },
  })

  const createMutation = useMutation({
    mutationFn: (req: CreateRecurringJournalRequest) => createRecurringJournal(req),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['recurring-journals-list'] })
      setIsCreateModalOpen(false)
      setFeedback({ type: 'success', message: 'Recurring journal template created.' })
    },
    onError: (err: unknown) => {
      setFeedback({
        type: 'error',
        message: err instanceof Error ? err.message : 'Failed to create recurring journal.',
      })
    },
  })

  const handleCreateSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (!debitAccountCode || !creditAccountCode) {
      setFeedback({ type: 'error', message: 'Please select both debit and credit GL accounts.' })
      return
    }
    const amt = Number(journalAmount) || 0
    createMutation.mutate({
      profileName,
      frequency,
      startDate,
      endDate: endDate || undefined,
      narration,
      autoPost,
      lines: [
        {
          accountCode: debitAccountCode,
          debitAmount: amt,
          creditAmount: 0,
          narration: `DR: ${narration}`,
        },
        {
          accountCode: creditAccountCode,
          debitAmount: 0,
          creditAmount: amt,
          narration: `CR: ${narration}`,
        },
      ],
    })
  }

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="General Ledger & Accounting"
        title="Recurring Journals"
        description="Automate monthly depreciation accruals, prepaid expense amortisation, standing payroll provisions, and routine GL journals."
        actions={
          <div style={{ display: 'flex', gap: 'var(--space-sm)' }}>
            <Button onClick={() => setIsCreateModalOpen(true)} variant="primary">
              <Plus size={14} style={{ marginRight: 6 }} />
              New Recurring Journal
            </Button>
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

      <div className="summary-strip">
        <div className="summary-card">
          <span className="summary-card__label">Active Journal Templates</span>
          <strong className="summary-card__value">
            <Quantity value={profiles.filter((p) => p.status === 'ACTIVE').length} />
          </strong>
          <span className="summary-card__hint">Scheduled GL templates</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__label">Entries Generated</span>
          <strong className="summary-card__value">
            <Quantity value={profiles.reduce((sum, p) => sum + (p.totalGenerated || 0), 0)} />
          </strong>
          <span className="summary-card__hint">Posted GL transactions</span>
        </div>
        <div className="summary-card summary-card--accent">
          <span className="summary-card__label">Auto-Post Engine</span>
          <strong className="summary-card__value" style={{ fontSize: '1rem', color: 'var(--color-success)' }}>
            Balanced DR/CR
          </strong>
          <span className="summary-card__hint">Automated double-entry posting</span>
        </div>
      </div>

      <div
        className="list-toolbar"
        style={{ justifyContent: 'space-between', flexWrap: 'wrap', gap: 'var(--space-sm)' }}
      >
        <div className="search-field" style={{ maxWidth: 360 }}>
          <Search size={16} />
          <input
            aria-label="Search recurring journals"
            onChange={(e) => setSearchTerm(e.target.value)}
            placeholder="Search recurring journals..."
            type="search"
            value={searchTerm}
          />
        </div>

        <div className="filter-chip-group">
          {['all', 'ACTIVE', 'STOPPED'].map((st) => (
            <button
              key={st}
              className={`filter-chip ${statusFilter === st ? 'filter-chip--active' : ''}`}
              onClick={() => setStatusFilter(st)}
              type="button"
            >
              {st === 'all' ? 'All Schedules' : st}
            </button>
          ))}
        </div>
      </div>

      {query.isLoading ? (
        <div className="directory-state">Loading recurring journals...</div>
      ) : filtered.length === 0 ? (
        <div className="directory-state">
          <Repeat size={24} />
          <strong>No recurring journals found.</strong>
          <p>Set up scheduled accrual / depreciation templates to automatically post to GL.</p>
        </div>
      ) : (
        <DataTable caption="Recurring journals list">
          <thead>
            <tr>
              <th scope="col">Profile Name</th>
              <th scope="col">Frequency</th>
              <th scope="col">Next Run Date</th>
              <th scope="col">Narration</th>
              <th scope="col">Status</th>
              <th className="numeric-cell" scope="col">Generated</th>
              <th className="numeric-cell" scope="col">Actions</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((p) => (
              <tr key={p.id}>
                <td>
                  <span className="table-code">
                    <Link className="table-row-link" to={`/recurring-journals/${p.id}`}>
                      {p.profileName}
                    </Link>
                  </span>
                </td>
                <td>
                  <span className="cell-muted">{p.frequency}</span>
                </td>
                <td>
                  <span className="cell-muted">{p.nextRunDate || 'â€”'}</span>
                </td>
                <td>
                  <strong>{p.narration || 'â€”'}</strong>
                </td>
                <td>
                  <StatusChip status={p.status} />
                </td>
                <td className="numeric-cell">
                  <Quantity value={p.totalGenerated} /> posted
                </td>
                <td className="numeric-cell">
                  <div style={{ display: 'inline-flex', gap: 6, alignItems: 'center' }}>
                    {p.status === 'ACTIVE' ? (
                      <button
                        title="Pause Schedule"
                        onClick={() => stopMutation.mutate(p.id)}
                        type="button"
                        style={{ background: 'none', border: 'none', color: 'var(--color-text-muted)', cursor: 'pointer', padding: 4 }}
                      >
                        <Pause size={15} />
                      </button>
                    ) : (
                      <button
                        title="Resume Schedule"
                        onClick={() => resumeMutation.mutate(p.id)}
                        type="button"
                        style={{ background: 'none', border: 'none', color: 'var(--color-success)', cursor: 'pointer', padding: 4 }}
                      >
                        <Play size={15} />
                      </button>
                    )}
                    <Link className="table-row-action" to={`/recurring-journals/${p.id}`}>
                      View
                    </Link>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      )}

      {/* Create Modal */}
      {isCreateModalOpen && (
        <div className="modal-backdrop" role="dialog" aria-modal="true">
          <div className="modal-card modal-card--wide">
            <header className="modal-header">
              <h2>New Recurring General Ledger Journal</h2>
              <button className="modal-close" onClick={() => setIsCreateModalOpen(false)} type="button">
                ×
              </button>
            </header>
            <form onSubmit={handleCreateSubmit}>
              <div className="modal-body form-grid">
                <div className="form-field">
                  <label htmlFor="jProfileName">Template Name *</label>
                  <input
                    id="jProfileName"
                    type="text"
                    required
                    value={profileName}
                    onChange={(e) => setProfileName(e.target.value)}
                    placeholder="e.g. Monthly Depreciation Schedule"
                  />
                </div>

                <div className="form-field">
                  <label htmlFor="jFrequency">Frequency *</label>
                  <select
                    id="jFrequency"
                    value={frequency}
                    onChange={(e) => setFrequency(e.target.value)}
                  >
                    <option value="MONTHLY">Monthly</option>
                    <option value="QUARTERLY">Quarterly</option>
                    <option value="YEARLY">Yearly</option>
                  </select>
                </div>

                <div className="form-field">
                  <label htmlFor="jStartDate">Start Date *</label>
                  <input
                    id="jStartDate"
                    type="date"
                    required
                    value={startDate}
                    onChange={(e) => setStartDate(e.target.value)}
                  />
                </div>

                <div className="form-field">
                  <label htmlFor="jAmount">Balanced Amount (₹) *</label>
                  <input
                    id="jAmount"
                    type="number"
                    min="1"
                    step="0.01"
                    required
                    value={journalAmount}
                    onChange={(e) => setJournalAmount(e.target.value)}
                  />
                </div>

                <div className="form-field">
                  <label htmlFor="debitAccount">Debit (DR) Account *</label>
                  <select
                    id="debitAccount"
                    required
                    value={debitAccountCode}
                    onChange={(e) => setDebitAccountCode(e.target.value)}
                  >
                    <option value="">Select DR account...</option>
                    {accounts.map((a) => (
                      <option key={a.code} value={a.code}>
                        {a.code} - {a.name} ({a.type})
                      </option>
                    ))}
                  </select>
                </div>

                <div className="form-field">
                  <label htmlFor="creditAccount">Credit (CR) Account *</label>
                  <select
                    id="creditAccount"
                    required
                    value={creditAccountCode}
                    onChange={(e) => setCreditAccountCode(e.target.value)}
                  >
                    <option value="">Select CR account...</option>
                    {accounts.map((a) => (
                      <option key={a.code} value={a.code}>
                        {a.code} - {a.name} ({a.type})
                      </option>
                    ))}
                  </select>
                </div>

                <div className="form-field form-field--full">
                  <label htmlFor="jNarration">Narration *</label>
                  <input
                    id="jNarration"
                    type="text"
                    required
                    value={narration}
                    onChange={(e) => setNarration(e.target.value)}
                  />
                </div>
              </div>

              <footer className="modal-footer">
                <Button onClick={() => setIsCreateModalOpen(false)} type="button" variant="secondary">
                  Cancel
                </Button>
                <Button disabled={createMutation.isPending} type="submit" variant="primary">
                  {createMutation.isPending ? 'Saving...' : 'Create Recurring Journal'}
                </Button>
              </footer>
            </form>
          </div>
        </div>
      )}
    </section>
  )
}
