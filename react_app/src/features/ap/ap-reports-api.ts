import { apiFetch } from '@/api/client/api-client'

export type ApAgeingBucket = {
  vendorId: string
  vendorName: string
  currentAmount: number | string
  days1To30: number | string
  days31To60: number | string
  days61To90: number | string
  days90Plus: number | string
  totalDue: number | string
}

export type ApAgeingReportResponse = {
  asOfDate: string
  totalPayable: number | string
  currentTotal: number | string
  days1To30Total: number | string
  days31To60Total: number | string
  days61To90Total: number | string
  days90PlusTotal: number | string
  vendors: ApAgeingBucket[]
}

export function getApAgeingReport(asOfDate?: string) {
  const params = new URLSearchParams()
  if (asOfDate) params.set('asOfDate', asOfDate)
  return apiFetch<ApAgeingReportResponse>(`/api/v1/ap/reports/ageing?${params.toString()}`)
}