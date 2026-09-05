import { apiFetch } from '@/api/client/api-client'
import type { PurchaseBill } from '@/features/bills/bills-api'
import type { StockReceipt } from '@/features/stock-receipts/stock-receipts-api'

export type PurchaseOrderLine = {
  id: string
  poId: string
  lineNumber?: number | string | null
  itemId: string
  itemName: string
  description: string | null
  quantity: number | string | null
  receivedQuantity: number | string | null
  unitPrice: number | string | null
  taxGroupId: string | null
  lineTotal: number | string | null
}

export type PurchaseOrder = {
  id: string
  orgId: string
  supplierId: string
  supplierName: string
  poNumber: string
  status: string
  orderDate: string | null
  expectedDeliveryDate: string | null
  notes: string | null
  warehouseId: string | null
  totalAmount: number | string | null
  lines: PurchaseOrderLine[]
  createdAt: string | null
}

export type CreatePurchaseOrderRequest = {
  supplierId: string
  orderDate: string
  expectedDeliveryDate?: string
  warehouseId?: string
  notes?: string
  lines: {
    itemId: string
    quantity: number
    unitPrice?: number
    description?: string
    taxGroupId?: string
  }[]
}

export async function listPurchaseOrders() {
  return apiFetch<PurchaseOrder[]>('/api/v1/purchase-orders')
}

export function getPurchaseOrder(id: string) {
  return apiFetch<PurchaseOrder>(`/api/v1/purchase-orders/${id}`)
}

export function createPurchaseOrder(req: CreatePurchaseOrderRequest) {
  return apiFetch<PurchaseOrder>('/api/v1/purchase-orders', {
    method: 'POST',
    body: JSON.stringify(req),
  })
}

export function sendPurchaseOrder(id: string) {
  return apiFetch<PurchaseOrder>(`/api/v1/purchase-orders/${id}/send`, { method: 'POST' })
}

export function cancelPurchaseOrder(id: string) {
  return apiFetch<PurchaseOrder>(`/api/v1/purchase-orders/${id}/cancel`, { method: 'POST' })
}

export function createGrnFromPo(id: string) {
  return apiFetch<StockReceipt>(`/api/v1/purchase-orders/${id}/create-grn`, { method: 'POST' })
}

export function createBillFromPo(id: string) {
  return apiFetch<PurchaseBill>(`/api/v1/purchase-orders/${id}/create-bill`, { method: 'POST' })
}
