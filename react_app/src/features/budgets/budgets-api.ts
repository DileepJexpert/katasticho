import { apiFetch } from '@/api/client/api-client'

export type BudgetLine = { accountCode: string; accountName: string; annualAmount: number | string; notes: string | null }
export type BudgetVarianceReport = {
  description: string
  rows: { code: string; account: string; budget: number; actual: number; variance: number; usagePct: number }[]
}
export function listBudget(fy: number) {
  return apiFetch<BudgetLine[]>(`/api/v1/budgets/${fy}`)
}
export function saveBudget(fy: number, lines: BudgetLine[]) {
  return apiFetch<BudgetLine[]>(`/api/v1/budgets/${fy}`, { method: 'PUT', body: lines })
}
export function getBudgetVariance(fy: number) {
  return apiFetch<BudgetVarianceReport>(`/api/v1/reports/budget-variance?startDate=${fy}-04-01&endDate=${fy + 1}-03-31`)
}
