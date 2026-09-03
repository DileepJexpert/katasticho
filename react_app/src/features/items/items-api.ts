import { apiFetch } from '@/api/client/api-client'

export type Item = {
  id: string
  sku: string | null
  barcode: string | null
  name: string
  itemType: 'GOODS' | 'SERVICE' | 'COMPOSITE' | string
  hsnCode: string | null
  unitOfMeasure: string | null
  purchasePrice: number | string | null
  salePrice: number | string | null
  gstRate: number | string | null
  trackInventory: boolean
  reorderLevel: number | string | null
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

type ListItemsOptions = {
  page: number
  search: string
  negativeStockOnly: boolean
}

export async function listItems({ negativeStockOnly, page, search }: ListItemsOptions) {
  const params = new URLSearchParams({ page: String(page), size: '25', sort: 'name,asc' })
  if (search.trim() && !negativeStockOnly) params.set('search', search.trim())
  if (negativeStockOnly) params.set('negativeStockOnly', 'true')
  return apiFetch<ItemPage>(`/api/v1/items?${params.toString()}`)
}

export async function getNegativeStockCount() {
  const response = await apiFetch<{ count: number | string }>('/api/v1/items/negative-stock/count')
  return Number(response.count) || 0
}
