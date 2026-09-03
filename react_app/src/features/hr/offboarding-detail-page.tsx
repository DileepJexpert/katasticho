import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  ArrowLeft,
  Banknote,
  CheckCircle2,
  FileCheck,
  FileText,
  X,
} from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import {
  completeOffboarding,
  completeOffboardingTask,
  getOffboarding,
  payGratuity,
  settleFnf,
} from '@/features/hr/hr-api'

export function OffboardingDetailPage() {
  const { offboardingId } = useParams<{ offboardingId: string }>()
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const [isFnfModalOpen, setIsFnfModalOpen] = useState(false)
  const [fnfAmount, setFnfAmount] = useState(75000)

  const query = useQuery({
    queryKey: ['hr-offboarding', offboardingId],
    queryFn: () => getOffboarding(offboardingId!),
    enabled: Boolean(offboardingId),
  })

  const taskMutation = useMutation({
    mutationFn: (taskId: string) => completeOffboardingTask(taskId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['hr-offboarding', offboardingId] })
    },
  })

  const fnfMutation = useMutation({
    mutationFn: (amount: number) => settleFnf(offboardingId!, amount),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['hr-offboarding', offboardingId] })
      setIsFnfModalOpen(false)
    },
  })

  const gratuityMutation = useMutation({
    mutationFn: () => payGratuity(offboardingId!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['hr-offboarding', offboardingId] })
      alert('Gratuity settlement posted to General Ledger.')
    },
  })

  const completeMutation = useMutation({
    mutationFn: () => completeOffboarding(offboardingId!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['hr-offboarding', offboardingId] })
    },
  })

  if (!offboardingId) return <DocumentError onBack={() => navigate(appRoutes.offboarding)} />
  if (query.isLoading) {
    return (
      <section className="workspace-page">
        <div aria-live="polite" className="directory-state">Loading exit clearance facts...</div>
      </section>
    )
  }
  if (query.isError || !query.data) {
    return <DocumentError onBack={() => navigate(appRoutes.offboarding)} />
  }

  const { offboarding, tasks = [] } = query.data
  

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Core HR / Exit Clearance"
        title={`Offboarding: ${offboarding.employeeName || 'Staff Member'}`}
        description={`Last Working Day: ${offboarding.lastWorkingDay ? formatDate(offboarding.lastWorkingDay) : 'To be confirmed'} Â· Reason: ${offboarding.reason || 'Career Transition'}`}
        actions={
          <div className="table-actions">
            <StatusChip status={formatStatusLabel(offboarding.status)} />
          </div>
        }
      />

      <div className="document-actions">
        <Button onClick={() => navigate(appRoutes.offboarding)} variant="secondary">
          <ArrowLeft aria-hidden="true" size={16} />
          Back to Offboarding List
        </Button>
        <Button onClick={() => setIsFnfModalOpen(true)} variant="secondary">
          <Banknote aria-hidden="true" size={16} />
          Settle FnF Statement
        </Button>
        <Button
          disabled={gratuityMutation.isPending}
          onClick={() => gratuityMutation.mutate()}
          variant="secondary"
        >
          <FileCheck aria-hidden="true" size={16} />
          Pay End-of-Service Gratuity
        </Button>
        {offboarding.status !== 'COMPLETED' ? (
          <Button
            disabled={completeMutation.isPending}
            onClick={() => completeMutation.mutate()}
            variant="primary"
          >
            <CheckCircle2 aria-hidden="true" size={16} />
            Final Offboarding Signoff
          </Button>
        ) : null}
      </div>

      <div className="summary-strip">
        <div className="summary-card">
          <span className="summary-card__label">Clearance Tasks</span>
          <strong className="summary-card__value">
            {tasks.filter((t) => t.completed).length} / {tasks.length || 4}
          </strong>
          <span className="summary-card__hint">Department handovers</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__label">FnF Settlement</span>
          <strong className="summary-card__value text-success">
            {offboarding.fnfSettlementAmount ? <Money amount={offboarding.fnfSettlementAmount} /> : 'Pending calculation'}
          </strong>
          <span className="summary-card__hint">Net exit dues</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__label">Gratuity Provision</span>
          <strong className="summary-card__value">
            {offboarding.gratuityAmount ? <Money amount={offboarding.gratuityAmount} /> : 'Statutory rule'}
          </strong>
          <span className="summary-card__hint">End of service benefit</span>
        </div>
      </div>

      <div className="document-section">
        <h2>Multi-department clearance checklist</h2>
        {tasks.length === 0 ? (
          <div className="directory-state">No clearance tasks assigned.</div>
        ) : (
          <DataTable caption="Clearance checklist items across departments">
            <thead>
              <tr>
                <th scope="col">Department</th>
                <th scope="col">Clearance Task</th>
                <th scope="col">Status</th>
                <th scope="col">Completion Date</th>
                <th scope="col">Action</th>
              </tr>
            </thead>
            <tbody>
              {tasks.map((task) => (
                <tr key={task.id}>
                  <td><strong>{task.department}</strong></td>
                  <td>{task.title || task.taskName || 'Clearance Check'}</td>
                  <td><StatusChip status={task.completed ? 'Cleared' : 'Pending'} /></td>
                  <td>{task.completedAt ? formatDate(task.completedAt) : 'â€”'}</td>
                  <td>
                    {!task.completed ? (
                      <Button
                        disabled={taskMutation.isPending}
                        onClick={() => taskMutation.mutate(task.id)}
                        variant="primary"
                      >
                        Sign Off Task
                      </Button>
                    ) : (
                      <span className="cell-muted">Signed off</span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        )}
      </div>

      {/* Settle FnF Modal */}
      {isFnfModalOpen ? (
        <div className="modal-backdrop" role="presentation">
          <div aria-labelledby="fnf-modal-title" aria-modal="true" className="modal-dialog" role="dialog">
            <div className="modal-header">
              <h2 id="fnf-modal-title">Full & Final (FnF) Settlement</h2>
              <button className="icon-button" onClick={() => setIsFnfModalOpen(false)} type="button">
                <X aria-hidden="true" size={18} />
              </button>
            </div>
            <form
              onSubmit={(e) => {
                e.preventDefault()
                fnfMutation.mutate(fnfAmount)
              }}
            >
              <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                <div>
                  <label className="form-label">Computed Net FnF Settlement Amount (â‚¹) *</label>
                  <input
                    className="text-input"
                    onChange={(e) => setFnfAmount(Number(e.target.value) || 0)}
                    required
                    type="number"
                    value={fnfAmount}
                  />
                  <p className="cell-muted" style={{ fontSize: '0.8rem', marginTop: 4 }}>
                    Includes prorated salary, leave encashment balance, notice pay recovery/payout, and gratuity.
                  </p>
                </div>
              </div>
              <div className="modal-footer">
                <Button onClick={() => setIsFnfModalOpen(false)} type="button" variant="secondary">Cancel</Button>
                <Button disabled={fnfMutation.isPending} type="submit" variant="primary">Confirm FnF Settlement</Button>
              </div>
            </form>
          </div>
        </div>
      ) : null}
    </section>
  )
}

function DocumentError({ onBack }: { onBack: () => void }) {
  return (
    <section className="workspace-page">
      <div className="directory-state directory-state--error" role="alert">
        <FileText aria-hidden="true" size={24} />
        <strong>Unable to load offboarding record.</strong>
        <p>The record was not found or your session cannot access this workspace.</p>
        <Button onClick={onBack} variant="secondary">
          <ArrowLeft aria-hidden="true" size={16} />
          Back to Offboarding
        </Button>
      </div>
    </section>
  )
}
