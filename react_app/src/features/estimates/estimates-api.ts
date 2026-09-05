import { apiFetch, apiFetchBlob } from '@/api/client/api-client'
import { type Invoice } from '@/features/invoices/invoices-api'

export type EstimateStatus = 'DRAFT' | 'SENT' | 'ACCEPTED' | 'DECLINED' | 'INVOICED' | 'EXPIRED' | string

export type EstimateLine = {
  id: string
  lineNumber: number
  itemId: string | null
  description: string
  quantity: number | string
  unit: string | null
  rate: number | string
  taxRate: number | string | null
  hsnCode: string | null
  discountPct: number | string | null
  amount: number | string
}

export type Estimate = {
  id: string
  estimateNumber: string
  contactId: string
  contactName: string
  estimateDate: string
  expiryDate: string | null
  referenceNumber: string | null
  subtotal: number | string
  discountAmount: number | string
  taxAmount: number | string
  total: number | string
  currency: string
  subject: string | null
  status: EstimateStatus
  notes: string | null
  terms: string | null
  convertedToInvoiceId: string | null
  convertedAt: string | null
  sentAt: string | null
  acceptedAt: string | null
  declinedAt: string | null
  lines: EstimateLine[]
  createdAt: string
}

export type EstimateLineRequest = {
  itemId?: string
  description: string
  unit?: string
  quantity: number
  rate: number
  taxRate: number
  hsnCode?: string
  discountPct: number
}

export type CreateEstimateRequest = {
  contactId: string
  estimateDate: string
  expiryDate?: string
  currency?: string
  subject?: string
  referenceNumber?: string
  notes?: string
  terms?: string
  lines: EstimateLineRequest[]
}

export type UpdateEstimateRequest = Partial<Omit<CreateEstimateRequest, 'currency'>>

export type EstimatePage = {
  content: Estimate[]
  page: number
  size: number
  totalElements: number
  totalPages: number
  last: boolean
}

export type BulkOperationResult = {
  succeeded: string[]
  failed: { id: string; reason: string }[]
  successCount: number
  failCount: number
}

export async function listEstimates(
  status?: string,
  contactId?: string,
  page = 0,
  size = 25
): Promise<EstimatePage> {
  // The frozen service prioritises contactId and ignores status when both are sent.
  if (contactId && status && status !== 'all') throw new Error('Choose a customer filter or a status filter, not both.')
  const params = new URLSearchParams()
  if (status && status !== 'all') params.set('status', status)
  if (contactId) params.set('contactId', contactId)
  params.set('page', String(page))
  params.set('size', String(size))
  return apiFetch<EstimatePage>(`/api/v1/estimates?${params.toString()}`)
}

export async function getEstimate(id: string): Promise<Estimate> {
  return apiFetch<Estimate>(`/api/v1/estimates/${id}`)
}

export function getEstimatePdf(id: string): Promise<Blob> {
  return apiFetchBlob(`/api/v1/estimates/${encodeURIComponent(id)}/pdf`, 'application/pdf')
}

export async function createEstimate(req: CreateEstimateRequest): Promise<Estimate> {
  return apiFetch<Estimate>('/api/v1/estimates', {
    method: 'POST',
    body: JSON.stringify(req),
  })
}

export async function updateEstimate(id: string, req: UpdateEstimateRequest): Promise<Estimate> {
  return apiFetch<Estimate>(`/api/v1/estimates/${id}`, {
    method: 'PUT',
    body: JSON.stringify(req),
  })
}

export async function deleteEstimate(id: string): Promise<void> {
  await apiFetch<void>(`/api/v1/estimates/${id}`, {
    method: 'DELETE',
  })
}

export async function sendEstimate(id: string): Promise<Estimate> {
  return apiFetch<Estimate>(`/api/v1/estimates/${id}/send`, {
    method: 'POST',
  })
}

export async function acceptEstimate(id: string): Promise<Estimate> {
  return apiFetch<Estimate>(`/api/v1/estimates/${id}/accept`, {
    method: 'POST',
  })
}

export async function declineEstimate(id: string): Promise<Estimate> {
  return apiFetch<Estimate>(`/api/v1/estimates/${id}/decline`, {
    method: 'POST',
  })
}

export async function convertEstimateToInvoice(id: string): Promise<Invoice> {
  return apiFetch<Invoice>(`/api/v1/estimates/${id}/convert-to-invoice`, {
    method: 'POST',
  })
}

export async function getEstimateWhatsAppLink(id: string): Promise<{ shareUrl: string; message: string; documentNumber: string; phone?: string }> {
  return apiFetch(`/api/v1/estimates/${id}/whatsapp-link`)
}

export async function bulkSendEstimates(ids: string[]): Promise<BulkOperationResult> {
  return apiFetch<BulkOperationResult>('/api/v1/estimates/bulk-send', {
    method: 'POST',
    body: JSON.stringify({ ids }),
  })
}

export async function bulkDeleteEstimates(ids: string[]): Promise<BulkOperationResult> {
  return apiFetch<BulkOperationResult>('/api/v1/estimates/bulk-delete', {
    method: 'DELETE',
    body: JSON.stringify({ ids }),
  })
}
