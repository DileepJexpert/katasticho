import { apiFetch } from '@/api/client/api-client'

type NumberLike = number | string | null

/** Read projection returned by the frozen AccountController contract. */
export type Account = {
  id: string
  code: string
  name: string
  type: string
  accountType?: string
  subType: string | null
  parentId: string | null
  parentAccountName: string | null
  level: number
  isSystem: boolean
  isInvolvedInTransaction: boolean
  hasChildren: boolean
  childCount: number
  description: string | null
  openingBalance: NumberLike
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
  debit: NumberLike
  credit: NumberLike
  currency: string | null
  baseDebit: NumberLike
  baseCredit: NumberLike
}

export function listAccounts() {
  return apiFetch<Account[]>('/api/v1/accounts')
}

export function getAccount(id: string) {
  return apiFetch<Account>(`/api/v1/accounts/${id}`)
}

export function getAccountTransactions(id: string) {
  return apiFetch<AccountTransaction[]>(`/api/v1/accounts/${id}/transactions`)
}
