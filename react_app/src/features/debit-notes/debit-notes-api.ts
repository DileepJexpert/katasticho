import { apiFetch } from '@/api/client/api-client'

export type DebitNoteLine = {
  id: string
  itemId: string
  description: string
  batchId: string | null
  batchNumber: string | null
  expiryDate: string | null
  quantity: number | string | null
  unitPrice: number | string | null
  taxGroupId: string | null
  hsnCode: string | null
  taxRate: number | string | null
  taxAmount: number | string | null
  lineTotal: number | string | null
}

export type DebitNote = {
  id: string
  supplierId: string
  supplierName: string
  debitNoteNumber: string
  status: string
  noteDate: string | null
  returnReason: string | null
  referenceBillId: string | null
  notes: string | null
  subtotal: number | string | null
  taxAmount: number | string | null
  totalAmount: number | string | null
  lines: DebitNoteLine[]
  createdAt: string | null
}

export type DebitNotePage = {
  content: DebitNote[]
  pageable: unknown
  totalElements: number
  totalPages: number
  number: number
  size: number
  last: boolean
}

type ListDebitNotesOptions = {
  status?: string
  supplierId?: string
  page: number
}

export async function listDebitNotes({ status, supplierId, page }: ListDebitNotesOptions) {
  const params = new URLSearchParams({ page: String(page), size: '25', sort: 'noteDate,desc' })
  if (status && status !== 'ALL') {
    params.set('status', status)
  }
  if (supplierId) {
    params.set('supplierId', supplierId)
  }
  return apiFetch<DebitNotePage>(`/api/v1/debit-notes?${params.toString()}`)
}

export function getDebitNote(id: string) {
  return apiFetch<DebitNote>(`/api/v1/debit-notes/${id}`)
}

export function submitDebitNote(id: string) {
  return apiFetch<DebitNote>(`/api/v1/debit-notes/${id}/submit`, { method: 'POST' })
}

export function deleteDebitNote(id: string) {
  return apiFetch<void>(`/api/v1/debit-notes/${id}`, { method: 'DELETE' })
}

export type CreateDebitNoteLineRequest = {
  itemId: string
  description?: string
  quantity: number
  unitPrice: number
  batchNumber?: string
  hsnCode?: string
  taxRate?: number
}

export type CreateDebitNoteRequest = {
  supplierId: string
  noteDate: string
  returnReason?: string
  referenceBillId?: string
  notes?: string
  lines: CreateDebitNoteLineRequest[]
}

export function createDebitNote(req: CreateDebitNoteRequest) {
  return apiFetch<DebitNote>('/api/v1/debit-notes', {
    method: 'POST',
    body: req,
  })
}