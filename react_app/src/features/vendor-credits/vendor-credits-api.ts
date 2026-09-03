import { apiFetch } from '@/api/client/api-client'

export type VendorCreditLine = {
  id: string
  itemId: string | null
  description: string
  accountId: string | null
  quantity: number | string
  unitPrice: number | string
  taxRate: number | string | null
  taxAmount: number | string | null
  lineTotal: number | string
}

export type VendorCredit = {
  id: string
  contactId: string
  vendorName: string | null
  creditNumber: string
  creditDate: string | null
  status: string
  subtotal: number | string | null
  taxAmount: number | string | null
  totalAmount: number | string | null
  unappliedAmount: number | string | null
  appliedAmount: number | string | null
  referenceBillId: string | null
  notes: string | null
  lines: VendorCreditLine[]
  createdAt: string | null
}

export type VendorCreditPage = {
  content: VendorCredit[]
  pageable: unknown
  totalElements: number
  totalPages: number
  number: number
  size: number
  last: boolean
}

export type CreateVendorCreditRequest = {
  contactId: string
  creditDate: string
  referenceBillId?: string | null
  notes?: string
  lines: {
    itemId?: string | null
    description: string
    accountId?: string | null
    quantity: number
    unitPrice: number
    taxRate?: number
  }[]
}

export type ApplyVendorCreditRequest = {
  billId: string
  amount: number
  applyDate: string
}

export async function listVendorCredits(status?: string, contactId?: string, page = 0, size = 25) {
  const params = new URLSearchParams({ page: String(page), size: String(size), sort: 'creditDate,desc' })
  if (status && status !== 'ALL') params.set('status', status)
  if (contactId) params.set('contact_id', contactId)
  return apiFetch<VendorCreditPage>(`/api/v1/vendor-credits?${params.toString()}`)
}

export function getVendorCredit(id: string) {
  return apiFetch<VendorCredit>(`/api/v1/vendor-credits/${id}`)
}

export function createVendorCredit(req: CreateVendorCreditRequest) {
  return apiFetch<VendorCredit>('/api/v1/vendor-credits', {
    method: 'POST',
    body: JSON.stringify(req),
  })
}

export function deleteVendorCredit(id: string) {
  return apiFetch<void>(`/api/v1/vendor-credits/${id}`, { method: 'DELETE' })
}

export function postVendorCredit(id: string) {
  return apiFetch<VendorCredit>(`/api/v1/vendor-credits/${id}/post`, { method: 'POST' })
}

export function voidVendorCredit(id: string, reason?: string) {
  return apiFetch<VendorCredit>(`/api/v1/vendor-credits/${id}/void`, {
    method: 'POST',
    body: JSON.stringify({ reason: reason || 'Voided' }),
  })
}

export function applyVendorCredit(id: string, req: ApplyVendorCreditRequest) {
  return apiFetch<VendorCredit>(`/api/v1/vendor-credits/${id}/apply`, {
    method: 'POST',
    body: JSON.stringify(req),
  })
}