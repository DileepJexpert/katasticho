import { apiFetch } from '@/api/client/api-client'

export type TodaySales = {
  totalSales: number | string | null
  cashUpiTotal: number | string | null
  creditTotal: number | string | null
  transactionCount: number
  currency: string | null
}

export type OutstandingSummary = {
  totalOutstanding: number | string | null
  overdueCount: number
  dueThisWeek: number | string | null
  dueThisWeekCount: number
  currency?: string | null
}

export type MonthlyProfit = {
  revenue: number | string | null
  cogs: number | string | null
  grossProfit: number | string | null
  currency: string | null
}

export async function getDashboardOverview() {
  const [todaySales, receivables, payables, monthlyProfit] = await Promise.all([
    apiFetch<TodaySales>('/api/v1/dashboard/today-sales'),
    apiFetch<OutstandingSummary>('/api/v1/dashboard/ar-summary'),
    apiFetch<OutstandingSummary>('/api/v1/dashboard/ap-summary'),
    apiFetch<MonthlyProfit>('/api/v1/dashboard/monthly-profit'),
  ])

  return { todaySales, receivables, payables, monthlyProfit }
}
