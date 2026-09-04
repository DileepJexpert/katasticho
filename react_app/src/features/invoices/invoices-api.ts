import { apiFetch } from '@/api/client/api-client'

export type InvoiceLine = {
  id: string
  lineNumber: number
  description: string | null
  hsnCode: string | null
  quantity: number | string | null
  unitPrice: number | string | null
  discountPercent: number | string | null
  discountAmount: number | string | null
  taxableAmount: number | string | null
  gstRate: number | string | null
  taxAmount: number | string | null
  lineTotal: number | string | null
  batchNumber: string | null
  batchExpiry: string | null
}

export type Invoice = {
  id: string
  contactId: string
  contactName: string | null
  invoiceNumber: string
  invoiceDate: string | null
  dueDate: string | null
  status: string
  subtotal: number | string | null
  taxAmount: number | string | null
  tcsAmount: number | string | null
  totalAmount: number | string | null
  amountPaid: number | string | null
  balanceDue: number | string | null
  currency: string | null
  placeOfSupply: string | null
  reverseCharge: boolean
  notes: string | null
  termsAndConditions: string | null
  lines: InvoiceLine[]
}

export type InvoicePayment = {
  id: string
  paymentNumber: string
  paymentDate: string | null
  amount: number | string | null
  currency: string | null
  paymentMethod: string | null
  referenceNumber: string | null
  status: string
}

export type InvoicePage = {
  content: Invoice[]
  page: number
  size: number
  totalElements: number
  totalPages: number
  last: boolean
}

type ListInvoicesOptions = {
  page: number
  search: string
  status: string | null
}

export async function listInvoices({ page, search, status }: ListInvoicesOptions) {
  const params = new URLSearchParams({ page: String(page), size: '25', sort: 'invoiceDate,desc' })
  if (search.trim()) params.set('search', search.trim())
  if (status) params.set('status', status)
  return apiFetch<InvoicePage>(`/api/v1/invoices?${params.toString()}`)
}

export function getInvoice(id: string) {
  return apiFetch<Invoice>(`/api/v1/invoices/${id}`)
}

export function getInvoicePayments(id: string) {
  return apiFetch<InvoicePayment[]>(`/api/v1/invoices/${id}/payments`)
}

export type CreateInvoiceLineRequest = {
  description: string
  quantity: number
  unitPrice: number
  hsnCode?: string
  gstRate?: number
  taxGroupId?: string
  itemId?: string
  batchId?: string
}

export type CreateInvoiceRequest = {
  contactId: string
  invoiceDate: string
  dueDate?: string
  placeOfSupply?: string
  reverseCharge?: boolean
  notes?: string
  termsAndConditions?: string
  lines: CreateInvoiceLineRequest[]
}

export function createInvoice(req: CreateInvoiceRequest) {
  return apiFetch<Invoice>('/api/v1/invoices', {
    method: 'POST',
    body: req,
  })
}

export function postInvoice(id: string) {
  return apiFetch<Invoice>(`/api/v1/invoices/${id}/post`, {
    method: 'POST',
  })
}

