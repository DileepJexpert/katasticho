import { apiFetch } from '@/api/client/api-client'

export type PicklistLine = {
  id: string
  itemId: string
  itemName: string
  sku: string | null
  salesOrderLineId: string
  requiredQuantity: number | string
  pickedQuantity: number | string
  batchId: string | null
  batchNumber?: string | null
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
  status: 'PENDING' | 'IN_PROGRESS' | 'COMPLETED' | 'CANCELLED' | string
  assignedTo: string | null
  lineCount: number
  pickedCount: number
  notes: string | null
  createdAt: string
  startedAt: string | null
  completedAt: string | null
  lines: PicklistLine[]
}

export type PicklistPage = {
  content: Picklist[]
  page: number
  size: number
  totalElements: number
  totalPages: number
  last: boolean
}

export type CreatePicklistRequest = {
  salesOrderId: string
  warehouseId: string
  notes?: string
  assignedTo?: string
  lines: { salesOrderLineId: string; requiredQuantity: number; batchId?: string; notes?: string }[]
}

export type UpdatePicklistLineRequest = {
  lines: { lineId: string; pickedQuantity: number; batchId?: string; notes?: string }[]
}

export async function listPicklists(page = 0) {
  return apiFetch<PicklistPage>(`/api/v1/picklists?page=${page}&size=25&sort=createdAt,desc`)
}

export async function getPicklist(id: string) {
  return apiFetch<Picklist>(`/api/v1/picklists/${id}`)
}

export async function createPicklist(req: CreatePicklistRequest) {
  return apiFetch<Picklist>('/api/v1/picklists', {
    method: 'POST',
    body: req,
  })
}

export async function startPicking(id: string) {
  return apiFetch<Picklist>(`/api/v1/picklists/${id}/start`, {
    method: 'POST',
  })
}

export const startPicklist = startPicking

export async function updatePickedQuantities(id: string, req: UpdatePicklistLineRequest) {
  return apiFetch<Picklist>(`/api/v1/picklists/${id}/lines`, {
    method: 'PUT',
    body: req,
  })
}

export const updatePicklistLines = updatePickedQuantities

export async function completePicklist(id: string) {
  return apiFetch<Picklist>(`/api/v1/picklists/${id}/complete`, {
    method: 'POST',
  })
}

export async function cancelPicklist(id: string) {
  return apiFetch<void>(`/api/v1/picklists/${id}/cancel`, {
    method: 'POST',
  })
}
