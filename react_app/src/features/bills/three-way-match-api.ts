import { apiFetch } from '@/api/client/api-client'

export type BillMatchResultLine = {
  id: string
  orgId: string
  billId: string
  billLineId: string
  poLineId: string | null
  grnLineId: string | null
  itemId: string
  billedQty: number | string
  receivedQty: number | string | null
  orderedQty: number | string | null
  billUnitPrice: number | string
  poUnitPrice: number | string | null
  qtyVariance: number | string | null
  priceVariance: number | string | null
  amountVariance: number | string | null
  status: 'MATCHED' | 'QTY_OVER' | 'PRICE_HIKE' | 'AMOUNT_MISMATCH' | 'NO_PO' | 'NO_GRN' | 'BYPASSED' | string
  createdAt: string
}

export type MatchSnapshot = {
  billId: string
  billNumber: string
  status: string | null
  matchedAt: string | null
  overriddenBy: string | null
  overrideReason: string | null
  lines: BillMatchResultLine[]
}

export type ThreeWayMatchSettings = {
  required: string
  qty_tolerance_pct: string
  price_tolerance_abs: string
  price_tolerance_pct: string
  bypass_threshold: string
}

export type MatchExceptionsPage = {
  content: BillMatchResultLine[]
  pageable: unknown
  totalElements: number
  totalPages: number
  number: number
  size: number
  last: boolean
}

export function runThreeWayMatch(billId: string) {
  return apiFetch<string>(`/api/v1/ap/three-way-match/${billId}/run`, {
    method: 'POST',
  })
}

export function getThreeWayMatch(billId: string) {
  return apiFetch<MatchSnapshot>(`/api/v1/ap/three-way-match/${billId}`)
}

export function listThreeWayMatchExceptions(page = 0, size = 20) {
  const params = new URLSearchParams({ page: String(page), size: String(size) })
  return apiFetch<MatchExceptionsPage>(`/api/v1/ap/three-way-match/exceptions?${params.toString()}`)
}

export function overrideThreeWayMatch(billId: string, reason: string) {
  return apiFetch<void>(`/api/v1/ap/three-way-match/${billId}/override`, {
    method: 'POST',
    body: JSON.stringify({ reason }),
  })
}

export function getThreeWayMatchSettings() {
  return apiFetch<ThreeWayMatchSettings>('/api/v1/ap/three-way-match/settings')
}

export function updateThreeWayMatchSettings(settings: Partial<ThreeWayMatchSettings>) {
  return apiFetch<void>('/api/v1/ap/three-way-match/settings', {
    method: 'PUT',
    body: JSON.stringify(settings),
  })
}