import { apiFetch } from '@/api/client/api-client'

export type StockCountLine = {
  id: string
  itemId: string
  itemName: string
  itemSku: string | null
  batchNumber?: string | null
  systemQuantity: number | string
  countedQuantity: number | string
  discrepancyQuantity: number | string
  discrepancyValue?: number | string | null
  notes: string | null
}

export type StockCount = {
  id: string
  countNumber: string
  warehouseId: string
  warehouseName: string | null
  status: 'IN_PROGRESS' | 'POSTED' | 'CANCELLED' | string
  notes: string | null
  createdAt: string
  postedAt: string | null
  lines: StockCountLine[]
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
  notes?: string
  lines?: {
    itemId: string
    countedQuantity: number
    batchNumber?: string
    notes?: string
  }[]
}

export async function listStockCounts(page = 0) {
  return apiFetch<StockCountPage>(`/api/v1/stock-counts?page=${page}&size=25&sort=createdAt,desc`)
}

export async function getStockCount(id: string) {
  return apiFetch<StockCount>(`/api/v1/stock-counts/${id}`)
}

export async function createStockCount(req: CreateStockCountRequest) {
  return apiFetch<StockCount>('/api/v1/stock-counts', {
    method: 'POST',
    body: req,
  })
}

export async function updateStockCountLines(id: string, lines: { lineId: string; countedQuantity: number; notes?: string }[]) {
  return apiFetch<StockCount>(`/api/v1/stock-counts/${id}/lines`, {
    method: 'PUT',
    body: lines,
  })
}

export async function postStockCount(id: string) {
  return apiFetch<StockCount>(`/api/v1/stock-counts/${id}/post`, {
    method: 'POST',
  })
}

export async function cancelStockCount(id: string) {
  return apiFetch<void>(`/api/v1/stock-counts/${id}/cancel`, {
    method: 'POST',
  })
}
