import { apiFetch } from '@/api/client/api-client'

export type CapaAction = {
  id: string
  capaNumber: string
  ncrId?: string | null
  ncrNumber?: string | null
  capaType: 'CORRECTIVE' | 'PREVENTIVE' | string
  title: string
  description?: string | null
  proposedAction?: string | null
  status: 'OPEN' | 'IN_PROGRESS' | 'COMPLETED' | 'VERIFIED' | 'CANCELLED' | string
  priority: 'URGENT' | 'HIGH' | 'NORMAL' | 'LOW' | string
  assignedTo?: string | null
  assigneeName?: string | null
  raisedBy?: string | null
  dueDate?: string | null
  completedAt?: string | null
  completionNotes?: string | null
  verifiedAt?: string | null
  verifiedBy?: string | null
  effectivenessNotes?: string | null
  cancelledAt?: string | null
  cancellationReason?: string | null
  createdAt: string
  updatedAt?: string
}

export type CapaPage = {
  content: CapaAction[]
  page: number
  size: number
  totalElements: number
  totalPages: number
  last: boolean
}

export async function listCapas(options: { status?: string; page?: number; size?: number } = {}) {
  const params = new URLSearchParams()
  if (options.status && options.status !== 'all') params.set('status', options.status)
  if (options.page !== undefined) params.set('page', String(options.page))
  params.set('size', String(options.size ?? 25))

  return apiFetch<CapaPage>(`/api/v1/manufacturing/capa?${params.toString()}`)
}

export async function getCapa(id: string) {
  return apiFetch<CapaAction>(`/api/v1/manufacturing/capa/${id}`)
}

export async function listCapasByNcr(ncrId: string) {
  return apiFetch<CapaAction[]>(`/api/v1/manufacturing/capa/by-ncr/${ncrId}`)
}

export async function raiseCapa(data: {
  ncrId?: string | null
  capaType: string
  title: string
  description?: string
  proposedAction?: string
  assignedTo?: string | null
  dueDate?: string | null
  priority?: string
}) {
  return apiFetch<CapaAction>('/api/v1/manufacturing/capa', {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

export async function startCapa(id: string) {
  return apiFetch<CapaAction>(`/api/v1/manufacturing/capa/${id}/start`, {
    method: 'POST',
  })
}

export async function completeCapa(id: string, completionNotes?: string) {
  return apiFetch<CapaAction>(`/api/v1/manufacturing/capa/${id}/complete`, {
    method: 'POST',
    body: JSON.stringify({ completionNotes }),
  })
}

export async function verifyCapa(id: string, effectivenessNotes?: string) {
  return apiFetch<CapaAction>(`/api/v1/manufacturing/capa/${id}/verify`, {
    method: 'POST',
    body: JSON.stringify({ effectivenessNotes }),
  })
}

export async function cancelCapa(id: string, reason?: string) {
  return apiFetch<CapaAction>(`/api/v1/manufacturing/capa/${id}/cancel`, {
    method: 'POST',
    body: JSON.stringify({ reason }),
  })
}