import { apiFetch } from '@/api/client/api-client'

export type StockReceiptLine = {
  id: string
  lineNumber: number
  itemId: string
  itemName?: string | null
  itemSku: string | null
  description: string | null
  hsnCode: string | null
  quantity: number | string | null
  unitOfMeasure: string | null
  unitPrice: number | string | null
  discountPercent: number | string | null
  taxableAmount: number | string | null
  gstRate: number | string | null
  taxAmount: number | string | null
  lineTotal: number | string | null
  landedUnitCost: number | string | null
  landedCost?: number | string | null
  batchNumber: string | null
  expiryDate: string | null
  manufacturingDate: string | null
  stockMovementId: string | null
  purchaseOrderLineId: string | null
}

export type StockReceipt = {
  id: string
  receiptNumber: string
  receiptDate: string | null
  warehouseId: string
  warehouseName: string
  supplierId: string
  supplierName: string
  supplierGstin: string | null
  supplierInvoiceNo: string | null
  supplierInvoiceDate: string | null
  status: string
  subtotal: number | string | null
  taxAmount: number | string | null
  totalAmount: number | string | null
  freightAmount: number | string | null
  dutyAmount: number | string | null
  insuranceAmount: number | string | null
  otherCharges: number | string | null
  currency: string | null
  notes: string | null
  purchaseOrderId: string | null
  lines: StockReceiptLine[]
  receivedAt: string | null
  cancelledAt: string | null
  cancelReason: string | null
  createdAt: string | null
}

export type StockReceiptPage = {
  content: StockReceipt[]
  page: number
  size: number
  totalElements: number
  totalPages: number
  last: boolean
}

type ListStockReceiptsOptions = {
  supplierId?: string
  page: number
}

export async function listStockReceipts({ supplierId, page }: ListStockReceiptsOptions) {
  const params = new URLSearchParams({ page: String(page), size: '25', sort: 'receiptDate,desc' })
  if (supplierId) {
    params.set('supplierId', supplierId)
  }
  return apiFetch<StockReceiptPage>(`/api/v1/stock-receipts?${params.toString()}`)
}

export function getStockReceipt(id: string) {
  return apiFetch<StockReceipt>(`/api/v1/stock-receipts/${id}`)
}

export function receiveStockReceipt(id: string) {
  return apiFetch<StockReceipt>(`/api/v1/stock-receipts/${id}/receive`, { method: 'POST' })
}

export function cancelStockReceipt(id: string, reason?: string) {
  return apiFetch<StockReceipt>(`/api/v1/stock-receipts/${id}/cancel`, {
    method: 'POST',
    body: JSON.stringify({ reason: reason || 'Cancelled' }),
  })
}

export type CreateStockReceiptLineRequest = {
  itemId: string
  description?: string
  hsnCode?: string
  quantity: number
  unitOfMeasure?: string
  unitPrice: number
  discountPercent?: number
  gstRate?: number
  batchNumber?: string
  expiryDate?: string
  manufacturingDate?: string
  purchaseOrderLineId?: string
}

export type CreateStockReceiptRequest = {
  supplierId: string
  warehouseId?: string
  receiptDate: string
  supplierInvoiceNo?: string
  supplierInvoiceDate?: string
  notes?: string
  freightAmount?: number
  dutyAmount?: number
  insuranceAmount?: number
  otherCharges?: number
  purchaseOrderId?: string
  lines: CreateStockReceiptLineRequest[]
}

export function createStockReceipt(req: CreateStockReceiptRequest) {
  return apiFetch<StockReceipt>('/api/v1/stock-receipts', {
    method: 'POST',
    body: req,
  })
}
