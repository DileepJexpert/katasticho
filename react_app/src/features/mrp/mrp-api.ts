import { apiFetch } from '@/api/client/api-client'

export type PlannedOrder = {
  id: string
  mrpRunId: string
  itemId: string
  itemName?: string | null
  orderType: 'PURCHASE' | 'PRODUCTION' | string
  suggestedQty: number | string
  requiredDate: string
  releaseDate: string
  status: 'PLANNED' | 'CONVERTED' | 'CANCELLED' | string
  convertedReferenceId?: string | null
  convertedReferenceNumber?: string | null
}

export type MrpDemand = {
  id: string
  mrpRunId: string
  itemId: string
  itemName?: string | null
  demandSource: string
  sourceReferenceId?: string | null
  requiredQty: number | string
  dueDate: string
}

export type MrpSupply = {
  id: string
  mrpRunId: string
  itemId: string
  itemName?: string | null
  supplyType: string
  sourceReferenceId?: string | null
  availableQty: number | string
  expectedDate: string
}

export type MrpRun = {
  id: string
  runNumber: string
  horizonDays: number
  runDate: string
  status: string
  notes?: string | null
  demandsCount?: number
  suppliesCount?: number
  plannedOrdersCount?: number
  plannedOrders?: PlannedOrder[]
}

export async function listMrpRuns() {
  return apiFetch<MrpRun[]>('/api/v1/manufacturing/mrp/runs')
}

export async function getMrpRun(id: string) {
  return apiFetch<MrpRun>(`/api/v1/manufacturing/mrp/runs/${id}`)
}

export async function runMrp(horizonDays = 90) {
  return apiFetch<MrpRun>('/api/v1/manufacturing/mrp/run', {
    method: 'POST',
    body: JSON.stringify({ horizonDays }),
  })
}

export async function convertPlannedToPO(plannedOrderId: string) {
  return apiFetch<PlannedOrder>(`/api/v1/manufacturing/mrp/planned-orders/${plannedOrderId}/convert-po`, {
    method: 'POST',
  })
}

export async function convertPlannedToWO(plannedOrderId: string) {
  return apiFetch<PlannedOrder>(`/api/v1/manufacturing/mrp/planned-orders/${plannedOrderId}/convert-wo`, {
    method: 'POST',
  })
}