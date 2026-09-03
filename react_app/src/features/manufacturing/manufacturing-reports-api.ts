import { apiFetch } from '@/api/client/api-client'

export type WipValuation = {
  totalWipValue: number | string
  openWorkOrdersCount: number
  breakdown: Array<{
    workOrderId: string
    workOrderNumber: string
    finishedGoodName: string
    rawMaterialCost: number | string
    directLaborCost: number | string
    overheadCost: number | string
    totalCost: number | string
  }>
}

export type WorkstationLoad = {
  workstationId: string
  workstationCode: string
  workstationName: string
  dailyCapacityHours: number | string
  allocatedHours: number | string
  utilizationPercent: number | string
}

export type Bottleneck = {
  workstationId: string
  workstationName: string
  queuedOrdersCount: number
  totalBacklogHours: number | string
  capacityShortfallHours: number | string
}

export type CostVariance = {
  workOrderId: string
  workOrderNumber: string
  finishedGoodName: string
  plannedTotalCost: number | string
  actualTotalCost: number | string
  varianceAmount: number | string
  variancePercent: number | string
}

export type ScrapRateDashboard = {
  totalScrapQty: number | string
  totalScrapCost: number | string
  overallScrapPercent: number | string
  reasonBreakdown: Array<{
    reasonCode: string
    description: string
    scrapQty: number | string
    scrapCost: number | string
  }>
}

export async function getWipValuation() {
  return apiFetch<WipValuation>('/api/v1/manufacturing/reports/wip-valuation')
}

export async function getWorkstationLoad() {
  return apiFetch<WorkstationLoad[]>('/api/v1/manufacturing/reports/workstation-load')
}

export async function getTopBottlenecks(limit = 5) {
  return apiFetch<Bottleneck[]>(`/api/v1/manufacturing/reports/bottlenecks?limit=${limit}`)
}

export async function getScrapRateDashboard(fromDate: string, toDate: string) {
  return apiFetch<ScrapRateDashboard>(`/api/v1/manufacturing/reports/scrap-rate?fromDate=${fromDate}&toDate=${toDate}`)
}