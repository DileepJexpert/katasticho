import { apiFetch } from '@/api/client/api-client'

type NumberLike = number | string

/** Read projection returned by the frozen StockCountController contract. */
export type StockCountLine = {
  id: string
  itemId: string
  itemName: string | null
  sku: string | null
  expectedQuantity: NumberLike
  countedQuantity: NumberLike
  variance: NumberLike
  notes: string | null
}

export type StockCount = {
  id: string
  countNumber: string
  warehouseId: string
  warehouseName: string | null
  countDate: string
  status: 'DRAFT' | 'POSTED' | 'CANCELLED' | string
  notes: string | null
  postedAt: string | null
  lineCount: number
  varianceCount: number
  lines: StockCountLine[]
  createdAt: string
}

export type StockCountPage = {
  content: StockCount[]
  page: number
  size: number
  totalElements: number
  totalPages: number
  last: boolean
}

export type CreateStockCountRequest = {
  warehouseId: string
  countDate?: string
  notes?: string
  lines: Array<{
    itemId: string
    countedQuantity: number
    notes?: string
  }>
}

export function listStockCounts(page = 0) {
  return apiFetch<StockCountPage>(`/api/v1/stock-counts?page=${page}&size=25&sort=countDate,desc`)
}

export function getStockCount(id: string) {
  return apiFetch<StockCount>(`/api/v1/stock-counts/${id}`)
}

export function createStockCount(request: CreateStockCountRequest) {
  return apiFetch<StockCount>('/api/v1/stock-counts', {
    method: 'POST',
    body: request,
  })
}

export function postStockCount(id: string) {
  return apiFetch<StockCount>(`/api/v1/stock-counts/${id}/post`, {
    method: 'POST',
  })
}

export function cancelStockCount(id: string) {
  return apiFetch<void>(`/api/v1/stock-counts/${id}/cancel`, {
    method: 'POST',
  })
}
