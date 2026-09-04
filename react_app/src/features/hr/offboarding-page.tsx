import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  LogOut,
  Plus,
} from 'lucide-react'
import { Link } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  DataTable,
  FormField,
  FormGrid,
  Modal,
  Money,
  PageHeader,
  SelectInput,
  StatusChip,
  TextAreaInput,
  TextInput,
} from '@/design-system'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import {
  initiateOffboarding,
  listOffboardings,
} from '@/features/hr/hr-api'
import { listEmployees } from '@/features/payroll/payroll-api'

export function OffboardingPage() {
  const [isInitiateOpen, setIsInitiateOpen] = useState(false)
  const queryClient = useQueryClient()

  const offQuery = useQuery({
    queryKey: ['hr-offboarding-list'],
    queryFn: () => listOffboardings(),
  })

  const empQuery = useQuery({
    queryKey: ['payroll-employees-lookup'],
    queryFn: () => listEmployees(0, 100),
  })

  const initMutation = useMutation({
    mutationFn: (req: { employeeUserId: string; resignationDate?: string; lastWorkingDay?: string; reason?: string }) =>
      initiateOffboarding(req),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['hr-offboarding-list'] })
      setIsInitiateOpen(false)
    },
  })

  const offboardings = offQuery.data ?? []
  const employees = empQuery.data?.content ?? []

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Core HR"
        title="Offboarding & Exit Management"
        description="Employee resignations, notice periods, multi-department clearances (IT, Finance, HR), and Full & Final Settlements (FnF)."
        actions={
          <div className="table-actions">
            <Button onClick={() => setIsInitiateOpen(true)} variant="primary">
              <Plus aria-hidden="true" size={16} />
              Initiate Offboarding
            </Button>
          </div>
        }
      />

      <div className="summary-strip">
        <div className="summary-card">
          <span className="summary-card__label">In-Progress Exits</span>
          <strong className="summary-card__value text-warning">
            {offboardings.filter((o) => o.status === 'IN_PROGRESS' || o.status === 'INITIATED').length}
          </strong>
          <span className="summary-card__hint">Active clearance workflows</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__label">Clearance Done</span>
          <strong className="summary-card__value">
            {offboardings.filter((o) => o.status === 'CLEARANCE_DONE').length}
          </strong>
          <span className="summary-card__hint">Awaiting FnF settlement</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__label">Completed Exits</span>
          <strong className="summary-card__value text-success">
            {offboardings.filter((o) => o.status === 'COMPLETED').length}
          </strong>
          <span className="summary-card__hint">Fully signed off</span>
        </div>
      </div>

      {offQuery.isLoading ? (
        <div className="directory-state">Loading exit workflows...</div>
      ) : offboardings.length === 0 ? (
        <div className="directory-state">
          <LogOut aria-hidden="true" size={24} />
          <strong>No active offboarding records.</strong>
          <p>Click "Initiate Offboarding" to record employee resignation or exit.</p>
        </div>
      ) : (
        <DataTable caption="Active and historical employee offboarding records">
          <thead>
            <tr>
              <th scope="col">Employee Name</th>
              <th scope="col">Resignation Date</th>
              <th scope="col">Last Working Day</th>
              <th scope="col">Reason</th>
              <th className="numeric-cell" scope="col">FnF Settlement</th>
              <th scope="col">Status</th>
              <th scope="col">Actions</th>
            </tr>
          </thead>
          <tbody>
            {offboardings.map((o) => (
              <tr key={o.id}>
                <td>
                  <Link
                    className="table-code"
                    to={appRoutes.offboardingDetail(o.id)}
                  >
                    {o.employeeName || 'Staff Member'}
                  </Link>
                </td>
                <td>{o.resignationDate ? formatDate(o.resignationDate) : 'â€”'}</td>
                <td><strong>{o.lastWorkingDay ? formatDate(o.lastWorkingDay) : 'â€”'}</strong></td>
                <td>{o.reason || 'Career Transition'}</td>
                <td className="numeric-cell">
                  {o.fnfSettlementAmount ? <Money amount={o.fnfSettlementAmount} /> : <span className="cell-muted">Pending FnF</span>}
                </td>
                <td><StatusChip status={formatStatusLabel(o.status)} /></td>
                <td>
                  <Link
                    className="table-row-action"
                    to={appRoutes.offboardingDetail(o.id)}
                  >
                    Clearance Checklist
                  </Link>
                </td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      )}

      {/* Initiate Offboarding Modal */}
      {isInitiateOpen && (
        <Modal
          description="Commence exit separation workflow, notice period tracking, and department clearances."
          footer={
            <>
              <Button onClick={() => setIsInitiateOpen(false)} type="button" variant="secondary">Cancel</Button>
              <Button form="off-form" disabled={initMutation.isPending} type="submit" variant="primary">
                {initMutation.isPending ? 'Initiating...' : 'Initiate Offboarding'}
              </Button>
            </>
          }
          isOpen={isInitiateOpen}
          onClose={() => setIsInitiateOpen(false)}
          size="md"
          title="Initiate Employee Offboarding"
        >
          <form
            id="off-form"
            onSubmit={(e) => {
              e.preventDefault()
              const fd = new FormData(e.currentTarget)
              initMutation.mutate({
                employeeUserId: String(fd.get('employeeUserId') ?? ''),
                resignationDate: String(fd.get('resignationDate') ?? '') || undefined,
                lastWorkingDay: String(fd.get('lastWorkingDay') ?? '') || undefined,
                reason: String(fd.get('reason') ?? '').trim() || undefined,
              })
            }}
            style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}
          >
            <FormField label="Employee" required>
              <SelectInput name="employeeUserId" required>
                {employees.map((e) => (
                  <option key={e.id} value={e.userId || e.id}>
                    {e.fullName} ({e.employeeCode || 'EMP'})
                  </option>
                ))}
              </SelectInput>
            </FormField>
            <FormGrid columns={2}>
              <FormField label="Resignation Date">
                <TextInput defaultValue={new Date().toISOString().slice(0, 10)} name="resignationDate" type="date" />
              </FormField>
              <FormField label="Last Working Day">
                <TextInput name="lastWorkingDay" type="date" />
              </FormField>
            </FormGrid>
            <FormField label="Exit Reason">
              <TextAreaInput name="reason" placeholder="e.g. Higher studies / Relocation / Better opportunity" rows={3} />
            </FormField>
          </form>
        </Modal>
      )}
    </section>
  )
}
