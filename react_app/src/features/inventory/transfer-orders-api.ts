import { apiFetch } from '@/api/client/api-client'

type NumberLike = number | string

/** Transfer-order values returned by the frozen inventory transfer contract. */
export type TransferOrderStatus = 'DRAFT' | 'IN_TRANSIT' | 'RECEIVED' | 'CANCELLED'

export type TransferOrderLine = {
  id: string
  itemId: string
  itemName: string | null
  sku: string | null
  batchId: string | null
  batchNumber: string | null
  quantity: NumberLike
  receivedQuantity: NumberLike
  notes: string | null
}

export type TransferOrder = {
  id: string
  transferNumber: string
  fromWarehouseId: string
  fromWarehouseName: string | null
  toWarehouseId: string
  toWarehouseName: string | null
  transferDate: string
  status: TransferOrderStatus
  notes: string | null
  shippedAt: string | null
  receivedAt: string | null
  lineCount: number
  lines: TransferOrderLine[]
  createdAt: string
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
  fromWarehouseId: string
  toWarehouseId: string
  transferDate?: string
  notes?: string
  lines: Array<{
    itemId: string
    quantity: number
    notes?: string
  }>
}

export function listTransferOrders(page = 0, size = 25) {
  const params = new URLSearchParams({
    page: String(page),
    size: String(size),
    sort: 'transferDate,desc',
  })
  return apiFetch<TransferOrderPage>(`/api/v1/transfer-orders?${params.toString()}`)
}

export function getTransferOrder(id: string) {
  return apiFetch<TransferOrder>(`/api/v1/transfer-orders/${id}`)
}

export function createTransferOrder(request: CreateTransferOrderRequest) {
  return apiFetch<TransferOrder>('/api/v1/transfer-orders', {
    method: 'POST',
    body: request,
  })
}

export function shipTransferOrder(id: string) {
  return apiFetch<TransferOrder>(`/api/v1/transfer-orders/${id}/ship`, {
    method: 'POST',
  })
}

export function receiveTransferOrder(id: string) {
  return apiFetch<TransferOrder>(`/api/v1/transfer-orders/${id}/receive`, {
    method: 'POST',
  })
}

export function cancelTransferOrder(id: string) {
  return apiFetch<void>(`/api/v1/transfer-orders/${id}/cancel`, {
    method: 'POST',
  })
}
