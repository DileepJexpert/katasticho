import { apiFetch } from '@/api/client/api-client'

type NumberLike = number | string | null

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

/** Read-only projection returned by the BatchController. */
export interface BatchDetail {
  id: string
  itemId: string
  batchNumber: string
  expiryDate: string | null
  manufacturingDate?: string | null
  unitCost: NumberLike
  supplierId: string | null
  active: boolean
  quantityAvailable: NumberLike
}

/** Immutable genealogy record returned directly from BatchTraceController. */
export interface BatchTraceRecord {
  id: string
  batchId: string
  itemId: string
  traceType: 'FORWARD' | 'BACKWARD' | string
  sourceBatchId: string | null
  sourceItemId: string | null
  workOrderId: string | null
  movementId: string | null
  quantity: NumberLike
  tracedAt: string
}

export interface BatchTraceHistory {
  backward: BatchTraceRecord[]
  forward: BatchTraceRecord[]
}

export interface BatchRecallReport {
  rmBatch: {
    batchId: string
    batchNumber: string | null
    itemId: string | null
    expiryDate: string | null
  }
  affectedFgBatches: Array<{
    fgBatchId: string
    fgBatchNumber: string | null
    fgItemId: string | null
  }>
  affectedShipments: Array<{
    fgBatchId: string
    movementDate: string | null
    quantity: NumberLike
    invoiceId: string | null
    invoiceNumber: string | null
    customerName: string | null
  }>
  affectedFgBatchCount: number
  affectedShipmentCount: number
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

export function listAvailableBatches(itemId: string, warehouseId?: string | null) {
  const params = new URLSearchParams()
  if (warehouseId) params.set('warehouseId', warehouseId)
  return apiFetch<BatchDetail[]>(`/api/v1/batches/item/${itemId}/available${params.size ? `?${params}` : ''}`)
}

export function getBatchTraceHistory(batchId: string) {
  return apiFetch<BatchTraceHistory>(`/api/v1/inventory/batch-trace/history/${batchId}`)
}

export function getBatchRecallReport(batchId: string) {
  return apiFetch<BatchRecallReport>(`/api/v1/inventory/batch-trace/recall/${batchId}`)
}
