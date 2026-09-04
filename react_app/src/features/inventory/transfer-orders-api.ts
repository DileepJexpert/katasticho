import { apiFetch } from '@/api/client/api-client'

export interface TransferOrderLine {
  id?: string
  itemId: string
  itemName?: string
  sku?: string
  batchId?: string | null
  batchNumber?: string | null
  quantity: number
  receivedQuantity?: number
  notes?: string | null
}

export interface TransferOrder {
  id: string
  transferNumber: string
  fromWarehouseId: string
  fromWarehouseName: string
  toWarehouseId: string
  toWarehouseName: string
  transferDate: string
  status: 'DRAFT' | 'SHIPPED' | 'RECEIVED' | 'CANCELLED' | string
  notes?: string | null
  shippedAt?: string | null
  receivedAt?: string | null
  lineCount: number
  lines?: TransferOrderLine[]
  createdAt: string
}

export interface PagedTransferOrders {
  content: TransferOrder[]
  totalElements: number
  totalPages: number
  pageNumber: number
  pageSize: number
}

export interface CreateTransferOrderRequest {
  fromWarehouseId: string
  toWarehouseId: string
  transferDate?: string
  notes?: string
  lines: {
    itemId: string
    batchId?: string | null
    quantity: number
    notes?: string
  }[]
}

export interface WarehouseOption {
  id: string
  name: string
  code: string
  isDefault?: boolean
}

export interface ItemCatalogOption {
  id: string
  name: string
  sku: string
  unit?: string
}

export async function listTransferOrders(page = 0, size = 50): Promise<PagedTransferOrders> {
  return apiFetch<PagedTransferOrders>(`/api/v1/transfer-orders?page=${page}&size=${size}`)
}

export async function getTransferOrder(id: string): Promise<TransferOrder> {
  return apiFetch<TransferOrder>(`/api/v1/transfer-orders/${id}`)
}

export async function createTransferOrder(request: CreateTransferOrderRequest): Promise<TransferOrder> {
  return apiFetch<TransferOrder>('/api/v1/transfer-orders', {
    method: 'POST',
    body: request,
  })
}

export async function shipTransferOrder(id: string): Promise<TransferOrder> {
  return apiFetch<TransferOrder>(`/api/v1/transfer-orders/${id}/ship`, {
    method: 'POST',
  })
}

export async function receiveTransferOrder(id: string): Promise<TransferOrder> {
  return apiFetch<TransferOrder>(`/api/v1/transfer-orders/${id}/receive`, {
    method: 'POST',
  })
}

export async function cancelTransferOrder(id: string): Promise<void> {
  return apiFetch<void>(`/api/v1/transfer-orders/${id}/cancel`, {
    method: 'POST',
  })
}

export async function listWarehouses(): Promise<WarehouseOption[]> {
  return apiFetch<WarehouseOption[]>('/api/v1/warehouses')
}

export async function listCatalogItems(): Promise<ItemCatalogOption[]> {
  interface PagedItems {
    content: ItemCatalogOption[]
  }
  const res = await apiFetch<PagedItems>('/api/v1/items?size=100')
  return res.content ?? []
}
