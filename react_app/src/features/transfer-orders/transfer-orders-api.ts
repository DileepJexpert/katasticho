import { apiFetch } from '@/api/client/api-client'

export type TransferOrderLine = {
  id: string
  itemId: string
  itemName: string
  itemSku: string | null
  requestedQuantity: number | string
  shippedQuantity?: number | string
  receivedQuantity?: number | string
  unitOfMeasure: string | null
  batchNumber?: string | null
}

export type TransferOrder = {
  id: string
  orderNumber: string
  sourceWarehouseId: string
  sourceWarehouseName: string | null
  destinationWarehouseId: string
  destinationWarehouseName: string | null
  status: 'DRAFT' | 'SHIPPED' | 'RECEIVED' | 'CANCELLED' | string
  notes: string | null
  createdAt: string
  shippedAt: string | null
  receivedAt: string | null
  lines: TransferOrderLine[]
}

export type TransferOrderPage = {
  content: TransferOrder[]
  page: number
  size: number
  totalElements: number
  totalPages: number
  last: boolean
}

export type CreateTransferOrderRequest = {
  sourceWarehouseId: string
  destinationWarehouseId: string
  notes?: string
  lines: {
    itemId: string
    requestedQuantity: number
    batchNumber?: string
  }[]
}

export type TransitDispatch = {
  id: string
  transferOrderId: string
  transferOrderNumber: string
  vehicleNumber: string
  driverName?: string
  driverPhone?: string
  status: 'DISPATCHED' | 'IN_TRANSIT' | 'DELIVERED' | 'RECEIVED' | string
  dispatchedAt: string
  expectedDeliveryDate?: string | null
  lastPingAt?: string | null
  currentLocationName?: string | null
}

export async function listTransferOrders(pageOrOptions: number | { page?: number; size?: number } = 0) {
  const page = typeof pageOrOptions === 'number' ? pageOrOptions : (pageOrOptions.page ?? 0)
  const size = typeof pageOrOptions === 'object' && pageOrOptions.size ? pageOrOptions.size : 25
  return apiFetch<TransferOrderPage>(`/api/v1/transfer-orders?page=${page}&size=${size}&sort=createdAt,desc`)
}

export async function getTransferOrder(id: string) {
  return apiFetch<TransferOrder>(`/api/v1/transfer-orders/${id}`)
}

export async function createTransferOrder(req: CreateTransferOrderRequest) {
  return apiFetch<TransferOrder>('/api/v1/transfer-orders', {
    method: 'POST',
    body: req,
  })
}

export async function shipTransferOrder(id: string, payload?: { vehicleNumber?: string; driverName?: string; driverPhone?: string; expectedDeliveryDate?: string }) {
  return apiFetch<TransferOrder>(`/api/v1/transfer-orders/${id}/ship`, {
    method: 'POST',
    body: payload,
  })
}

export async function receiveTransferOrder(id: string, payload?: { destinationDiscrepancies?: string; notes?: string; receivedLines?: { lineId: string; receivedQuantity: number; notes?: string }[] }) {
  return apiFetch<TransferOrder>(`/api/v1/transfer-orders/${id}/receive`, {
    method: 'POST',
    body: payload,
  })
}

export async function cancelTransferOrder(id: string) {
  return apiFetch<void>(`/api/v1/transfer-orders/${id}/cancel`, {
    method: 'POST',
  })
}

export async function listTransitDispatches(status?: string) {
  const q = status ? `?status=${status}` : ''
  return apiFetch<TransitDispatch[]>(`/api/v1/inventory/transfers/transit${q}`)
}

export async function createTransitDispatch(req: { transferOrderId: string; vehicleNumber: string; driverName?: string; driverPhone?: string; expectedDeliveryDate?: string }) {
  return apiFetch<TransitDispatch>('/api/v1/inventory/transfers/transit', {
    method: 'POST',
    body: req,
  })
}

export async function pingTransitTelemetry(
  dispatchIdOrReq: string | { transitDispatchId?: string; dispatchId?: string; locationName: string; notes?: string; statusNotes?: string; latitude?: number; longitude?: number },
  req?: { locationName: string; notes?: string; statusNotes?: string; latitude?: number; longitude?: number }
) {
  const id = typeof dispatchIdOrReq === 'string'
    ? dispatchIdOrReq
    : (dispatchIdOrReq.transitDispatchId || dispatchIdOrReq.dispatchId || 'default')
  const payload = typeof dispatchIdOrReq === 'object' ? dispatchIdOrReq : req
  return apiFetch<TransitDispatch>(`/api/v1/inventory/transfers/transit/${id}/ping`, {
    method: 'POST',
    body: payload,
  })
}

