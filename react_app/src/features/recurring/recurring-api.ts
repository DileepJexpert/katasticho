import { apiFetch } from '@/api/client/api-client'
import { type Invoice } from '@/features/invoices/invoices-api'

export type RecurringFrequency = 'DAILY' | 'WEEKLY' | 'MONTHLY' | 'QUARTERLY' | 'YEARLY' | string

// ── Recurring Invoices ──

export type RecurringInvoiceLine = {
  itemId: string
  description?: string
  unit?: string
  hsnCode?: string
  quantity: number
  rate: number
  discountPct?: number
  taxRate?: number
  accountCode?: string
  amount: number
}

export type RecurringInvoice = {
  id: string
  profileName: string
  contactId: string
  contactName: string
  frequency: RecurringFrequency
  startDate: string
  endDate: string | null
  nextInvoiceDate: string | null
  paymentTermsDays: number
  autoSend: boolean
  status: 'ACTIVE' | 'STOPPED' | 'EXPIRED' | string
  currency: string | null
  notes: string | null
  terms: string | null
  totalGenerated: number
  lastGeneratedAt: string | null
  templateTotal: number
  lineItems: RecurringInvoiceLine[]
  createdAt: string
}

export type CreateRecurringInvoiceRequest = {
  profileName: string
  contactId: string
  frequency: RecurringFrequency
  startDate: string
  endDate?: string
  nextInvoiceDate?: string
  paymentTermsDays?: number
  autoSend?: boolean
  currency?: string
  notes?: string
  terms?: string
  lineItems: {
    itemId: string
    description?: string
    unit?: string
    hsnCode?: string
    quantity: number
    rate: number
    discountPct?: number
    taxRate?: number
    accountCode?: string
  }[]
}

export type GeneratedInvoice = {
  invoiceId: string
  invoiceNumber: string
  invoiceDate: string
  total: number
  generatedAt: string
}

export async function listRecurringInvoices(status?: string, page = 0, size = 50): Promise<{ content: RecurringInvoice[] }> {
  const params = new URLSearchParams()
  if (status && status !== 'all') params.set('status', status)
  params.set('page', String(page))
  params.set('size', String(size))
  return apiFetch<{ content: RecurringInvoice[] }>(`/api/v1/recurring-invoices?${params.toString()}`)
}

export async function getRecurringInvoice(id: string): Promise<RecurringInvoice> {
  return apiFetch<RecurringInvoice>(`/api/v1/recurring-invoices/${id}`)
}

export async function createRecurringInvoice(req: CreateRecurringInvoiceRequest): Promise<RecurringInvoice> {
  return apiFetch<RecurringInvoice>('/api/v1/recurring-invoices', {
    method: 'POST',
    body: JSON.stringify(req),
  })
}

export async function stopRecurringInvoice(id: string): Promise<RecurringInvoice> {
  return apiFetch<RecurringInvoice>(`/api/v1/recurring-invoices/${id}/stop`, {
    method: 'POST',
  })
}

export async function resumeRecurringInvoice(id: string): Promise<RecurringInvoice> {
  return apiFetch<RecurringInvoice>(`/api/v1/recurring-invoices/${id}/resume`, {
    method: 'POST',
  })
}

export async function generateRecurringInvoiceNow(id: string): Promise<Invoice> {
  return apiFetch<Invoice>(`/api/v1/recurring-invoices/${id}/generate-now`, {
    method: 'POST',
  })
}

export async function listGeneratedInvoices(id: string): Promise<GeneratedInvoice[]> {
  return apiFetch<GeneratedInvoice[]>(`/api/v1/recurring-invoices/${id}/generated-invoices`)
}

// ── Recurring Bills ──

export type RecurringBillLine = {
  itemId?: string
  description: string
  quantity: number
  rate: number
  taxRate?: number
  accountCode?: string
  amount: number
}

export type RecurringBill = {
  id: string
  profileName: string
  contactId: string
  frequency: RecurringFrequency
  startDate: string
  endDate: string | null
  nextBillDate: string | null
  paymentTermsDays: number
  reverseCharge: boolean
  placeOfSupply: string | null
  autoPost: boolean
  status: string
  totalGenerated: number
  lastGeneratedAt: string | null
  notes: string | null
  terms: string | null
  lineItems: RecurringBillLine[]
}

export type CreateRecurringBillRequest = {
  profileName: string
  contactId: string
  frequency: RecurringFrequency
  startDate: string
  endDate?: string
  paymentTermsDays?: number
  reverseCharge?: boolean
  placeOfSupply?: string
  autoPost?: boolean
  notes?: string
  terms?: string
  lineItems: RecurringBillLine[]
}

