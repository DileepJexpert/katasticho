import { apiFetch } from '@/api/client/api-client'

type NumberLike = number | string | null

/** Item types accepted by the frozen ItemController write contract. */
export type ItemType = 'GOODS' | 'SERVICE' | 'COMPOSITE'

export type UnitPriceEntry = {
  uomAbbreviation: string
  conversionFactor: number
  customPrice?: number
}

type ItemWriteFields = {
  name: string
  description?: string
  itemType: ItemType
  category?: string
  brand?: string
  hsnCode?: string
  unitOfMeasure?: string
  purchasePrice?: number
  salePrice?: number
  mrp?: number
  gstRate?: number
  trackInventory?: boolean
  trackBatches?: boolean
  reorderLevel?: number
  reorderQuantity?: number
  barcode?: string
  manufacturer?: string
  preferredVendorId?: string
  rackLocationId?: string
  weight?: number
  weightUnit?: string
  length?: number
  width?: number
  height?: number
  dimensionUnit?: string
  drugSchedule?: string
  composition?: string
  dosageForm?: string
  packSize?: string
  storageCondition?: string
  prescriptionRequired?: boolean
  weightBasedBilling?: boolean
  revenueAccountCode?: string
  cogsAccountCode?: string
  inventoryAccountCode?: string
  purchaseUom?: string
  purchaseUomConversion?: number
  purchasePricePerUom?: number
  secondaryUnits?: UnitPriceEntry[]
}

/**
 * The existing create contract records opening stock as an auditable OPENING
 * movement. These fields intentionally do not exist on updates.
 */
export type CreateItemRequest = ItemWriteFields & {
  sku?: string
  openingStock?: number
  openingWarehouseId?: string
  openingBatchNumber?: string
  openingMfgDate?: string
  openingExpiryDate?: string
  groupId?: string
  variantAttributes?: Record<string, string>
}

/** Stock adjustments stay outside the item master update contract. */
export type UpdateItemRequest = ItemWriteFields & {
  sku: string
  active?: boolean
}

/** Read projection returned by the frozen ItemController contract. */
export type Item = {
  id: string
  sku: string | null
  barcode: string | null
  name: string
  description: string | null
  itemType: string
  category: string | null
  brand: string | null
  manufacturer: string | null
  hsnCode: string | null
  unitOfMeasure: string | null
  unit?: string | null
  purchasePrice: NumberLike
  salePrice: NumberLike
  sellingPrice?: NumberLike
  mrp: NumberLike
  gstRate: NumberLike
  defaultTaxGroupId: string | null
  taxGroupId?: string | null
  trackInventory: boolean
  trackBatches: boolean
  stockBalance?: NumberLike
  onHandStock?: NumberLike
  reorderLevel: NumberLike
  reorderQuantity: NumberLike
  preferredVendorId: string | null
  preferredVendorName: string | null
  rackLocationId: string | null
  rackLocationCode: string | null
  rackLocationName: string | null
  weight: NumberLike
  weightUnit: string | null
  length: NumberLike
  width: NumberLike
  height: NumberLike
  dimensionUnit: string | null
  drugSchedule: string | null
  composition: string | null
  dosageForm: string | null
  packSize: string | null
  storageCondition: string | null
  prescriptionRequired: boolean
  weightBasedBilling: boolean
  revenueAccountCode: string | null
  cogsAccountCode: string | null
  inventoryAccountCode: string | null
  active: boolean
  totalOnHand: NumberLike
  createdAt: string | null
  groupId: string | null
  variantAttributes: Record<string, string> | null
  groupName: string | null
  purchaseUom: string | null
  purchaseUomConversion: NumberLike
  purchasePricePerUom: NumberLike
  secondaryUnits: Array<{
    uomId: string
    uomAbbreviation: string
    uomName: string
    conversionFactor: NumberLike
    customPrice: NumberLike
  }> | null
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
  itemId: string
  itemSku: string | null
  itemName: string
  warehouseId: string
  warehouseName: string
  quantityOnHand: NumberLike
  averageCost: NumberLike
  reorderLevel: NumberLike
  lowStock: boolean
  lastMovementAt: string | null
}

