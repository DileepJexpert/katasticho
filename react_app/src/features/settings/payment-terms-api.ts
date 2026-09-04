import { apiFetch } from '@/api/client/api-client'

type NumberLike = number | string | null

/** Read projection returned by the frozen PaymentTermController contract. */
export type PaymentTermLine = {
  id: string
  seq: number
  valueType: 'PERCENT' | 'BALANCE' | string
  value: NumberLike
  daysOffset: number
}

export type PaymentTerm = {
  id: string
  name: string
  description: string | null
  isDefault: boolean
  active: boolean
  lines: PaymentTermLine[]
}

export function listPaymentTerms(activeOnly = false) {
  const params = new URLSearchParams({ activeOnly: String(activeOnly) })
  return apiFetch<PaymentTerm[]>(`/api/v1/payment-terms?${params.toString()}`)
}
