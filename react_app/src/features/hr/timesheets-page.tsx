import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  CheckCircle2,
  Clock,
  Plus,
  Send,
  Trash2,
  X,
} from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import {
  approveTimesheet,
  deleteTimesheet,
  listMyTimesheets,
  listPendingTimesheets,
  logTimesheet,
  submitTimesheetRange,
} from '@/features/hr/hr-api'

const timesheetTabs = [
  { key: 'mine', label: 'My Timesheets' },
  { key: 'pending', label: 'Pending Approvals (Manager)' },
] as const

type TimesheetTab = (typeof timesheetTabs)[number]['key']

export function TimesheetsPage() {
  const [activeTab, setActiveTab] = useState<TimesheetTab>('mine')
  const [isLogOpen, setIsLogOpen] = useState(false)
  const [from] = useState('2026-08-25')
  const [to] = useState('2026-08-31')

  const queryClient = useQueryClient()

  const myQuery = useQuery({
    queryKey: ['hr-timesheets-mine', from, to],
    queryFn: () => listMyTimesheets(from, to),
  })

  const pendingQuery = useQuery({
    queryKey: ['hr-timesheets-pending'],
    queryFn: () => listPendingTimesheets(),
  })

  const logMutation = useMutation({
    mutationFn: (req: { workDate: string; project?: string; task?: string; hours: number; billable: boolean; notes?: string }) =>
      logTimesheet(req),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['hr-timesheets-mine'] })
      setIsLogOpen(false)
    },
  })

  const submitMutation = useMutation({
    mutationFn: () => submitTimesheetRange(from, to),
    onSuccess: (data) => {
      queryClient.invalidateQueries({ queryKey: ['hr-timesheets-mine'] })
      alert(`${data.submitted} timesheet entries submitted for manager approval.`)
    },
  })

  const approveMutation = useMutation({
    mutationFn: (id: string) => approveTimesheet(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['hr-timesheets-pending'] })
    },
  })

  const deleteMutation = useMutation({
    mutationFn: (id: string) => deleteTimesheet(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['hr-timesheets-mine'] })
    },
  })

  const myEntries = myQuery.data ?? []
  const pendingEntries = pendingQuery.data ?? []

  const totalHours = myEntries.reduce((acc, e) => acc + Number(e.hours || 0), 0)
  const billableHours = myEntries.filter((e) => e.billable).reduce((acc, e) => acc + Number(e.hours || 0), 0)

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Core HR"
        title="Project Timesheets"
        description="Weekly task time tracking, billable project allocation, submission cycles, and manager approvals."
        actions={
          <div className="table-actions">
            <Button
              disabled={submitMutation.isPending || myEntries.length === 0}
              onClick={() => submitMutation.mutate()}
              variant="secondary"
            >
              <Send aria-hidden="true" size={16} />
              Submit Range for Approval
            </Button>
            <Button onClick={() => setIsLogOpen(true)} variant="primary">
              <Plus aria-hidden="true" size={16} />
              Log Time
            </Button>
          </div>
        }
      />

      <div className="summary-strip">
        <div className="summary-card">
          <span className="summary-card__label">Logged Hours</span>
          <strong className="summary-card__value">{totalHours} hrs</strong>
          <span className="summary-card__hint">Selected period total</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__label">Billable Hours</span>
          <strong className="summary-card__value text-success">{billableHours} hrs</strong>
          <span className="summary-card__hint">Client invoiceable</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__label">Entries</span>
          <strong className="summary-card__value">{myEntries.length}</strong>
          <span className="summary-card__hint">Activity line items</span>
        </div>
      </div>

      <div className="list-toolbar">
        <div aria-label="Timesheet tabs" className="list-tabs" role="tablist">
          {timesheetTabs.map((tab) => (
            <button
              aria-selected={activeTab === tab.key}
              className={activeTab === tab.key ? 'list-tab list-tab--active' : 'list-tab'}
              key={tab.key}
              onClick={() => setActiveTab(tab.key)}
              role="tab"
              type="button"
            >
              {tab.label}
              {tab.key === 'pending' && pendingEntries.length > 0 ? (
                <span className="status-badge" style={{ marginLeft: 6 }}>{pendingEntries.length}</span>
              ) : null}
            </button>
          ))}
        </div>
      </div>

      {activeTab === 'mine' ? (
        <div>
          {myEntries.length === 0 ? (
            <div className="directory-state">
              <Clock aria-hidden="true" size={24} />
              <strong>No timesheet entries in this date range.</strong>
              <p>Click "Log Time" to record project and task work hours.</p>
            </div>
          ) : (
            <DataTable caption="Logged personal timesheet activity">
              <thead>
                <tr>
                  <th scope="col">Work Date</th>
                  <th scope="col">Project</th>
                  <th scope="col">Task / Activity</th>
                  <th className="numeric-cell" scope="col">Hours</th>
                  <th scope="col">Billable</th>
                  <th scope="col">Status</th>
                  <th scope="col">Actions</th>
                </tr>
              </thead>
              <tbody>
                {myEntries.map((e) => (
                  <tr key={e.id}>
                    <td><strong>{formatDate(e.workDate)}</strong></td>
                    <td>{e.project || 'General Operations'}</td>
                    <td>{e.task || 'Routine Tasks'}</td>
                    <td className="numeric-cell"><strong>{e.hours} hrs</strong></td>
                    <td><StatusChip status={e.billable ? 'Billable' : 'Internal'} /></td>
                    <td><StatusChip status={formatStatusLabel(e.status || 'DRAFT')} /></td>
                    <td>
                      {e.status === 'DRAFT' ? (
                        <Button
                          disabled={deleteMutation.isPending}
                          onClick={() => deleteMutation.mutate(e.id)}
                          variant="ghost"
                        >
                          <Trash2 aria-hidden="true" size={14} />
                        </Button>
                      ) : null}
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          )}
        </div>
      ) : null}

      {activeTab === 'pending' ? (
        <div>
          {pendingEntries.length === 0 ? (
            <div className="directory-state">
              <CheckCircle2 aria-hidden="true" size={24} />
              <strong>No pending timesheets awaiting approval.</strong>
            </div>
          ) : (
            <DataTable caption="Submitted timesheets awaiting manager approval">
              <thead>
                <tr>
                  <th scope="col">Work Date</th>
                  <th scope="col">Staff</th>
                  <th scope="col">Project & Task</th>
                  <th className="numeric-cell" scope="col">Hours</th>
                  <th scope="col">Billable</th>
                  <th scope="col">Actions</th>
                </tr>
              </thead>
              <tbody>
                {pendingEntries.map((e) => (
                  <tr key={e.id}>
                    <td>{formatDate(e.workDate)}</td>
                    <td><strong>{e.userName || 'Staff Member'}</strong></td>
                    <td>{e.project} Â· {e.task}</td>
                    <td className="numeric-cell"><strong>{e.hours} hrs</strong></td>
                    <td><StatusChip status={e.billable ? 'Billable' : 'Internal'} /></td>
                    <td>
                      <Button
                        disabled={approveMutation.isPending}
                        onClick={() => approveMutation.mutate(e.id)}
                        variant="primary"
                      >
                        Approve
                      </Button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          )}
        </div>
      ) : null}

      {/* Log Time Modal */}
      {isLogOpen ? (
        <div className="modal-backdrop" role="presentation">
          <div aria-labelledby="log-title" aria-modal="true" className="modal-dialog" role="dialog">
            <div className="modal-header">
              <h2 id="log-title">Log Timesheet Activity</h2>
              <button className="icon-button" onClick={() => setIsLogOpen(false)} type="button">
                <X aria-hidden="true" size={18} />
              </button>
            </div>
            <form
              onSubmit={(e) => {
                e.preventDefault()
                const fd = new FormData(e.currentTarget)
                logMutation.mutate({
                  workDate: String(fd.get('workDate') ?? ''),
                  project: String(fd.get('project') ?? '').trim() || undefined,
                  task: String(fd.get('task') ?? '').trim() || undefined,
                  hours: Number(fd.get('hours') ?? 8),
                  billable: fd.get('billable') === 'on',
                  notes: String(fd.get('notes') ?? '').trim() || undefined,
                })
              }}
            >
              <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                <div>
                  <label className="form-label">Work Date *</label>
                  <input className="text-input" defaultValue={new Date().toISOString().slice(0, 10)} name="workDate" required type="date" />
                </div>
                <div>
                  <label className="form-label">Project Name</label>
                  <input className="text-input" name="project" placeholder="e.g. ERP Implementation / Client Audit" type="text" />
                </div>
                <div>
                  <label className="form-label">Task / Description</label>
                  <input className="text-input" name="task" placeholder="e.g. Data migration and report validation" type="text" />
                </div>
                <div>
                  <label className="form-label">Hours Logged *</label>
                  <input className="text-input" defaultValue={8} min={0.5} name="hours" required step={0.5} type="number" />
                </div>
                <label style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
                  <input defaultChecked name="billable" type="checkbox" />
                  <span>Billable to Client</span>
                </label>
              </div>
              <div className="modal-footer">
                <Button onClick={() => setIsLogOpen(false)} type="button" variant="secondary">Cancel</Button>
                <Button disabled={logMutation.isPending} type="submit" variant="primary">Save Entry</Button>
              </div>
            </form>
          </div>
        </div>
      ) : null}
    </section>
  )
}
