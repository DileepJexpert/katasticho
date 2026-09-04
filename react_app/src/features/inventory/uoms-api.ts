import { apiFetch } from '@/api/client/api-client'

export type UomCategory = 'COUNT' | 'WEIGHT' | 'VOLUME' | 'LENGTH' | 'AREA' | 'TIME'

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
