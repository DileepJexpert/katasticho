import { apiFetch } from '@/api/client/api-client'

export interface TaxRateInfo {
  id: string
  rateCode: string
  name: string
  percentage: number
  taxType: string
  recoverable: boolean
}

export interface TaxGroupResponse {
  id: string
  name: string
  description?: string | null
  active: boolean
  rates: TaxRateInfo[]
}

export function getTaxGroups() {
  return apiFetch<TaxGroupResponse[]>('/api/v1/tax-groups')
}

export function getTaxGroup(id: string) {
  return apiFetch<TaxGroupResponse>(`/api/v1/tax-groups/${id}`)
}
