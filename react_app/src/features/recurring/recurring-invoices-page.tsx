import { useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  FileText,
  Pause,
  Play,
  Plus,
  Repeat,
  Search,
} from 'lucide-react'
import { Link } from 'react-router-dom'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import { listContacts } from '@/features/contacts/contacts-api'
import {
  createRecurringInvoice,
  listRecurringInvoices,
  resumeRecurringInvoice,
  stopRecurringInvoice,
  type CreateRecurringInvoiceRequest,
  type RecurringInvoice,
} from '@/features/recurring/recurring-api'

export function RecurringInvoicesPage() {
  const queryClient = useQueryClient()
  const [searchTerm, setSearchTerm] = useState('')
  const [statusFilter, setStatusFilter] = useState<string>('all')
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false)
  const [feedback, setFeedback] = useState<{ type: 'success' | 'error'; message: string } | null>(null)

  // Form State
  const [profileName, setProfileName] = useState('')
  const [contactId, setContactId] = useState('')
  const [frequency, setFrequency] = useState('MONTHLY')
  const [startDate, setStartDate] = useState(() => new Date().toISOString().split('T')[0] || '')
  const [endDate, setEndDate] = useState('')
  const [autoSend] = useState(true)
  const [paymentTermsDays, setPaymentTermsDays] = useState('30')
  const [lineDesc, setLineDesc] = useState('Monthly Subscription / Retainer')
  const [lineAmount, setLineAmount] = useState('5000')

  const query = useQuery({
    queryKey: ['recurring-invoices-list', statusFilter],
    queryFn: () => listRecurringInvoices(statusFilter === 'all' ? undefined : statusFilter),
  })

  const contactsQuery = useQuery({
    queryKey: ['contacts-customer-select'],
    queryFn: () => listContacts({ filter: 'CUSTOMER', page: 0, search: '' }),
  })

  const profiles: RecurringInvoice[] = query.data?.content ?? []
  const contacts = contactsQuery.data?.content ?? []

  const filtered = useMemo(() => {
    const term = searchTerm.trim().toLowerCase()
    if (!term) return profiles
    return profiles.filter(
      (p) =>
        p.profileName.toLowerCase().includes(term) ||
        p.contactName.toLowerCase().includes(term) ||
        p.frequency.toLowerCase().includes(term)
    )
  }, [profiles, searchTerm])

  const totalMonthlyRunRate = useMemo(() => {
    return profiles
      .filter((p) => p.status === 'ACTIVE')
      .reduce((sum, p) => sum + Number(p.templateTotal || 0), 0)
  }, [profiles])

  const activeCount = profiles.filter((p) => p.status === 'ACTIVE').length

  // Mutations
  const stopMutation = useMutation({
    mutationFn: (id: string) => stopRecurringInvoice(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['recurring-invoices-list'] })
      setFeedback({ type: 'success', message: 'Recurring invoice schedule paused.' })
    },
  })

  const resumeMutation = useMutation({
    mutationFn: (id: string) => resumeRecurringInvoice(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['recurring-invoices-list'] })
      setFeedback({ type: 'success', message: 'Recurring invoice schedule resumed.' })
    },
  })

  const createMutation = useMutation({
    mutationFn: (req: CreateRecurringInvoiceRequest) => createRecurringInvoice(req),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['recurring-invoices-list'] })
      setIsCreateModalOpen(false)
      setFeedback({ type: 'success', message: 'Recurring invoice profile created successfully.' })
    },
    onError: (err: unknown) => {
      setFeedback({
        type: 'error',
        message: err instanceof Error ? err.message : 'Failed to create recurring invoice.',
      })
    },
  })

  const handleCreateSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (!contactId) return
    createMutation.mutate({
      profileName,
      contactId,
      frequency,
      startDate,
      endDate: endDate || undefined,
      autoSend,
      paymentTermsDays: parseInt(paymentTermsDays, 10) || 30,
      lineItems: [
        {
          itemId: '00000000-0000-0000-0000-000000000000',
          description: lineDesc,
          quantity: 1,
          rate: Number(lineAmount) || 0,
        },
      ],
    })
  }

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Sales & Subscriptions"
        title="Recurring Invoices"
        description="Automated recurring customer billing, subscription schedules, auto-generation cron jobs, and billing histories."
        actions={
          <div style={{ display: 'flex', gap: 'var(--space-sm)' }}>
            <Button onClick={() => setIsCreateModalOpen(true)} variant="primary">
              <Plus aria-hidden="true" size={14} style={{ marginRight: 6 }} />
              New Recurring Profile
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
          <span className="summary-card__label">Active Schedules</span>
          <strong className="summary-card__value">
            <Quantity value={activeCount} />
          </strong>
          <span className="summary-card__hint">Of {profiles.length} total profiles</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__label">Active Billing Run-Rate</span>
          <strong className="summary-card__value" style={{ color: 'var(--color-success)' }}>
            <Money amount={totalMonthlyRunRate} />
          </strong>
          <span className="summary-card__hint">Recurring schedule sum</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__label">Total Invoices Minted</span>
          <strong className="summary-card__value">
            <Quantity
              value={profiles.reduce((sum, p) => sum + (p.totalGenerated || 0), 0)}
            />
          </strong>
          <span className="summary-card__hint">Historical generations</span>
        </div>
        <div className="summary-card summary-card--accent">
          <span className="summary-card__label">Cron Automation</span>
          <strong className="summary-card__value" style={{ fontSize: '1rem', color: 'var(--color-primary)' }}>
            Daily at 06:00 IST
          </strong>
          <span className="summary-card__hint">Auto-mints nextInvoiceDate</span>
        </div>
      </div>

      <div
        className="list-toolbar"
        style={{ justifyContent: 'space-between', flexWrap: 'wrap', gap: 'var(--space-sm)' }}
      >
        <div className="search-field" style={{ maxWidth: 360 }}>
          <Search aria-hidden="true" size={16} />
          <input
            aria-label="Search profiles by name or customer"
            onChange={(e) => setSearchTerm(e.target.value)}
            placeholder="Search recurring profile or customer..."
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
        <div className="directory-state">Loading recurring profiles...</div>
      ) : query.isError ? (
        <div className="directory-state directory-state--error">
          <FileText size={24} />
          <strong>Unable to load recurring invoices.</strong>
          <Button onClick={() => query.refetch()} variant="secondary">
            Retry
          </Button>
        </div>
      ) : filtered.length === 0 ? (
        <div className="directory-state">
          <Repeat size={24} />
          <strong>No recurring invoice profiles found.</strong>
          <p>{searchTerm ? 'Try a different search term.' : 'Set up automated customer retainer / subscription billing.'}</p>
        </div>
      ) : (
        <DataTable caption="Recurring invoices list">
          <thead>
            <tr>
              <th scope="col">Profile Name</th>
              <th scope="col">Customer</th>
              <th scope="col">Frequency</th>
              <th scope="col">Next Invoice Date</th>
              <th scope="col">Status</th>
              <th className="numeric-cell" scope="col">Amount</th>
              <th scope="col">Generated</th>
              <th className="numeric-cell" scope="col">Actions</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((p) => (
              <tr key={p.id}>
                <td>
                  <span className="table-code">
                    <Link className="table-row-link" to={`/recurring-invoices/${p.id}`}>
                      {p.profileName}
                    </Link>
                  </span>
                </td>
                <td>
                  <strong>{p.contactName}</strong>
                </td>
                <td>
                  <span className="cell-muted">{p.frequency}</span>
                </td>
                <td>
                  <span className="cell-muted">{p.nextInvoiceDate || 'â€”'}</span>
                </td>
                <td>
                  <StatusChip status={p.status} />
                </td>
                <td className="numeric-cell">
                  <strong>
                    <Money amount={p.templateTotal} />
                  </strong>
                </td>
                <td>
                  <Quantity value={p.totalGenerated} /> minted
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
                    <Link className="table-row-action" to={`/recurring-invoices/${p.id}`}>
                      View
                    </Link>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      )}

      {/* Modal: New Recurring Profile */}
      {isCreateModalOpen && (
        <div className="modal-backdrop" role="dialog" aria-modal="true">
          <div className="modal-card modal-card--wide">
            <header className="modal-header">
              <h2>New Recurring Invoice Schedule</h2>
              <button className="modal-close" onClick={() => setIsCreateModalOpen(false)} type="button">
                ×
              </button>
            </header>
            <form onSubmit={handleCreateSubmit}>
              <div className="modal-body form-grid">
                <div className="form-field">
                  <label htmlFor="profileName">Profile / Subscription Name *</label>
                  <input
                    id="profileName"
                    type="text"
                    required
                    value={profileName}
                    onChange={(e) => setProfileName(e.target.value)}
                    placeholder="e.g. Monthly Software License"
                  />
                </div>

                <div className="form-field">
                  <label htmlFor="contactId">Customer *</label>
                  <select
                    id="contactId"
                    required
                    value={contactId}
                    onChange={(e) => setContactId(e.target.value)}
                  >
                    <option value="">Select customer...</option>
                    {contacts.map((c) => (
                      <option key={c.id} value={c.id}>
                        {c.name}
                      </option>
                    ))}
                  </select>
                </div>

                <div className="form-field">
                  <label htmlFor="frequency">Repeat Frequency *</label>
                  <select
                    id="frequency"
                    value={frequency}
                    onChange={(e) => setFrequency(e.target.value)}
                  >
                    <option value="WEEKLY">Weekly</option>
                    <option value="MONTHLY">Monthly</option>
                    <option value="QUARTERLY">Quarterly</option>
                    <option value="YEARLY">Yearly</option>
                  </select>
                </div>

                <div className="form-field">
                  <label htmlFor="startDate">Start Date *</label>
                  <input
                    id="startDate"
                    type="date"
                    required
                    value={startDate}
                    onChange={(e) => setStartDate(e.target.value)}
                  />
                </div>

                <div className="form-field">
                  <label htmlFor="endDate">End Date (Optional)</label>
                  <input
                    id="endDate"
                    type="date"
                    value={endDate}
                    onChange={(e) => setEndDate(e.target.value)}
                  />
                </div>

                <div className="form-field">
                  <label htmlFor="termsDays">Payment Terms (Days)</label>
                  <input
                    id="termsDays"
                    type="number"
                    value={paymentTermsDays}
                    onChange={(e) => setPaymentTermsDays(e.target.value)}
                  />
                </div>

                <div className="form-field form-field--full">
                  <label htmlFor="lineDesc">Service / Line Item Description *</label>
                  <input
                    id="lineDesc"
                    type="text"
                    required
                    value={lineDesc}
                    onChange={(e) => setLineDesc(e.target.value)}
                  />
                </div>

                <div className="form-field">
                  <label htmlFor="lineAmount">Billing Amount per Cycle (₹) *</label>
                  <input
                    id="lineAmount"
                    type="number"
                    min="1"
                    step="0.01"
                    required
                    value={lineAmount}
                    onChange={(e) => setLineAmount(e.target.value)}
                  />
                </div>
              </div>

              <footer className="modal-footer">
                <Button onClick={() => setIsCreateModalOpen(false)} type="button" variant="secondary">
                  Cancel
                </Button>
                <Button disabled={createMutation.isPending} type="submit" variant="primary">
                  {createMutation.isPending ? 'Creating...' : 'Create Recurring Profile'}
                </Button>
              </footer>
            </form>
          </div>
        </div>
      )}
    </section>
  )
}
