import { apiFetch } from '@/api/client/api-client'

export interface BankAccount {
  id: string
  name: string
  bankName: string
  accountNumber: string
  ifsc?: string | null
  branch?: string | null
  accountType: 'CURRENT' | 'SAVINGS' | 'OVERDRAFT' | 'CREDIT_CARD' | string
  glAccountId?: string | null
  glAccountCode?: string | null
  openingBalance?: number | null
  isDefault: boolean
  isActive: boolean
  notes?: string | null
  // Legacy / convenience fallbacks
  accountName?: string
  ifscCode?: string | null
  currentBalance?: number | null
}

export type BankAccountType = 'CURRENT' | 'SAVINGS' | 'OVERDRAFT' | 'CREDIT_CARD' | string

/**
 * Lists all bank accounts for the active organisation.
 * GET /api/v1/bank-accounts
 */
export async function listBankAccounts(activeOnly = false): Promise<BankAccount[]> {
  const accounts = await apiFetch<BankAccount[]>(`/api/v1/bank-accounts?active_only=${activeOnly}`)
  return accounts.map((acc) => ({
    ...acc,
    name: acc.name ?? acc.accountName ?? '',
    ifsc: acc.ifsc ?? acc.ifscCode ?? null,
    openingBalance: acc.openingBalance ?? acc.currentBalance ?? 0,
  }))
}

/**
 * Gets a single bank account by ID.
 * GET /api/v1/bank-accounts/{id}
 */
export async function getBankAccount(id: string): Promise<BankAccount> {
  const acc = await apiFetch<BankAccount>(`/api/v1/bank-accounts/${id}`)
  return {
    ...acc,
    openingBalance: acc.openingBalance ?? acc.currentBalance ?? 0,
  }
}

export type BankAccountRequest = {
  name: string
  bankName?: string | null
  accountNumber?: string | null
  ifsc?: string | null
  branch?: string | null
  accountType?: string | null
  glAccountCode?: string | null
  openingBalance?: number | null
  isDefault?: boolean
  isActive?: boolean
  notes?: string | null
}

export function createBankAccount(request: BankAccountRequest) {
  return apiFetch<BankAccount>('/api/v1/bank-accounts', {
    method: 'POST',
    body: request,
  })
}

export function updateBankAccount(id: string, request: BankAccountRequest) {
  return apiFetch<BankAccount>(`/api/v1/bank-accounts/${id}`, {
    method: 'PUT',
    body: request,
  })
}

export function deleteBankAccount(id: string) {
  return apiFetch<void>(`/api/v1/bank-accounts/${id}`, {
    method: 'DELETE',
  })
}

export function setDefaultBankAccount(id: string) {
  return apiFetch<BankAccount>(`/api/v1/bank-accounts/${id}/set-default`, {
    method: 'POST',
  })
}

export type PaymentMatch = {
  id: string
  matchType: string
  invoiceId?: string | null
  billId?: string | null
  documentNumber?: string | null
  invoiceNumber?: string | null
  contactId?: string | null
  contactName?: string | null
  matchedAmount?: number | null
  confidence?: number | null
  matchStatus: string
  paymentId?: string | null
  acceptedAt?: string | null
}

export type BankTransaction = {
  id: string
  transactionDate: string
  amount: number
  direction: 'INFLOW' | 'OUTFLOW' | string
  narration?: string | null
  utr?: string | null
  payerName?: string | null
  payerVpa?: string | null
  status: 'UNRECONCILED' | 'RECONCILED' | 'IGNORED' | 'PARTIAL' | string
  paymentId?: string | null
  suggestedMatches?: PaymentMatch[]
  createdAt?: string | null
}

export type BankReconciliationSummary = {
  totalTransactions?: number
  unreconciledCount?: number
  reconciledCount?: number
  ignoredCount?: number
  unreconciledInflow?: number
  unreconciledOutflow?: number
  [key: string]: unknown
}

export type PagedResponse<T> = {
  content: T[]
  totalElements: number
  totalPages: number
  number: number
  size: number
}

export function listBankTransactions(status?: string, page = 0, size = 20) {
  const query = new URLSearchParams()
  if (status && status !== 'ALL') query.set('status', status)
  query.set('page', String(page))
  query.set('size', String(size))
  return apiFetch<PagedResponse<BankTransaction>>(`/api/v1/banking/transactions?${query.toString()}`)
}

export function getBankReconciliationSummary() {
  return apiFetch<BankReconciliationSummary>('/api/v1/banking/summary')
}

export function importBankStatementFile(file: File) {
  const formData = new FormData()
  formData.append('file', file)
  return apiFetch<{ importedCount: number; duplicateCount: number }>('/api/v1/banking/transactions/import-file', {
    method: 'POST',
    body: formData,
  })
}

export function acceptPaymentMatch(matchId: string, bankAccountId?: string) {
  const query = bankAccountId ? `?bank_account_id=${bankAccountId}` : ''
  return apiFetch<BankTransaction>(`/api/v1/banking/matches/${matchId}/accept${query}`, {
    method: 'POST',
  })
}

export function rejectPaymentMatch(matchId: string) {
  return apiFetch<BankTransaction>(`/api/v1/banking/matches/${matchId}/reject`, {
    method: 'POST',
  })
}

export function ignoreBankTransaction(transactionId: string) {
  return apiFetch<BankTransaction>(`/api/v1/banking/transactions/${transactionId}/ignore`, {
    method: 'POST',
  })
}

export function rerunBankMatches(transactionId: string) {
  return apiFetch<BankTransaction>(`/api/v1/banking/transactions/${transactionId}/rerun-match`, {
    method: 'POST',
  })
}

export function runAutoMatch(bankAccountId: string) {
  return apiFetch<unknown[]>('/api/v1/banking/auto-match/run', {
    method: 'POST',
    body: { bankAccountId },
  })
}
