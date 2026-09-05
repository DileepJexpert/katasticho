import { apiFetch } from '@/api/client/api-client'

export type SchemeType = 'BUY_X_GET_Y' | 'HALF_FULL_SCHEME' | 'PERCENT_DISCOUNT' | 'SPECIAL_NET_RATE'
export const schemeLabels: Record<SchemeType, string> = {
  BUY_X_GET_Y: 'Buy X, get Y free', HALF_FULL_SCHEME: 'Half and full scheme',
  PERCENT_DISCOUNT: 'Percentage discount', SPECIAL_NET_RATE: 'Special net rate',
}
export type SchemeRequest = {
  name: string
  schemeType: SchemeType
  itemId: string | null
  buyQuantity: number | null
  freeQuantity: number | null
  discountPercent: number | null
  minOrderQuantity: number
  validFrom: string | null
  validTo: string | null
  supplierId: string | null
  active: boolean
  allowHalfScheme: boolean
  halfSchemeMinQty: number | null
  companySubsidyPercent: number
  specialNetRate: number | null
  maxFreeQuantityCap: number | null
}
export type Scheme = SchemeRequest & {
  id: string; itemName: string | null; supplierName: string | null; createdAt: string | null
}
export type SchemeEvaluationRequest = { itemId: string; quantity: number; unitPrice: number; schemeId: string | null }
export type SchemeCalculation = {
  schemeId: string | null; schemeName: string | null; schemeType: string
  orderedQuantity: number; freeQuantity: number; discountPercent: number; discountAmount: number
  baseUnitPrice: number; effectiveUnitPrice: number; totalLineAmount: number
  companyFundedAmount: number; distributorFundedAmount: number
  isHalfSchemeApplied: boolean; explanation: string
}
export function listSchemes() { return apiFetch<Scheme[]>('/api/v1/schemes') }
export function createScheme(request: SchemeRequest) { return apiFetch<Scheme>('/api/v1/schemes', { method: 'POST', body: request }) }
export function updateScheme(id: string, request: SchemeRequest) { return apiFetch<Scheme>(`/api/v1/schemes/${id}`, { method: 'PUT', body: request }) }
export function deleteScheme(id: string) { return apiFetch<void>(`/api/v1/schemes/${id}`, { method: 'DELETE' }) }
export function listApplicableSchemes(itemId: string, quantity: number) {
  const params = new URLSearchParams({ itemId, quantity: String(quantity) })
  return apiFetch<Scheme[]>(`/api/v1/schemes/applicable?${params}`)
}
export function evaluateScheme(request: SchemeEvaluationRequest) {
  return apiFetch<SchemeCalculation>('/api/v1/schemes/evaluate', { method: 'POST', body: request })
}

export function validateScheme(request: SchemeRequest): string | null {
  if (!request.name.trim()) return 'Enter a scheme name.'
  if (!(request.schemeType in schemeLabels)) return 'Choose a supported scheme type.'
  if (request.validFrom && request.validTo && request.validFrom > request.validTo) return 'The end date must be on or after the start date.'
  const numbers = [request.buyQuantity, request.freeQuantity, request.discountPercent, request.minOrderQuantity, request.halfSchemeMinQty, request.companySubsidyPercent, request.specialNetRate, request.maxFreeQuantityCap]
  if (numbers.some((value) => value !== null && (!Number.isFinite(value) || value < 0))) return 'Quantities, rates, and percentages must be finite values of zero or more.'
  if (request.companySubsidyPercent > 100 || (request.discountPercent ?? 0) > 100) return 'Percentages must be between zero and 100.'
  if (['BUY_X_GET_Y', 'HALF_FULL_SCHEME'].includes(request.schemeType) && (!(Number(request.buyQuantity) > 0) || !(Number(request.freeQuantity) > 0))) return 'Enter positive buy and free quantities.'
  if (request.schemeType === 'PERCENT_DISCOUNT' && request.discountPercent === null) return 'Enter a discount percentage.'
  if (request.schemeType === 'SPECIAL_NET_RATE' && request.specialNetRate === null) return 'Enter the special net rate.'
  return null
}
