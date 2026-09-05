import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Link, useParams } from 'react-router-dom'
import { apiFetchBlob } from '@/api/client/api-client'
import { appRoutes } from '@/app/navigation'
import { Button, DataTable, Fact, FactList, FormCard, FormField, Modal, Money, PageHeader, Quantity, SelectInput, StatusChip } from '@/design-system'
import { downloadBlob } from '@/shared/files/download-blob'
import { formatDate } from '@/shared/format/format'
import { useSessionStore } from '@/shared/session/session-store'
import { ConfirmedAction } from '@/shared/workflows/confirmed-action'
import { LocalDirectory } from '@/shared/workflows/local-directory'
import { QueryFeedback } from '@/shared/workflows/query-feedback'
import { WorkspaceBoundary } from '@/shared/workflows/workspace-boundary'
import { approvePayrollRun, calculatePayrollRun, cancelPayrollRun, getEmployee, getPayrollRun, getPayslip, listPayslips, postPayrollRun } from './payroll-api'

const lifecycle = { calculate: calculatePayrollRun, approve: approvePayrollRun, post: postPayrollRun, cancel: cancelPayrollRun }
type Action = keyof typeof lifecycle
const descriptions: Record<Action, string> = {
  calculate: 'Calculate or replace draft payslips using current salary structures and approved attendance. Review the resulting figures before approval.',
  approve: 'Approve this calculated payroll run? Review every payslip before continuing.',
  post: 'Post this approved payroll run to the general ledger? Posting salary liabilities is not a bank payment.',
  cancel: 'Cancel this unposted payroll run? Posted payroll cannot be cancelled here.',
}
export function PayrollRunDetailPage() {
  const { runId = '' } = useParams()
  return <WorkspaceBoundary roles={['OWNER', 'ADMIN', 'ACCOUNTANT']}><PayrollRunDetail key={runId} id={runId} /></WorkspaceBoundary>
}
function PayrollRunDetail({ id }: { id: string }) {
  const orgId = useSessionStore((s) => s.user!.orgId)
  const client = useQueryClient()
  const runQuery = useQuery({ queryKey: ['payroll-runs', orgId, id], queryFn: () => getPayrollRun(id), enabled: !!id })
  const slipsQuery = useQuery({ queryKey: ['payroll-runs', orgId, id, 'payslips'], queryFn: () => listPayslips(id), enabled: !!id })
  const [action, setAction] = useState<Action | null>(null)
  const [slip, setSlip] = useState<string | null>(null)
  const [format, setFormat] = useState('GENERIC')
  const run = runQuery.data
  const canCalculate = run?.status === 'DRAFT' || run?.status === 'CALCULATED'
  return <section className="workspace-page"><Link to={appRoutes.payrollRuns}>Back to payroll runs</Link><PageHeader eyebrow="HR and payroll" title={run ? `Payroll: ${formatDate(run.periodStart)} to ${formatDate(run.periodEnd)}` : 'Payroll run'} description="Review server-calculated salaries, approve, and post the payroll liability." />
    <QueryFeedback query={runQuery}>{run && <><FormCard title="Payroll summary" headerAction={<StatusChip status={run.status} />}><FactList><Fact label="Employees" value={run.employeeCount} /><Fact label="Gross payroll" value={<Money amount={run.grossTotal} />} /><Fact label="Deductions" value={<Money amount={run.deductionTotal} />} /><Fact label="Employer contributions" value={<Money amount={run.employerContributionTotal} />} /><Fact label="Net payable" value={<Money amount={run.netPayTotal} />} /><Fact label="Journal" value={run.journalEntryId ? <Link to={appRoutes.journalDetail(run.journalEntryId)}>Open posted journal</Link> : 'Not posted'} /></FactList><div className="document-actions">{canCalculate && <Button onClick={() => setAction('calculate')}>{run.status === 'DRAFT' ? 'Calculate payroll' : 'Recalculate payroll'}</Button>}{run.status === 'CALCULATED' && <Button onClick={() => setAction('approve')}>Approve payroll</Button>}{run.status === 'APPROVED' && <Button onClick={() => setAction('post')}>Post to general ledger</Button>}{['DRAFT', 'CALCULATED', 'APPROVED'].includes(run.status) && <Button variant="destructive" onClick={() => setAction('cancel')}>Cancel run</Button>}</div></FormCard>
      <FormCard title="Payroll exports"><p>These downloads use the existing payroll generators. Downloading does not send a bank payment or file a statutory return. Review the files before use.</p><FormField label="Bank file format"><SelectInput value={format} onChange={(e) => setFormat(e.target.value)}>{['GENERIC', 'HDFC', 'ICICI', 'SBI'].map((value) => <option key={value}>{value}</option>)}</SelectInput></FormField><div className="document-actions"><PayrollDownload path={`/api/v1/payroll/runs/${encodeURIComponent(id)}/bank-file?format=${format}`} filename={`salary-${run.periodStart}-${format}.csv`} accept="text/csv" label="Download bank CSV" /><PayrollDownload path={`/api/v1/payroll/runs/${encodeURIComponent(id)}/ecr`} filename={`pf-ecr-${run.periodStart}.txt`} accept="text/plain" label="Download PF ECR" /><PayrollDownload path={`/api/v1/payroll/runs/${encodeURIComponent(id)}/esi-return`} filename={`esi-${run.periodStart}.csv`} accept="text/csv" label="Download ESIC return" /></div></FormCard>
    </>}</QueryFeedback>
    <FormCard title="Employee payslips"><QueryFeedback query={slipsQuery}><LocalDirectory rows={slipsQuery.data ?? []} caption="Payroll payslips" searchText={(row) => `${row.employeeName ?? ''} ${row.employeeCode ?? ''} ${row.status ?? ''}`} header={<tr><th>Employee</th><th className="numeric-cell">LOP days</th><th className="numeric-cell">Gross</th><th className="numeric-cell">Deductions</th><th className="numeric-cell">Employer contributions</th><th className="numeric-cell">Net payable</th><th>Actions</th></tr>} renderRow={(row) => <tr key={row.id}><td><PayrollEmployeeName id={row.employeeId} /></td><td className="numeric-cell"><Quantity value={row.lopDays} /></td><td className="numeric-cell"><Money amount={row.grossPay} /></td><td className="numeric-cell"><Money amount={row.totalDeductions} /></td><td className="numeric-cell"><Money amount={row.employerContributions} /></td><td className="numeric-cell"><Money amount={row.netPay} /></td><td><Button variant="ghost" onClick={() => setSlip(row.id)}>View payslip</Button></td></tr>} /></QueryFeedback></FormCard>
    {action && <ConfirmedAction title={`${action} payroll`} description={descriptions[action]} destructive={action === 'cancel'} run={() => lifecycle[action](id)} onClose={() => setAction(null)} onDone={() => { setAction(null); void client.invalidateQueries({ queryKey: ['payroll-runs'] }) }} />}
    {slip && <PayslipDetail id={slip} onClose={() => setSlip(null)} />}
  </section>
}
function PayrollEmployeeName({ id }: { id: string }) {
  const orgId = useSessionStore((s) => s.user!.orgId)
  const query = useQuery({ queryKey: ['payroll-employee', orgId, id], queryFn: () => getEmployee(id) })
  return <Link to={appRoutes.employeeDetail(id)}>{query.data ? `${query.data.fullName}${query.data.employeeCode ? ` (${query.data.employeeCode})` : ''}` : query.isError ? 'Employee unavailable' : 'Loading employee...'}</Link>
}
function PayslipDetail({ id, onClose }: { id: string; onClose: () => void }) {
  const orgId = useSessionStore((s) => s.user!.orgId)
  const query = useQuery({ queryKey: ['payslip', orgId, id], queryFn: () => getPayslip(id) })
  const slip = query.data
  return <Modal isOpen size="lg" title="Payslip breakdown" onClose={onClose} footer={<><PayrollDownload path={`/api/v1/payroll/payslips/${encodeURIComponent(id)}/pdf`} filename="payslip.pdf" accept="application/pdf" label="Download payslip PDF" /><Button variant="secondary" onClick={onClose}>Close</Button></>}><QueryFeedback query={query}>{slip && <><PayrollEmployeeName id={slip.employeeId} /><FactList><Fact label="Gross pay" value={<Money amount={slip.grossPay} />} /><Fact label="Deductions" value={<Money amount={slip.totalDeductions} />} /><Fact label="Net payable" value={<Money amount={slip.netPay} />} /></FactList><DataTable caption="Payslip component lines"><thead><tr><th>Component type</th><th className="numeric-cell">Amount</th></tr></thead><tbody>{slip.lines?.map((line) => <tr key={line.id}><td>{line.componentType ?? 'Component'}</td><td className="numeric-cell"><Money amount={line.amount} /></td></tr>)}</tbody></DataTable><p>The JSON service omits component names; the generated PDF contains the detailed pay slip.</p></>}</QueryFeedback></Modal>
}
function PayrollDownload({ path, filename, accept, label }: { path: string; filename: string; accept: string; label: string }) {
  const identity = useSessionStore((s) => `${s.user?.orgId}:${s.user?.id}`)
  const download = useMutation({ mutationFn: async () => {
    const blob = await apiFetchBlob(path, accept)
    const user = useSessionStore.getState().user
    if (`${user?.orgId}:${user?.id}` !== identity) throw new Error('The workspace changed. Download again from the current workspace.')
    downloadBlob(blob, filename)
  } })
  return <div><Button variant="secondary" loading={download.isPending} disabled={download.isPending} onClick={() => download.mutate()}>{label}</Button>{download.error && <p role="alert" className="form-error">{download.error.message}</p>}</div>
}
