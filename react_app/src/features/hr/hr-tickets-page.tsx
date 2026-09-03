import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  HelpCircle,
  Plus,
  Search,
  X,
} from 'lucide-react'
import { Link } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import {
  listTickets,
  raiseTicket,
} from '@/features/hr/hr-api'

const ticketTabs = [
  { key: 'open', label: 'Open Tickets' },
  { key: 'assigned', label: 'Assigned to Me' },
  { key: 'me', label: 'My Raised Tickets' },
] as const

type TicketTab = (typeof ticketTabs)[number]['key']

export function HrTicketsPage() {
  const [activeTab, setActiveTab] = useState<TicketTab>('open')
  const [search, setSearch] = useState('')
  const [isRaiseOpen, setIsRaiseOpen] = useState(false)

  const queryClient = useQueryClient()

  const query = useQuery({
    queryKey: ['hr-tickets', activeTab],
    queryFn: () => listTickets(activeTab),
  })

  const raiseMutation = useMutation({
    mutationFn: (req: { category: string; subject: string; description: string; priority: string }) =>
      raiseTicket(req),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['hr-tickets'] })
      setIsRaiseOpen(false)
    },
  })

  const rawList = query.data ?? []
  const filtered = rawList.filter((t) => {
    if (!search.trim()) return true
    const q = search.toLowerCase()
    return (
      t.subject.toLowerCase().includes(q) ||
      t.category.toLowerCase().includes(q) ||
      (t.requesterName && t.requesterName.toLowerCase().includes(q))
    )
  })

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Core HR"
        title="HR Help Desk & Requests"
        description="Internal employee queries, payroll discrepancies, tax proof clarifications, policy inquiries, and HR support tickets."
        actions={
          <div className="table-actions">
            <Button onClick={() => setIsRaiseOpen(true)} variant="primary">
              <Plus aria-hidden="true" size={16} />
              Raise Ticket
            </Button>
          </div>
        }
      />

      <div className="summary-strip">
        <div className="summary-card">
          <span className="summary-card__label">Active Tickets</span>
          <strong className="summary-card__value">{rawList.length}</strong>
          <span className="summary-card__hint">In current view</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__label">Open / Unresolved</span>
          <strong className="summary-card__value text-warning">
            {rawList.filter((t) => t.status === 'OPEN' || t.status === 'IN_PROGRESS').length}
          </strong>
          <span className="summary-card__hint">Awaiting resolution</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__label">Resolved</span>
          <strong className="summary-card__value text-success">
            {rawList.filter((t) => t.status === 'RESOLVED' || t.status === 'CLOSED').length}
          </strong>
          <span className="summary-card__hint">Completed requests</span>
        </div>
      </div>

      <div className="list-toolbar">
        <label className="directory-search">
          <Search aria-hidden="true" size={18} />
          <span className="sr-only">Search tickets</span>
          <input
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search by subject, category, or employee..."
            type="search"
            value={search}
          />
        </label>
        <div aria-label="Ticket tabs" className="list-tabs" role="tablist">
          {ticketTabs.map((tab) => (
            <button
              aria-selected={activeTab === tab.key}
              className={activeTab === tab.key ? 'list-tab list-tab--active' : 'list-tab'}
              key={tab.key}
              onClick={() => setActiveTab(tab.key)}
              role="tab"
              type="button"
            >
              {tab.label}
            </button>
          ))}
        </div>
      </div>

      {query.isLoading ? (
        <div className="directory-state">Loading HR tickets...</div>
      ) : filtered.length === 0 ? (
        <div className="directory-state">
          <HelpCircle aria-hidden="true" size={24} />
          <strong>No HR tickets in this queue.</strong>
          <p>Click "Raise Ticket" to submit a question or request to HR.</p>
        </div>
      ) : (
        <DataTable caption="HR support tickets and employee inquiries">
          <thead>
            <tr>
              <th scope="col">Ticket Subject</th>
              <th scope="col">Category</th>
              <th scope="col">Requester</th>
              <th scope="col">Priority</th>
              <th scope="col">Created Date</th>
              <th scope="col">Status</th>
              <th scope="col">Actions</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((t) => (
              <tr key={t.id}>
                <td>
                  <Link
                    className="table-code"
                    to={appRoutes.hrTicketDetail(t.id)}
                  >
                    {t.subject}
                  </Link>
                </td>
                <td><StatusChip status={t.category} /></td>
                <td><strong>{t.requesterName || 'Staff Member'}</strong></td>
                <td><StatusChip status={t.priority} /></td>
                <td>{t.createdAt ? formatDate(t.createdAt) : 'â€”'}</td>
                <td><StatusChip status={formatStatusLabel(t.status)} /></td>
                <td>
                  <Link
                    className="table-row-action"
                    to={appRoutes.hrTicketDetail(t.id)}
                  >
                    View Thread
                  </Link>
                </td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      )}

      {/* Raise Ticket Modal */}
      {isRaiseOpen ? (
        <div className="modal-backdrop" role="presentation">
          <div aria-labelledby="raise-title" aria-modal="true" className="modal-dialog" role="dialog">
            <div className="modal-header">
              <h2 id="raise-title">Raise HR Support Ticket</h2>
              <button className="icon-button" onClick={() => setIsRaiseOpen(false)} type="button">
                <X aria-hidden="true" size={18} />
              </button>
            </div>
            <form
              onSubmit={(e) => {
                e.preventDefault()
                const fd = new FormData(e.currentTarget)
                raiseMutation.mutate({
                  category: String(fd.get('category') ?? 'PAYROLL'),
                  subject: String(fd.get('subject') ?? '').trim(),
                  description: String(fd.get('description') ?? '').trim(),
                  priority: String(fd.get('priority') ?? 'MEDIUM'),
                })
              }}
            >
              <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                  <div>
                    <label className="form-label">Category</label>
                    <select className="select-input" defaultValue="PAYROLL" name="category">
                      <option value="PAYROLL">Payroll & Payslip Query</option>
                      <option value="TAX">Income Tax / Form 16</option>
                      <option value="LEAVE">Leave & Attendance Discrepancy</option>
                      <option value="BENEFITS">Insurance / PF / ESI</option>
                      <option value="POLICY">Policy Clarification</option>
                    </select>
                  </div>
                  <div>
                    <label className="form-label">Priority</label>
                    <select className="select-input" defaultValue="MEDIUM" name="priority">
                      <option value="LOW">Low</option>
                      <option value="MEDIUM">Medium</option>
                      <option value="HIGH">High</option>
                      <option value="URGENT">Urgent</option>
                    </select>
                  </div>
                </div>
                <div>
                  <label className="form-label">Subject *</label>
                  <input className="text-input" name="subject" placeholder="Brief summary of inquiry..." required type="text" />
                </div>
                <div>
                  <label className="form-label">Description *</label>
                  <textarea className="text-input" name="description" placeholder="Provide detailed explanation..." required rows={4} />
                </div>
              </div>
              <div className="modal-footer">
                <Button onClick={() => setIsRaiseOpen(false)} type="button" variant="secondary">Cancel</Button>
                <Button disabled={raiseMutation.isPending} type="submit" variant="primary">
                  {raiseMutation.isPending ? 'Submitting...' : 'Submit Ticket'}
                </Button>
              </div>
            </form>
          </div>
        </div>
      ) : null}
    </section>
  )
}
