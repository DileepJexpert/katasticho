import { apiFetch } from '@/api/client/api-client'

export type Item = {
  id: string
  sku: string | null
  barcode: string | null
  name: string
  description?: string | null
  itemType: 'RAW_MATERIAL' | 'WORK_IN_PROGRESS' | 'FINISHED_GOOD' | 'MERCHANDISE' | 'SERVICE' | 'GOODS' | string
  hsnCode: string | null
  unitOfMeasure: string | null
  purchasePrice: number | string | null
  salePrice: number | string | null
  gstRate: number | string | null
  trackInventory: boolean
  trackBatches?: boolean
  trackSerials?: boolean
  minStockLevel?: number | string | null
  maxStockLevel?: number | string | null
  reorderLevel: number | string | null
  reorderQuantity?: number | string | null
  costingMethod?: 'FIFO' | 'WEIGHTED_AVERAGE' | string
  active: boolean
  totalOnHand: number | string | null
}

export type ItemPage = {
  content: Item[]
  page: number
  size: number
  totalElements: number
  totalPages: number
  last: boolean
}

export type StockBalance = {
  id: string
  warehouseId: string
  warehouseName: string
  warehouseCode?: string
  itemId: string
  itemName: string
  currentBalance: number | string
  allocatedQuantity?: number | string
  availableQuantity?: number | string
  reorderLevel?: number | string
}

export type StockMovement = {
  id: string
  movementDate: string
  movementType: 'OPENING_BALANCE' | 'PURCHASE' | 'SALE' | 'TRANSFER_IN' | 'TRANSFER_OUT' | 'ADJUSTMENT' | 'SCRAP' | 'WORK_ORDER_ISSUE' | 'WORK_ORDER_RECEIPT' | string
  quantity: number | string
  unitCost: number | string | null
  totalCost: number | string | null
  referenceType: string | null
  referenceId: string | null
  referenceNumber?: string | null
  notes: string | null
  createdAt: string
}

export type StockBatch = {
  id: string
  batchNumber: string
  mfgDate: string | null
  expiryDate: string | null
  mrp: number | string | null
  purchaseRate: number | string | null
  salePrice: number | string | null
  currentBalance?: number | string
  quantityAvailable?: number | string
  isExpired?: boolean
  isNearExpiry?: boolean
}

export type SerialNumber = {
  id: string
  serialNumber: string
  itemId: string
  warehouseId: string | null
  status: 'AVAILABLE' | 'RESERVED' | 'SOLD' | 'DEFECTIVE' | string
  warrantyEndDate: string | null
  receivedAt: string | null
  soldAt: string | null
}

export type PackagingBarcode = {
  id: string
  itemId: string
  packagingLevel: 'EACH' | 'INNER_PACK' | 'MASTER_CARTON' | 'PALLET' | string
  barcode: string
  conversionFactor: number | string
  grossWeightKg?: number | string | null
  dimensionsCm?: string | null
  isDefault: boolean
}

export type AtpResult = {
  itemId: string
  warehouseId: string
  onHandQuantity: number | string
  reservedQuantity: number | string
  inboundPoQuantity: number | string
  netAvailableQuantity: number | string
  requestedQuantity: number | string
  isFulfillable: boolean
  earliestFulfillmentDate?: string | null
}

export type ShortbookItem = {
  itemId: string
  itemSku: string
  itemName: string
  totalOnHand: number | string
  reorderLevel: number | string
  reorderQuantity: number | string
  deficitQuantity: number | string
  unitOfMeasure: string
  purchasePrice: number | string
  estimatedCost: number | string
  primarySupplierName?: string | null
}

export type BatchTraceRecord = {
  id: string
  batchId: string
  batchNumber: string
  step: string
  sourceType: string
  sourceId: string
  sourceNumber?: string
  targetType: string
  targetId: string
  targetNumber?: string
  quantity: number | string
  timestamp: string
  contactName?: string
  notes?: string
}

export type BatchRecallReport = {
  rmBatchId: string
  rmBatchNumber: string
  finishedGoodsBatches: {
    fgBatchId: string
    fgBatchNumber: string
    workOrderId: string
    quantityProduced: number | string
  }[]
  customerShipments: {
    invoiceId: string
    invoiceNumber: string
    invoiceDate: string
    customerName: string
    customerPhone?: string
    customerEmail?: string
    quantityShipped: number | string
    deliveryChallanNumber?: string
  }[]
}

type ListItemsOptions = {
  page?: number
  search?: string
  negativeStockOnly?: boolean
  activeOnly?: boolean
}

export async function listItems({ negativeStockOnly = false, activeOnly = false, page = 0, search = '' }: ListItemsOptions = {}) {
  const params = new URLSearchParams({ page: String(page), size: '25', sort: 'name,asc' })
  if (search.trim() && !negativeStockOnly) params.set('search', search.trim())
  if (negativeStockOnly) params.set('negativeStockOnly', 'true')
  if (activeOnly) params.set('activeOnly', 'true')
  return apiFetch<ItemPage>(`/api/v1/items?${params.toString()}`)
}

