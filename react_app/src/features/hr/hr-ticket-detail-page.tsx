import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  ArrowLeft,
  CheckCircle2,
  MessageSquare,
  Send,
} from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  DocumentCard,
  DocumentError,
  Fact,
  FactList,
  FormField,
  Modal,
  PageHeader,
  SelectInput,
  StatusChip,
  TextAreaInput,
} from '@/design-system'
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
  const [isStatusModalOpen, setIsStatusModalOpen] = useState(false)
  const [statusVal, setStatusVal] = useState('IN_PROGRESS')
  const [resolutionText, setResolutionText] = useState('')

  const ticketQuery = useQuery({
    queryKey: ['hr-ticket', ticketId],
    queryFn: () => getTicket(ticketId!),
    enabled: Boolean(ticketId),
  })

  const commentMutation = useMutation({
    mutationFn: (body: string) => addTicketComment(ticketId!, body),
    onSuccess: () => {
      setCommentText('')
      queryClient.invalidateQueries({ queryKey: ['hr-ticket', ticketId] })
    },
  })

  const statusMutation = useMutation({
    mutationFn: (payload: { status: string; resolution?: string }) =>
      updateTicketStatus(ticketId!, payload.status, payload.resolution),
    onSuccess: () => {
      setIsStatusModalOpen(false)
      queryClient.invalidateQueries({ queryKey: ['hr-ticket', ticketId] })
    },
  })

  if (!ticketId) return <DocumentError onBack={() => navigate(appRoutes.hrTickets)} />
  if (ticketQuery.isLoading) {
    return (
      <section className="workspace-page">
        <div aria-live="polite" className="directory-state">Loading ticket details...</div>
      </section>
    )
  }
  if (ticketQuery.isError || !ticketQuery.data) {
    return <DocumentError onBack={() => navigate(appRoutes.hrTickets)} />
  }

  const ticket = ticketQuery.data.ticket
  const comments = ticketQuery.data.comments ?? []

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <div className="table-actions">
            <Button onClick={() => navigate(appRoutes.hrTickets)} variant="secondary">
              <ArrowLeft aria-hidden="true" size={16} />
              Back to Tickets
            </Button>
            <Button onClick={() => setIsStatusModalOpen(true)} variant="primary">
              <CheckCircle2 aria-hidden="true" size={16} />
              Update Status & Resolution
            </Button>
          </div>
        }
        description={`Ticket #${ticket.ticketNumber || ticket.id.slice(0, 8)} · Submitted by ${ticket.requesterName || 'Employee'}`}
        eyebrow="Human Resources / Support Desk"
        title={ticket.subject}
      />

      <div className="document-layout">
        <DocumentCard title="Ticket description & details">
          <FactList>
            <Fact label="Status" value={<StatusChip status={ticket.status}>{formatStatusLabel(ticket.status)}</StatusChip>} />
            <Fact label="Category" value={ticket.category} />
            <Fact label="Priority" value={ticket.priority} />
            <Fact label="Requester" value={ticket.requesterName || 'Staff Member'} />
            <Fact label="Assigned HR Specialist" value={ticket.assigneeName || 'Unassigned'} />
            <Fact label="Created Date" value={ticket.createdAt ? formatDate(ticket.createdAt) : '—'} />
            <Fact label="Resolution Note" value={ticket.resolution || 'Pending resolution'} />
          </FactList>
          <div style={{ marginTop: 14, padding: 12, background: 'var(--k-color-surface-sunken)', borderRadius: 6 }}>
            <p style={{ margin: 0, fontSize: '0.95rem' }}>{ticket.description || 'No additional details provided.'}</p>
          </div>
        </DocumentCard>

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
              <TextAreaInput
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
      {isStatusModalOpen && (
        <Modal
          description="Change lifecycle status and document resolution provided to employee."
          footer={
            <>
              <Button onClick={() => setIsStatusModalOpen(false)} type="button" variant="secondary">Cancel</Button>
              <Button disabled={statusMutation.isPending} onClick={() => statusMutation.mutate({ status: statusVal, resolution: resolutionText })} variant="primary">
                {statusMutation.isPending ? 'Applying...' : 'Apply Status'}
              </Button>
            </>
          }
          isOpen={isStatusModalOpen}
          onClose={() => setIsStatusModalOpen(false)}
          size="md"
          title="Update Ticket Status & Resolution"
        >
          <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
            <FormField label="Status">
              <SelectInput
                onChange={(e) => setStatusVal(e.target.value)}
                value={statusVal}
              >
                <option value="IN_PROGRESS">In Progress</option>
                <option value="RESOLVED">Resolved</option>
                <option value="CLOSED">Closed</option>
              </SelectInput>
            </FormField>
            <FormField label="Resolution Details">
              <TextAreaInput
                onChange={(e) => setResolutionText(e.target.value)}
                placeholder="Explanation of resolution provided..."
                rows={4}
                value={resolutionText}
              />
            </FormField>
          </div>
        </Modal>
      )}
    </section>
  )
}

