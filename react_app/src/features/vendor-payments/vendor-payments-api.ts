import { apiFetch } from '@/api/client/api-client'

export type VendorPaymentAllocation = {
  id?: string
  billId: string
  billNumber?: string
  amountApplied: number | string | null
}

export type VendorPayment = {
  id: string
  contactId: string | null
  vendorName: string | null
  paymentNumber: string
  paymentDate: string | null
  amount: number | string | null
  currency: string | null
  paymentMode: string | null
  paidThroughId: string | null
  referenceNumber: string | null
  tdsAmount: number | string | null
  notes: string | null
  journalEntryId: string | null
  allocations: VendorPaymentAllocation[]
  createdAt: string | null
}

export type VendorPaymentPage = {
  content: VendorPayment[]
  page: number
  size: number
  totalElements: number
  totalPages: number
  last: boolean
}

export type VendorPaymentRequest = {
  contactId: string
  paymentDate: string
  amount: number
  paymentMode: string
  paidThroughId?: string
  referenceNumber?: string
  notes?: string
  allocations?: {
    billId: string
    amountApplied: number
  }[]
}

export type ChequePrintResponse = {
  chequeNumber: string
  payeeName: string
  amount: number
  amountInWords: string
  date: string
  bankAccountName: string
}

type ListVendorPaymentsOptions = {
  page: number
  contactId?: string | null
}

export async function listVendorPayments({ page, contactId }: ListVendorPaymentsOptions) {
  const params = new URLSearchParams({ page: String(page), size: '25', sort: 'paymentDate,desc' })
  if (contactId) params.set('contact_id', contactId)
  return apiFetch<VendorPaymentPage>(`/api/v1/vendor-payments?${params.toString()}`)
}

export function getVendorPayment(id: string) {
  return apiFetch<VendorPayment>(`/api/v1/vendor-payments/${id}`)
}

export function recordVendorPayment(req: VendorPaymentRequest) {
  return apiFetch<VendorPayment>('/api/v1/vendor-payments', {
    method: 'POST',
    body: JSON.stringify(req),
  })
}

export function voidVendorPayment(id: string) {
  return apiFetch<VendorPayment>(`/api/v1/vendor-payments/${id}/void`, { method: 'POST' })
}

export function getChequePrint(id: string, chequeNumber?: string) {
  const params = new URLSearchParams()
  if (chequeNumber) params.set('chequeNumber', chequeNumber)
  return apiFetch<ChequePrintResponse>(`/api/v1/vendor-payments/${id}/cheque-print?${params.toString()}`)
}