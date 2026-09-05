import { apiFetch } from '@/api/client/api-client'

export type EmployeeFamily = {
  id: string
  employeeId?: string
  name: string
  relationship: string
  dateOfBirth?: string | null
  dependent?: boolean
}

export type EmployeeEducation = {
  id: string
  employeeId?: string
  degree: string
  institution: string
  passingYear?: number | null
  scorePercentage?: string | null
}

export type EmployeeExperience = {
  id: string
  employeeId?: string
  companyName: string
  designation: string
  fromDate?: string | null
  toDate?: string | null
  lastSalary?: number | string | null
}

export type EmployeeDocument = {
  id: string
  employeeUserId?: string
  category?: string | null
  title: string
  expiryDate?: string | null
  filePath?: string | null
  contentType?: string | null
  uploadedAt?: string
}

export type AttendanceRegularization = {
  id: string
  userId?: string
  workDate: string
  punchIn?: string | null
  punchOut?: string | null
  reason: string
  status: 'PENDING' | 'APPROVED' | 'REJECTED' | string
  rejectionReason?: string | null
  createdAt?: string
}

export type AttendanceSummary = {
  presentDays?: number
  absentDays?: number
  halfDays?: number
  leaveDays?: number
  holidayDays?: number
  lateDays?: number
  overtimeHours?: number
  lopDays?: number
}

export type LeaveType = {
  id: string
  code: string
  name: string
  paid: boolean
  annualQuota: number | string
  accrualMethod?: string | null
  carryForwardMax?: number | string | null
  requiresApproval?: boolean
  active: boolean
}

export type LeaveRequest = {
  id: string
  userId?: string
  leaveTypeId: string
  leaveTypeCode?: string
  leaveTypeName?: string
  fromDate: string
  toDate: string
  reason?: string | null
  status: 'PENDING' | 'APPROVED' | 'REJECTED' | 'CANCELLED' | string
  rejectionReason?: string | null
  createdAt?: string
}

export type Holiday = {
  id: string
  date: string
  name: string
  optional: boolean
}

export type Shift = {
  id: string
  code: string
  name: string
  startTime: string
  endTime: string
  weeklyOffs?: string | null
  active: boolean
}

export type ShiftAssignment = {
  id: string
  userId: string
  shiftId: string
  shiftName?: string
  effectiveFrom: string
  effectiveTo?: string | null
}

export type TimesheetEntry = {
  id: string
  userId?: string
  userName?: string
  workDate: string
  project?: string | null
  task?: string | null
  hours: number | string
  billable: boolean
  notes?: string | null
  status?: 'DRAFT' | 'SUBMITTED' | 'APPROVED' | 'REJECTED' | string
  rejectionReason?: string | null
}

export type HrTicket = {
  id: string
  ticketNumber?: string
  requesterId?: string
  requesterName?: string
  category: string
  subject: string
  description?: string | null
  priority: 'LOW' | 'MEDIUM' | 'HIGH' | 'URGENT' | string
  status: 'OPEN' | 'IN_PROGRESS' | 'RESOLVED' | 'CLOSED' | string
  assigneeId?: string | null
  assigneeName?: string | null
  resolution?: string | null
  createdAt?: string
  updatedAt?: string
}

export type HrTicketComment = {
  id: string
  ticketId: string
  authorId?: string
  authorName?: string
  isHr?: boolean
  body: string
  createdAt?: string
}

export type OffboardingTask = {
  id: string
  offboardingId?: string
  department: 'IT' | 'FINANCE' | 'HR' | 'ADMIN' | string
  taskName?: string
  title?: string
  completed: boolean
  completedAt?: string | null
  notes?: string | null
}

export type Offboarding = {
  id: string
  employeeUserId: string
  employeeName?: string
  resignationDate?: string | null
  lastWorkingDay?: string | null
  reason?: string | null
  status: 'INITIATED' | 'IN_PROGRESS' | 'CLEARANCE_DONE' | 'SETTLED' | 'COMPLETED' | 'CANCELLED' | string
  fnfSettlementAmount?: number | string | null
  gratuityAmount?: number | string | null
  gratuityJournalId?: string | null
  tasks?: OffboardingTask[]
}

