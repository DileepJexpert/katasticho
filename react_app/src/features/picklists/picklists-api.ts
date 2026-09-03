import { apiFetch } from '@/api/client/api-client'

export type PicklistLine = {
  id: string
  salesOrderLineId: string
  itemId: string
  itemName: string | null
  sku: string | null
  requiredQuantity: number | string | null
  pickedQuantity: number | string | null
  batchId: string | null
  batchNumber: string | null
  rackLocationId: string | null
  rackLocationCode: string | null
  notes: string | null
}

export type Picklist = {
  id: string
  picklistNumber: string
  salesOrderId: string
  salesOrderNumber: string | null
  warehouseId: string
  warehouseName: string | null
  status: string
  assignedTo: string | null
  notes: string | null
  startedAt: string | null
  completedAt: string | null
  lineCount: number
  pickedCount: number
  lines: PicklistLine[]
  createdAt: string | null
}

export type PicklistPage = {
  content: Picklist[]
  page: number
  size: number
  totalElements: number
  totalPages: number
  last: boolean
}

export function listPicklists(page: number) {
  const params = new URLSearchParams({ page: String(page), size: '25' })
  return apiFetch<PicklistPage>(`/api/v1/picklists?${params.toString()}`)
}

export function getPicklist(id: string) {
  return apiFetch<Picklist>(`/api/v1/picklists/${id}`)
}
