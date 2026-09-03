import { apiFetch } from '@/api/client/api-client'

export type AccountType = 'ASSET' | 'LIABILITY' | 'EQUITY' | 'REVENUE' | 'EXPENSE'

export type Account = {
  id: string
  code: string
  name: string
  type: string
  subType: string | null
  parentId: string | null
  parentAccountName: string | null
  level: number
  isSystem: boolean
  isInvolvedInTransaction: boolean
  hasChildren: boolean
  childCount: number
  description: string | null
  openingBalance: number | string | null
  currency: string | null
  isActive: boolean
}

export type AccountTransaction = {
  lineId: string
  journalEntryId: string
  entryNumber: string
  effectiveDate: string | null
  sourceModule: string | null
  entryDescription: string | null
  lineDescription: string | null
  debit: number | string | null
  credit: number | string | null
  currency: string | null
  baseDebit: number | string | null
  baseCredit: number | string | null
}

export type CreateAccountRequest = {
  code: string
  name: string
  type: AccountType | string
  subType?: string
  parentId?: string
  description?: string
  openingBalance?: number
  currency?: string
}

export type UpdateAccountRequest = {
  name: string
  subType?: string
  description?: string
  isActive?: boolean
}

export async function listAccounts() {
  return apiFetch<Account[]>('/api/v1/accounts')
}

export async function getAccount(id: string) {
  return apiFetch<Account>(`/api/v1/accounts/${id}`)
}

export async function createAccount(req: CreateAccountRequest) {
  return apiFetch<Account>('/api/v1/accounts', {
    method: 'POST',
    body: req,
  })
}

export async function updateAccount(id: string, req: UpdateAccountRequest) {
  return apiFetch<Account>(`/api/v1/accounts/${id}`, {
    method: 'PUT',
    body: req,
  })
}

export async function deleteAccount(id: string) {
  return apiFetch<void>(`/api/v1/accounts/${id}`, {
    method: 'DELETE',
  })
}

export async function seedTemplate(industry = 'TRADING') {
  return apiFetch<{ result: unknown; industry: string }>('/api/v1/accounts/template', {
    method: 'POST',
    body: { industry },
  })
}

export async function getAccountTransactions(id: string, startDate?: string, endDate?: string) {
  const params = new URLSearchParams()
  if (startDate) params.set('startDate', startDate)
  if (endDate) params.set('endDate', endDate)
  const q = params.toString() ? `?${params.toString()}` : ''
  return apiFetch<AccountTransaction[]>(`/api/v1/accounts/${id}/transactions${q}`)
}
