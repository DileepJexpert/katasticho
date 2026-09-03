import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  ArrowLeft,
  CheckCircle2,
  FileText,
  MessageSquare,
  Send,
  X,
} from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import {
  addTicketComment,
  getTicket,
  updateTicketStatus,
} from '@/features/hr/hr-api'

export function HrTicketDetailPage() {
  const { ticketId } = useParams<{ ticketId: string }>()
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const [commentText, setCommentText] = useState('')
  const [statusVal, setStatusVal] = useState('RESOLVED')
  const [resolutionText, setResolutionText] = useState('')
  const [isStatusModalOpen, setIsStatusModalOpen] = useState(false)

  const query = useQuery({
    queryKey: ['hr-ticket', ticketId],
    queryFn: () => getTicket(ticketId!),
    enabled: Boolean(ticketId),
  })

  const commentMutation = useMutation({
    mutationFn: (body: string) => addTicketComment(ticketId!, body),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['hr-ticket', ticketId] })
      setCommentText('')
    },
  })

  const statusMutation = useMutation({
    mutationFn: ({ status, resolution }: { status: string; resolution?: string }) =>
      updateTicketStatus(ticketId!, status, resolution),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['hr-ticket', ticketId] })
      setIsStatusModalOpen(false)
    },
  })

  if (!ticketId) return <DocumentError onBack={() => navigate(appRoutes.hrTickets)} />
  if (query.isLoading) {
    return (
      <section className="workspace-page">
        <div aria-live="polite" className="directory-state">Loading ticket thread...</div>
      </section>
    )
  }
  if (query.isError || !query.data) {
    return <DocumentError onBack={() => navigate(appRoutes.hrTickets)} />
  }

  const { ticket, comments = [] } = query.data

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Core HR / Help Desk"
        title={ticket.subject}
        description={`Category: ${ticket.category} Â· Priority: ${ticket.priority} Â· Raised: ${ticket.createdAt ? formatDate(ticket.createdAt) : 'â€”'}`}
        actions={
          <div className="table-actions">
            <StatusChip status={formatStatusLabel(ticket.status)} />
          </div>
        }
      />

      <div className="document-actions">
        <Button onClick={() => navigate(appRoutes.hrTickets)} variant="secondary">
          <ArrowLeft aria-hidden="true" size={16} />
          Back to Tickets
        </Button>
        <Button onClick={() => setIsStatusModalOpen(true)} variant="primary">
          <CheckCircle2 aria-hidden="true" size={16} />
          Update Status & Resolution
        </Button>
      </div>

      <div className="document-layout">
        <section className="document-card">
          <h2>Ticket description & details</h2>
          <dl className="document-facts">
            <Fact label="Category" value={ticket.category} />
            <Fact label="Priority" value={ticket.priority} />
            <Fact label="Requester" value={ticket.requesterName || 'Staff Member'} />
            <Fact label="Assigned HR Specialist" value={ticket.assigneeName || 'Unassigned'} />
            <Fact label="Created Date" value={ticket.createdAt ? formatDate(ticket.createdAt) : 'â€”'} />
            <Fact label="Resolution Note" value={ticket.resolution || 'Pending resolution'} />
          </dl>
          <div style={{ marginTop: 14, padding: 12, background: 'var(--k-color-surface-sunken)', borderRadius: 6 }}>
            <p style={{ margin: 0, fontSize: '0.95rem' }}>{ticket.description || 'No additional details provided.'}</p>
          </div>
        </section>

        <section className="document-card">
          <h2>
            <MessageSquare aria-hidden="true" size={18} style={{ display: 'inline', marginRight: 6 }} />
            Conversation Thread ({comments.length})
          </h2>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12, marginTop: 12 }}>
            {comments.length === 0 ? (
              <p className="cell-muted">No messages posted yet. Reply below to communicate with the employee.</p>
            ) : (
              comments.map((c) => (
                <div
                  key={c.id}
                  style={{
                    padding: 10,
                    borderRadius: 6,
                    border: '1px solid var(--k-color-border-subtle)',
                    background: c.isHr ? 'var(--k-color-surface-sunken)' : 'var(--k-color-surface-elevated)',
                  }}
                >
                  <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.8rem', color: 'var(--k-color-text-muted)' }}>
                    <strong>{c.authorName || (c.isHr ? 'HR Support' : 'Staff')}</strong>
                    <span>{c.createdAt ? formatDate(c.createdAt) : 'â€”'}</span>
                  </div>
                  <p style={{ margin: '6px 0 0 0', fontSize: '0.9rem' }}>{c.body}</p>
                </div>
              ))
            )}

            <form
              onSubmit={(e) => {
                e.preventDefault()
                if (!commentText.trim()) return
                commentMutation.mutate(commentText.trim())
              }}
              style={{ marginTop: 8, display: 'flex', flexDirection: 'column', gap: 8 }}
            >
              <textarea
                className="text-input"
                onChange={(e) => setCommentText(e.target.value)}
                placeholder="Write a reply to the ticket..."
                rows={3}
                value={commentText}
              />
              <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
                <Button disabled={commentMutation.isPending || !commentText.trim()} type="submit" variant="primary">
                  <Send aria-hidden="true" size={14} />
                  Post Reply
                </Button>
              </div>
            </form>
          </div>
        </section>
      </div>

      {/* Update Status Modal */}
      {isStatusModalOpen ? (
        <div className="modal-backdrop" role="presentation">
          <div aria-labelledby="status-modal-title" aria-modal="true" className="modal-dialog" role="dialog">
            <div className="modal-header">
              <h2 id="status-modal-title">Update Ticket Status & Resolution</h2>
              <button className="icon-button" onClick={() => setIsStatusModalOpen(false)} type="button">
                <X aria-hidden="true" size={18} />
              </button>
            </div>
            <form
              onSubmit={(e) => {
                e.preventDefault()
                statusMutation.mutate({ status: statusVal, resolution: resolutionText })
              }}
            >
              <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                <div>
                  <label className="form-label">Status</label>
                  <select
                    className="select-input"
                    onChange={(e) => setStatusVal(e.target.value)}
                    value={statusVal}
                  >
                    <option value="IN_PROGRESS">In Progress</option>
                    <option value="RESOLVED">Resolved</option>
                    <option value="CLOSED">Closed</option>
                  </select>
                </div>
                <div>
                  <label className="form-label">Resolution Details</label>
                  <textarea
                    className="text-input"
                    onChange={(e) => setResolutionText(e.target.value)}
                    placeholder="Explanation of resolution provided..."
                    rows={4}
                    value={resolutionText}
                  />
                </div>
              </div>
              <div className="modal-footer">
                <Button onClick={() => setIsStatusModalOpen(false)} type="button" variant="secondary">Cancel</Button>
                <Button disabled={statusMutation.isPending} type="submit" variant="primary">Apply Status</Button>
              </div>
            </form>
          </div>
        </div>
      ) : null}
    </section>
  )
}

function Fact({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div>
      <dt className="document-fact-label">{label}</dt>
      <dd className="document-fact-value">{value}</dd>
    </div>
  )
}

function DocumentError({ onBack }: { onBack: () => void }) {
  return (
    <section className="workspace-page">
      <div className="directory-state directory-state--error" role="alert">
        <FileText aria-hidden="true" size={24} />
        <strong>Unable to load ticket details.</strong>
        <p>The record was not found or your session cannot access this workspace.</p>
        <Button onClick={onBack} variant="secondary">
          <ArrowLeft aria-hidden="true" size={16} />
          Back to Tickets
        </Button>
      </div>
    </section>
  )
}
