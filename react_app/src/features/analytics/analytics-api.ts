import { apiFetch } from '@/api/client/api-client'

export type CashRunwayWeeklyBucket = {
  weekNumber: number
  startDate: string
  endDate: string
  openingCash: number
  totalInflow: number
  totalOutflow: number
  netChange: number
  closingCash: number
  isDeficit: boolean
}

export type WorkingCapitalMetrics = {
  projectedCurrentRatio: number
  projectedQuickRatio: number
  estimatedCashConversionDays: number
  liquidityStatus: string
}

export type CashRunwayReport = {
  asOfDate: string
  baseCurrency: string
  currentLiquidCash: number
  safetyBufferAmount: number
  runwayWeeks: number
  minProjectedBalance: number
  minBalanceWeek: number
  totalInflows13W: number
  totalOutflows13W: number
  netChange13W: number
  deficitWeeksCount: number
  deficitAlerts: string[]
  weeklyBuckets: CashRunwayWeeklyBucket[]
  workingCapitalHealth?: WorkingCapitalMetrics
}

export type FluxItem = {
  accountCode: string
  accountName: string
  accountType: string
  baseBalance: number
  compBalance: number
  absoluteChange: number
  percentageChange: number
  isMaterial: boolean
  commentary?: string | null
}

export type FinancialFluxReport = {
  periodType: string
  basePeriodLabel: string
  compPeriodLabel: string
  totalBaseRevenue: number
  totalCompRevenue: number
  totalBaseExpense: number
  totalCompExpense: number
  items: FluxItem[]
  summaryCommentary?: string | null
}

export async function get13WeekCashRunway(asOfDate?: string) {
  const params = new URLSearchParams()
  if (asOfDate) params.set('asOfDate', asOfDate)
  return apiFetch<CashRunwayReport>(`/api/v1/treasury/cash-runway/13-week?${params.toString()}`)
}

export async function simulateCashRunway(data: {
  asOfDate?: string
  inflowMultiplier?: number
  outflowMultiplier?: number
  oneTimeInflows?: Array<{ weekNumber: number; amount: number; description: string }>
  oneTimeOutflows?: Array<{ weekNumber: number; amount: number; description: string }>
}) {
  const params = new URLSearchParams()
  if (data.asOfDate) params.set('asOfDate', data.asOfDate)
  return apiFetch<CashRunwayReport>(`/api/v1/treasury/cash-runway/simulate?${params.toString()}`, {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

export async function getFluxReport(params: {
  periodType?: string
  baseStart?: string
  baseEnd?: string
  compStart?: string
  compEnd?: string
  minMaterialAmount?: number
  minMaterialPercent?: number
}) {
  const q = new URLSearchParams()
  if (params.periodType) q.set('periodType', params.periodType)
  if (params.baseStart) q.set('baseStart', params.baseStart)
  if (params.baseEnd) q.set('baseEnd', params.baseEnd)
  if (params.compStart) q.set('compStart', params.compStart)
  if (params.compEnd) q.set('compEnd', params.compEnd)
  if (params.minMaterialAmount) q.set('minMaterialAmount', String(params.minMaterialAmount))
  if (params.minMaterialPercent) q.set('minMaterialPercent', String(params.minMaterialPercent))
  return apiFetch<FinancialFluxReport>(`/api/v1/reports/flux-commentary?${q.toString()}`)
}
