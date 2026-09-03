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
import { listContacts } from '@/features/contacts/contacts-api'
import {
  createRecurringBill,
  listRecurringBills,
  resumeRecurringBill,
  stopRecurringBill,
  type CreateRecurringBillRequest,
  type RecurringBill,
} from '@/features/recurring/recurring-api'

export function RecurringBillsPage() {
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
  const [endDate] = useState('')
  const [autoPost] = useState(false)
  const [paymentTermsDays] = useState('30')
  const [lineDesc, setLineDesc] = useState('Monthly Office Rent / Utility')
  const [lineAmount, setLineAmount] = useState('15000')

  const query = useQuery({
    queryKey: ['recurring-bills-list', statusFilter],
    queryFn: () => listRecurringBills(statusFilter === 'all' ? undefined : statusFilter),
  })

  const contactsQuery = useQuery({
    queryKey: ['contacts-vendor-select'],
    queryFn: () => listContacts({ filter: 'VENDOR', page: 0, search: '' }),
  })

  const profiles: RecurringBill[] = query.data?.content ?? []
  const vendors = contactsQuery.data?.content ?? []

  const filtered = useMemo(() => {
    const term = searchTerm.trim().toLowerCase()
    if (!term) return profiles
    return profiles.filter(
      (p) =>
        p.profileName.toLowerCase().includes(term) ||
        p.frequency.toLowerCase().includes(term)
    )
  }, [profiles, searchTerm])

  // Mutations
  const stopMutation = useMutation({
    mutationFn: (id: string) => stopRecurringBill(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['recurring-bills-list'] })
      setFeedback({ type: 'success', message: 'Recurring bill schedule stopped.' })
    },
  })

  const resumeMutation = useMutation({
    mutationFn: (id: string) => resumeRecurringBill(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['recurring-bills-list'] })
      setFeedback({ type: 'success', message: 'Recurring bill schedule resumed.' })
    },
  })

  const createMutation = useMutation({
    mutationFn: (req: CreateRecurringBillRequest) => createRecurringBill(req),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['recurring-bills-list'] })
      setIsCreateModalOpen(false)
      setFeedback({ type: 'success', message: 'Recurring bill profile created.' })
    },
    onError: (err: unknown) => {
      setFeedback({
        type: 'error',
        message: err instanceof Error ? err.message : 'Failed to create recurring bill.',
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
      paymentTermsDays: parseInt(paymentTermsDays, 10) || 30,
      autoPost,
      lineItems: [
        {
          description: lineDesc,
          quantity: 1,
          rate: Number(lineAmount) || 0,
          amount: Number(lineAmount) || 0,
        },
      ],
    })
  }

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Purchases & Accounts Payable"
        title="Recurring Bills & Standing Orders"
        description="Schedule automated supplier bills, rent payments, recurring utility expenses, and AP posting cycles."
        actions={
          <div style={{ display: 'flex', gap: 'var(--space-sm)' }}>
            <Button onClick={() => setIsCreateModalOpen(true)} variant="primary">
              <Plus size={14} style={{ marginRight: 6 }} />
              New Recurring Bill
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
          <span className="summary-card__label">Active Bill Schedules</span>
          <strong className="summary-card__value">
            <Quantity value={profiles.filter((p) => p.status === 'ACTIVE').length} />
          </strong>
          <span className="summary-card__hint">Standing purchase orders</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__label">Total Bills Minted</span>
          <strong className="summary-card__value">
            <Quantity value={profiles.reduce((sum, p) => sum + (p.totalGenerated || 0), 0)} />
          </strong>
          <span className="summary-card__hint">Historical AP bills</span>
        </div>
        <div className="summary-card summary-card--accent">
          <span className="summary-card__label">AP Automation</span>
          <strong className="summary-card__value" style={{ fontSize: '1rem', color: 'var(--color-primary)' }}>
            Scheduled Cron
          </strong>
          <span className="summary-card__hint">Auto-generates vendor bills</span>
        </div>
      </div>

      <div
        className="list-toolbar"
        style={{ justifyContent: 'space-between', flexWrap: 'wrap', gap: 'var(--space-sm)' }}
      >
        <div className="search-field" style={{ maxWidth: 360 }}>
          <Search size={16} />
          <input
            aria-label="Search recurring bills"
            onChange={(e) => setSearchTerm(e.target.value)}
            placeholder="Search recurring bills..."
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
        <div className="directory-state">Loading recurring bills...</div>
      ) : filtered.length === 0 ? (
        <div className="directory-state">
          <Repeat size={24} />
          <strong>No recurring bills found.</strong>
          <p>Create standing vendor bills for rent, subscriptions, or regular retainer services.</p>
        </div>
      ) : (
        <DataTable caption="Recurring bills list">
          <thead>
            <tr>
              <th scope="col">Profile Name</th>
              <th scope="col">Frequency</th>
              <th scope="col">Next Bill Date</th>
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
                    <Link className="table-row-link" to={`/recurring-bills/${p.id}`}>
                      {p.profileName}
                    </Link>
                  </span>
                </td>
                <td>
                  <span className="cell-muted">{p.frequency}</span>
                </td>
                <td>
                  <span className="cell-muted">{p.nextBillDate || 'â€”'}</span>
                </td>
                <td>
                  <StatusChip status={p.status} />
                </td>
                <td className="numeric-cell">
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
                    <Link className="table-row-action" to={`/recurring-bills/${p.id}`}>
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
              <h2>New Recurring Purchase Bill</h2>
              <button className="modal-close" onClick={() => setIsCreateModalOpen(false)} type="button">
                ×
              </button>
            </header>
            <form onSubmit={handleCreateSubmit}>
              <div className="modal-body form-grid">
                <div className="form-field">
                  <label htmlFor="billProfileName">Profile Name *</label>
                  <input
                    id="billProfileName"
                    type="text"
                    required
                    value={profileName}
                    onChange={(e) => setProfileName(e.target.value)}
                    placeholder="e.g. Warehouse Lease Rent"
                  />
                </div>

                <div className="form-field">
                  <label htmlFor="vendorSelect">Supplier / Vendor *</label>
                  <select
                    id="vendorSelect"
                    required
                    value={contactId}
                    onChange={(e) => setContactId(e.target.value)}
                  >
                    <option value="">Select vendor...</option>
                    {vendors.map((v) => (
                      <option key={v.id} value={v.id}>
                        {v.name}
                      </option>
                    ))}
                  </select>
                </div>

                <div className="form-field">
                  <label htmlFor="billFrequency">Frequency *</label>
                  <select
                    id="billFrequency"
                    value={frequency}
                    onChange={(e) => setFrequency(e.target.value)}
                  >
                    <option value="MONTHLY">Monthly</option>
                    <option value="QUARTERLY">Quarterly</option>
                    <option value="YEARLY">Yearly</option>
                  </select>
                </div>

                <div className="form-field">
                  <label htmlFor="billStartDate">Start Date *</label>
                  <input
                    id="billStartDate"
                    type="date"
                    required
                    value={startDate}
                    onChange={(e) => setStartDate(e.target.value)}
                  />
                </div>

                <div className="form-field form-field--full">
                  <label htmlFor="billDesc">Expense / Bill Line Description *</label>
                  <input
                    id="billDesc"
                    type="text"
                    required
                    value={lineDesc}
                    onChange={(e) => setLineDesc(e.target.value)}
                  />
                </div>

                <div className="form-field">
                  <label htmlFor="billAmount">Recurring Bill Amount (₹) *</label>
                  <input
                    id="billAmount"
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
                  {createMutation.isPending ? 'Saving...' : 'Create Recurring Bill'}
                </Button>
              </footer>
            </form>
          </div>
        </div>
      )}
    </section>
  )
}
