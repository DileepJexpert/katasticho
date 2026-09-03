import { apiFetch } from '@/api/client/api-client'

export type Warehouse = {
  id: string
  code: string
  name: string
  warehouseType?: 'CENTRAL' | 'REGIONAL' | 'RETAIL' | 'TRANSIT' | string
  addressLine1?: string | null
  addressLine2?: string | null
  city?: string | null
  state?: string | null
  pincode?: string | null
  gstin?: string | null
  active: boolean
  isDefault: boolean
}

export type WarehouseZone = {
  id: string
  warehouseId: string
  code: string
  name: string
  zoneType: 'STORAGE' | 'RECEIVING' | 'SHIPPING' | 'COLD_STORAGE' | 'QUARANTINE' | 'PICK_FACE' | string
  capacity?: number | string | null
  temperatureControlled: boolean
  notes?: string | null
}

export type PutawayTask = {
  id: string
  taskId: string
  warehouseId: string
  status: 'PENDING' | 'IN_PROGRESS' | 'COMPLETED' | 'CANCELLED' | string
  createdAt: string
  lines: {
    id: string
    itemId: string
    itemName: string
    quantity: number | string
    suggestedZoneId?: string
    suggestedZoneName?: string
    confirmedZoneId?: string
    confirmedRack?: string
    status: 'PENDING' | 'CONFIRMED' | string
  }[]
}

export type CreateWarehouseRequest = {
  code: string
  name: string
  warehouseType?: string
  addressLine1?: string
  addressLine2?: string
  city?: string
  state?: string
  pincode?: string
  gstin?: string
  isDefault?: boolean
}

export async function listWarehouses() {
  return apiFetch<Warehouse[]>('/api/v1/warehouses')
}

export async function getWarehouse(id: string) {
  return apiFetch<Warehouse>(`/api/v1/warehouses/${id}`)
}

export async function createWarehouse(req: CreateWarehouseRequest) {
  return apiFetch<Warehouse>('/api/v1/warehouses', {
    method: 'POST',
    body: req,
  })
}

export async function updateWarehouse(id: string, req: CreateWarehouseRequest) {
  return apiFetch<Warehouse>(`/api/v1/warehouses/${id}`, {
    method: 'PUT',
    body: req,
  })
}

export async function deleteWarehouse(id: string) {
  return apiFetch<void>(`/api/v1/warehouses/${id}`, {
    method: 'DELETE',
  })
}

export async function listWarehouseZones(warehouseId: string) {
  return apiFetch<WarehouseZone[]>(`/api/v1/inventory/warehouse-zones/by-warehouse/${warehouseId}`)
}

export async function createWarehouseZone(
  warehouseIdOrReq: string | { warehouseId: string; code: string; name: string; zoneType: string; capacity?: number; temperatureControlled?: boolean; notes?: string },
  reqIfWarehouseId?: { code: string; name: string; zoneType: string; capacity?: number; temperatureControlled?: boolean; notes?: string }
) {
  const body = typeof warehouseIdOrReq === 'string'
    ? { warehouseId: warehouseIdOrReq, ...reqIfWarehouseId }
    : warehouseIdOrReq
  return apiFetch<WarehouseZone>('/api/v1/inventory/warehouse-zones', {
    method: 'POST',
    body,
  })
}

export async function listPutawayTasks(warehouseId: string) {
  return apiFetch<PutawayTask[]>(`/api/v1/inventory/putaway/by-warehouse/${warehouseId}`)
}

export async function confirmPutawayLine(taskId: string, lineId: string, req: { confirmedZoneId: string; confirmedRack?: string }) {
  return apiFetch<PutawayTask>(`/api/v1/inventory/putaway/${taskId}/lines/${lineId}/confirm`, {
    method: 'POST',
    body: req,
  })
}