export type StockMovement = {
  id: string
  itemId: string
  itemName: string
  itemSku: string | null
  warehouseId: string
  warehouseName: string
  movementDate: string
  createdAt: string
  movementType: string
  quantity: NumberLike
  unitCost: NumberLike
  totalCost: NumberLike
  referenceType: string | null
  referenceId: string | null
  referenceNumber: string | null
  reversal: boolean
  reversalOfId: string | null
  reversed: boolean
  notes: string | null
  batchId: string | null
  batchNumber: string | null
  batchExpiryDate: string | null
}

export type StockBatch = {
  id: string
  itemId: string
  batchNumber: string
  expiryDate: string | null
  manufacturingDate: string | null
  unitCost: NumberLike
  supplierId: string | null
  active: boolean
  quantityAvailable: NumberLike
}

export type PackagingBarcode = {
  id: string
  itemId: string
  itemName: string
  itemSku: string | null
  barcode: string
  packagingLevel: string
  packagingName: string | null
  conversionFactor: NumberLike
  uomName: string | null
  mrp: NumberLike
  salePrice: NumberLike
  purchasePrice: NumberLike
  isPrimary: boolean
  notes: string | null
}

export type ShortbookItem = {
  itemId: string
  itemSku: string
  itemName: string
  totalOnHand: NumberLike
  reorderLevel: NumberLike
  reorderQuantity: NumberLike
  deficitQuantity: NumberLike
  unitOfMeasure: string
  purchasePrice: NumberLike
  estimatedCost: NumberLike
  primarySupplierName?: string | null
}

export type ListItemsOptions = {
  page?: number
  size?: number | string
  search?: string
  negativeStockOnly?: boolean
  activeOnly?: boolean
}

export function listItems({ negativeStockOnly = false, activeOnly = false, page = 0, size = 25, search = '' }: ListItemsOptions = {}) {
  const params = new URLSearchParams({ page: String(page), size: String(size), sort: 'name,asc' })
  if (search.trim() && !negativeStockOnly) params.set('search', search.trim())
  if (negativeStockOnly) params.set('negativeStockOnly', 'true')
  if (activeOnly) params.set('activeOnly', 'true')
  return apiFetch<ItemPage>(`/api/v1/items?${params.toString()}`)
}

export function getItem(id: string) {
  return apiFetch<Item>(`/api/v1/items/${id}`)
}

export function createItem(request: CreateItemRequest) {
  return apiFetch<Item>('/api/v1/items', {
    method: 'POST',
    body: request,
  })
}

export function updateItem(id: string, request: UpdateItemRequest) {
  return apiFetch<Item>(`/api/v1/items/${id}`, {
    method: 'PUT',
    body: request,
  })
}

export async function getNegativeStockCount() {
  const response = await apiFetch<{ count: NumberLike }>('/api/v1/items/negative-stock/count')
  return Number(response.count) || 0
}

export function getItemBalances(itemId: string) {
  return apiFetch<StockBalance[]>(`/api/v1/stock/items/${itemId}/balances`)
}

export function getItemMovements(itemId: string, page = 0) {
  return apiFetch<StockMovement[]>(`/api/v1/stock/items/${itemId}/movements?page=${page}&size=50`)
}

export function getItemBatches(itemId: string) {
  return apiFetch<StockBatch[]>(`/api/v1/batches/item/${itemId}`)
}

export function listPackagingBarcodes(itemId: string) {
  return apiFetch<PackagingBarcode[]>(`/api/v1/inventory/packaging-barcodes/items/${itemId}`)
}

export function getShortbook() {
  return apiFetch<ShortbookItem[]>('/api/v1/stock/shortbook')
}
