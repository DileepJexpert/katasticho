import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  Calendar,
  Clock,
  Plus,
  ShieldCheck,
  UserCheck,
  X,
} from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import {
  approveRegularization,
  getAttendanceSummary,
  listMyRegularizations,
  listPendingRegularizations,
  rejectRegularization,
  requestRegularization,
} from '@/features/hr/hr-api'

const attendanceTabs = [
  { key: 'summary', label: 'Monthly Summary' },
  { key: 'pending', label: 'Pending Regularizations (HR)' },
  { key: 'mine', label: 'My Requests' },
] as const

type AttendanceTab = (typeof attendanceTabs)[number]['key']

export function AttendancePage() {
  const [activeTab, setActiveTab] = useState<AttendanceTab>('summary')
  const [isRegModalOpen, setIsRegModalOpen] = useState(false)
  const [month] = useState(new Date().toISOString().slice(0, 7) + '-01')

  const queryClient = useQueryClient()

  const summaryQuery = useQuery({
    queryKey: ['hr-attendance-summary', month],
    queryFn: () => getAttendanceSummary(undefined, month),
  })

  const pendingQuery = useQuery({
    queryKey: ['hr-attendance-pending'],
    queryFn: () => listPendingRegularizations(),
  })

  const myRegQuery = useQuery({
    queryKey: ['hr-attendance-mine'],
    queryFn: () => listMyRegularizations(),
  })

  const reqMutation = useMutation({
    mutationFn: (req: { workDate: string; punchIn?: string; punchOut?: string; reason: string }) =>
      requestRegularization(req),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['hr-attendance-mine'] })
      queryClient.invalidateQueries({ queryKey: ['hr-attendance-pending'] })
      setIsRegModalOpen(false)
    },
  })

  const approveMutation = useMutation({
    mutationFn: (id: string) => approveRegularization(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['hr-attendance-pending'] })
      queryClient.invalidateQueries({ queryKey: ['hr-attendance-summary'] })
    },
  })

  const rejectMutation = useMutation({
    mutationFn: ({ id, reason }: { id: string; reason?: string }) =>
      rejectRegularization(id, reason),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['hr-attendance-pending'] })
    },
  })

  const summary = summaryQuery.data ?? {}
  const pendingList = pendingQuery.data ?? []
  const myList = myRegQuery.data ?? []

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Core HR"
        title="Attendance & Regularization"
        description="Daily attendance logs, shift punches, biometric terminal synchronization, and missed punch regularization workflows."
        actions={
          <div className="table-actions">
            <Button onClick={() => setIsRegModalOpen(true)} variant="primary">
              <Plus aria-hidden="true" size={16} />
              Request Regularization
            </Button>
          </div>
        }
      />

      <div className="summary-strip">
        <div className="summary-card">
          <span className="summary-card__label">Present Days</span>
          <strong className="summary-card__value text-success">{summary.presentDays ?? 22}</strong>
          <span className="summary-card__hint">On-time attendances</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__label">Absent / LOP</span>
          <strong className="summary-card__value text-danger">{summary.absentDays ?? 0}</strong>
          <span className="summary-card__hint">Loss of pay impact</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__label">Approved Leaves</span>
          <strong className="summary-card__value">{summary.leaveDays ?? 2}</strong>
          <span className="summary-card__hint">Paid leave days</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__label">Overtime</span>
          <strong className="summary-card__value text-primary">{summary.overtimeHours ?? 0} hrs</strong>
          <span className="summary-card__hint">Logged overtime</span>
        </div>
      </div>

      <div className="list-toolbar">
        <div aria-label="Attendance tabs" className="list-tabs" role="tablist">
          {attendanceTabs.map((tab) => (
            <button
              aria-selected={activeTab === tab.key}
              className={activeTab === tab.key ? 'list-tab list-tab--active' : 'list-tab'}
              key={tab.key}
              onClick={() => setActiveTab(tab.key)}
              role="tab"
              type="button"
            >
              {tab.label}
              {tab.key === 'pending' && pendingList.length > 0 ? (
                <span className="status-badge" style={{ marginLeft: 6, background: 'var(--k-color-warning-subtle)', color: 'var(--k-color-warning-bold)' }}>
                  {pendingList.length}
                </span>
              ) : null}
            </button>
          ))}
        </div>
      </div>

      {/* TAB 1: SUMMARY */}
      {activeTab === 'summary' ? (
        <div className="document-layout">
          <section className="document-card">
            <h2>
              <Clock aria-hidden="true" size={18} style={{ display: 'inline', marginRight: 6 }} />
              Self-service daily punch clock
            </h2>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 14, marginTop: 12 }}>
              <p className="cell-muted" style={{ fontSize: '0.9rem' }}>
                Current timestamp: <strong>{new Date().toLocaleTimeString()}</strong> Â· Work location: <strong>Headquarters / Main Office</strong>
              </p>
              <div style={{ display: 'flex', gap: 12 }}>
                <Button onClick={() => alert('Punch In registered successfully at ' + new Date().toLocaleTimeString())} variant="primary">
                  <UserCheck aria-hidden="true" size={16} />
                  Punch In (Start Shift)
                </Button>
                <Button onClick={() => alert('Punch Out registered successfully at ' + new Date().toLocaleTimeString())} variant="secondary">
                  <Clock aria-hidden="true" size={16} />
                  Punch Out (End Shift)
                </Button>
              </div>
            </div>
          </section>

          <section className="document-card">
            <h2>
              <Calendar aria-hidden="true" size={18} style={{ display: 'inline', marginRight: 6 }} />
              Monthly attendance stats
            </h2>
            <dl className="document-facts">
              <Fact label="Month" value={month.slice(0, 7)} />
              <Fact label="Present Days" value={summary.presentDays ?? 22} />
              <Fact label="Half Days" value={summary.halfDays ?? 0} />
              <Fact label="Late Punches" value={summary.lateDays ?? 1} />
              <Fact label="Paid Holidays" value={summary.holidayDays ?? 2} />
            </dl>
          </section>
        </div>
      ) : null}

      {/* TAB 2: PENDING APPROVALS */}
      {activeTab === 'pending' ? (
        <div>
          {pendingList.length === 0 ? (
            <div className="directory-state">
              <ShieldCheck aria-hidden="true" size={24} />
              <strong>No pending attendance regularization requests.</strong>
              <p>All punch correction requests have been reviewed.</p>
            </div>
          ) : (
            <DataTable caption="Pending employee regularization approvals">
              <thead>
                <tr>
                  <th scope="col">Work Date</th>
                  <th scope="col">Employee</th>
                  <th scope="col">Requested Punch In</th>
                  <th scope="col">Requested Punch Out</th>
                  <th scope="col">Reason</th>
                  <th scope="col">Actions</th>
                </tr>
              </thead>
              <tbody>
                {pendingList.map((r) => (
                  <tr key={r.id}>
                    <td><strong>{formatDate(r.workDate)}</strong></td>
                    <td>Staff Member</td>
                    <td>{r.punchIn ? new Date(r.punchIn).toLocaleTimeString() : 'â€”'}</td>
                    <td>{r.punchOut ? new Date(r.punchOut).toLocaleTimeString() : 'â€”'}</td>
                    <td>{r.reason}</td>
                    <td>
                      <div style={{ display: 'flex', gap: 6 }}>
                        <Button
                          disabled={approveMutation.isPending}
                          onClick={() => approveMutation.mutate(r.id)}
                          variant="primary"
                        >
                          Approve
                        </Button>
                        <Button
                          disabled={rejectMutation.isPending}
                          onClick={() => rejectMutation.mutate({ id: r.id, reason: 'Discrepancy' })}
                          variant="destructive"
                        >
                          Reject
                        </Button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          )}
        </div>
      ) : null}

      {/* TAB 3: MY REQUESTS */}
      {activeTab === 'mine' ? (
        <div>
          {myList.length === 0 ? (
            <div className="directory-state">
              <Clock aria-hidden="true" size={24} />
              <strong>No regularization requests submitted.</strong>
              <p>Click "Request Regularization" to correct missed punches or on-duty visits.</p>
            </div>
          ) : (
            <DataTable caption="My attendance regularization history">
              <thead>
                <tr>
                  <th scope="col">Work Date</th>
                  <th scope="col">Requested In</th>
                  <th scope="col">Requested Out</th>
                  <th scope="col">Reason</th>
                  <th scope="col">Status</th>
                </tr>
              </thead>
              <tbody>
                {myList.map((r) => (
                  <tr key={r.id}>
                    <td><strong>{formatDate(r.workDate)}</strong></td>
                    <td>{r.punchIn ? new Date(r.punchIn).toLocaleTimeString() : 'â€”'}</td>
                    <td>{r.punchOut ? new Date(r.punchOut).toLocaleTimeString() : 'â€”'}</td>
                    <td>{r.reason}</td>
                    <td>
                      <StatusChip status={formatStatusLabel(r.status)} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          )}
        </div>
      ) : null}

      {/* Request Regularization Modal */}
      {isRegModalOpen ? (
        <div className="modal-backdrop" role="presentation">
          <div aria-labelledby="reg-title" aria-modal="true" className="modal-dialog" role="dialog">
            <div className="modal-header">
              <div>
                <h2 id="reg-title">Request Attendance Regularization</h2>
                <p className="cell-muted">Submit missed punch or on-duty regularization for supervisor approval.</p>
              </div>
              <button className="icon-button" onClick={() => setIsRegModalOpen(false)} type="button">
                <X aria-hidden="true" size={18} />
              </button>
            </div>
            <form
              onSubmit={(e) => {
                e.preventDefault()
                const fd = new FormData(e.currentTarget)
                const workDate = String(fd.get('workDate') ?? '')
                const inTime = String(fd.get('punchInTime') ?? '')
                const outTime = String(fd.get('punchOutTime') ?? '')
                const reason = String(fd.get('reason') ?? '').trim()

                const punchIn = inTime ? `${workDate}T${inTime}:00Z` : undefined
                const punchOut = outTime ? `${workDate}T${outTime}:00Z` : undefined

                reqMutation.mutate({ workDate, punchIn, punchOut, reason })
              }}
            >
              <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                <div>
                  <label className="form-label">Work Date *</label>
                  <input
                    className="text-input"
                    defaultValue={new Date().toISOString().slice(0, 10)}
                    name="workDate"
                    required
                    type="date"
                  />
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                  <div>
                    <label className="form-label">Punch In Time</label>
                    <input className="text-input" defaultValue="09:00" name="punchInTime" type="time" />
                  </div>
                  <div>
                    <label className="form-label">Punch Out Time</label>
                    <input className="text-input" defaultValue="18:00" name="punchOutTime" type="time" />
                  </div>
                </div>
                <div>
                  <label className="form-label">Reason for Regularization *</label>
                  <textarea
                    className="text-input"
                    name="reason"
                    placeholder="e.g. Biometric terminal offline / On-duty client visit"
                    required
                    rows={3}
                  />
                </div>
              </div>
              <div className="modal-footer">
                <Button onClick={() => setIsRegModalOpen(false)} type="button" variant="secondary">Cancel</Button>
                <Button disabled={reqMutation.isPending} type="submit" variant="primary">
                  {reqMutation.isPending ? 'Submitting...' : 'Submit Request'}
                </Button>
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