export type BiometricDevice = {
  id: string
  deviceName: string
  deviceIp?: string | null
  port: number
  serialNumber?: string | null
  protocol: 'ZK_TCP' | 'ADMS_PUSH' | string
  location?: string | null
  status: 'ONLINE' | 'OFFLINE' | string
  lastSyncAt?: string | null
  cloudWebhookToken?: string | null
}

export type BiometricPunchLog = {
  id: string
  deviceId?: string | null
  deviceName?: string
  employeeCode?: string
  employeeName?: string
  biometricPin?: string
  punchTime: string
  punchType?: string
  verifyMode?: string
  syncStatus?: string
}

// â”€â”€ Sub-resources APIs â”€â”€

export async function listFamily(employeeId: string) {
  return apiFetch<EmployeeFamily[]>(`/api/v1/hr/employees/${employeeId}/family`)
}

export async function addFamily(employeeId: string, req: Partial<EmployeeFamily>) {
  return apiFetch<EmployeeFamily>(`/api/v1/hr/employees/${employeeId}/family`, {
    method: 'POST',
    body: JSON.stringify(req),
  })
}

export async function deleteFamily(id: string) {
  return apiFetch<void>(`/api/v1/hr/employees/family/${id}`, { method: 'DELETE' })
}

export async function listEducation(employeeId: string) {
  return apiFetch<EmployeeEducation[]>(`/api/v1/hr/employees/${employeeId}/education`)
}

export async function addEducation(employeeId: string, req: Partial<EmployeeEducation>) {
  return apiFetch<EmployeeEducation>(`/api/v1/hr/employees/${employeeId}/education`, {
    method: 'POST',
    body: JSON.stringify(req),
  })
}

export async function deleteEducation(id: string) {
  return apiFetch<void>(`/api/v1/hr/employees/education/${id}`, { method: 'DELETE' })
}

export async function listExperience(employeeId: string) {
  return apiFetch<EmployeeExperience[]>(`/api/v1/hr/employees/${employeeId}/experience`)
}

export async function addExperience(employeeId: string, req: Partial<EmployeeExperience>) {
  return apiFetch<EmployeeExperience>(`/api/v1/hr/employees/${employeeId}/experience`, {
    method: 'POST',
    body: JSON.stringify(req),
  })
}

export async function deleteExperience(id: string) {
  return apiFetch<void>(`/api/v1/hr/employees/experience/${id}`, { method: 'DELETE' })
}

export async function listDocuments(employeeUserId: string) {
  return apiFetch<EmployeeDocument[]>(`/api/v1/hr/documents/${employeeUserId}`)
}

// â”€â”€ Attendance & Regularization APIs â”€â”€

export async function listPendingRegularizations() {
  return apiFetch<AttendanceRegularization[]>('/api/v1/hr/attendance/regularizations/pending')
}

export async function listMyRegularizations() {
  return apiFetch<AttendanceRegularization[]>('/api/v1/hr/attendance/regularizations/me')
}

export async function requestRegularization(req: { workDate: string; punchIn?: string; punchOut?: string; reason: string }) {
  return apiFetch<AttendanceRegularization>('/api/v1/hr/attendance/regularizations', {
    method: 'POST',
    body: JSON.stringify(req),
  })
}

export async function approveRegularization(id: string) {
  return apiFetch<AttendanceRegularization>(`/api/v1/hr/attendance/regularizations/${id}/approve`, {
    method: 'POST',
  })
}

export async function rejectRegularization(id: string, reason?: string) {
  return apiFetch<AttendanceRegularization>(`/api/v1/hr/attendance/regularizations/${id}/reject`, {
    method: 'POST',
    body: JSON.stringify({ reason }),
  })
}

export async function getAttendanceSummary(userId?: string, month?: string) {
  const m = month || new Date().toISOString().slice(0, 7) + '-01'
  const path = userId
    ? `/api/v1/hr/attendance/summary/${userId}?month=${m}`
    : `/api/v1/hr/attendance/summary/me?month=${m}`
  return apiFetch<AttendanceSummary>(path)
}

// â”€â”€ Leave & Holiday APIs â”€â”€

export async function listLeaveTypes(activeOnly = false) {
  return apiFetch<LeaveType[]>(`/api/v1/hr/leave/types?activeOnly=${activeOnly}`)
}

export async function upsertLeaveType(req: Partial<LeaveType>) {
  return apiFetch<LeaveType>('/api/v1/hr/leave/types', {
    method: 'POST',
    body: JSON.stringify(req),
  })
}

