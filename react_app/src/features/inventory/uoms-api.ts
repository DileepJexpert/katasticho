import { apiFetch } from '@/api/client/api-client'

export type UomCategory = 'COUNT' | 'WEIGHT' | 'VOLUME' | 'LENGTH' | 'PACKAGING'

export const UOM_CATEGORIES: UomCategory[] = ['COUNT', 'WEIGHT', 'VOLUME', 'LENGTH', 'PACKAGING']
export type UomRequest = Omit<UomResponse, 'id'>

export interface UomResponse {
  id: string
  name: string
  abbreviation: string
  category: UomCategory
  base: boolean
  active: boolean
}

export function getUoms(category?: UomCategory) {
  const query = category ? `?category=${encodeURIComponent(category)}` : ''
  return apiFetch<UomResponse[]>(`/api/v1/uoms${query}`)
}

export function getUom(id: string) {
  return apiFetch<UomResponse>(`/api/v1/uoms/${id}`)
}

export function createUom(request: UomRequest) {
  return apiFetch<UomResponse>('/api/v1/uoms', { method: 'POST', body: JSON.stringify(request) })
}

export function updateUom(id: string, request: UomRequest) {
  return apiFetch<UomResponse>(`/api/v1/uoms/${encodeURIComponent(id)}`, { method: 'PUT', body: JSON.stringify(request) })
}

export function deleteUom(id: string) {
  return apiFetch<void>(`/api/v1/uoms/${encodeURIComponent(id)}`, { method: 'DELETE' })
}