export type GeneratedBill = {
  billId: string
  generatedAt: string
  autoPosted: boolean
}

export async function listRecurringBills(status?: string, page = 0, size = 50): Promise<{ content: RecurringBill[] }> {
  const params = new URLSearchParams()
  if (status && status !== 'all') params.set('status', status)
  params.set('page', String(page))
  params.set('size', String(size))
  return apiFetch<{ content: RecurringBill[] }>(`/api/v1/recurring-bills?${params.toString()}`)
}

export async function getRecurringBill(id: string): Promise<RecurringBill> {
  return apiFetch<RecurringBill>(`/api/v1/recurring-bills/${id}`)
}

export async function createRecurringBill(req: CreateRecurringBillRequest): Promise<RecurringBill> {
  return apiFetch<RecurringBill>('/api/v1/recurring-bills', {
    method: 'POST',
    body: JSON.stringify(req),
  })
}

export async function stopRecurringBill(id: string): Promise<RecurringBill> {
  return apiFetch<RecurringBill>(`/api/v1/recurring-bills/${id}/stop`, {
    method: 'POST',
  })
}

export async function resumeRecurringBill(id: string): Promise<RecurringBill> {
  return apiFetch<RecurringBill>(`/api/v1/recurring-bills/${id}/resume`, {
    method: 'POST',
  })
}

export async function generateRecurringBillNow(id: string): Promise<{ generated: boolean; billId: string }> {
  return apiFetch<{ generated: boolean; billId: string }>(`/api/v1/recurring-bills/${id}/generate-now`, {
    method: 'POST',
  })
}

export async function listGeneratedBills(id: string): Promise<GeneratedBill[]> {
  return apiFetch<GeneratedBill[]>(`/api/v1/recurring-bills/${id}/generated-bills`)
}

// ── Recurring Journals ──

export type RecurringJournalLine = {
  accountCode: string
  narration?: string
  debitAmount?: number
  creditAmount?: number
}

export type RecurringJournal = {
  id: string
  profileName: string
  frequency: RecurringFrequency
  startDate: string
  endDate: string | null
  nextRunDate: string | null
  narration: string | null
  autoPost: boolean
  status: string
  totalGenerated: number
  lastGeneratedAt: string | null
  notes: string | null
  lines: RecurringJournalLine[]
}

export type CreateRecurringJournalRequest = {
  profileName: string
  frequency: RecurringFrequency
  startDate: string
  endDate?: string
  narration: string
  autoPost?: boolean
  notes?: string
  lines: RecurringJournalLine[]
}

export type GeneratedJournal = {
  journalEntryId: string
  generatedAt: string
  autoPosted: boolean
}

export async function listRecurringJournals(status?: string, page = 0, size = 50): Promise<{ content: RecurringJournal[] }> {
  const params = new URLSearchParams()
  if (status && status !== 'all') params.set('status', status)
  params.set('page', String(page))
  params.set('size', String(size))
  return apiFetch<{ content: RecurringJournal[] }>(`/api/v1/recurring-journals?${params.toString()}`)
}

export async function getRecurringJournal(id: string): Promise<RecurringJournal> {
  return apiFetch<RecurringJournal>(`/api/v1/recurring-journals/${id}`)
}

export async function createRecurringJournal(req: CreateRecurringJournalRequest): Promise<RecurringJournal> {
  return apiFetch<RecurringJournal>('/api/v1/recurring-journals', {
    method: 'POST',
    body: JSON.stringify(req),
  })
}

export async function stopRecurringJournal(id: string): Promise<RecurringJournal> {
  return apiFetch<RecurringJournal>(`/api/v1/recurring-journals/${id}/stop`, {
    method: 'POST',
  })
}

export async function resumeRecurringJournal(id: string): Promise<RecurringJournal> {
  return apiFetch<RecurringJournal>(`/api/v1/recurring-journals/${id}/resume`, {
    method: 'POST',
  })
}

export async function generateRecurringJournalNow(id: string): Promise<{ generated: boolean; journalEntryId: string }> {
  return apiFetch<{ generated: boolean; journalEntryId: string }>(`/api/v1/recurring-journals/${id}/generate-now`, {
    method: 'POST',
  })
}

export async function listGeneratedJournals(id: string): Promise<GeneratedJournal[]> {
  return apiFetch<GeneratedJournal[]>(`/api/v1/recurring-journals/${id}/generated-journals`)
}
