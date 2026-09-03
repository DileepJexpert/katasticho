import { apiFetch } from '@/api/client/api-client'

export type BudgetLine = {
  accountId: string
  accountCode?: string
  accountName?: string
  accountType?: string
  amount: number | string
  actualAmount?: number | string
  variance?: number | string
  variancePercentage?: number | string
}

export type BudgetVarianceReport = {
  fiscalYear: number
  totalBudget: number | string
  totalActual: number | string
  totalVariance: number | string
  lines: BudgetLine[]
}

export async function listBudget(fy: number) {
  return apiFetch<BudgetLine[]>(`/api/v1/budgets/${fy}`)
}

export async function saveBudget(fy: number, lines: BudgetLine[]) {
  return apiFetch<BudgetLine[]>(`/api/v1/budgets/${fy}`, {
    method: 'PUT',
    body: lines,
  })
}
