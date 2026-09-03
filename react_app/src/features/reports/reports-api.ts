import { apiFetch } from '@/api/client/api-client'

export type ColumnDef = {
  key: string
  label: string
  type?: 'TEXT' | 'MONEY' | 'CURRENCY' | 'NUMBER' | 'PERCENT' | 'DATE' | 'BADGE' | string
  align?: 'left' | 'right' | 'center'
  format?: string
}

export type MetricDef = {
  key: string
  label: string
  value: number | string
  format?: 'MONEY' | 'CURRENCY' | 'QUANTITY' | 'NUMBER' | 'PERCENT' | 'TEXT' | string
  hint?: string
  tone?: 'positive' | 'negative' | 'neutral'
}

export type OperationalReportData = {
  title: string
  description?: string
  columns: ColumnDef[]
  rows: Record<string, unknown>[]
  metrics?: MetricDef[]
}

export type ReportCatalogItem = {
  key: string
  title: string
  description: string
  category: 'FINANCIAL' | 'SALES_AR' | 'PURCHASES_AP' | 'INVENTORY' | 'TAX_COMPLIANCE'
  endpoint: string
  hasDateRange?: boolean
  hasAsOfDate?: boolean
  requiresAccountId?: boolean
}

export const reportCatalog: ReportCatalogItem[] = [
  {
    key: 'trial-balance',
    title: 'Trial Balance',
    description: 'Summary of debit and credit balances for all general ledger accounts as of a specific date.',
    category: 'FINANCIAL',
    endpoint: '/api/v1/reports/trial-balance',
    hasAsOfDate: true,
  },
  {
    key: 'profit-loss',
    title: 'Profit & Loss Statement',
    description: 'Income, cost of goods sold, and operating expenditure resulting in net profit or loss.',
    category: 'FINANCIAL',
    endpoint: '/api/v1/reports/profit-loss',
    hasDateRange: true,
  },
  {
    key: 'balance-sheet',
    title: 'Balance Sheet',
    description: 'Snapshot of entity assets, liabilities, and owners equity at a given date.',
    category: 'FINANCIAL',
    endpoint: '/api/v1/reports/balance-sheet',
    hasAsOfDate: true,
  },
  {
    key: 'cash-flow',
    title: 'Cash Flow Statement',
    description: 'Cash inflows and outflows across operating, investing, and financing activities.',
    category: 'FINANCIAL',
    endpoint: '/api/v1/reports/cash-flow',
    hasDateRange: true,
  },
  {
    key: 'general-ledger',
    title: 'General Ledger Report',
    description: 'Detailed chronological transaction register and running balances per account.',
    category: 'FINANCIAL',
    endpoint: '/api/v1/reports/general-ledger',
    hasDateRange: true,
    requiresAccountId: true,
  },
  {
    key: 'day-book',
    title: 'Day Book',
    description: 'Daily transaction log of all financial vouchers and ledger entries.',
    category: 'FINANCIAL',
    endpoint: '/api/v1/reports/day-book',
    hasDateRange: true,
  },
  {
    key: 'journal-register',
    title: 'Journal Register',
    description: 'Audit log of all manual and automated journal vouchers.',
    category: 'FINANCIAL',
    endpoint: '/api/v1/reports/journal-register',
    hasDateRange: true,
  },
  {
    key: 'ratio-analysis',
    title: 'Financial Ratio Analysis',
    description: 'Liquidity, solvency, profitability, and turnover financial ratios.',
    category: 'FINANCIAL',
    endpoint: '/api/v1/reports/ratio-analysis',
    hasDateRange: true,
  },
  {
    key: 'budget-variance',
    title: 'Budget Variance Report',
    description: 'Comparison of planned operational budget limits against actual ledger expenses.',
    category: 'FINANCIAL',
    endpoint: '/api/v1/reports/budget-variance',
    hasDateRange: true,
  },
  {
    key: 'sales-register',
    title: 'Sales Register',
    description: 'Detailed register of all sales invoices, taxable values, and output GST breakdown.',
    category: 'SALES_AR',
    endpoint: '/api/v1/reports/sales-register',
    hasDateRange: true,
  },
  {
    key: 'ar-aging',
    title: 'Accounts Receivable (AR) Aging',
    description: 'Customer outstanding balances grouped by 0-30, 31-60, 61-90, and 90+ days aging buckets.',
    category: 'SALES_AR',
    endpoint: '/api/v1/reports/ar-aging',
    hasAsOfDate: true,
  },
  {
    key: 'overdue-interest',
    title: 'Overdue Interest Calculation',
    description: 'Accrued interest on overdue commercial invoices under MSME or contract terms.',
    category: 'SALES_AR',
    endpoint: '/api/v1/reports/overdue-interest',
  },
  {
    key: 'purchase-register',
    title: 'Purchase Register',
    description: 'Detailed log of supplier bills, input tax credit amounts, and vendor liabilities.',
    category: 'PURCHASES_AP',
    endpoint: '/api/v1/reports/purchase-register',
    hasDateRange: true,
  },
  {
    key: 'ap-aging',
    title: 'Accounts Payable (AP) Aging',
    description: 'Vendor payment liabilities classified by overdue aging buckets.',
    category: 'PURCHASES_AP',
    endpoint: '/api/v1/reports/ap-aging',
    hasAsOfDate: true,
  },
  {
    key: 'stock-ageing',
    title: 'Stock Ageing Analysis',
    description: 'Inventory balances categorized by shelf age to identify slow-moving stock.',
    category: 'INVENTORY',
    endpoint: '/api/v1/reports/stock-ageing',
  },
  {
    key: 'fifo-valuation',
    title: 'FIFO Inventory Valuation',
    description: 'First-in-first-out cost lot breakdown and stock balance valuation.',
    category: 'INVENTORY',
    endpoint: '/api/v1/reports/fifo-valuation',
  },
  {
    key: 'gst-summary',
    title: 'GST Return Summary',
    description: 'Monthly output liability and input tax credit (ITC) reconciliation for GSTR-3B.',
    category: 'TAX_COMPLIANCE',
    endpoint: '/api/v1/reports/gst-summary',
    hasDateRange: true,
  },
]

