import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import {
  ArrowLeft,
  CheckCircle2,
  Play,
  ShieldAlert,
  ShieldCheck,
  XCircle,
} from 'lucide-react'
import { Link, useParams } from 'react-router-dom'
import {
  Button,
  FormField,
  Modal,
  PageHeader,
  StatusChip,
  TextAreaInput,
} from '@/design-system'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import {
  cancelCapa,
  completeCapa,
  getCapa,
  startCapa,
  verifyCapa,
} from '@/features/capa/capa-api'

export function CapaDetailPage() {
  const { capaId = '' } = useParams<{ capaId: string }>()
  const queryClient = useQueryClient()
  const [feedback, setFeedback] = useState<{ type: 'success' | 'error'; message: string } | null>(null)

  // Action Modals State
  const [isCompleteModalOpen, setIsCompleteModalOpen] = useState(false)
  const [completionNotes, setCompletionNotes] = useState('')

  const [isVerifyModalOpen, setIsVerifyModalOpen] = useState(false)
  const [effectivenessNotes, setEffectivenessNotes] = useState('')

  const [isCancelModalOpen, setIsCancelModalOpen] = useState(false)
  const [cancelReason, setCancelReason] = useState('')

  const query = useQuery({
    queryKey: ['capa-detail', capaId],
    queryFn: () => getCapa(capaId),
    enabled: Boolean(capaId),
  })

  const capa = query.data

  // Mutations
  const startMutation = useMutation({
    mutationFn: () => startCapa(capaId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['capa-detail', capaId] })
      queryClient.invalidateQueries({ queryKey: ['capas'] })
      setFeedback({ type: 'success', message: 'CAPA moved to In Progress investigation.' })
    },
    onError: (err: unknown) => {
      setFeedback({
        type: 'error',
        message: err instanceof Error ? err.message : 'Failed to start CAPA investigation.',
      })
    },
  })

  const completeMutation = useMutation({
    mutationFn: () => completeCapa(capaId, completionNotes),
    onSuccess: () => {
      setIsCompleteModalOpen(false)
      setCompletionNotes('')
      queryClient.invalidateQueries({ queryKey: ['capa-detail', capaId] })
      queryClient.invalidateQueries({ queryKey: ['capas'] })
      setFeedback({ type: 'success', message: 'CAPA marked as Completed. Pending QA effectiveness verification.' })
    },
    onError: (err: unknown) => {
      setFeedback({
        type: 'error',
        message: err instanceof Error ? err.message : 'Failed to complete CAPA.',
      })
    },
  })

  const verifyMutation = useMutation({
    mutationFn: () => verifyCapa(capaId, effectivenessNotes),
    onSuccess: () => {
      setIsVerifyModalOpen(false)
      setEffectivenessNotes('')
      queryClient.invalidateQueries({ queryKey: ['capa-detail', capaId] })
      queryClient.invalidateQueries({ queryKey: ['capas'] })
      setFeedback({ type: 'success', message: 'CAPA successfully Verified for compliance & effectiveness.' })
    },
    onError: (err: unknown) => {
      setFeedback({
        type: 'error',
        message: err instanceof Error ? err.message : 'Failed to verify CAPA.',
      })
    },
  })

  const cancelMutation = useMutation({
    mutationFn: () => cancelCapa(capaId, cancelReason),
    onSuccess: () => {
      setIsCancelModalOpen(false)
      setCancelReason('')
      queryClient.invalidateQueries({ queryKey: ['capa-detail', capaId] })
      queryClient.invalidateQueries({ queryKey: ['capas'] })
      setFeedback({ type: 'success', message: 'CAPA has been cancelled.' })
    },
    onError: (err: unknown) => {
      setFeedback({
        type: 'error',
        message: err instanceof Error ? err.message : 'Failed to cancel CAPA.',
      })
    },
  })

  if (query.isLoading) {
    return (
      <section className="workspace-page">
        <div aria-live="polite" className="directory-state">
          Loading CAPA remediation details...
        </div>
      </section>
    )
  }

  if (query.isError || !capa) {
    return (
      <section className="workspace-page">
        <div className="directory-state directory-state--error" role="alert">
          <ShieldAlert aria-hidden="true" size={24} />
          <strong>CAPA record not found or inaccessible.</strong>
          <Link className="btn btn--secondary" to="/capa">
            Back to CAPA Hub
          </Link>
        </div>
      </section>
    )
  }

  return (
    <section className="workspace-page">
      <div style={{ marginBottom: 'var(--space-sm)' }}>
        <Link className="table-row-action" to="/capa">
          <ArrowLeft aria-hidden="true" size={14} style={{ display: 'inline', marginRight: 4 }} />
          Back to all CAPAs
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
        eyebrow="Quality & Compliance / CAPA"
        title={`CAPA #${capa.capaNumber}: ${capa.title}`}
        description={`${capa.capaType} action · Priority: ${capa.priority}`}
        actions={
          <div style={{ display: 'flex', gap: 'var(--space-sm)', flexWrap: 'wrap' }}>
            {capa.status === 'OPEN' && (
              <Button
                disabled={startMutation.isPending}
                onClick={() => startMutation.mutate()}
                variant="primary"
              >
                <Play aria-hidden="true" size={14} style={{ marginRight: 6 }} />
                Start Investigation
              </Button>
            )}

            {capa.status === 'IN_PROGRESS' && (
              <Button onClick={() => setIsCompleteModalOpen(true)} variant="primary">
                <CheckCircle2 aria-hidden="true" size={14} style={{ marginRight: 6 }} />
                Complete Remediation
              </Button>
            )}

            {capa.status === 'COMPLETED' && (
              <Button onClick={() => setIsVerifyModalOpen(true)} variant="primary">
                <ShieldCheck aria-hidden="true" size={14} style={{ marginRight: 6 }} />
                Verify Effectiveness
              </Button>
            )}

            {capa.status !== 'CANCELLED' && capa.status !== 'VERIFIED' && (
              <Button onClick={() => setIsCancelModalOpen(true)} variant="destructive">
                <XCircle aria-hidden="true" size={14} style={{ marginRight: 6 }} />
                Cancel CAPA
              </Button>
            )}
          </div>
        }
      />

      {/* Summary Cards */}
      <div className="summary-strip">
        <div className="summary-card">
          <span className="summary-card__label">Action Type</span>
          <strong className="summary-card__value" style={{ fontSize: '1.1rem' }}>
            {capa.capaType}
          </strong>
          <span className="summary-card__hint">Remediation category</span>
        </div>

        <div className="summary-card">
          <span className="summary-card__label">Target Due Date</span>
          <strong className="summary-card__value" style={{ fontSize: '1.1rem' }}>
            {capa.dueDate ? formatDate(capa.dueDate) : 'No due date'}
          </strong>
          <span className="summary-card__hint">Resolution SLA</span>
        </div>

        <div className="summary-card">
          <span className="summary-card__label">Lifecycle Status</span>
          <div style={{ marginTop: 4 }}>
            <StatusChip status={formatStatusLabel(capa.status)} />
          </div>
          <span className="summary-card__hint">Current workflow step</span>
        </div>

        <div className="summary-card summary-card--accent">
          <span className="summary-card__label">Priority Level</span>
          <strong
            className="summary-card__value"
            style={{
              color:
                capa.priority === 'URGENT' || capa.priority === 'HIGH'
                  ? 'var(--color-danger)'
                  : 'inherit',
            }}
          >
            {capa.priority}
          </strong>
          <span className="summary-card__hint">Assigned: {capa.assigneeName || 'Unassigned'}</span>
        </div>
      </div>

      {/* Linked NCR Notice */}
      {capa.ncrId && (
        <div className="banner banner--info" style={{ marginBottom: 'var(--space-md)' }}>
          <ShieldAlert size={16} />
          <span>
            Raised from Non-Conformance Report <strong>#{capa.ncrNumber || capa.ncrId}</strong>.{' '}
            <Link to={`/ncrs/${capa.ncrId}`} style={{ textDecoration: 'underline', fontWeight: 600 }}>
              View Root Cause Investigation
            </Link>
          </span>
        </div>
      )}

      {/* Detailed Content Panels */}
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))',
          gap: 'var(--space-md)',
          marginBottom: 'var(--space-md)',
        }}
      >
        <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
          <h3 style={{ fontSize: '1.05rem', margin: '0 0 var(--space-sm) 0' }}>Issue Description & Background</h3>
          <p style={{ margin: 0, fontSize: '0.9rem', lineHeight: 1.5 }} className="cell-muted">
            {capa.description || 'No detailed issue description provided.'}
          </p>
        </div>

        <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
          <h3 style={{ fontSize: '1.05rem', margin: '0 0 var(--space-sm) 0' }}>Proposed Corrective / Preventive Plan</h3>
          <p style={{ margin: 0, fontSize: '0.9rem', lineHeight: 1.5, color: 'var(--color-primary)' }}>
            {capa.proposedAction || 'Action plan under formulation.'}
          </p>
        </div>
      </div>

      {/* Completion & Verification Audit Card */}
      <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
        <h3 style={{ fontSize: '1.05rem', margin: '0 0 var(--space-md) 0' }}>Remediation & QA Sign-off History</h3>
        <dl className="document-facts">
          <div className="document-fact">
            <dt>Raised On</dt>
            <dd>{formatDate(capa.createdAt)}</dd>
          </div>
          <div className="document-fact">
            <dt>Completion Log</dt>
            <dd>
              {capa.completedAt ? (
                <div>
                  <strong>{formatDate(capa.completedAt)}</strong>
                  <p style={{ margin: '4px 0 0 0', fontSize: '0.85rem' }} className="cell-muted">
                    {capa.completionNotes || 'Remediation work completed.'}
                  </p>
                </div>
              ) : (
                <span className="cell-muted">Pending completion</span>
              )}
            </dd>
          </div>
          <div className="document-fact">
            <dt>QA Effectiveness Verification</dt>
            <dd>
              {capa.verifiedAt ? (
                <div>
                  <strong className="text-success">{formatDate(capa.verifiedAt)}</strong>
                  <p style={{ margin: '4px 0 0 0', fontSize: '0.85rem' }} className="text-success">
                    {capa.effectivenessNotes || 'Verified effective by QA auditor.'}
                  </p>
                </div>
              ) : (
                <span className="cell-muted">Pending verification</span>
              )}
            </dd>
          </div>
          {capa.cancelledAt && (
            <div className="document-fact">
              <dt>Cancellation Reason</dt>
              <dd className="text-danger">
                <strong>{formatDate(capa.cancelledAt)}</strong>: {capa.cancellationReason || 'No reason provided.'}
              </dd>
            </div>
          )}
        </dl>
      </div>

      {/* Complete Modal */}
      <Modal
        description="Document the corrective or preventive actions implemented on the production floor / warehouse."
        footer={
          <>
            <Button onClick={() => setIsCompleteModalOpen(false)} type="button" variant="secondary">
              Cancel
            </Button>
            <Button disabled={completeMutation.isPending || !completionNotes.trim()} onClick={() => completeMutation.mutate()} variant="primary">
              {completeMutation.isPending ? 'Saving...' : 'Confirm Completion'}
            </Button>
          </>
        }
        isOpen={isCompleteModalOpen}
        onClose={() => setIsCompleteModalOpen(false)}
        size="md"
        title="Complete CAPA Remediation"
      >
        <FormField label="Implementation Notes" required>
          <TextAreaInput
            onChange={(e) => setCompletionNotes(e.target.value)}
            placeholder="Details of SOP revision, machine recalibration, or operator retraining..."
            required
            rows={3}
            value={completionNotes}
          />
        </FormField>
      </Modal>

      {/* Verify Modal */}
      <Modal
        description="Confirm that the root-cause has been eliminated and no repeat defects occurred in subsequent batches."
        footer={
          <>
            <Button onClick={() => setIsVerifyModalOpen(false)} type="button" variant="secondary">
              Cancel
            </Button>
            <Button disabled={verifyMutation.isPending || !effectivenessNotes.trim()} onClick={() => verifyMutation.mutate()} variant="primary">
              {verifyMutation.isPending ? 'Verifying...' : 'Sign Off Verification'}
            </Button>
          </>
        }
        isOpen={isVerifyModalOpen}
        onClose={() => setIsVerifyModalOpen(false)}
        size="md"
        title="Verify CAPA Effectiveness"
      >
        <FormField label="QA Effectiveness Evaluation" required>
          <TextAreaInput
            onChange={(e) => setEffectivenessNotes(e.target.value)}
            placeholder="Audit evidence confirming zero defect recurrence across 3 trial production runs..."
            required
            rows={3}
            value={effectivenessNotes}
          />
        </FormField>
      </Modal>

      {/* Cancel Modal */}
      <Modal
        description="State the justification for voiding or cancelling this remediation item."
        footer={
          <>
            <Button onClick={() => setIsCancelModalOpen(false)} type="button" variant="secondary">
              Cancel
            </Button>
            <Button disabled={cancelMutation.isPending || !cancelReason.trim()} onClick={() => cancelMutation.mutate()} variant="destructive">
              {cancelMutation.isPending ? 'Cancelling...' : 'Void CAPA'}
            </Button>
          </>
        }
        isOpen={isCancelModalOpen}
        onClose={() => setIsCancelModalOpen(false)}
        size="md"
        title="Cancel CAPA Action"
      >
        <FormField label="Cancellation Justification" required>
          <TextAreaInput
            onChange={(e) => setCancelReason(e.target.value)}
            placeholder="e.g. Obsolete equipment line or duplicate ticket..."
            required
            rows={3}
            value={cancelReason}
          />
        </FormField>
      </Modal>
    </section>
  )
}
