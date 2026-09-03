import { apiFetch } from '@/api/client/api-client'

export type FixedAsset = {
  id: string
  orgId: string
  assetCode: string
  name: string
  category: string | null
  acquisitionDate: string
  cost: number | string
  residualValue: number | string
  bookMethod: 'SLM' | 'WDV' | string
  bookUsefulLifeMonths: number | null
  bookRatePct: number | string | null
  accumulatedDepreciation: number | string
  itBlock: string | null
  itRatePct: number | string | null
  assetAccountCode: string | null
  accumulatedDepAccountCode: string | null
  depExpenseAccountCode: string | null
  status: 'ACTIVE' | 'DISPOSED' | 'WRITTEN_OFF' | string
  disposalDate: string | null
  disposalProceeds: number | string | null
  disposalGainLoss: number | string | null
  notes: string | null
  createdAt?: string
  updatedAt?: string
}

export type FixedAssetDepreciation = {
  id: string
  fixedAssetId: string
  periodYear: number
  periodMonth: number
  openingBookValue: number | string
  depreciationAmount: number | string
  closingBookValue: number | string
  journalEntryId: string | null
  createdAt: string
}

export type SchedulePreviewEntry = {
  periodYear: number
  periodMonth: number
  openingBookValue: number | string
  depreciationAmount: number | string
  closingBookValue: number | string
}

export type FixedAssetDetailResponse = {
  asset: FixedAsset
  bookValue: number | string
  schedule: FixedAssetDepreciation[]
}

export type CreateFixedAssetRequest = {
  assetCode: string
  name: string
  category?: string
  acquisitionDate: string
  cost: number
  residualValue?: number
  bookMethod: 'SLM' | 'WDV' | string
  bookUsefulLifeMonths?: number
  assetAccountCode?: string
  accumulatedDepAccountCode?: string
  depExpenseAccountCode?: string
  notes?: string
}

export type DisposeAssetRequest = {
  disposalDate: string
  disposalProceeds: number
  notes?: string
}

export async function listFixedAssets() {
  return apiFetch<FixedAsset[]>('/api/v1/fixed-assets')
}

export async function getFixedAsset(id: string) {
  return apiFetch<FixedAssetDetailResponse>(`/api/v1/fixed-assets/${id}`)
}

export async function createFixedAsset(req: CreateFixedAssetRequest) {
  return apiFetch<FixedAsset>('/api/v1/fixed-assets', {
    method: 'POST',
    body: req,
  })
}

export async function runDepreciation(id: string, year: number, month: number) {
  return apiFetch<FixedAssetDepreciation>(`/api/v1/fixed-assets/${id}/depreciation?year=${year}&month=${month}`, {
    method: 'POST',
  })
}

export async function disposeFixedAsset(id: string, req: DisposeAssetRequest) {
  return apiFetch<FixedAsset>(`/api/v1/fixed-assets/${id}/dispose`, {
    method: 'POST',
    body: req,
  })
}

export async function getFixedAssetSchedulePreview(id: string) {
  return apiFetch<SchedulePreviewEntry[]>(`/api/v1/fixed-assets/${id}/schedule-preview`)
}
