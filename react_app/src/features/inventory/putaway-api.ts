import { apiFetch } from '@/api/client/api-client'

export interface PutawayLine {
  id: string
  itemId: string
  batchNumber: string | null
  quantity: number | string
  suggestedRackId: string | null
  confirmedRackId: string | null
  status: string
  confirmedAt: string | null
  confirmedBy: string | null
}
export interface PutawayTask {
  id: string
  orgId: string
  taskNumber: string
  goodsReceiptId: string | null
  warehouseId: string
  sourceLocation: string | null
  status: string
  assignedTo: string | null
  notes: string | null
  createdAt: string
  updatedAt: string
  lines: PutawayLine[]
}
export interface PutawayRequest {
  goodsReceiptId?: string
  warehouseId: string
  sourceLocation?: string
  assignedTo?: string
  notes?: string
  lines: Array<{ itemId: string; batchNumber?: string; quantity: number; suggestedRackId?: string }>
}
const base = '/api/v1/inventory/putaway-tasks'
export function listPutawayTasks(status?: string) {
  return apiFetch<PutawayTask[]>(`${base}${status ? `?status=${encodeURIComponent(status)}` : ''}`)
}
export function getPutawayTask(id: string) {
  return apiFetch<PutawayTask>(`${base}/${encodeURIComponent(id)}`)
}
export function createPutawayTask(request: PutawayRequest) {
  return apiFetch<PutawayTask>(base, { method: 'POST', body: JSON.stringify(request) })
}
export function confirmPutawayLine(taskId: string, lineId: string, confirmedRackId: string) {
  return apiFetch<PutawayTask>(`${base}/${encodeURIComponent(taskId)}/lines/${encodeURIComponent(lineId)}/confirm`, { method: 'POST', body: JSON.stringify({ confirmedRackId }) })
}
export function cancelPutawayTask(id: string) {
  return apiFetch<PutawayTask>(`${base}/${encodeURIComponent(id)}/cancel`, { method: 'POST' })
}
