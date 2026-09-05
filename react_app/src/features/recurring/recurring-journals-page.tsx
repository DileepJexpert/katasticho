import { useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  Pause,
  Play,
  Plus,
  Repeat,
} from 'lucide-react'
import { Link } from 'react-router-dom'
import {
  Button,
  DataTable,
  DirectoryToolbar,
  FilterTabs,
  FormField,
  FormGrid,
  Modal,
  PageHeader,
  Quantity,
  SearchInput,
  SelectInput,
  StatusChip,
  TextInput,
} from '@/design-system'
import { listAccounts } from '@/features/accounts/accounts-api'
import {
  createRecurringJournal,
  listRecurringJournals,
  resumeRecurringJournal,
  stopRecurringJournal,
  type CreateRecurringJournalRequest,
  type RecurringJournal,
} from '@/features/recurring/recurring-api'

const recurringJournalStatusTabs = [
  { label: 'All schedules', value: 'all' },
  { label: 'Active', value: 'ACTIVE' },
  { label: 'Stopped', value: 'STOPPED' },
] as const

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

      <DirectoryToolbar ariaLabel="Recurring journal filters">
        <SearchInput
          ariaLabel="Search recurring journals"
          onChange={setSearchTerm}
          onClear={() => setSearchTerm('')}
          placeholder="Search recurring journals..."
          value={searchTerm}
        />
        <FilterTabs
          activeValue={statusFilter}
          ariaLabel="Filter recurring journals by status"
          items={recurringJournalStatusTabs}
          onChange={setStatusFilter}
        />
      </DirectoryToolbar>

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

      <Modal
        error={feedback?.type === 'error' ? feedback.message : null}
        footer={
          <>
            <Button onClick={() => setIsCreateModalOpen(false)} type="button" variant="secondary">
              Cancel
            </Button>
            <Button disabled={createMutation.isPending} form="recurring-journal-create-form" loading={createMutation.isPending} type="submit" variant="primary">
              Create Recurring Journal
            </Button>
          </>
        }
        isOpen={isCreateModalOpen}
        onClose={() => setIsCreateModalOpen(false)}
        size="lg"
        title="New Recurring General Ledger Journal"
      >
        <form id="recurring-journal-create-form" onSubmit={handleCreateSubmit}>
          <FormGrid columns={2}>
            <FormField htmlFor="jProfileName" label="Template name" required span="full">
              <TextInput
                id="jProfileName"
                onChange={(event) => setProfileName(event.target.value)}
                placeholder="e.g. Monthly depreciation schedule"
                required
                value={profileName}
              />
            </FormField>

            <FormField htmlFor="jFrequency" label="Frequency" required>
              <SelectInput id="jFrequency" onChange={(event) => setFrequency(event.target.value)} value={frequency}>
                <option value="MONTHLY">Monthly</option>
                <option value="QUARTERLY">Quarterly</option>
                <option value="YEARLY">Yearly</option>
              </SelectInput>
            </FormField>

            <FormField htmlFor="jStartDate" label="Start date" required>
              <TextInput
                id="jStartDate"
                onChange={(event) => setStartDate(event.target.value)}
                required
                type="date"
                value={startDate}
              />
            </FormField>

            <FormField htmlFor="jAmount" label="Balanced amount (INR)" required span="full">
              <TextInput
                id="jAmount"
                min="1"
                onChange={(event) => setJournalAmount(event.target.value)}
                required
                step="0.01"
                type="number"
                value={journalAmount}
              />
            </FormField>

            <FormField htmlFor="debitAccount" label="Debit (DR) account" required>
              <SelectInput id="debitAccount" onChange={(event) => setDebitAccountCode(event.target.value)} placeholderOption="Select DR account..." required value={debitAccountCode}>
                {accounts.map((account) => (
                  <option key={account.code} value={account.code}>
                    {account.code} - {account.name} ({account.type})
                  </option>
                ))}
              </SelectInput>
            </FormField>

            <FormField htmlFor="creditAccount" label="Credit (CR) account" required>
              <SelectInput id="creditAccount" onChange={(event) => setCreditAccountCode(event.target.value)} placeholderOption="Select CR account..." required value={creditAccountCode}>
                {accounts.map((account) => (
                  <option key={account.code} value={account.code}>
                    {account.code} - {account.name} ({account.type})
                  </option>
                ))}
              </SelectInput>
            </FormField>

            <FormField htmlFor="jNarration" label="Narration" required span="full">
              <TextInput
                id="jNarration"
                onChange={(event) => setNarration(event.target.value)}
                required
                value={narration}
              />
            </FormField>
          </FormGrid>
        </form>
      </Modal>
    </section>
  )
}
