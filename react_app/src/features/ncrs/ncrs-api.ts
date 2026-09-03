import { apiFetch } from '@/api/client/api-client'

export type NonConformanceReport = {
  id: string
  ncrNumber: string
  qcInspectionId: string | null
  itemId: string
  itemName?: string | null
  batchNumber: string | null
  severity: 'MINOR' | 'MAJOR' | 'CRITICAL' | string
  reason: string | null
  description: string | null
  status: 'OPEN' | 'INVESTIGATING' | 'CAPA_RAISED' | 'CLOSED' | string
  correctiveAction: string | null
  rootCause: string | null
  closedAt: string | null
  closedBy: string | null
  createdAt: string
  updatedAt?: string
}

export type NcrPage = {
  content: NonConformanceReport[]
  page: number
  size: number
  totalElements: number
  totalPages: number
  last: boolean
}

export async function listNcrs(options: { status?: string; page?: number; size?: number } = {}) {
  const params = new URLSearchParams()
  if (options.status && options.status !== 'all') params.set('status', options.status)
  if (options.page !== undefined) params.set('page', String(options.page))
  params.set('size', String(options.size ?? 25))

  return apiFetch<NcrPage>(`/api/v1/manufacturing/qc/ncrs?${params.toString()}`)
}

export async function getNcr(id: string) {
  return apiFetch<NonConformanceReport>(`/api/v1/manufacturing/qc/ncrs/${id}`)
}

export async function createNcr(data: {
  qcInspectionId?: string | null
  itemId: string
  batchNumber?: string | null
  severity: string
  reason?: string | null
  description?: string | null
}) {
  return apiFetch<NonConformanceReport>('/api/v1/manufacturing/qc/ncrs', {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

export async function updateNcr(id: string, data: {
  correctiveAction?: string | null
  rootCause?: string | null
  status?: string | null
}) {
  return apiFetch<NonConformanceReport>(`/api/v1/manufacturing/qc/ncrs/${id}`, {
    method: 'PUT',
    body: JSON.stringify(data),
  })
}

export async function closeNcr(id: string) {
  return apiFetch<NonConformanceReport>(`/api/v1/manufacturing/qc/ncrs/${id}/close`, {
    method: 'POST',
  })
}