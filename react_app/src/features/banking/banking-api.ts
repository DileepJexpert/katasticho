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
    name: acc.name ?? acc.accountName ?? '',
    ifsc: acc.ifsc ?? acc.ifscCode ?? null,
    openingBalance: acc.openingBalance ?? acc.currentBalance ?? 0,
  }
}
