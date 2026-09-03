import { apiFetch } from '@/api/client/api-client'
import { type Invoice } from '@/features/invoices/invoices-api'

export type EstimateStatus = 'DRAFT' | 'SENT' | 'ACCEPTED' | 'DECLINED' | 'INVOICED' | 'EXPIRED' | string

export type EstimateLine = {
  id: string
  itemId: string
  itemName: string
  itemSku: string | null
  description: string | null
  quantity: number
  unit: string | null
  rate: number
  taxGroupId: string | null
  taxGroupName: string | null
  taxRate: number | null
  hsnCode: string | null
  discountPercentage: number | null
  discountAmount: number | null
  amount: number
  batchId: string | null
}

export type Estimate = {
  id: string
  estimateNumber: string
  contactId: string
  contactName: string
  estimateDate: string
  expiryDate: string | null
  referenceNumber: string | null
  subtotal: number
  taxAmount: number
  total: number
  status: EstimateStatus
  notes: string | null
  terms: string | null
  convertedInvoiceId: string | null
  lines: EstimateLine[]
  createdAt: string
}

export type EstimateLineRequest = {
  itemId: string
  description?: string
  quantity: number
  rate: number
  taxGroupId?: string
  hsnCode?: string
  discountPercentage?: number
  batchId?: string
}

export type CreateEstimateRequest = {
  contactId: string
  estimateDate: string
  expiryDate?: string
  referenceNumber?: string
  notes?: string
  terms?: string
  lines: EstimateLineRequest[]
}

export type UpdateEstimateRequest = {
  contactId: string
  estimateDate: string
  expiryDate?: string
  referenceNumber?: string
  notes?: string
  terms?: string
  lines: EstimateLineRequest[]
}

export type EstimatePage = {
  content: Estimate[]
  page: number
  size: number
  totalElements: number
  totalPages: number
  last: boolean
}

export type BulkOperationResult = {
  successCount: number
  failCount: number
  errors: string[]
}

export async function listEstimates(
  status?: string,
  contactId?: string,
  page = 0,
  size = 50
): Promise<EstimatePage> {
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

export async function getEstimateWhatsAppLink(id: string): Promise<{ shareUrl?: string; message?: string }> {
  return apiFetch<{ shareUrl?: string; message?: string }>(`/api/v1/estimates/${id}/whatsapp-link`)
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
