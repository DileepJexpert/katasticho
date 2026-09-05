import { beforeEach, expect, it, vi } from 'vitest'
import { apiFetch } from '@/api/client/api-client'
import { createRackLocation, listRackLocations } from '@/features/pharmacy/pharmacy-api'
import { cancelPutawayTask, confirmPutawayLine, createPutawayTask, listPutawayTasks } from './putaway-api'
import { createUom, deleteUom, updateUom, UOM_CATEGORIES } from './uoms-api'
import { listAvailableSerials, listSerialNumbers } from './serial-numbers-api'
import { getItemMovements } from '@/features/items/items-api'

vi.mock('@/api/client/api-client', () => ({ apiFetch: vi.fn() }))
beforeEach(() => vi.clearAllMocks())

it('uses the existing warehouse-scoped rack contract', async () => {
  await listRackLocations('warehouse-id')
  expect(apiFetch).toHaveBeenLastCalledWith('/api/v1/pharmacy-masters/rack-locations?warehouseId=warehouse-id')
  const request = { warehouseId: 'warehouse-id', code: 'A-01', zone: 'Receiving' }
  await createRackLocation(request)
  expect(apiFetch).toHaveBeenLastCalledWith('/api/v1/pharmacy-masters/rack-locations', { method: 'POST', body: JSON.stringify(request) })
})

it('creates placement lines and confirms the actual rack without inventory payloads', async () => {
  const request = { warehouseId: 'warehouse-id', goodsReceiptId: 'receipt-id', lines: [{ itemId: 'item-id', quantity: 2, batchNumber: 'B-1', suggestedRackId: 'rack-id' }] }
  await createPutawayTask(request)
  expect(apiFetch).toHaveBeenLastCalledWith('/api/v1/inventory/putaway-tasks', { method: 'POST', body: JSON.stringify(request) })
  await confirmPutawayLine('task-id', 'line-id', 'actual-rack-id')
  expect(apiFetch).toHaveBeenLastCalledWith('/api/v1/inventory/putaway-tasks/task-id/lines/line-id/confirm', { method: 'POST', body: JSON.stringify({ confirmedRackId: 'actual-rack-id' }) })
  await listPutawayTasks('IN_PROGRESS')
  expect(apiFetch).toHaveBeenLastCalledWith('/api/v1/inventory/putaway-tasks?status=IN_PROGRESS')
  await cancelPutawayTask('task-id')
  expect(apiFetch).toHaveBeenLastCalledWith('/api/v1/inventory/putaway-tasks/task-id/cancel', { method: 'POST' })
})

it('uses actual UoM categories and metadata write operations', async () => {
  expect(UOM_CATEGORIES).toEqual(['COUNT', 'WEIGHT', 'VOLUME', 'LENGTH', 'PACKAGING'])
  const request = { name: 'Carton', abbreviation: 'CTN', category: 'PACKAGING' as const, base: false, active: true }
  await createUom(request)
  expect(apiFetch).toHaveBeenLastCalledWith('/api/v1/uoms', { method: 'POST', body: JSON.stringify(request) })
  await updateUom('unit-id', request)
  expect(apiFetch).toHaveBeenLastCalledWith('/api/v1/uoms/unit-id', { method: 'PUT', body: JSON.stringify(request) })
  await deleteUom('unit-id')
  expect(apiFetch).toHaveBeenLastCalledWith('/api/v1/uoms/unit-id', { method: 'DELETE' })
})

it('uses server paging for serial history and warehouse-scoped availability', async () => {
  await listSerialNumbers('item-id', 2)
  expect(apiFetch).toHaveBeenLastCalledWith('/api/v1/serial-numbers/by-item/item-id?page=2&size=25&sort=serial%2Casc')
  await listAvailableSerials('item-id', 'warehouse-id')
  expect(apiFetch).toHaveBeenLastCalledWith('/api/v1/serial-numbers/available?itemId=item-id&warehouseId=warehouse-id')
})

it('passes the requested stock-ledger page to the existing list endpoint', async () => {
  await getItemMovements('item-id', 3)
  expect(apiFetch).toHaveBeenLastCalledWith('/api/v1/stock/items/item-id/movements?page=3&size=50')
})
