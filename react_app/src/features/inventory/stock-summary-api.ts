import { apiFetch } from '@/api/client/api-client'

export interface StockSummaryItem {
  itemId: string
  itemName: string
  sku: string
  unit: string
  quantityOnHand: number
  purchasePrice: number
  inventoryValue: number
  reorderLevel: number
  status: string
  averageCost?: number
  lastMovementAt?: string | null
}

export interface StockSummaryReport {
  asOfDate: string
  totalInventoryValue: number
  itemCount: number
  lowStockCount: number
  outOfStockCount: number
  items: StockSummaryItem[]
}

export interface LowStockAlertItem {
  itemId: string
  itemName: string
  sku: string
  currentStock: number
  reorderLevel: number
  reorderQuantity: number
  deficitQty: number
  supplierId?: string | null
  supplierName?: string | null
  estimatedCost?: number | null
}

export interface LowStockAlertReport {
  generatedAt: string
  itemCount: number
  estimatedPurchaseCost: number
  items: LowStockAlertItem[]
}

export interface FifoSummaryMetric {
  key: string
  label: string
  value: number | string
  format: string
}

export interface FifoColumnDef {
  key: string
  label: string
  type: string
}

export interface FifoValuationReport {
  reportKey: string
  title: string
  description: string
  startDate?: string | null
  endDate?: string | null
  currency: string
  metrics: FifoSummaryMetric[]
  columns: FifoColumnDef[]
  rows: Record<string, unknown>[]
}

export interface WarehouseOption {
  id: string
  name: string
  code: string
  isDefault?: boolean
}

export async function getStockSummary(): Promise<StockSummaryReport> {
  return apiFetch<StockSummaryReport>('/api/v1/inventory-reports/stock-summary')
}

export async function getLowStockAlert(): Promise<LowStockAlertReport> {
  return apiFetch<LowStockAlertReport>('/api/v1/inventory-reports/low-stock-alert')
}

export async function getFifoValuation(): Promise<FifoValuationReport> {
  return apiFetch<FifoValuationReport>('/api/v1/reports/fifo-valuation')
}

export function getStockValuation() {
  return apiFetch<FifoValuationReport>('/api/v1/reports/stock-summary')
}

export async function listWarehouses(): Promise<WarehouseOption[]> {
  return apiFetch<WarehouseOption[]>('/api/v1/warehouses')
}
