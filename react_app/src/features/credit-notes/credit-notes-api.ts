import { apiFetch } from '@/api/client/api-client'

export type CreditNoteLine = {
  id: string
  lineNumber: number
  description: string
  hsnCode: string | null
  quantity: number | string | null
  unitPrice: number | string | null
  taxableAmount: number | string | null
  gstRate: number | string | null
  taxAmount: number | string | null
  lineTotal: number | string | null
  accountCode: string | null
}

export type CreditNote = {
  id: string
  contactId: string
  contactName: string
  invoiceId: string | null
  invoiceNumber: string | null
  creditNoteNumber: string
  creditNoteDate: string | null
  reason: string | null
  status: string
  subtotal: number | string | null
  taxAmount: number | string | null
  totalAmount: number | string | null
  currency: string | null
  placeOfSupply: string | null
  journalEntryId: string | null
  lines: CreditNoteLine[]
  createdAt: string | null
}

export type CreditNotePage = {
  content: CreditNote[]
  page: number
  size: number
  totalElements: number
  totalPages: number
  last: boolean
}

type ListCreditNotesOptions = {
  page: number
}

export async function listCreditNotes({ page }: ListCreditNotesOptions) {
  const params = new URLSearchParams({ page: String(page), size: '25', sort: 'creditNoteDate,desc' })
  return apiFetch<CreditNotePage>(`/api/v1/credit-notes?${params.toString()}`)
}

export function getCreditNote(id: string) {
  return apiFetch<CreditNote>(`/api/v1/credit-notes/${id}`)
}

export type CreateCreditNoteLineRequest = {
  description: string
  quantity: number
  unitPrice: number
  hsnCode?: string
  gstRate?: number
}

export type CreateCreditNoteRequest = {
  contactId: string
  invoiceId?: string
  creditNoteDate: string
  reason: string
  lines: CreateCreditNoteLineRequest[]
}

export function createCreditNote(req: CreateCreditNoteRequest) {
  return apiFetch<CreditNote>('/api/v1/credit-notes', {
    method: 'POST',
    body: req,
  })
}

