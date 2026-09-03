import { apiFetch } from '@/api/client/api-client'

export type BankAccount = {
  id: string
  accountName: string
  bankName: string
  accountNumber: string
  ifscCode?: string | null
  branch?: string | null
  currency: string
  accountType: 'SAVINGS' | 'CURRENT' | 'OVERDRAFT' | 'CREDIT_CARD' | string
  currentBalance: number
  glAccountId: string
  glAccountName?: string | null
  isDefault: boolean
  active: boolean
}

export type CreateBankAccountRequest = {
  accountName: string
  bankName: string
  accountNumber: string
  ifscCode?: string | null
  branch?: string | null
  currency?: string
  accountType: string
  openingBalance?: number
  glAccountId?: string
}

export type BankReconciliationSummary = {
  totalBankBalance: number
  totalBookBalance: number
  unreconciledDifference: number
  unreconciledCount: number
  matchedCount: number
  ignoredCount: number
}

export type BankTransactionMatch = {
  id: string
  journalEntryId?: string | null
  journalNumber?: string | null
  paymentId?: string | null
  matchedAmount: number
  confidenceScore: number
  matchType: 'EXACT_AMOUNT_DATE' | 'REF_NUMBER' | 'AI_SUGGESTION' | string
  status: 'PROPOSED' | 'ACCEPTED' | 'REJECTED' | string
}

export type BankTransaction = {
  id: string
  bankAccountId: string
  bankAccountName?: string | null
  transactionDate: string
  description: string
  referenceNumber?: string | null
  debitAmount: number
  creditAmount: number
  runningBalance?: number | null
  reconciliationStatus: 'UNRECONCILED' | 'RECONCILED' | 'IGNORED' | string
  matchedJournalId?: string | null
  matches: BankTransactionMatch[]
}

export type BankRule = {
  id: string
  name: string
  priority: number
  ruleType: 'AUTO_CATEGORIZE' | 'AUTO_MATCH' | string
  conditions: string
  targetAccountId?: string | null
  targetAccountName?: string | null
  active: boolean
}

export type BankTransactionPage = {
  content: BankTransaction[]
  page: number
  size: number
  totalElements: number
  totalPages: number
  last: boolean
}

// â”€â”€ Bank Account Endpoints â”€â”€

export async function listBankAccounts(activeOnly = false): Promise<BankAccount[]> {
  return apiFetch<BankAccount[]>(`/api/v1/bank-accounts?active_only=${activeOnly}`)
}

export async function getBankAccount(id: string): Promise<BankAccount> {
  return apiFetch<BankAccount>(`/api/v1/bank-accounts/${id}`)
}

export async function createBankAccount(req: CreateBankAccountRequest): Promise<BankAccount> {
  return apiFetch<BankAccount>('/api/v1/bank-accounts', {
    method: 'POST',
    body: JSON.stringify(req),
  })
}

export async function updateBankAccount(id: string, req: CreateBankAccountRequest): Promise<BankAccount> {
  return apiFetch<BankAccount>(`/api/v1/bank-accounts/${id}`, {
    method: 'PUT',
    body: JSON.stringify(req),
  })
}

export async function setDefaultBankAccount(id: string): Promise<BankAccount> {
  return apiFetch<BankAccount>(`/api/v1/bank-accounts/${id}/set-default`, {
    method: 'POST',
  })
}

export async function deleteBankAccount(id: string): Promise<void> {
  return apiFetch<void>(`/api/v1/bank-accounts/${id}`, {
    method: 'DELETE',
  })
}

// â”€â”€ Bank Reconciliation & Statements â”€â”€

export async function getBankReconciliationSummary(): Promise<BankReconciliationSummary> {
  return apiFetch<BankReconciliationSummary>('/api/v1/banking/summary')
}

export async function listBankTransactions(status?: string, page = 0, size = 50): Promise<BankTransactionPage> {
  const params = new URLSearchParams()
  params.set('page', String(page))
  params.set('size', String(size))
  if (status && status !== 'ALL') params.set('status', status)
  return apiFetch<BankTransactionPage>(`/api/v1/banking/transactions?${params.toString()}`)
}

export async function acceptReconciliationMatch(matchId: string, bankAccountId?: string): Promise<BankTransaction> {
  const params = new URLSearchParams()
  if (bankAccountId) params.set('bank_account_id', bankAccountId)
  return apiFetch<BankTransaction>(`/api/v1/banking/matches/${matchId}/accept?${params.toString()}`, {
    method: 'POST',
  })
}

export async function rejectReconciliationMatch(matchId: string): Promise<BankTransaction> {
  return apiFetch<BankTransaction>(`/api/v1/banking/matches/${matchId}/reject`, {
    method: 'POST',
  })
}

export async function rerunReconciliationMatch(transactionId: string): Promise<BankTransaction> {
  return apiFetch<BankTransaction>(`/api/v1/banking/transactions/${transactionId}/rerun-match`, {
    method: 'POST',
  })
}

export async function ignoreBankTransaction(transactionId: string): Promise<BankTransaction> {
  return apiFetch<BankTransaction>(`/api/v1/banking/transactions/${transactionId}/ignore`, {
    method: 'POST',
  })
}

export async function listBankRules(): Promise<BankRule[]> {
  return apiFetch<BankRule[]>('/api/v1/banking/rules')
}