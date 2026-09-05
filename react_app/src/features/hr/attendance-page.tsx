import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Button, Fact, FactList, FilterTabs, FormCard, FormGrid, Modal, PageHeader, StatusChip } from '@/design-system'
import { TextField } from '@/design-system/text-field'
import { listOrgUsers } from '@/features/settings/settings-api'
import { useSessionStore } from '@/shared/session/session-store'
import { ConfirmedAction } from '@/shared/workflows/confirmed-action'
import { LocalDirectory } from '@/shared/workflows/local-directory'
import { QueryFeedback } from '@/shared/workflows/query-feedback'
import { WorkspaceBoundary } from '@/shared/workflows/workspace-boundary'
import { approveRegularization, getAttendanceSummary, getAttendanceToday, listMyRegularizations, listPendingRegularizations, recordAttendancePunch, rejectRegularization, requestRegularization } from './hr-api'
import { regularizationTime } from './regularization-time'

function today() { const now = new Date(); return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}` }
export function AttendancePage() { return <WorkspaceBoundary roles={['OWNER', 'ADMIN', 'ACCOUNTANT', 'OPERATOR', 'VIEWER']}><Attendance /></WorkspaceBoundary> }
function Attendance() {
  const user = useSessionStore((s) => s.user!)
  const admin = ['OWNER', 'ADMIN'].includes(user.role)
  const client = useQueryClient()
  const [tab, setTab] = useState('summary')
  const [month, setMonth] = useState(today().slice(0, 7))
  const [create, setCreate] = useState(false)
  const [action, setAction] = useState<{ type: 'punch-in' | 'punch-out' | 'approve' | 'reject'; id?: string } | null>(null)
  const [reason, setReason] = useState('')
  const summary = useQuery({ queryKey: ['hr-attendance', user.orgId, user.id, 'summary', month], queryFn: () => getAttendanceSummary(undefined, `${month}-01`), enabled: !!month })
  const current = useQuery({ queryKey: ['hr-attendance', user.orgId, user.id, 'today'], queryFn: getAttendanceToday })
  const mine = useQuery({ queryKey: ['hr-attendance', user.orgId, user.id, 'mine'], queryFn: listMyRegularizations, enabled: tab === 'mine' })
  const pending = useQuery({ queryKey: ['hr-attendance', user.orgId, 'pending'], queryFn: listPendingRegularizations, enabled: admin && tab === 'pending' })
  const users = useQuery({ queryKey: ['hr-attendance', user.orgId, 'users'], queryFn: listOrgUsers, enabled: admin && tab === 'pending' })
  const refresh = () => { setCreate(false); setAction(null); void client.invalidateQueries({ queryKey: ['hr-attendance'] }) }
  const directory = tab === 'pending' ? pending : mine
  return <section className="workspace-page"><PageHeader eyebrow="Core HR" title="Attendance and regularization" description="Actual server attendance records and approved punch corrections." actions={<Button onClick={() => setCreate(true)}>Request regularization</Button>} /><FilterTabs activeValue={tab} onChange={setTab} ariaLabel="Attendance sections" items={[{ value: 'summary', label: 'Monthly summary' }, { value: 'mine', label: 'My requests' }, ...(admin ? [{ value: 'pending', label: 'Pending approvals' }] : [])]} />
    {tab === 'summary' ? <><FormCard title="Daily punch clock"><QueryFeedback query={current}><FactList><Fact label="Punch in" value={current.data?.punchInAt ? new Date(current.data.punchInAt).toLocaleString() : 'Not recorded'} /><Fact label="Punch out" value={current.data?.punchOutAt ? new Date(current.data.punchOutAt).toLocaleString() : 'Not recorded'} /></FactList><div className="document-actions"><Button disabled={!current.isSuccess || !!current.data?.punchInAt} onClick={() => setAction({ type: 'punch-in' })}>Punch in</Button><Button variant="secondary" disabled={!current.data?.punchInAt || !!current.data.punchOutAt} onClick={() => setAction({ type: 'punch-out' })}>Punch out</Button></div></QueryFeedback><p>The server records the punch time for your signed-in account. This office punch does not include GPS coordinates.</p></FormCard><FormCard title="Monthly attendance"><TextField label="Month" type="month" value={month} onChange={(e) => setMonth(e.target.value)} /><QueryFeedback query={summary}>{summary.data && <FactList><Fact label="Present days" value={summary.data.presentDays ?? '--'} /><Fact label="Absent days" value={summary.data.absentDays ?? '--'} /><Fact label="Approved leave days (paid and unpaid)" value={summary.data.leaveDays ?? '--'} /><Fact label="Payable days" value={summary.data.payableDays ?? '--'} /><Fact label="Recorded hours" value={summary.data.totalHours ?? '--'} /><Fact label="Holidays" value={summary.data.holidays ?? '--'} /></FactList>}</QueryFeedback></FormCard></> : <QueryFeedback query={directory}><LocalDirectory rows={directory.data ?? []} caption="Attendance corrections" searchText={(row) => `${row.workDate} ${row.reason} ${row.status}`} header={<tr><th>Date</th><th>Employee</th><th>Requested punch in</th><th>Requested punch out</th><th>Reason</th><th>Status</th><th>Actions</th></tr>} renderRow={(row) => <tr key={row.id}><td>{row.workDate}</td><td>{row.userId === user.id ? user.fullName || user.email : users.data?.find((entry) => entry.id === row.userId)?.fullName || 'Employee unavailable'}</td><td>{row.requestedPunchIn ? new Date(row.requestedPunchIn).toLocaleString() : '--'}</td><td>{row.requestedPunchOut ? new Date(row.requestedPunchOut).toLocaleString() : '--'}</td><td>{row.reason}</td><td><StatusChip status={row.status} /></td><td>{admin && row.status === 'PENDING' && <div className="table-actions"><Button variant="secondary" onClick={() => setAction({ type: 'approve', id: row.id })}>Approve</Button><Button variant="destructive" onClick={() => { setReason(''); setAction({ type: 'reject', id: row.id }) }}>Reject</Button></div>}</td></tr>} /></QueryFeedback>}
    {create && <RegularizationForm onClose={() => setCreate(false)} onDone={refresh} />}
    {action && action.type !== 'reject' && <ConfirmedAction title={action.type === 'approve' ? 'Approve attendance correction' : action.type === 'punch-in' ? 'Record punch in' : 'Record punch out'} description={action.type === 'approve' ? 'Approval writes the requested punch times onto the employee attendance record. Confirm you checked the correction.' : 'Record this attendance punch now using the server time?'} run={() => action.type === 'approve' ? approveRegularization(action.id!) : recordAttendancePunch(action.type as 'punch-in' | 'punch-out')} onClose={() => setAction(null)} onDone={refresh} />}
    {action?.type === 'reject' && <RejectRegularization id={action.id!} reason={reason} setReason={setReason} onClose={() => setAction(null)} onDone={refresh} />}
  </section>
}
function RegularizationForm({ onClose, onDone }: { onClose: () => void; onDone: () => void }) {
  const [error, setError] = useState('')
  const save = useMutation({ mutationFn: requestRegularization, onSuccess: onDone })
  return <Modal isOpen title="Request attendance regularization" onClose={() => { if (!save.isPending) onClose() }} error={error || save.error?.message} footer={<><Button variant="secondary" disabled={save.isPending} onClick={onClose}>Cancel</Button><Button type="submit" form="attendance-correction" disabled={save.isPending} loading={save.isPending}>Submit request</Button></>}><p>Times use this device's local timezone and are converted to UTC for the API. For an overnight shift, submit each affected date separately.</p><form id="attendance-correction" onSubmit={(event) => { event.preventDefault(); if (save.isPending) return; setError(''); const form = new FormData(event.currentTarget); const workDate = String(form.get('date') ?? ''); const reason = String(form.get('reason') ?? '').trim(); try { if (!reason) throw new Error('Enter a reason.'); save.mutate({ workDate, reason, ...regularizationTime(workDate, String(form.get('in') ?? ''), String(form.get('out') ?? '')) }) } catch (cause) { setError(cause instanceof Error ? cause.message : 'Invalid punch times.') } }}><FormGrid><TextField label="Work date" type="date" name="date" required defaultValue={today()} /><TextField label="Punch in time" type="time" name="in" /><TextField label="Punch out time" type="time" name="out" /><TextField label="Reason" name="reason" required /></FormGrid></form></Modal>
}
function RejectRegularization({ id, reason, setReason, onClose, onDone }: { id: string; reason: string; setReason: (value: string) => void; onClose: () => void; onDone: () => void }) {
  const save = useMutation({ mutationFn: () => rejectRegularization(id, reason.trim()), onSuccess: onDone })
  return <Modal isOpen title="Reject attendance correction" onClose={() => { if (!save.isPending) onClose() }} error={save.error?.message} footer={<Button variant="destructive" disabled={!reason.trim() || save.isPending} onClick={() => save.mutate()}>Confirm rejection</Button>}><TextField label="Rejection reason" required value={reason} onChange={(e) => setReason(e.target.value)} /></Modal>
}
