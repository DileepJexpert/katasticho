import { apiFetch } from '@/api/client/api-client'

export type PurchaseBillLine = {
  id: string
  lineNumber: number
  description: string | null
  hsnCode: string | null
  itemId: string | null
  accountId: string | null
  quantity: number | string | null
  unitPrice: number | string | null
  discountPercent: number | string | null
  discountAmount: number | string | null
  taxableAmount: number | string | null
  gstRate: number | string | null
  taxAmount: number | string | null
  lineTotal: number | string | null
  purchaseOrderLineId: string | null
}

export type PurchaseBill = {
  id: string
  contactId: string | null
  vendorName: string | null
  billNumber: string
  vendorBillNumber: string | null
  billDate: string | null
  dueDate: string | null
  status: string
  subtotal: number | string | null
  taxAmount: number | string | null
  totalAmount: number | string | null
  amountPaid: number | string | null
  balanceDue: number | string | null
  tdsAmount: number | string | null
  currency: string | null
  placeOfSupply: string | null
  reverseCharge: boolean
  journalEntryId: string | null
  purchaseOrderId: string | null
  threeWayMatchStatus: string | null
  notes: string | null
  lines: PurchaseBillLine[]
  createdAt: string | null
}

export type VendorBillPayment = {
  id: string
  vendorName: string | null
  paymentNumber: string
  paymentDate: string | null
  amount: number | string | null
  currency: string | null
  paymentMode: string | null
  referenceNumber: string | null
  tdsAmount: number | string | null
}

export type PurchaseBillPage = {
  content: PurchaseBill[]
  page: number
  size: number
  totalElements: number
  totalPages: number
  last: boolean
}

type ListBillsOptions = {
  page: number
  search: string
  status: string | null
  vendorId?: string | null
}

export type CreatePurchaseBillRequest = {
  contactId: string
  billDate: string
  dueDate?: string
  vendorBillNumber?: string
  notes?: string
  placeOfSupply?: string
  reverseCharge?: boolean
  lines: {
    itemId?: string | null
    description: string
    quantity: number
    unitPrice: number
    gstRate?: number
    hsnCode?: string
  }[]
}

export async function listBills({ page, search, status, vendorId }: ListBillsOptions) {
  const params = new URLSearchParams({ page: String(page), size: '25', sort: 'billDate,desc' })
  if (search.trim()) params.set('search', search.trim())
  if (status) params.set('status', status)
  if (vendorId) params.set('contact_id', vendorId)
  return apiFetch<PurchaseBillPage>(`/api/v1/bills?${params.toString()}`)
}

export function getBill(id: string) {
  return apiFetch<PurchaseBill>(`/api/v1/bills/${id}`)
}

export function createBill(req: CreatePurchaseBillRequest) {
  return apiFetch<PurchaseBill>('/api/v1/bills', {
    method: 'POST',
    body: JSON.stringify(req),
  })
}

export function updateBill(id: string, req: Partial<CreatePurchaseBillRequest>) {
  return apiFetch<PurchaseBill>(`/api/v1/bills/${id}`, {
    method: 'PUT',
    body: JSON.stringify(req),
  })
}

export function deleteBill(id: string) {
  return apiFetch<void>(`/api/v1/bills/${id}`, { method: 'DELETE' })
}

export function postBill(id: string) {
  return apiFetch<PurchaseBill>(`/api/v1/bills/${id}/post`, { method: 'POST' })
}

export function voidBill(id: string, reason?: string) {
  return apiFetch<PurchaseBill>(`/api/v1/bills/${id}/void`, {
    method: 'POST',
    body: JSON.stringify({ reason: reason || 'Voided' }),
  })
}

export function getBillPayments(id: string) {
  return apiFetch<VendorPaymentResponseDto[]>(`/api/v1/bills/${id}/payments`)
}

export function getBillWhatsappLink(id: string) {
  return apiFetch<{ url: string }>(`/api/v1/bills/${id}/whatsapp-link`)
}

type VendorPaymentResponseDto = {
  id: string
  vendorName: string | null
  paymentNumber: string
  paymentDate: string | null
  amount: number | string | null
  currency: string | null
  paymentMode: string | null
  referenceNumber: string | null
  tdsAmount: number | string | null
}