// â”€â”€ Saved Reports Models â”€â”€

export type SavedReport = {
  id: string
  name: string
  description?: string | null
  baseReportKey: string
  columnKeys: string[]
  filters?: Record<string, unknown> | null
  tags?: string | null
  isPublic: boolean
  createdBy: string
  createdAt: string
  updatedAt?: string
}

export type ReportSchedule = {
  id: string
  savedReportId: string
  frequency: 'DAILY' | 'WEEKLY' | 'MONTHLY' | string
  dayOfWeek?: number | null
  dayOfMonth?: number | null
  sendTime: string
  recipientEmails: string[]
  subjectTemplate?: string | null
  active: boolean
  lastSentAt?: string | null
  nextRunAt?: string | null
}

// â”€â”€ Strongly-typed Domain Models â”€â”€

export type TrialBalanceRow = {
  accountId: string
  accountCode: string
  accountName: string
  accountType: string
  debit: number | string
  credit: number | string
  netBalance: number | string
}

export type TrialBalanceResponse = {
  asOfDate: string
  basis: string
  totalDebit: number | string
  totalCredit: number | string
  isBalanced: boolean
  rows: TrialBalanceRow[]
}

export type ProfitLossSection = {
  title: string
  accounts: {
    accountId: string
    accountCode: string
    accountName: string
    amount: number | string
  }[]
  subtotal: number | string
}

export type ProfitLossResponse = {
  startDate: string
  endDate: string
  basis: string
  operatingRevenue: ProfitLossSection
  costOfGoodsSold: ProfitLossSection
  grossProfit: number | string
  operatingExpenses: ProfitLossSection
  operatingIncome: number | string
  nonOperatingRevenue: ProfitLossSection
  nonOperatingExpenses: ProfitLossSection
  netProfit: number | string
}

export type BalanceSheetSection = {
  title: string
  accounts: {
    accountId: string
    accountCode: string
    accountName: string
    amount: number | string
  }[]
  subtotal: number | string
}

export type BalanceSheetResponse = {
  asOfDate: string
  basis: string
  currentAssets: BalanceSheetSection
  nonCurrentAssets: BalanceSheetSection
  totalAssets: number | string
  currentLiabilities: BalanceSheetSection
  nonCurrentLiabilities: BalanceSheetSection
  totalLiabilities: number | string
  equity: BalanceSheetSection
  retainedEarnings: number | string
  totalEquity: number | string
  totalLiabilitiesAndEquity: number | string
  isBalanced: boolean
}

export type GeneralLedgerEntry = {
  transactionDate: string
  entryNumber: string
  journalId: string
  description: string
  sourceModule: string
  debit: number | string
  credit: number | string
  runningBalance: number | string
}

export type GeneralLedgerResponse = {
  accountId: string
  accountCode: string
  accountName: string
  accountType: string
  startDate: string
  endDate: string
  openingBalance: number | string
  totalDebit: number | string
  totalCredit: number | string
  closingBalance: number | string
  entries: GeneralLedgerEntry[]
}

