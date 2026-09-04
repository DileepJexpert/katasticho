import { apiFetch } from '@/api/client/api-client'

export interface BranchSalesRow {
  branchId: string
  branchName: string
  totalSales: number | string
  transactionCount: number
}

export interface TodaySalesResponse {
  from?: string | null
  to?: string | null
  branchFilter?: string | null
  totalSales: number | string | null
  cashUpiTotal: number | string | null
  creditTotal: number | string | null
  posSalesTotal: number | string | null
  paidInvoiceTotal: number | string | null
  transactionCount: number
  posTransactionCount: number
  invoiceTransactionCount: number
  currency: string | null
  byBranch?: BranchSalesRow[] | null
}

export interface ArSummaryResponse {
  totalOutstanding: number | string | null
  overdueCount: number
  dueThisWeek: number | string | null
  dueThisWeekCount: number
  currency: string | null
}

export interface BranchPurchaseRow {
  branchId: string
  branchName: string
  totalPurchases: number | string
  sharePercent?: number | null
}

export interface ApSummaryResponse {
  totalOutstanding: number | string | null
  overdueCount: number
  dueThisWeek: number | string | null
  dueThisWeekCount: number
  byBranch?: BranchPurchaseRow[] | null
}

export interface MonthlyProfitResponse {
  from?: string | null
  to?: string | null
  revenue: number | string | null
  cogs: number | string | null
  grossProfit: number | string | null
  currency: string | null
}

export interface SoAlertItem {
  id: string
  orderNumber: string
  contactName: string
  status: string
  totalAmount: number | string
  orderDate: string
  daysPending: number
}

export interface SoAlertResponse {
  confirmedCount: number
  backorderCount: number
  partiallyShippedCount: number
  overdueCount: number
  draftChallanCount: number
  dispatchedChallanCount: number
  deliveredChallanCount: number
  recentOrders?: SoAlertItem[] | null
}

export interface TopSellingItem {
  rank: number
  itemId: string
  sku: string
  name: string
  unit: string
  quantity: number | string
  revenue: number | string
}

export interface DailyPoint {
  date: string
  revenue: number | string
}

export interface RevenueTrendResponse {
  from?: string | null
  to?: string | null
  days: number
  totalRevenue: number | string
  currency: string | null
  trend: DailyPoint[]
}

export interface CashFlowResponse {
  from?: string | null
  to?: string | null
  cashIn: number | string
  cashOut: number | string
  netCashFlow: number | string
  currency: string | null
}

export interface ExpiringSoonResponse {
  itemId: string
  itemName: string
  sku: string
  batchNumber: string
  expiryDate: string
  daysLeft: number
  quantityOnHand: number | string
}

export interface RecentTransactionResponse {
  id: string
  type: string
  number: string
  customerName: string
  amount: number | string
  paymentMode: string
  createdAt: string
}

export interface BranchResponse {
  id: string
  code: string
  name: string
  addressLine1?: string | null
  addressLine2?: string | null
  city?: string | null
  state?: string | null
  stateCode?: string | null
  postalCode?: string | null
  country?: string | null
  gstin?: string | null
  isDefault: boolean
  active: boolean
}

export interface DailySummarySnapshot {
  totalSale: number | string
  totalCost: number | string
  earning: number | string
  cashUpiIn: number | string
  creditSale: number | string
  billCount: number
}

export interface DailySummaryRow {
  date: string
  sale: number | string
  cost: number | string
  earning: number | string
}

export interface WeekComparison {
  totalSale: number | string
  totalEarning: number | string
  vsLastWeekSalePct: number | string
  vsLastWeekEarningPct: number | string
}

export interface DailySummaryResponse {
  today: DailySummarySnapshot
  daily: DailySummaryRow[]
  thisWeek: WeekComparison
  currency?: string | null
}

export interface TopCustomerRow {
  contactId: string
  name: string
  outstanding: number | string
  invoiceCount: number
}

export interface OutstandingReceivableResponse {
  totalOutstanding: number | string
  overdueCount: number
  overdueAmount: number | string
  currency?: string | null
  topCustomers: TopCustomerRow[]
}

export interface RecentBillResponse {
  id: string
  billNumber: string
  vendorName: string
  status: string
  totalAmount: number | string
  billDate: string
}

export interface RecentJournalResponse {
  id: string
  entryNumber: string
  effectiveDate: string
  description?: string | null
  sourceModule: string
  status: string
  totalDebit: number | string
}

export interface AgeingReportResponse {
  totalOutstanding: number | string
  current: number | string
  days1to30: number | string
  days31to60: number | string
  days61to90: number | string
  days90plus: number | string
}

export interface ApAgeingReportResponse {
  totalOutstanding: number | string
  current: number | string
  days1to30: number | string
  days31to60: number | string
  days61to90: number | string
  days90plus: number | string
}