export async function applyLeave(req: { leaveTypeId: string; fromDate: string; toDate: string; reason?: string }) {
  return apiFetch<LeaveRequest>('/api/v1/hr/leave/apply', {
    method: 'POST',
    body: JSON.stringify(req),
  })
}

export async function approveLeave(id: string) {
  return apiFetch<LeaveRequest>(`/api/v1/hr/leave/${id}/approve`, { method: 'POST' })
}

export async function rejectLeave(id: string, reason?: string) {
  return apiFetch<LeaveRequest>(`/api/v1/hr/leave/${id}/reject`, {
    method: 'POST',
    body: JSON.stringify({ reason }),
  })
}

export async function cancelLeave(id: string) {
  return apiFetch<LeaveRequest>(`/api/v1/hr/leave/${id}/cancel`, { method: 'POST' })
}

export async function listHolidays(year: number) {
  return apiFetch<Holiday[]>(`/api/v1/hr/leave/holidays?year=${year}`)
}

export async function addHoliday(req: { date: string; name: string; optional?: boolean }) {
  return apiFetch<Holiday>('/api/v1/hr/leave/holidays', {
    method: 'POST',
    body: JSON.stringify(req),
  })
}

export async function deleteHoliday(id: string) {
  return apiFetch<void>(`/api/v1/hr/leave/holidays/${id}`, { method: 'DELETE' })
}

// â”€â”€ Shifts APIs â”€â”€

export async function listShifts(activeOnly = false) {
  return apiFetch<Shift[]>(`/api/v1/hr/shifts?activeOnly=${activeOnly}`)
}

export async function upsertShift(req: Partial<Shift>) {
  return apiFetch<Shift>('/api/v1/hr/shifts', {
    method: 'POST',
    body: JSON.stringify(req),
  })
}

export async function assignShift(req: { userId: string; shiftId: string; effectiveFrom: string; effectiveTo?: string }) {
  return apiFetch<ShiftAssignment>('/api/v1/hr/shifts/assignments', {
    method: 'POST',
    body: JSON.stringify(req),
  })
}

export async function listShiftAssignments(userId: string) {
  return apiFetch<ShiftAssignment[]>(`/api/v1/hr/shifts/assignments?userId=${userId}`)
}

// â”€â”€ Timesheets APIs â”€â”€

export async function listMyTimesheets(from: string, to: string) {
  return apiFetch<TimesheetEntry[]>(`/api/v1/hr/timesheets/me?from=${from}&to=${to}`)
}

export async function listPendingTimesheets() {
  return apiFetch<TimesheetEntry[]>('/api/v1/hr/timesheets/pending')
}

export async function logTimesheet(req: { workDate: string; project?: string; task?: string; hours: number; billable: boolean; notes?: string }) {
  return apiFetch<TimesheetEntry>('/api/v1/hr/timesheets', {
    method: 'POST',
    body: JSON.stringify(req),
  })
}

export async function updateTimesheet(id: string, req: Partial<TimesheetEntry>) {
  return apiFetch<TimesheetEntry>(`/api/v1/hr/timesheets/${id}`, {
    method: 'PUT',
    body: JSON.stringify(req),
  })
}

export async function deleteTimesheet(id: string) {
  return apiFetch<void>(`/api/v1/hr/timesheets/${id}`, { method: 'DELETE' })
}

export async function submitTimesheetRange(from: string, to: string) {
  return apiFetch<{ submitted: number }>(`/api/v1/hr/timesheets/submit?from=${from}&to=${to}`, { method: 'POST' })
}

export async function approveTimesheet(id: string) {
  return apiFetch<TimesheetEntry>(`/api/v1/hr/timesheets/${id}/approve`, { method: 'POST' })
}

export async function rejectTimesheet(id: string, reason?: string) {
  return apiFetch<TimesheetEntry>(`/api/v1/hr/timesheets/${id}/reject`, {
    method: 'POST',
    body: JSON.stringify({ reason }),
  })
}

// â”€â”€ Helpdesk APIs â”€â”€

export async function listTickets(scope: 'me' | 'assigned' | 'open') {
  const path = scope === 'open' ? '/open' : scope === 'assigned' ? '/assigned-to-me' : '/me'
  return apiFetch<HrTicket[]>(`/api/v1/hr/helpdesk/tickets${path}`)
}

