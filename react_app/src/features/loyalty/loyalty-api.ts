import { apiFetch } from '@/api/client/api-client'

export type WalletResponse = {
  id: string | null
  contactId: string
  balance: number
  totalEarned: number
  totalRedeemed: number
  maxRedeemable: number | null
}

export type WalletTransactionResponse = {
  id: string
  txnType: 'EARN' | 'REDEEM' | 'EXPIRE' | 'REVERSAL' | string
  amount: number
  balanceAfter: number
  referenceType: string | null
  notes: string | null
  createdAt: string | null
}

export type EarnPointsRequest = { contactId: string; saleTotal: number; receiptId: string }

export type RedeemPointsRequest = { contactId: string; redeemAmount: number; receiptId: string }

export async function getWallet(contactId: string): Promise<WalletResponse> {
  return apiFetch<WalletResponse>(`/api/v1/wallet/contact/${contactId}`)
}

export async function getWalletTransactions(contactId: string): Promise<WalletTransactionResponse[]> {
  return apiFetch<WalletTransactionResponse[]>(`/api/v1/wallet/contact/${contactId}/transactions`)
}

export async function getWalletRedeemable(contactId: string, saleTotal: number): Promise<WalletResponse> {
  return apiFetch<WalletResponse>(`/api/v1/wallet/contact/${contactId}/redeemable?saleTotal=${saleTotal}`)
}

export async function earnLoyaltyPoints(req: EarnPointsRequest): Promise<WalletResponse> {
  return apiFetch<WalletResponse>('/api/v1/wallet/earn', {
    method: 'POST',
    body: JSON.stringify(req),
  })
}

export async function redeemLoyaltyPoints(req: RedeemPointsRequest): Promise<WalletResponse> {
  return apiFetch<WalletResponse>('/api/v1/wallet/redeem', {
    method: 'POST',
    body: JSON.stringify(req),
  })
}
