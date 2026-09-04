import { apiFetch } from '@/api/client/api-client'

export type CaFirm = {
  id: string
  firmName: string
  icaiNumber?: string
  partnerUserId: string
  createdAt: string
}

export type CaClientSummary = {
  linkId: string
  clientOrgId: string
  clientOrgName: string
  industry?: string
  healthStatus: 'HEALTHY' | 'ATTENTION' | 'CRITICAL'
  issueCount: number
  nextDeadlineType?: string
  nextDeadlineDate?: string
  lastActivity?: string
  assignedUserId?: string
  assignedStaffName?: string
  engagementType: string
  status: 'ACTIVE' | 'PENDING' | 'TERMINATED'
  healthReasons?: string[]
}

export type CaDashboard = {
  totalClients: number
  criticalCount: number
  gstDueThisWeekCount: number
  unbalancedTrialBalanceCount: number
  clients: CaClientSummary[]
}

export type CaComplianceDeadline = {
  id: string
  linkId?: string
  clientOrgId: string
  clientOrgName: string
  deadlineType: string
  periodLabel: string
  dueDate: string
  status: 'PENDING' | 'FILED' | 'OVERDUE'
  filedAt?: string
  filingReference?: string
  notes?: string
}

export type CaAlert = {
  id: string
  clientOrgId: string
  clientOrgName: string
  entityType?: string
  entityId?: string
  suggestionType: string
  title: string
  reasoning: string
  priority: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL'
  priorityScore?: number
  status: string
  dismissed: boolean
  assignedUserId?: string
  suggestedValue?: Record<string, unknown>
  createdAt: string
}

export type ReportDispatch = {
  id: string
  clientOrgId?: string
  periodLabel: string
  reportTypes: string[]
  sentVia: string
  aiCommentary: boolean
  status: 'QUEUED' | 'SENT' | 'FAILED'
  sentAt?: string
  createdAt: string
}

export type CaStaff = {
  userId: string
  fullName: string
  email: string
  phone?: string
  role: string
  clientCount: number
  active: boolean
}

export type DelegatedAccess = {
  token: string
  redirectUrl: string
  expiresAt: string
}

export async function createCaFirm(data: { firmName: string; icaiNumber?: string }): Promise<CaFirm> {
  return apiFetch<CaFirm>('/api/v1/ca/firm', {
    method: 'POST',
    body: data,
  })
}

export async function getCurrentFirm(): Promise<CaFirm> {
  return apiFetch<CaFirm>('/api/v1/ca/firm')
}

export async function getCaDashboard(): Promise<CaDashboard> {
  return apiFetch<CaDashboard>('/api/v1/ca/dashboard')
}

export async function listClients(healthStatus?: string, assignedUserId?: string, engagementType?: string): Promise<CaClientSummary[]> {
  const params = new URLSearchParams()
  if (healthStatus) params.set('healthStatus', healthStatus)
  if (assignedUserId) params.set('assignedUserId', assignedUserId)
  if (engagementType) params.set('engagementType', engagementType)
  return apiFetch<CaClientSummary[]>(`/api/v1/ca/clients?${params.toString()}`)
}

export async function inviteClient(data: { clientOrgId?: string; clientName?: string; emailOrPhone: string; engagementType: string; assignedUserId?: string; notes?: string }): Promise<CaClientSummary> {
  return apiFetch<CaClientSummary>('/api/v1/ca/clients/invite', {
    method: 'POST',
    body: data,
  })
}

export async function assignClient(linkId: string, data: { assignedUserId: string }): Promise<void> {
  await apiFetch<void>(`/api/v1/ca/clients/${linkId}/assign`, {
    method: 'POST',
    body: data,
  })
}

export async function endClientEngagement(linkId: string): Promise<void> {
  await apiFetch<void>(`/api/v1/ca/clients/${linkId}`, {
    method: 'DELETE',
  })
}

export async function getDelegatedAccessToken(linkId: string): Promise<DelegatedAccess> {
  return apiFetch<DelegatedAccess>(`/api/v1/ca/clients/${linkId}/access-token`, {
    method: 'POST',
    body: {},
  })
}

export async function listComplianceDeadlines(deadlineType?: string, status?: string, fromDate?: string, toDate?: string, clientOrgId?: string): Promise<CaComplianceDeadline[]> {
  const params = new URLSearchParams()
  if (deadlineType) params.set('deadlineType', deadlineType)
  if (status) params.set('status', status)
  if (fromDate) params.set('fromDate', fromDate)
  if (toDate) params.set('toDate', toDate)
  if (clientOrgId) params.set('clientOrgId', clientOrgId)
  return apiFetch<CaComplianceDeadline[]>(`/api/v1/ca/compliance/deadlines?${params.toString()}`)
}

export async function markComplianceFiled(deadlineId: string, data: { filingReference?: string; notes?: string; filedDate?: string }): Promise<CaComplianceDeadline> {
  return apiFetch<CaComplianceDeadline>(`/api/v1/ca/compliance/deadlines/${deadlineId}/mark-filed`, {
    method: 'POST',
    body: data,
  })
}

export async function generateComplianceDeadlines(): Promise<number> {
  return apiFetch<number>('/api/v1/ca/compliance/deadlines/generate', {
    method: 'POST',
    body: {},
  })
}

export async function listCaAlerts(severity?: string, clientOrgId?: string, suggestionType?: string, status?: string): Promise<CaAlert[]> {
  const params = new URLSearchParams()
  if (severity) params.set('severity', severity)
  if (clientOrgId) params.set('clientOrgId', clientOrgId)
  if (suggestionType) params.set('suggestionType', suggestionType)
  if (status) params.set('status', status)
  return apiFetch<CaAlert[]>(`/api/v1/ca/alerts?${params.toString()}`)
}

export async function dismissCaAlert(suggestionId: string): Promise<void> {
  await apiFetch<void>(`/api/v1/ca/alerts/${suggestionId}/dismiss`, {
    method: 'POST',
    body: {},
  })
}

export async function assignCaAlert(suggestionId: string, data: { assignedUserId: string; note?: string }): Promise<void> {
  await apiFetch<void>(`/api/v1/ca/alerts/${suggestionId}/assign`, {
    method: 'POST',
    body: data,
  })
}

export async function dispatchReports(data: { clientOrgIds?: string[]; allClients?: boolean; periodLabel: string; reportTypes: string[]; sendVia: string; includeAiCommentary: boolean; customMessage?: string }): Promise<ReportDispatch[]> {
  return apiFetch<ReportDispatch[]>('/api/v1/ca/reports/dispatch', {
    method: 'POST',
    body: data,
  })
}

export async function getDispatchStatus(jobId: string): Promise<ReportDispatch> {
  return apiFetch<ReportDispatch>(`/api/v1/ca/reports/dispatch/${jobId}/status`)
}

export async function getDispatchHistory(): Promise<ReportDispatch[]> {
  return apiFetch<ReportDispatch[]>('/api/v1/ca/reports/dispatch/history')
}

export async function listCaStaff(): Promise<CaStaff[]> {
  return apiFetch<CaStaff[]>('/api/v1/ca/staff')
}
