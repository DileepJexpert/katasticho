import { useState, useMemo } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import {
  AlertCircle,
  Calendar,
  CheckCircle2,
  Clock,
  LogIn,
  LogOut,
  MapPin,
  RefreshCw,
  Users,
  XCircle,
} from 'lucide-react'
import {
  Button,
  DataTable,
  DocumentCard,
  PageHeader,
  StatusChip,
} from '@/design-system'
import {
  approveLeave,
  getPendingLeaves,
  getTeamAttendance,
  getTodayAttendance,
  punchIn,
  punchOut,
  rejectLeave,
  type AttendancePunch,
  type LeaveRequest,
} from '@/features/field-sales/field-sales-api'

function getTodayIso(): string {
  const now = new Date()
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`
}

export function FieldAttendancePage() {
  const queryClient = useQueryClient()
  const [selectedDate, setSelectedDate] = useState(getTodayIso())
  const [punchMessage, setPunchMessage] = useState<string | null>(null)
  const [punchError, setPunchError] = useState<string | null>(null)

  const todayAttendanceQuery = useQuery({
    queryKey: ['attendance', 'today'],
    queryFn: () => getTodayAttendance(),
  })

  const teamAttendanceQuery = useQuery({
    queryKey: ['attendance', 'team', selectedDate],
    queryFn: () => getTeamAttendance(selectedDate),
  })

  const leavesQuery = useQuery({
    queryKey: ['attendance', 'leaves', 'pending'],
    queryFn: () => getPendingLeaves(),
  })

  function handleRefresh() {
    queryClient.invalidateQueries({ queryKey: ['attendance'] })
  }

  const punchInMutation = useMutation({
    mutationFn: async () => {
      let lat = 0
      let lng = 0
      try {
        if (navigator.geolocation) {
          const pos = await new Promise<GeolocationPosition>((resolve, reject) => {
            navigator.geolocation.getCurrentPosition(resolve, reject, { timeout: 10000 })
          })
          lat = pos.coords.latitude
          lng = pos.coords.longitude
        }
      } catch {
        // Fall back to 0,0 if geolocation permission denied or timeout
      }
      return punchIn(lat, lng, 'Punched in from web console')
    },
    onSuccess: () => {
      setPunchMessage('Successfully punched in for today.')
      setPunchError(null)
      queryClient.invalidateQueries({ queryKey: ['attendance'] })
    },
    onError: (err: Error) => {
      setPunchError(err.message || 'Failed to punch in.')
    },
  })

  const punchOutMutation = useMutation({
    mutationFn: async () => {
      let lat = 0
      let lng = 0
      try {
        if (navigator.geolocation) {
          const pos = await new Promise<GeolocationPosition>((resolve, reject) => {
            navigator.geolocation.getCurrentPosition(resolve, reject, { timeout: 10000 })
          })
          lat = pos.coords.latitude
          lng = pos.coords.longitude
        }
      } catch {
        // Fall back
      }
      return punchOut(lat, lng)
    },
    onSuccess: () => {
      setPunchMessage('Successfully punched out.')
      setPunchError(null)
      queryClient.invalidateQueries({ queryKey: ['attendance'] })
    },
    onError: (err: Error) => {
      setPunchError(err.message || 'Failed to punch out.')
    },
  })

  const approveLeaveMutation = useMutation({
    mutationFn: (id: string) => approveLeave(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['attendance', 'leaves'] })
    },
  })

  const rejectLeaveMutation = useMutation({
    mutationFn: ({ id, reason }: { id: string; reason: string }) => rejectLeave(id, reason),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['attendance', 'leaves'] })
    },
  })

  const myPunch = todayAttendanceQuery.data
  const teamList: AttendancePunch[] = useMemo(() => teamAttendanceQuery.data ?? [], [teamAttendanceQuery.data])
  const pendingLeaves: LeaveRequest[] = useMemo(() => leavesQuery.data ?? [], [leavesQuery.data])

  const isPunchedIn = Boolean(myPunch?.punchInTime && !myPunch?.punchOutTime)
  const isPunchedOut = Boolean(myPunch?.punchOutTime)

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <div className="flex items-center gap-2">
            <Button
              aria-label="Refresh attendance"
              onClick={handleRefresh}
              variant="secondary"
            >
              <RefreshCw size={15} aria-hidden="true" />
              <span>Refresh</span>
            </Button>
          </div>
        }
        eyebrow="Field Operations • Time & Check-in"
        title="Field Attendance & Leave Approvals"
        description="Daily GPS punch-in / punch-out time tracking, team attendance roll, and field leave request approvals."
      />

      <div className="dashboard-workspace">
        {/* Feedback messages */}
        {punchMessage && (
          <div className="p-3 text-sm rounded bg-emerald-50 text-emerald-800 border border-emerald-200 flex items-center gap-2">
            <CheckCircle2 size={16} className="text-emerald-600 flex-none" />
            <span>{punchMessage}</span>
          </div>
        )}

        {punchError && (
          <div className="p-3 text-sm rounded bg-rose-50 text-rose-800 border border-rose-200 flex items-center gap-2">
            <AlertCircle size={16} className="text-rose-600 flex-none" />
            <span>{punchError}</span>
          </div>
        )}

        {/* ── My Punch Console Card ── */}
        <DocumentCard title="Daily Attendance Punch Console">
          <div className="flex flex-wrap items-center justify-between gap-4 p-2">
            <div className="flex items-center gap-3">
              <div className={`w-10 h-10 rounded-full flex items-center justify-center flex-none ${
                isPunchedIn ? 'bg-emerald-100 text-emerald-700' : isPunchedOut ? 'bg-zinc-100 text-zinc-600' : 'bg-teal-50 text-teal-700'
              }`}>
                <Clock size={20} />
              </div>
              <div>
                <strong className="block text-sm text-primary">
                  {isPunchedIn
                    ? 'Currently Checked In'
                    : isPunchedOut
                    ? 'Shift Finished (Punched Out)'
                    : 'Not Checked In Today'}
                </strong>
                <span className="text-xs text-secondary">
                  {myPunch?.punchInTime
                    ? `In at ${new Date(myPunch.punchInTime).toLocaleTimeString('en-IN')}${myPunch.punchOutTime ? ` · Out at ${new Date(myPunch.punchOutTime).toLocaleTimeString('en-IN')}` : ''}`
                    : 'Log your attendance to begin your daily beat execution.'}
                </span>
              </div>
            </div>

            <div className="flex items-center gap-2">
              {!isPunchedIn && !isPunchedOut && (
                <Button
                  disabled={punchInMutation.isPending}
                  onClick={() => punchInMutation.mutate()}
                  variant="primary"
                >
                  <LogIn size={15} aria-hidden="true" />
                  <span>{punchInMutation.isPending ? 'Punching In...' : 'Punch In'}</span>
                </Button>
              )}

              {isPunchedIn && (
                <Button
                  disabled={punchOutMutation.isPending}
                  onClick={() => punchOutMutation.mutate()}
                  variant="destructive"
                >
                  <LogOut size={15} aria-hidden="true" />
                  <span>{punchOutMutation.isPending ? 'Punching Out...' : 'Punch Out'}</span>
                </Button>
              )}
            </div>
          </div>
        </DocumentCard>

        {/* ── Pending Leave Requests ── */}
        <DocumentCard title={`Pending Leave Requests (${pendingLeaves.length})`}>
          {leavesQuery.isLoading ? (
            <div className="p-4 text-secondary text-sm">Loading leave requests...</div>
          ) : pendingLeaves.length > 0 ? (
            <DataTable caption="Staff field leave requests awaiting manager approval">
              <thead>
                <tr>
                  <th scope="col">Staff Member</th>
                  <th scope="col">Leave Type</th>
                  <th scope="col">Date Range</th>
                  <th scope="col">Reason</th>
                  <th className="numeric-cell" scope="col">Actions</th>
                </tr>
              </thead>
              <tbody>
                {pendingLeaves.map((leave) => (
                  <tr key={leave.id}>
                    <td>
                      <strong>{leave.userName || 'Field Rep'}</strong>
                    </td>
                    <td>
                      <span className="font-semibold text-xs text-secondary">{leave.leaveType}</span>
                    </td>
                    <td>
                      <span className="font-mono text-xs">{leave.startDate} to {leave.endDate}</span>
                    </td>
                    <td>
                      <span className="text-secondary text-xs">{leave.reason}</span>
                    </td>
                    <td className="numeric-cell">
                      <div className="flex items-center justify-end gap-1.5">
                        <Button
                          disabled={approveLeaveMutation.isPending}
                          onClick={() => approveLeaveMutation.mutate(leave.id)}
                          variant="primary"
                        >
                          <CheckCircle2 size={13} aria-hidden="true" />
                          <span>Approve</span>
                        </Button>
                        <Button
                          disabled={rejectLeaveMutation.isPending}
                          onClick={() => rejectLeaveMutation.mutate({ id: leave.id, reason: 'Rejected by manager' })}
                          variant="secondary"
                        >
                          <XCircle size={13} aria-hidden="true" />
                          <span>Reject</span>
                        </Button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          ) : (
            <div className="p-4 text-center text-secondary text-xs text-muted">
              No pending leave requests requiring manager review.
            </div>
          )}
        </DocumentCard>

        {/* ── Team Attendance Register ── */}
        <DocumentCard title="Team Attendance Roll">
          <div className="flex items-center gap-2 mb-3">
            <Calendar size={14} className="text-muted" />
            <span className="text-xs font-semibold text-secondary uppercase tracking-wider">Date:</span>
            <input
              aria-label="Attendance date selector"
              type="date"
              className="dashboard-branch-select font-mono text-xs"
              value={selectedDate}
              onChange={(e) => setSelectedDate(e.target.value)}
            />
          </div>

          {teamAttendanceQuery.isLoading ? (
            <div className="p-4 text-secondary text-sm">Loading team attendance...</div>
          ) : teamList.length > 0 ? (
            <DataTable caption="Team daily attendance punch log and status">
              <thead>
                <tr>
                  <th scope="col">Sales Representative</th>
                  <th scope="col">Punch In</th>
                  <th scope="col">Punch Out</th>
                  <th scope="col">GPS Geotag</th>
                  <th scope="col">Status</th>
                </tr>
              </thead>
              <tbody>
                {teamList.map((punch) => (
                  <tr key={punch.id}>
                    <td>
                      <strong>{punch.userName || 'Rep'}</strong>
                    </td>
                    <td>
                      <span className="font-mono text-xs">
                        {punch.punchInTime ? new Date(punch.punchInTime).toLocaleTimeString('en-IN') : '—'}
                      </span>
                    </td>
                    <td>
                      <span className="font-mono text-xs">
                        {punch.punchOutTime ? new Date(punch.punchOutTime).toLocaleTimeString('en-IN') : '—'}
                      </span>
                    </td>
                    <td>
                      {punch.punchInLatitude && punch.punchInLongitude ? (
                        <span className="font-mono text-xs text-brand flex items-center gap-1">
                          <MapPin size={12} />
                          {punch.punchInLatitude.toFixed(4)}, {punch.punchInLongitude.toFixed(4)}
                        </span>
                      ) : (
                        <span className="text-muted text-xs">No GPS recorded</span>
                      )}
                    </td>
                    <td>
                      <StatusChip status={punch.status} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          ) : (
            <div className="p-6 text-center text-secondary text-sm">
              <Users size={24} className="mx-auto mb-1 text-muted opacity-40" />
              <span>No attendance punches recorded for {selectedDate}.</span>
            </div>
          )}
        </DocumentCard>
      </div>
    </section>
  )
}