export async function getTicket(id: string) {
  return apiFetch<{ ticket: HrTicket; comments: HrTicketComment[] }>(`/api/v1/hr/helpdesk/tickets/${id}`)
}

export async function raiseTicket(req: { category: string; subject: string; description: string; priority: string }) {
  return apiFetch<HrTicket>('/api/v1/hr/helpdesk/tickets', {
    method: 'POST',
    body: JSON.stringify(req),
  })
}

export async function addTicketComment(id: string, body: string) {
  return apiFetch<HrTicketComment>(`/api/v1/hr/helpdesk/tickets/${id}/comments`, {
    method: 'POST',
    body: JSON.stringify({ body }),
  })
}

export async function assignTicket(id: string, assigneeId?: string) {
  return apiFetch<HrTicket>(`/api/v1/hr/helpdesk/tickets/${id}/assign`, {
    method: 'POST',
    body: JSON.stringify({ assigneeId }),
  })
}

export async function updateTicketStatus(id: string, status: string, resolution?: string) {
  return apiFetch<HrTicket>(`/api/v1/hr/helpdesk/tickets/${id}/status`, {
    method: 'POST',
    body: JSON.stringify({ status, resolution }),
  })
}

// â”€â”€ Offboarding APIs â”€â”€

export async function listOffboardings(status?: string) {
  const query = status ? `?status=${status}` : ''
  return apiFetch<Offboarding[]>(`/api/v1/hr/offboarding${query}`)
}

export async function getOffboarding(id: string) {
  return apiFetch<{ offboarding: Offboarding; tasks: OffboardingTask[] }>(`/api/v1/hr/offboarding/${id}`)
}

export async function initiateOffboarding(req: { employeeUserId: string; resignationDate?: string; lastWorkingDay?: string; reason?: string }) {
  return apiFetch<Offboarding>('/api/v1/hr/offboarding', {
    method: 'POST',
    body: JSON.stringify(req),
  })
}

export async function completeOffboardingTask(taskId: string) {
  return apiFetch<OffboardingTask>(`/api/v1/hr/offboarding/tasks/${taskId}/complete`, { method: 'POST' })
}

export async function settleFnf(id: string, amount: number) {
  return apiFetch<Offboarding>(`/api/v1/hr/offboarding/${id}/fnf`, {
    method: 'POST',
    body: JSON.stringify({ amount }),
  })
}

export async function payGratuity(id: string, paymentAccount?: string) {
  const q = paymentAccount ? `?paymentAccount=${encodeURIComponent(paymentAccount)}` : ''
  return apiFetch<Offboarding>(`/api/v1/hr/offboarding/${id}/pay-gratuity${q}`, { method: 'POST' })
}

export async function completeOffboarding(id: string) {
  return apiFetch<Offboarding>(`/api/v1/hr/offboarding/${id}/complete`, { method: 'POST' })
}

export async function cancelOffboarding(id: string) {
  return apiFetch<Offboarding>(`/api/v1/hr/offboarding/${id}/cancel`, { method: 'POST' })
}

// â”€â”€ Biometric Devices APIs â”€â”€

export async function listBiometricDevices() {
  return apiFetch<BiometricDevice[]>('/api/v1/attendance/biometric/devices')
}

export async function registerBiometricDevice(req: Partial<BiometricDevice>) {
  return apiFetch<BiometricDevice>('/api/v1/attendance/biometric/devices', {
    method: 'POST',
    body: JSON.stringify(req),
  })
}

export async function testDeviceConnection(id: string) {
  return apiFetch<{ reachable: boolean; latencyMs?: number; message?: string }>(`/api/v1/attendance/biometric/devices/${id}/test`)
}

export async function triggerDeviceSync(id: string) {
  return apiFetch<{ syncedCount: number }>(`/api/v1/attendance/biometric/devices/${id}/sync`, { method: 'POST' })
}

export async function listPunchLogs(page = 0, size = 50) {
  return apiFetch<{ content: BiometricPunchLog[]; totalElements: number }>(`/api/v1/attendance/biometric/logs?page=${page}&size=${size}`)
}

// ── Employee Documents APIs ──

export async function getMyDocuments() {
  return apiFetch<EmployeeDocument[]>('/api/v1/hr/documents/me')
}

export async function getExpiringDocuments(days = 30) {
  return apiFetch<EmployeeDocument[]>(`/api/v1/hr/documents/expiring?days=${days}`)
}

