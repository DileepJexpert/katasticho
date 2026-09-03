import { apiFetch } from '@/api/client/api-client'

export type Workstation = {
  id: string
  code: string
  name: string
  description?: string | null
  hourlyRate: number | string | null
  capacityHoursPerDay: number | string
  isActive: boolean
  createdAt?: string
  updatedAt?: string
}

export type MaintenanceSchedule = {
  id: string
  workstationId: string
  workstationName?: string | null
  code: string
  title: string
  description?: string | null
  frequencyDays: number
  lastCompletedDate?: string | null
  nextDueDate: string
  estimatedDurationMin?: number | null
  assignedToUserId?: string | null
  active: boolean
  createdAt?: string
  updatedAt?: string
}

export type MaintenanceWorkOrder = {
  id: string
  mwoNumber: string
  workstationId: string
  workstationName?: string | null
  scheduleId?: string | null
  maintenanceType: 'PREVENTIVE' | 'BREAKDOWN' | 'INSPECTION' | string
  status: 'DRAFT' | 'IN_PROGRESS' | 'COMPLETED' | 'CANCELLED' | string
  priority: 'URGENT' | 'HIGH' | 'NORMAL' | 'LOW' | string
  title: string
  description?: string | null
  reportedAt: string
  startedAt?: string | null
  completedAt?: string | null
  downtimeMinutes?: number | null
  cost?: number | string | null
  assignedToUserId?: string | null
  completedBy?: string | null
  completionNotes?: string | null
  createdAt?: string
  updatedAt?: string
}

export async function listWorkstations() {
  return apiFetch<Workstation[]>('/api/v1/manufacturing/workstations')
}

export async function getWorkstation(id: string) {
  return apiFetch<Workstation>(`/api/v1/manufacturing/workstations/${id}`)
}

export async function createWorkstation(data: {
  code: string
  name: string
  description?: string
  hourlyRate?: number | string | null
  capacityHoursPerDay?: number | string | null
}) {
  return apiFetch<Workstation>('/api/v1/manufacturing/workstations', {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

export async function listMaintenanceSchedules(workstationId?: string) {
  const query = workstationId ? `?workstationId=${workstationId}` : ''
  return apiFetch<MaintenanceSchedule[]>(`/api/v1/manufacturing/maintenance/schedules${query}`)
}

export async function listDueMaintenanceSchedules(cutoff?: string) {
  const query = cutoff ? `?cutoff=${cutoff}` : ''
  return apiFetch<MaintenanceSchedule[]>(`/api/v1/manufacturing/maintenance/schedules/due${query}`)
}

export async function getMaintenanceSchedule(id: string) {
  return apiFetch<MaintenanceSchedule>(`/api/v1/manufacturing/maintenance/schedules/${id}`)
}

export async function createMaintenanceSchedule(data: {
  workstationId: string
  code: string
  title: string
  description?: string
  frequencyDays: number
  nextDueDate: string
  estimatedDurationMin?: number
  assignedToUserId?: string
}) {
  return apiFetch<MaintenanceSchedule>('/api/v1/manufacturing/maintenance/schedules', {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

export async function generateDueMaintenanceWorkOrders(asOf?: string) {
  const query = asOf ? `?asOf=${asOf}` : ''
  return apiFetch<MaintenanceWorkOrder[]>(`/api/v1/manufacturing/maintenance/schedules/generate-due${query}`, {
    method: 'POST',
  })
}

export async function listMaintenanceWorkOrders(status?: string, workstationId?: string) {
  const params = new URLSearchParams()
  if (status && status !== 'all') params.append('status', status)
  if (workstationId) params.append('workstationId', workstationId)
  const qs = params.toString() ? `?${params.toString()}` : ''
  return apiFetch<MaintenanceWorkOrder[]>(`/api/v1/manufacturing/maintenance/work-orders${qs}`)
}

export async function getMaintenanceWorkOrder(id: string) {
  return apiFetch<MaintenanceWorkOrder>(`/api/v1/manufacturing/maintenance/work-orders/${id}`)
}

export async function createMaintenanceWorkOrder(data: {
  workstationId: string
  maintenanceType: string
  priority: string
  title: string
  description?: string
}) {
  return apiFetch<MaintenanceWorkOrder>('/api/v1/manufacturing/maintenance/work-orders', {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

export async function startMaintenanceWorkOrder(id: string) {
  return apiFetch<MaintenanceWorkOrder>(`/api/v1/manufacturing/maintenance/work-orders/${id}/start`, {
    method: 'POST',
  })
}

export async function completeMaintenanceWorkOrder(id: string, notes?: string, cost?: number | string) {
  return apiFetch<MaintenanceWorkOrder>(`/api/v1/manufacturing/maintenance/work-orders/${id}/complete`, {
    method: 'POST',
    body: JSON.stringify({ notes, cost }),
  })
}

export async function cancelMaintenanceWorkOrder(id: string, reason?: string) {
  return apiFetch<MaintenanceWorkOrder>(`/api/v1/manufacturing/maintenance/work-orders/${id}/cancel`, {
    method: 'POST',
    body: JSON.stringify({ reason }),
  })
}