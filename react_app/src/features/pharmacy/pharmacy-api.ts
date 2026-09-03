import { apiFetch } from '@/api/client/api-client'

export type DrugMaster = {
  id: string
  brandName: string
  genericName: string | null
  saltComposition: string | null
  manufacturer: string | null
  hsnCode: string | null
  gstRate: number | null
  drugSchedule: string | null
  dosageForm: string | null
  packSize: string | null
  mrp: number | null
  prescriptionRequired: boolean
}

export type SaltMaster = {
  id: string
  name: string
  category: string | null
}

export type ManufacturerMaster = {
  id: string
  name: string
  country: string | null
  website: string | null
}

export type HsnGstMaster = {
  id: string
  hsnCode: string
  description: string | null
  category: string | null
  gstRate: number | null
}

export type HsnGstRateHistory = {
  hsnCode: string
  gstRate: number | null
  cessRate: number | null
  effectiveFrom: string | null
  effectiveTo: string | null
  notificationRef: string | null
  source: string | null
  description: string | null
}

export type RackLocation = {
  id: string
  warehouseId: string
  code: string
  name: string | null
  zone: string | null
  aisle: string | null
  shelf: string | null
  bin: string | null
  active: boolean
}

export type RackLocationRequest = {
  warehouseId: string
  code: string
  name?: string
  zone?: string
  aisle?: string
  shelf?: string
  bin?: string
}

export type GenericSubstitution = {
  id: string
  drugMasterId: string
  substituteDrugMasterId: string
  substituteBrandName: string
  substituteComposition: string | null
  manufacturer: string | null
  mrp: number | null
  estimatedSavings: number | null
  reason: string | null
}

export type DrugInteraction = {
  id: string
  primarySaltId: string
  interactingSaltId: string
  severity: string
  warning: string
  recommendation: string | null
}

export type ExpiryBatch = {
  batchId: string
  itemId: string
  itemName: string
  batchNumber: string
  expiryDate: string
  quantityOnHand: number
  daysUntilExpiry: number
  urgency: string
}

export type ExpirySummary = {
  expired: number
  within7Days: number
  within30Days: number
  within90Days: number
}

// ── Drug Master Endpoints ──

export async function searchDrugs(q = '', limit = 50): Promise<DrugMaster[]> {
  const params = new URLSearchParams()
  if (q.trim()) params.set('q', q.trim())
  params.set('limit', String(limit))
  return apiFetch<DrugMaster[]>(`/api/v1/drug-master/search?${params.toString()}`)
}

export async function getDrugById(id: string): Promise<DrugMaster> {
  return apiFetch<DrugMaster>(`/api/v1/drug-master/${id}`)
}

export async function searchSalts(q = '', limit = 50): Promise<SaltMaster[]> {
  const params = new URLSearchParams()
  if (q.trim()) params.set('q', q.trim())
  params.set('limit', String(limit))
  return apiFetch<SaltMaster[]>(`/api/v1/drug-master/salts/search?${params.toString()}`)
}

// ── Pharmacy Masters Endpoints ──

export async function searchManufacturers(q = '', limit = 50): Promise<ManufacturerMaster[]> {
  const params = new URLSearchParams()
  if (q.trim()) params.set('q', q.trim())
  params.set('limit', String(limit))
  return apiFetch<ManufacturerMaster[]>(`/api/v1/pharmacy-masters/manufacturers/search?${params.toString()}`)
}

export async function searchHsn(q = '', limit = 50): Promise<HsnGstMaster[]> {
  const params = new URLSearchParams()
  if (q.trim()) params.set('q', q.trim())
  params.set('limit', String(limit))
  return apiFetch<HsnGstMaster[]>(`/api/v1/pharmacy-masters/hsn/search?${params.toString()}`)
}

export async function getHsnByCode(code: string): Promise<HsnGstMaster> {
  return apiFetch<HsnGstMaster>(`/api/v1/pharmacy-masters/hsn/${encodeURIComponent(code)}`)
}

export async function getHsnRateHistory(code: string): Promise<HsnGstRateHistory[]> {
  return apiFetch<HsnGstRateHistory[]>(`/api/v1/pharmacy-masters/hsn/${encodeURIComponent(code)}/rate-history`)
}

export async function listRackLocations(warehouseId?: string): Promise<RackLocation[]> {
  const qs = warehouseId ? `?warehouseId=${encodeURIComponent(warehouseId)}` : ''
  return apiFetch<RackLocation[]>(`/api/v1/pharmacy-masters/rack-locations${qs}`)
}

export async function createRackLocation(data: RackLocationRequest): Promise<RackLocation> {
  return apiFetch<RackLocation>('/api/v1/pharmacy-masters/rack-locations', {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

export async function seedDemoRackLocations(): Promise<RackLocation[]> {
  return apiFetch<RackLocation[]>('/api/v1/pharmacy-masters/rack-locations/seed-demo', {
    method: 'POST',
  })
}

export async function getSubstitutions(drugMasterId: string): Promise<GenericSubstitution[]> {
  return apiFetch<GenericSubstitution[]>(`/api/v1/pharmacy-masters/substitutions?drugMasterId=${encodeURIComponent(drugMasterId)}`)
}

// ── Near-Expiry & Batch Alerts ──

export async function getNearExpiryBatches(days = 90): Promise<ExpiryBatch[]> {
  return apiFetch<ExpiryBatch[]>(`/api/v1/batches/near-expiry?days=${days}`)
}

export async function getExpirySummary(): Promise<ExpirySummary> {
  return apiFetch<ExpirySummary>('/api/v1/batches/expiry-summary')
}
