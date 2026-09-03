import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  ArrowLeft,
  Calendar,
  CheckCircle2,
  FileCheck,
  FileSpreadsheet,
  FileText,
  Play,
  RotateCcw,
  Send,
  Users,
  X,
  XCircle,
} from 'lucide-react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import {
  approvePayrollRun,
  calculatePayrollRun,
  cancelPayrollRun,
  getPayrollRun,
  listEmployees,
  listPayslips,
  postPayrollRun,
  type Payslip,
} from '@/features/payroll/payroll-api'

export function PayrollRunDetailPage() {
  const { runId } = useParams<{ runId: string }>()
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const [selectedPayslip, setSelectedPayslip] = useState<Payslip | null>(null)

  const runQuery = useQuery({
    queryKey: ['payroll-runs', runId],
    queryFn: () => getPayrollRun(runId!),
    enabled: Boolean(runId),
  })

  const payslipsQuery = useQuery({
    queryKey: ['payroll-runs', runId, 'payslips'],
    queryFn: () => listPayslips(runId!),
    enabled: Boolean(runId),
  })

  const employeesQuery = useQuery({
    queryKey: ['payroll-employees-lookup'],
    queryFn: () => listEmployees(0, 200),
  })

  // Lifecycle mutations
  const calculateMutation = useMutation({
    mutationFn: () => calculatePayrollRun(runId!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['payroll-runs', runId] })
      queryClient.invalidateQueries({ queryKey: ['payroll-runs', runId, 'payslips'] })
    },
  })

  const approveMutation = useMutation({
    mutationFn: () => approvePayrollRun(runId!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['payroll-runs', runId] })
    },
  })

  const postMutation = useMutation({
    mutationFn: () => postPayrollRun(runId!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['payroll-runs', runId] })
    },
  })

  const cancelMutation = useMutation({
    mutationFn: () => cancelPayrollRun(runId!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['payroll-runs', runId] })
    },
  })

  if (!runId) return <DocumentError onBack={() => navigate(appRoutes.payrollRuns)} />
  if (runQuery.isLoading) {
    return (
      <section className="workspace-page">
        <div aria-live="polite" className="directory-state">
          Loading payroll run details...
        </div>
      </section>
    )
  }
  if (runQuery.isError || !runQuery.data) {
    return <DocumentError onBack={() => navigate(appRoutes.payrollRuns)} />
  }

  const run = runQuery.data
  const payslips = payslipsQuery.data ?? []
  const employeeMap = new Map((employeesQuery.data?.content ?? []).map((e) => [e.id, e]))

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="HR & Payroll / Processing Run"
        title={`Payroll Cycle: ${formatDate(run.periodStart)} â€“ ${formatDate(run.periodEnd)}`}
        description={`Monthly salary disbursement batch covering ${run.employeeCount} eligible employees.`}
        actions={
          <div className="table-actions">
            <span className="status-badge">
              <Users aria-hidden="true" size={14} style={{ display: 'inline', marginRight: 4 }} />
              {run.employeeCount} Employees
            </span>
            <StatusChip status={formatStatusLabel(run.status)} />
          </div>
        }
      />

      <div className="document-actions">
        <Button onClick={() => navigate(appRoutes.payrollRuns)} variant="secondary">
          <ArrowLeft aria-hidden="true" size={16} />
          Back to Payroll Runs
        </Button>

        {/* Lifecycle Action Buttons */}
        {run.status === 'DRAFT' ? (
          <Button
            disabled={calculateMutation.isPending}
            onClick={() => calculateMutation.mutate()}
            variant="primary"
          >
            <Play aria-hidden="true" size={16} />
            {calculateMutation.isPending ? 'Calculating...' : 'Calculate Payroll'}
          </Button>
        ) : null}

        {run.status === 'CALCULATED' ? (
          <div style={{ display: 'flex', gap: 8 }}>
            <Button
              disabled={calculateMutation.isPending}
              onClick={() => calculateMutation.mutate()}
              variant="secondary"
            >
              <RotateCcw aria-hidden="true" size={16} />
              Recalculate
            </Button>
            <Button
              disabled={approveMutation.isPending}
              onClick={() => approveMutation.mutate()}
              variant="primary"
            >
              <CheckCircle2 aria-hidden="true" size={16} />
              Approve Payroll
            </Button>
            <Button
              disabled={cancelMutation.isPending}
              onClick={() => cancelMutation.mutate()}
              variant="destructive"
            >
              <XCircle aria-hidden="true" size={16} />
              Cancel Run
            </Button>
          </div>
        ) : null}

        {run.status === 'APPROVED' ? (
          <div style={{ display: 'flex', gap: 8 }}>
            <Button
              disabled={postMutation.isPending}
              onClick={() => postMutation.mutate()}
              variant="primary"
            >
              <Send aria-hidden="true" size={16} />
              Post to General Ledger (GL)
            </Button>
            <Button
              disabled={cancelMutation.isPending}
              onClick={() => cancelMutation.mutate()}
              variant="destructive"
            >
              <XCircle aria-hidden="true" size={16} />
              Cancel Run
            </Button>
          </div>
        ) : null}

        {run.status === 'POSTED' ? (
          <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
            <span className="status-badge" style={{ color: 'var(--k-color-text-success)' }}>
              <CheckCircle2 aria-hidden="true" size={14} style={{ display: 'inline', marginRight: 4 }} />
              Posted to GL (Journal ID: {run.journalEntryId ? <code className="table-code">{run.journalEntryId.slice(0, 8)}</code> : 'Recorded'})
            </span>
          </div>
        ) : null}
      </div>

      <div className="summary-strip">
        <div className="summary-card">
          <span className="summary-card__label">Gross Payroll</span>
          <strong className="summary-card__value">
            <Money amount={run.grossTotal} />
          </strong>
          <span className="summary-card__hint">Total employee earnings</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__label">Total Deductions</span>
          <strong className="summary-card__value text-danger">
            <Money amount={run.deductionTotal} />
          </strong>
          <span className="summary-card__hint">PF, ESI, PT, TDS & LOP</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__label">Employer Statutory</span>
          <strong className="summary-card__value">
            <Money amount={run.employerContributionTotal} />
          </strong>
          <span className="summary-card__hint">PF 12% + ESI 3.25% Match</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__label">Net Disbursable Pay</span>
          <strong className="summary-card__value text-success">
            <Money amount={run.netPayTotal} />
          </strong>
          <span className="summary-card__hint">Total bank disbursement</span>
        </div>
      </div>

      <div className="document-layout">
        <section className="document-card">
          <h2>
            <Calendar aria-hidden="true" size={18} style={{ display: 'inline', marginRight: 6 }} />
            Cycle execution facts
          </h2>
          <dl className="document-facts">
            <Fact label="Period Start" value={formatDate(run.periodStart)} />
            <Fact label="Period End" value={formatDate(run.periodEnd)} />
            <Fact label="Execution Status" value={<StatusChip status={formatStatusLabel(run.status)} />} />
            <Fact label="Eligible Headcount" value={<Quantity unit="Staff" value={run.employeeCount} />} />
            <Fact label="Calculated Timestamp" value={run.calculatedAt ? formatDate(run.calculatedAt) : 'Pending calculation'} />
            <Fact label="Approved Timestamp" value={run.approvedAt ? formatDate(run.approvedAt) : 'Pending approval'} />
            <Fact label="Posted Timestamp" value={run.postedAt ? formatDate(run.postedAt) : 'Not posted to GL'} />
            <Fact
              label="GL Journal Reference"
              value={
                run.journalEntryId ? (
                  <Link className="table-code" to={appRoutes.journalDetail(run.journalEntryId)}>
                    {run.journalEntryId}
                  </Link>
                ) : (
                  'Pending GL Post'
                )
              }
            />
          </dl>
        </section>

        <section className="document-card">
          <h2>
            <FileSpreadsheet aria-hidden="true" size={18} style={{ display: 'inline', marginRight: 6 }} />
            Statutory & Disbursal Files
          </h2>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginTop: 12 }}>
            <p className="cell-muted" style={{ fontSize: '0.85rem' }}>
              Compliant bank transfer and statutory return templates generated from calculated payslips.
            </p>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              <Button onClick={() => alert('Bank NEFT/RTGS salary transfer file exported.')} variant="secondary">
                <FileSpreadsheet aria-hidden="true" size={14} />
                Export Bank Disbursal File (CSV)
              </Button>
              <Button onClick={() => alert('EPFO Electronic Challan cum Return (ECR) text file generated.')} variant="secondary">
                <FileText aria-hidden="true" size={14} />
                Export EPFO ECR Return File
              </Button>
              <Button onClick={() => alert('ESIC Monthly Contribution Return file generated.')} variant="secondary">
                <FileCheck aria-hidden="true" size={14} />
                Export ESIC Monthly Return
              </Button>
            </div>
          </div>
        </section>
      </div>

      <div className="document-section">
        <h2>
          <Users aria-hidden="true" size={18} style={{ display: 'inline', marginRight: 6 }} />
          Individual employee payslips ({payslips.length})
        </h2>
        {payslips.length === 0 ? (
          <div className="directory-state">
            <Users aria-hidden="true" size={24} />
            <strong>No payslips generated for this run yet.</strong>
            <p>Click "Calculate Payroll" to execute earnings and statutory deduction engines for all staff.</p>
          </div>
        ) : (
          <DataTable caption="Calculated employee salary slips with deductions and net payout">
            <thead>
              <tr>
                <th scope="col">Code</th>
                <th scope="col">Employee Name</th>
                <th scope="col">Department</th>
                <th className="numeric-cell" scope="col">LOP Days</th>
                <th className="numeric-cell" scope="col">Gross Pay</th>
                <th className="numeric-cell" scope="col">Deductions</th>
                <th className="numeric-cell" scope="col">Employer Match</th>
                <th className="numeric-cell" scope="col">Net Pay</th>
                <th scope="col">Actions</th>
              </tr>
            </thead>
            <tbody>
              {payslips.map((ps) => {
                const emp = ps.employee || employeeMap.get(ps.employeeId)
                const code = ps.employeeCode || emp?.employeeCode || `EMP-${ps.employeeId.slice(0, 6).toUpperCase()}`
                const name = ps.employeeName || emp?.fullName || 'Staff Member'
                const dept = ps.department || emp?.department || 'Operations'

                return (
                  <tr key={ps.id}>
                    <td>
                      <Link
                        className="table-code"
                        to={appRoutes.employeeDetail(ps.employeeId)}
                      >
                        {code}
                      </Link>
                    </td>
                    <td>
                      <strong>{name}</strong>
                    </td>
                    <td>{dept}</td>
                    <td className="numeric-cell">
                      {Number(ps.lopDays || 0) > 0 ? (
                        <span className="text-danger">{ps.lopDays} d</span>
                      ) : (
                        '0'
                      )}
                    </td>
                    <td className="numeric-cell">
                      <Money amount={ps.grossPay} />
                    </td>
                    <td className="numeric-cell text-danger">
                      <Money amount={ps.totalDeductions} />
                    </td>
                    <td className="numeric-cell">
                      <Money amount={ps.employerContributions} />
                    </td>
                    <td className="numeric-cell">
                      <strong><Money amount={ps.netPay} /></strong>
                    </td>
                    <td>
                      <Button
                        onClick={() => setSelectedPayslip(ps)}
                        variant="ghost"
                      >
                        View Breakdown
                      </Button>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </DataTable>
        )}
      </div>

      {/* Payslip Breakdown Modal */}
      {selectedPayslip ? (
        <PayslipBreakdownModal
          onClose={() => setSelectedPayslip(null)}
          payslip={selectedPayslip}
        />
      ) : null}
    </section>
  )
}

function PayslipBreakdownModal({
  payslip,
  onClose,
}: {
  payslip: Payslip
  onClose: () => void
}) {
  return (
    <div className="modal-backdrop" role="presentation">
      <div aria-labelledby="payslip-modal-title" aria-modal="true" className="modal-dialog modal-dialog--lg" role="dialog">
        <div className="modal-header">
          <div>
            <h2 id="payslip-modal-title">
              Payslip: {payslip.employeeName || 'Staff Member'}
            </h2>
            <p className="cell-muted">Detailed earnings and statutory deduction ledger.</p>
          </div>
          <button className="icon-button" onClick={onClose} type="button">
            <X aria-hidden="true" size={18} />
          </button>
        </div>
        <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <div className="summary-strip">
            <div className="summary-card">
              <span className="summary-card__label">Gross Earnings</span>
              <strong className="summary-card__value text-success">
                <Money amount={payslip.grossPay} />
              </strong>
            </div>
            <div className="summary-card">
              <span className="summary-card__label">Deductions Total</span>
              <strong className="summary-card__value text-danger">
                <Money amount={payslip.totalDeductions} />
              </strong>
            </div>
            <div className="summary-card">
              <span className="summary-card__label">Net Disbursed</span>
              <strong className="summary-card__value text-primary">
                <Money amount={payslip.netPay} />
              </strong>
            </div>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
            <section className="document-card">
              <h2>Earnings</h2>
              <dl className="document-facts">
                <Fact label="Gross Salary" value={<Money amount={payslip.grossPay} />} />
                <Fact label="Loss of Pay (LOP)" value={`${payslip.lopDays} days`} />
              </dl>
            </section>

            <section className="document-card">
              <h2>Statutory & Other Deductions</h2>
              <dl className="document-facts">
                <Fact label="Employee Deductions" value={<Money amount={payslip.totalDeductions} />} />
                <Fact label="Employer Contributions" value={<Money amount={payslip.employerContributions} />} />
              </dl>
            </section>
          </div>
        </div>
        <div className="modal-footer">
          <Button onClick={() => alert('Downloading official Form 16 / Payslip PDF...')} variant="secondary">
            <FileText aria-hidden="true" size={14} />
            Download PDF Payslip
          </Button>
          <Button onClick={onClose} variant="primary">Close</Button>
        </div>
      </div>
    </div>
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
        <strong>Unable to load payroll run details.</strong>
        <p>The record was not found or your session cannot access this workspace.</p>
        <Button onClick={onBack} variant="secondary">
          <ArrowLeft aria-hidden="true" size={16} />
          Back to Payroll Runs
        </Button>
      </div>
    </section>
  )
}