// ── Dashboard API Fetchers ──

export async function getTodaySales(from?: string, to?: string, branchId?: string): Promise<TodaySalesResponse> {
  const params = new URLSearchParams()
  if (from) params.set('from', from)
  if (to) params.set('to', to)
  if (branchId) params.set('branchId', branchId)
  const qs = params.toString() ? `?${params.toString()}` : ''
  return apiFetch<TodaySalesResponse>(`/api/v1/dashboard/today-sales${qs}`)
}

export async function getArSummary(): Promise<ArSummaryResponse> {
  return apiFetch<ArSummaryResponse>('/api/v1/dashboard/receivables')
}

export async function getApSummary(from?: string, to?: string, branchId?: string): Promise<ApSummaryResponse> {
  const params = new URLSearchParams()
  if (from) params.set('from', from)
  if (to) params.set('to', to)
  if (branchId) params.set('branchId', branchId)
  const qs = params.toString() ? `?${params.toString()}` : ''
  return apiFetch<ApSummaryResponse>(`/api/v1/dashboard/ap-summary${qs}`)
}

export async function getMonthlyProfit(from?: string, to?: string): Promise<MonthlyProfitResponse> {
  const params = new URLSearchParams()
  if (from) params.set('from', from)
  if (to) params.set('to', to)
  const qs = params.toString() ? `?${params.toString()}` : ''
  return apiFetch<MonthlyProfitResponse>(`/api/v1/dashboard/monthly-profit${qs}`)
}

export async function getSoAlerts(): Promise<SoAlertResponse> {
  return apiFetch<SoAlertResponse>('/api/v1/dashboard/so-alerts')
}

export async function getTopSelling(from?: string, to?: string, limit = 5): Promise<TopSellingItem[]> {
  const params = new URLSearchParams({ limit: String(limit) })
  if (from) params.set('from', from)
  if (to) params.set('to', to)
  return apiFetch<TopSellingItem[]>(`/api/v1/dashboard/top-selling?${params.toString()}`)
}

export async function getRevenueTrend(days = 30): Promise<RevenueTrendResponse> {
  return apiFetch<RevenueTrendResponse>(`/api/v1/dashboard/revenue-trend?days=${days}`)
}

export async function getCashFlow(from?: string, to?: string): Promise<CashFlowResponse> {
  const params = new URLSearchParams()
  if (from) params.set('from', from)
  if (to) params.set('to', to)
  const qs = params.toString() ? `?${params.toString()}` : ''
  return apiFetch<CashFlowResponse>(`/api/v1/dashboard/cash-flow${qs}`)
}

export async function getExpiringSoon(withinDays = 90): Promise<ExpiringSoonResponse[]> {
  return apiFetch<ExpiringSoonResponse[]>(`/api/v1/dashboard/expiring-soon?withinDays=${withinDays}`)
}

export async function getRecentTransactions(from?: string, to?: string, limit = 5): Promise<RecentTransactionResponse[]> {
  const params = new URLSearchParams({ limit: String(limit) })
  if (from) params.set('from', from)
  if (to) params.set('to', to)
  return apiFetch<RecentTransactionResponse[]>(`/api/v1/dashboard/recent-transactions?${params.toString()}`)
}

export async function getDailySummary(days = 7): Promise<DailySummaryResponse> {
  return apiFetch<DailySummaryResponse>(`/api/v1/dashboard/daily-summary?days=${days}`)
}

export async function getOutstandingReceivable(): Promise<OutstandingReceivableResponse> {
  return apiFetch<OutstandingReceivableResponse>('/api/v1/dashboard/outstanding-receivable')
}

export async function getRecentBills(limit = 5): Promise<RecentBillResponse[]> {
  return apiFetch<RecentBillResponse[]>(`/api/v1/dashboard/recent-bills?limit=${limit}`)
}

export async function getRecentJournals(limit = 10): Promise<RecentJournalResponse[]> {
  return apiFetch<RecentJournalResponse[]>(`/api/v1/dashboard/recent-journals?limit=${limit}`)
}

export async function getArAging(asOfDate?: string): Promise<AgeingReportResponse> {
  const qs = asOfDate ? `?asOfDate=${asOfDate}` : ''
  return apiFetch<AgeingReportResponse>(`/api/v1/ar/reports/ageing${qs}`)
}

export async function getApAging(asOfDate?: string): Promise<ApAgeingReportResponse> {
  const qs = asOfDate ? `?asOfDate=${asOfDate}` : ''
  return apiFetch<ApAgeingReportResponse>(`/api/v1/ap/reports/ageing${qs}`)
}

export async function listBranches(): Promise<BranchResponse[]> {
  return apiFetch<BranchResponse[]>('/api/v1/branches')
}
