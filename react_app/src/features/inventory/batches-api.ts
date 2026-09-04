import { apiFetch } from '@/api/client/api-client'

export interface ExpirySummary {
  expired: number
  within7Days: number
  within30Days: number
  within90Days: number
}

export interface ExpiryBatch {
  batchId: string
  itemId: string
  itemName: string
  batchNumber: string
  expiryDate: string
  quantityOnHand: number
  daysUntilExpiry: number
  urgency: 'EXPIRED' | 'CRITICAL' | 'WARNING' | 'OK' | string
}

export interface BatchDetail {
  id: string
  itemId: string
  batchNumber: string
  expiryDate: string
  manufacturingDate?: string | null
  mrp?: number | null
  costPrice?: number | null
  quantityAvailable?: number | null
}

export async function getExpirySummary(): Promise<ExpirySummary> {
  return apiFetch<ExpirySummary>('/api/v1/batches/expiry-summary')
}

export async function getNearExpiryBatches(days = 90): Promise<ExpiryBatch[]> {
  return apiFetch<ExpiryBatch[]>(`/api/v1/batches/near-expiry?days=${days}`)
}

export async function getBatch(id: string): Promise<BatchDetail> {
  return apiFetch<BatchDetail>(`/api/v1/batches/${id}`)
}

export async function listBatchesByItem(itemId: string): Promise<BatchDetail[]> {
  return apiFetch<BatchDetail[]>(`/api/v1/batches/item/${itemId}`)
}