export async function uploadMyDocument(formData: FormData) {
  return apiFetch<EmployeeDocument>('/api/v1/hr/documents/me', {
    method: 'POST',
    body: formData,
  })
}

export async function deleteEmployeeDocument(id: string) {
  return apiFetch<void>(`/api/v1/hr/documents/${id}`, { method: 'DELETE' })
}

// ── HR Analytics Dashboard APIs ──

export type HrAnalyticsDashboard = {
  headcount: number
  byDepartment: Record<string, number>
  onLeaveToday: number
  pendingLeaves: number
  pendingRegularizations: number
  pendingTimesheets: number
  openTickets: number
  documentsExpiringIn30Days: number
}

export async function getHrAnalyticsDashboard() {
  return apiFetch<HrAnalyticsDashboard>('/api/v1/hr/analytics/dashboard')
}

// ── My Profile & Self-Service APIs ──

export type MyProfileData = {
  employee: {
    id: string
    orgId: string
    userId?: string | null
    employeeCode?: string | null
    fullName: string
    designation?: string | null
    department?: string | null
    email?: string | null
    phone?: string | null
    dateOfBirth?: string | null
    gender?: string | null
    maritalStatus?: string | null
    bloodGroup?: string | null
    nationality?: string | null
    personalEmail?: string | null
    currentAddressLine1?: string | null
    currentAddressLine2?: string | null
    currentCity?: string | null
    currentState?: string | null
    currentPincode?: string | null
    permanentAddressLine1?: string | null
    permanentAddressLine2?: string | null
    permanentCity?: string | null
    permanentState?: string | null
    permanentPincode?: string | null
    emergencyContactName?: string | null
    emergencyContactRelationship?: string | null
    emergencyContactPhone?: string | null
    photoAttachmentId?: string | null
    dateOfJoining?: string | null
    employmentStatus?: string | null
    pan?: string | null
    uan?: string | null
    esiNumber?: string | null
    aadhaarLast4?: string | null
  }
  family: EmployeeFamily[]
  education: EmployeeEducation[]
  experience: EmployeeExperience[]
}

export async function getMyProfile() {
  return apiFetch<MyProfileData>('/api/v1/hr/employees/me')
}

export async function claimMyProfile() {
  return apiFetch<MyProfileData['employee']>('/api/v1/hr/employees/me/claim', {
    method: 'POST',
  })
}

export async function updateMyProfile(data: Partial<MyProfileData['employee']>) {
  return apiFetch<MyProfileData['employee']>('/api/v1/hr/employees/me', {
    method: 'PUT',
    body: JSON.stringify(data),
  })
}

export async function addMyFamily(data: Partial<EmployeeFamily>) {
  return apiFetch<EmployeeFamily>('/api/v1/hr/employees/me/family', {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

export async function updateMyFamily(id: string, data: Partial<EmployeeFamily>) {
  return apiFetch<EmployeeFamily>(`/api/v1/hr/employees/me/family/${id}`, {
    method: 'PUT',
    body: JSON.stringify(data),
  })
}

export async function deleteMyFamily(id: string) {
  return apiFetch<void>(`/api/v1/hr/employees/me/family/${id}`, { method: 'DELETE' })
}

export async function addMyEducation(data: Partial<EmployeeEducation>) {
  return apiFetch<EmployeeEducation>('/api/v1/hr/employees/me/education', {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

export async function updateMyEducation(id: string, data: Partial<EmployeeEducation>) {
  return apiFetch<EmployeeEducation>(`/api/v1/hr/employees/me/education/${id}`, {
    method: 'PUT',
    body: JSON.stringify(data),
  })
}

export async function deleteMyEducation(id: string) {
  return apiFetch<void>(`/api/v1/hr/employees/me/education/${id}`, { method: 'DELETE' })
}

export async function addMyExperience(data: Partial<EmployeeExperience>) {
  return apiFetch<EmployeeExperience>('/api/v1/hr/employees/me/experience', {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

export async function updateMyExperience(id: string, data: Partial<EmployeeExperience>) {
  return apiFetch<EmployeeExperience>(`/api/v1/hr/employees/me/experience/${id}`, {
    method: 'PUT',
    body: JSON.stringify(data),
  })
}

export async function deleteMyExperience(id: string) {
  return apiFetch<void>(`/api/v1/hr/employees/me/experience/${id}`, { method: 'DELETE' })
}