export async function getItem(id: string) {
  return apiFetch<Item>(`/api/v1/items/${id}`)
}

export type CreateItemRequest = {
  sku?: string
  barcode?: string
  name: string
  description?: string
  itemType?: string
  hsnCode?: string
  unitOfMeasure?: string
  purchasePrice?: number
  salePrice?: number
  gstRate?: number
  trackInventory?: boolean
  trackBatches?: boolean
  trackSerials?: boolean
  minStockLevel?: number
  maxStockLevel?: number
  reorderLevel?: number
  reorderQuantity?: number
  costingMethod?: string
}

export async function createItem(req: CreateItemRequest) {
  return apiFetch<Item>('/api/v1/items', {
    method: 'POST',
    body: req,
  })
}

export async function updateItem(id: string, req: CreateItemRequest) {
  return apiFetch<Item>(`/api/v1/items/${id}`, {
    method: 'PUT',
    body: req,
  })
}

export async function deleteItem(id: string) {
  return apiFetch<void>(`/api/v1/items/${id}`, {
    method: 'DELETE',
  })
}

export async function getNegativeStockCount() {
  const response = await apiFetch<{ count: number | string }>('/api/v1/items/negative-stock/count')
  return Number(response.count) || 0
}

export async function getItemBalances(itemId: string) {
  return apiFetch<StockBalance[]>(`/api/v1/stock/items/${itemId}/balances`)
}

export async function getItemMovements(itemId: string, page = 0) {
  return apiFetch<StockMovement[]>(`/api/v1/stock/items/${itemId}/movements?page=${page}&size=50`)
}

export type StockAdjustmentRequest = {
  itemId: string
  warehouseId: string
  quantityDelta: number
  unitCost?: number
  reason: string
  batchNumber?: string
  expiryDate?: string
}

export async function adjustStock(req: StockAdjustmentRequest) {
  return apiFetch<StockMovement>('/api/v1/stock/adjust', {
    method: 'POST',
    body: req,
  })
}

export async function reverseStockMovement(id: string, reason?: string) {
  return apiFetch<StockMovement>(`/api/v1/stock/movements/${id}/reverse`, {
    method: 'POST',
    body: { reason },
  })
}

export async function getItemBatches(itemId: string) {
  return apiFetch<StockBatch[]>(`/api/v1/batches/item/${itemId}`)
}

export async function getItemAvailableBatches(itemId: string, warehouseId?: string) {
  const q = warehouseId ? `?warehouseId=${warehouseId}` : ''
  return apiFetch<StockBatch[]>(`/api/v1/batches/item/${itemId}/available${q}`)
}

export async function getAvailableSerials(itemId: string, warehouseId?: string) {
  const q = warehouseId ? `&warehouseId=${warehouseId}` : ''
  return apiFetch<SerialNumber[]>(`/api/v1/serial-numbers/available?itemId=${itemId}${q}`)
}

export async function receiveSerials(req: { itemId: string; warehouseId?: string; batchId?: string; serials: string[] }) {
  return apiFetch<SerialNumber[]>('/api/v1/serial-numbers/receive', {
    method: 'POST',
    body: req,
  })
}

export async function markSerialDamaged(id: string, notes?: string) {
  return apiFetch<SerialNumber>(`/api/v1/serial-numbers/${id}/damage`, {
    method: 'POST',
    body: { notes },
  })
}

export async function listPackagingBarcodes(itemId: string) {
  return apiFetch<PackagingBarcode[]>(`/api/v1/inventory/packaging-barcodes/items/${itemId}`)
}

export async function addPackagingBarcode(itemId: string, req: Partial<PackagingBarcode>) {
  return apiFetch<PackagingBarcode>(`/api/v1/inventory/packaging-barcodes/items/${itemId}`, {
    method: 'POST',
    body: req,
  })
}

export async function deletePackagingBarcode(id: string) {
  return apiFetch<void>(`/api/v1/inventory/packaging-barcodes/${id}`, {
    method: 'DELETE',
  })
}

export async function computeAtp(itemId: string, warehouseId: string, qty = 0) {
  return apiFetch<AtpResult>(`/api/v1/inventory/atp?itemId=${itemId}&warehouseId=${warehouseId}&qty=${qty}`)
}

export async function getShortbook() {
  return apiFetch<ShortbookItem[]>('/api/v1/stock/shortbook')
}

export async function getBatchTraceForward(batchId: string) {
  return apiFetch<BatchTraceRecord[]>(`/api/v1/inventory/batch-trace/forward/${batchId}`)
}

export async function getBatchTraceBackward(batchId: string) {
  return apiFetch<BatchTraceRecord[]>(`/api/v1/inventory/batch-trace/backward/${batchId}`)
}

export async function getBatchRecallReport(rmBatchId: string) {
  return apiFetch<BatchRecallReport>(`/api/v1/inventory/batch-trace/recall/${rmBatchId}`)
}