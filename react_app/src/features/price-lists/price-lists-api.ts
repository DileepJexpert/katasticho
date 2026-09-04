import { apiFetch } from '@/api/client/api-client'

type NumberLike = number | string | null

/** Read projection returned by the frozen PriceListController contract. */
export type PriceList = {
  id: string
  name: string
  description: string | null
  currency: string | null
  isDefault: boolean
  active: boolean
  createdAt: string | null
}

export type PriceListItem = {
  id: string
  priceListId: string
  itemId: string
  itemSku: string | null
  itemName: string | null
  minQuantity: NumberLike
  price: NumberLike
}

/** The customer read endpoint intentionally returns this compact projection. */
export type PriceListCustomer = {
  id: string
  displayName: string
  contactType: string | null
  phone: string | null
  defaultPriceListId: string | null
}

export function listPriceLists() {
  return apiFetch<PriceList[]>('/api/v1/price-lists')
}

export function getPriceList(id: string) {
  return apiFetch<PriceList>(`/api/v1/price-lists/${id}`)
}

export function listPriceListItems(id: string) {
  return apiFetch<PriceListItem[]>(`/api/v1/price-lists/${id}/items`)
}

export function listPriceListCustomers(id: string) {
  return apiFetch<PriceListCustomer[]>(`/api/v1/price-lists/${id}/customers`)
}
