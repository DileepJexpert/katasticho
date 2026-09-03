import { apiFetch } from '@/api/client/api-client'

export type PriceListItem = {
  id: string
  itemId: string
  itemName: string
  itemSku: string | null
  customPrice: number | string | null
  discountPercentage: number | string | null
  markupPercentage?: number | string | null
  minQuantity?: number | string | null
}

export type PriceListContact = {
  id: string
  contactId: string
  contactName: string
  email?: string | null
  phone?: string | null
}

export type PriceList = {
  id: string
  code: string
  name: string
  description: string | null
  currency: string
  schemeType: 'FIXED_PRICE' | 'PERCENTAGE_DISCOUNT' | 'MARKUP' | string
  isDefault: boolean
  active: boolean
  itemCount: number
}

export type CreatePriceListRequest = {
  code: string
  name: string
  description?: string
  currency?: string
  schemeType?: string
  isDefault?: boolean
  items?: {
    itemId: string
    customPrice?: number
    discountPercentage?: number
    minQuantity?: number
  }[]
}

export async function listPriceLists() {
  return apiFetch<PriceList[]>('/api/v1/price-lists')
}

export async function getPriceList(id: string) {
  return apiFetch<PriceList>(`/api/v1/price-lists/${id}`)
}

export async function createPriceList(req: CreatePriceListRequest) {
  return apiFetch<PriceList>('/api/v1/price-lists', {
    method: 'POST',
    body: req,
  })
}

export async function updatePriceList(id: string, req: CreatePriceListRequest) {
  return apiFetch<PriceList>(`/api/v1/price-lists/${id}`, {
    method: 'PUT',
    body: req,
  })
}

export async function deletePriceList(id: string) {
  return apiFetch<void>(`/api/v1/price-lists/${id}`, {
    method: 'DELETE',
  })
}

export async function listPriceListItems(id: string) {
  return apiFetch<PriceListItem[]>(`/api/v1/price-lists/${id}/items`)
}

export const getPriceListItems = listPriceListItems

export async function savePriceListItems(id: string, items: { itemId: string; customPrice?: number; discountPercentage?: number; minQuantity?: number }[]) {
  return apiFetch<PriceListItem[]>(`/api/v1/price-lists/${id}/items`, {
    method: 'PUT',
    body: items,
  })
}

export async function addPriceListItem(id: string, item: { itemId: string; customPrice?: number; discountPercentage?: number; minQuantity?: number }) {
  return savePriceListItems(id, [item])
}

export async function deletePriceListItem(id: string, itemId: string) {
  return apiFetch<void>(`/api/v1/price-lists/${id}/items/${itemId}`, {
    method: 'DELETE',
  })
}

export const removePriceListItem = deletePriceListItem

export async function listPriceListContacts(id: string) {
  return apiFetch<PriceListContact[]>(`/api/v1/price-lists/${id}/contacts`)
}

export const getPriceListContacts = listPriceListContacts

export async function addPriceListContact(id: string, contactId: string) {
  return apiFetch<void>(`/api/v1/price-lists/${id}/contacts`, {
    method: 'POST',
    body: { contactId },
  })
}

export async function removePriceListContact(id: string, contactId: string) {
  return apiFetch<void>(`/api/v1/price-lists/${id}/contacts/${contactId}`, {
    method: 'DELETE',
  })
}
