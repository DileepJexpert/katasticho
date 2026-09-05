import { apiFetch } from '@/api/client/api-client'

export type JournalEntryLine = {
  id: string
  accountId: string
  accountCode: string
  accountName: string
  description: string | null
  debit: number | string | null
  credit: number | string | null
  currency: string | null
  exchangeRate: number | string | null
  baseDebit: number | string | null
  baseCredit: number | string | null
  taxComponentCode: string | null
}

export type JournalEntry = {
  id: string
  entryNumber: string
  effectiveDate: string | null
  createdAt: string | null
  description: string | null
  sourceModule: string | null
  sourceId: string | null
  status: string
  isReversal: boolean
  isReversed: boolean
  reversalOfId: string | null
  periodYear: number
  periodMonth: number
  totalDebit: number | string | null
  lines: JournalEntryLine[]
}

export type JournalEntryPage = {
  content: JournalEntry[]
  page: number
  size: number
  totalElements: number
  totalPages: number
  last: boolean
}

export type CreateJournalLineRequest = {
  accountCode: string
  debit?: number
  credit?: number
  description?: string
  costCentre?: string
}

export type CreateJournalRequest = {
  effectiveDate: string
  description: string
  sourceModule: string
  sourceId?: string
  lines: CreateJournalLineRequest[]
  autoPost: boolean
  postDated: boolean
}

type ListJournalsOptions = {
  sourceModule?: string
  search?: string
  page?: number
  dateFrom?: string
  dateTo?: string
}

export async function listJournals(options: ListJournalsOptions = {}) {
  const { sourceModule, search, page = 0, dateFrom, dateTo } = options
  const params = new URLSearchParams({ page: String(page), size: '25', sort: 'effectiveDate,desc' })
  if (sourceModule && sourceModule !== 'ALL') {
    params.set('sourceModule', sourceModule)
  }
  if (search) {
    params.set('search', search)
  }
  if (dateFrom) {
    params.set('dateFrom', dateFrom)
  }
  if (dateTo) {
    params.set('dateTo', dateTo)
  }
  return apiFetch<JournalEntryPage>(`/api/v1/journal-entries?${params.toString()}`)
}

export async function getJournal(id: string) {
  return apiFetch<JournalEntry>(`/api/v1/journal-entries/${id}`)
}

export async function createJournal(req: CreateJournalRequest) {
  return apiFetch<JournalEntry>('/api/v1/journal-entries', {
    method: 'POST',
    body: req,
  })
}

export async function postJournal(id: string) {
  return apiFetch<JournalEntry>(`/api/v1/journal-entries/${id}/post`, {
    method: 'POST',
  })
}

export async function reverseJournal(id: string) {
  return apiFetch<JournalEntry>(`/api/v1/journal-entries/${id}/reverse`, {
    method: 'POST',
  })
}

export async function deleteJournal(id: string) {
  return apiFetch<void>(`/api/v1/journal-entries/${id}`, {
    method: 'DELETE',
  })
}
