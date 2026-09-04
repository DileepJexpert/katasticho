import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  ArrowLeft,
  Banknote,
  CheckCircle2,
  FileCheck,
} from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  DataTable,
  DocumentError,
  FormField,
  Modal,
  Money,
  NumberInput,
  PageHeader,
  StatusChip,
} from '@/design-system'
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
        description={`Last Working Day: ${offboarding.lastWorkingDay ? formatDate(offboarding.lastWorkingDay) : 'To be confirmed'} · Reason: ${offboarding.reason || 'Career Transition'}`}
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
      {isFnfModalOpen && (
        <Modal
          description="Final settlement calculation including unpaid salary, encashed leaves, and gratuity."
          footer={
            <>
              <Button onClick={() => setIsFnfModalOpen(false)} type="button" variant="secondary">Cancel</Button>
              <Button disabled={fnfMutation.isPending} onClick={() => fnfMutation.mutate(fnfAmount)} variant="primary">
                {fnfMutation.isPending ? 'Confirming...' : 'Confirm FnF Settlement'}
              </Button>
            </>
          }
          isOpen={isFnfModalOpen}
          onClose={() => setIsFnfModalOpen(false)}
          size="md"
          title="Full & Final (FnF) Settlement"
        >
          <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
            <FormField label="Computed Net FnF Settlement Amount (₹)" required>
              <NumberInput
                min={0}
                onChange={(e) => setFnfAmount(Number(e.target.value) || 0)}
                required
                step="0.01"
                value={fnfAmount}
              />
            </FormField>
            <p style={{ margin: 0, fontSize: '0.8rem', color: 'var(--color-text-muted)' }}>
              Includes prorated salary, leave encashment balance, notice pay recovery/payout, and gratuity.
            </p>
          </div>
        </Modal>
      )}
    </section>
  )
}