export type AgingBucket = {
  contactId: string
  contactName: string
  currentDue: number | string
  days1To30: number | string
  days31To60: number | string
  days61To90: number | string
  days90Plus: number | string
  totalOutstanding: number | string
}

// â”€â”€ API Invocation Functions â”€â”€

export async function getOperationalReport(
  endpoint: string,
  startDate?: string,
  endDate?: string,
  asOfDate?: string
): Promise<OperationalReportData> {
  const params = new URLSearchParams()
  if (startDate) params.set('startDate', startDate)
  if (endDate) params.set('endDate', endDate)
  if (asOfDate) params.set('asOfDate', asOfDate)
  const qs = params.toString() ? `?${params.toString()}` : ''
  return apiFetch<OperationalReportData>(`${endpoint}${qs}`)
}

export async function listSavedReports(): Promise<SavedReport[]> {
  return apiFetch<SavedReport[]>('/api/v1/saved-reports')
}

export async function getSavedReport(id: string): Promise<SavedReport> {
  return apiFetch<SavedReport>(`/api/v1/saved-reports/${id}`)
}

export async function listReportSchedules(savedReportId: string): Promise<ReportSchedule[]> {
  return apiFetch<ReportSchedule[]>(`/api/v1/saved-reports/${savedReportId}/schedules`)
}

export async function getTrialBalance(asOfDate?: string, basis = 'ACCRUAL') {
  const q = asOfDate ? `?asOfDate=${asOfDate}&basis=${basis}` : `?basis=${basis}`
  return apiFetch<TrialBalanceResponse>(`/api/v1/reports/trial-balance${q}`)
}

export async function getProfitLoss(startDate: string, endDate: string, basis = 'ACCRUAL') {
  return apiFetch<ProfitLossResponse>(
    `/api/v1/reports/profit-loss?startDate=${startDate}&endDate=${endDate}&basis=${basis}`
  )
}

export async function getBalanceSheet(asOfDate?: string, basis = 'ACCRUAL') {
  const q = asOfDate ? `?asOfDate=${asOfDate}&basis=${basis}` : `?basis=${basis}`
  return apiFetch<BalanceSheetResponse>(`/api/v1/reports/balance-sheet${q}`)
}

export async function getGeneralLedger(accountId: string, startDate: string, endDate: string) {
  return apiFetch<GeneralLedgerResponse>(
    `/api/v1/reports/general-ledger/${accountId}?startDate=${startDate}&endDate=${endDate}`
  )
}

export async function getDayBook(startDate: string, endDate: string) {
  return apiFetch<OperationalReportData>(
    `/api/v1/reports/day-book?startDate=${startDate}&endDate=${endDate}`
  )
}

export async function getCashFlow(startDate: string, endDate: string) {
  return apiFetch<OperationalReportData>(
    `/api/v1/reports/cash-flow?startDate=${startDate}&endDate=${endDate}`
  )
}

export async function getJournalRegister(startDate: string, endDate: string) {
  return apiFetch<OperationalReportData>(
    `/api/v1/reports/journal-register?startDate=${startDate}&endDate=${endDate}`
  )
}

export async function getRatioAnalysis(startDate: string, endDate: string) {
  return apiFetch<OperationalReportData>(
    `/api/v1/reports/ratio-analysis?startDate=${startDate}&endDate=${endDate}`
  )
}

export async function getBudgetVariance(startDate: string, endDate: string) {
  return apiFetch<OperationalReportData>(
    `/api/v1/reports/budget-variance?startDate=${startDate}&endDate=${endDate}`
  )
}

export async function getOverdueInterest() {
  return apiFetch<OperationalReportData>('/api/v1/reports/overdue-interest')
}

export async function draftInterestDebitNote(invoiceId: string) {
  return apiFetch<{ journalEntryId: string }>(
    `/api/v1/reports/overdue-interest/${invoiceId}/draft-debit-note`,
    {
      method: 'POST',
    }
  )
}

export async function getStockAgeing() {
  return apiFetch<OperationalReportData>('/api/v1/reports/stock-ageing')
}

export async function getSalesRegister(startDate: string, endDate: string) {
  return apiFetch<OperationalReportData>(
    `/api/v1/reports/sales-register?startDate=${startDate}&endDate=${endDate}`
  )
}

export async function getPurchaseRegister(startDate: string, endDate: string) {
  return apiFetch<OperationalReportData>(
    `/api/v1/reports/purchase-register?startDate=${startDate}&endDate=${endDate}`
  )
}

export async function getApAging() {
  return apiFetch<AgingBucket[]>('/api/v1/reports/ap-aging')
}

export async function getArAging() {
  return apiFetch<AgingBucket[]>('/api/v1/reports/ar-aging')
}