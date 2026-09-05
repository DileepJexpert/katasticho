import { apiFetch } from '@/api/client/api-client'

type NumberLike = number | string | null

/** Read projection returned by the frozen WarehouseController contract. */
export type Warehouse = {
  id: string
  code: string
  name: string
  addressLine1: string | null
  addressLine2: string | null
  city: string | null
  state: string | null
  stateCode: string | null
  postalCode: string | null
  country: string | null
  isDefault: boolean
  active: boolean
  createdAt: string | null
}

/** The zone controller currently returns the persisted entity directly. */
export type WarehouseZone = {
  id: string
  warehouseId: string
  code: string
  name: string
  zoneType: string
  capacity: NumberLike
  currentUtilization: NumberLike
  temperatureControlled: boolean
  notes: string | null
}

export function listWarehouses() {
  return apiFetch<Warehouse[]>('/api/v1/warehouses')
}

export function getWarehouse(id: string) {
  return apiFetch<Warehouse>(`/api/v1/warehouses/${id}`)
}

export function listWarehouseZones(warehouseId: string) {
  return apiFetch<WarehouseZone[]>(`/api/v1/inventory/warehouse-zones/by-warehouse/${warehouseId}`)
}

export type WarehouseRequest = Omit<Warehouse, 'id' | 'createdAt'>
export function createWarehouse(request: WarehouseRequest) {
  return apiFetch<Warehouse>('/api/v1/warehouses', { method: 'POST', body: request })
}
export function updateWarehouse(id: string, request: WarehouseRequest) {
  return apiFetch<Warehouse>(`/api/v1/warehouses/${id}`, { method: 'PUT', body: request })
}
export function deleteWarehouse(id: string) {
  return apiFetch<void>(`/api/v1/warehouses/${id}`, { method: 'DELETE' })
}

export type WarehouseZoneUpdate = {
  name: string
  zoneType: string
  capacity?: number
  temperatureControlled: boolean
  notes: string
}
export function createWarehouseZone(request: WarehouseZoneUpdate & { warehouseId: string; code: string }) {
  return apiFetch<WarehouseZone>('/api/v1/inventory/warehouse-zones', { method: 'POST', body: request })
}
export function updateWarehouseZone(id: string, request: WarehouseZoneUpdate) {
  return apiFetch<WarehouseZone>(`/api/v1/inventory/warehouse-zones/${id}`, { method: 'PUT', body: request })
}
export function deleteWarehouseZone(id: string) {
  return apiFetch<void>(`/api/v1/inventory/warehouse-zones/${id}`, { method: 'DELETE' })
}
