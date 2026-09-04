import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { DashboardPage } from './dashboard-page'
import * as dashboardApi from './dashboard-api'
import { useSessionStore } from '@/shared/session/session-store'

vi.mock('./dashboard-api', () => ({
  getTodaySales: vi.fn(),
  getArSummary: vi.fn(),
  getApSummary: vi.fn(),
  getMonthlyProfit: vi.fn(),
  getSoAlerts: vi.fn(),
  getTopSelling: vi.fn(),
  getRevenueTrend: vi.fn(),
  getCashFlow: vi.fn(),
  getExpiringSoon: vi.fn(),
  getRecentTransactions: vi.fn(),
  getDailySummary: vi.fn(),
  getOutstandingReceivable: vi.fn(),
  getRecentBills: vi.fn(),
  getRecentJournals: vi.fn(),
  getArAging: vi.fn(),
  getApAging: vi.fn(),
  listBranches: vi.fn(),
}))

const mockBranches: dashboardApi.BranchResponse[] = [
  {
    id: 'branch-1',
    code: 'MB01',
    name: 'Main Warehouse',
    isDefault: true,
    active: true,
  },
  {
    id: 'branch-2',
    code: 'SB02',
    name: 'City Pharmacy Outlet',
    isDefault: false,
    active: true,
  },
]

const mockTodaySales: dashboardApi.TodaySalesResponse = {
  totalSales: 154000,
  cashUpiTotal: 84000,
  creditTotal: 70000,
  posSalesTotal: 54000,
  paidInvoiceTotal: 30000,
  transactionCount: 42,
  posTransactionCount: 30,
  invoiceTransactionCount: 12,
  currency: 'INR',
  byBranch: [
    {
      branchId: 'branch-1',
      branchName: 'Main Warehouse',
      totalSales: 104000,
      transactionCount: 26,
    },
    {
      branchId: 'branch-2',
      branchName: 'City Pharmacy Outlet',
      totalSales: 50000,
      transactionCount: 16,
    },
  ],
}

const mockArSummary: dashboardApi.ArSummaryResponse = {
  totalOutstanding: 620000,
  overdueCount: 8,
  dueThisWeek: 120000,
  dueThisWeekCount: 5,
  currency: 'INR',
}

const mockApSummary: dashboardApi.ApSummaryResponse = {
  totalOutstanding: 450000,
  overdueCount: 3,
  dueThisWeek: 95000,
  dueThisWeekCount: 2,
}

const mockMonthlyProfit: dashboardApi.MonthlyProfitResponse = {
  revenue: 2800000,
  cogs: 2100000,
  grossProfit: 700000,
  currency: 'INR',
}

const mockSoAlerts: dashboardApi.SoAlertResponse = {
  confirmedCount: 14,
  backorderCount: 3,
  partiallyShippedCount: 2,
  overdueCount: 4,
  draftChallanCount: 2,
  dispatchedChallanCount: 5,
  deliveredChallanCount: 12,
  recentOrders: [
    {
      id: 'so-1',
      orderNumber: 'SO-2026-0042',
      contactName: 'Apollo Hospital Indiranagar',
      status: 'CONFIRMED',
      totalAmount: 125000,
      orderDate: '2026-09-02',
      daysPending: 3,
    },
  ],
}

const mockTopSelling: dashboardApi.TopSellingItem[] = [
  {
    rank: 1,
    itemId: 'item-1',
    sku: 'MED-PAC-500',
    name: 'Paracetamol 500mg Tablets',
    unit: 'Strip',
    quantity: 1200,
    revenue: 48000,
  },
  {
    rank: 2,
    itemId: 'item-2',
    sku: 'MED-AMX-250',
    name: 'Amoxicillin 250mg Capsules',
    unit: 'Box',
    quantity: 450,
    revenue: 36000,
  },
]

const mockRevenueTrend: dashboardApi.RevenueTrendResponse = {
  days: 30,
  totalRevenue: 2450000,
  currency: 'INR',
  trend: [
    { date: '2026-09-01', revenue: 78000 },
    { date: '2026-09-02', revenue: 84000 },
    { date: '2026-09-03', revenue: 92000 },
  ],
}

const mockCashFlow: dashboardApi.CashFlowResponse = {
  cashIn: 850000,
  cashOut: 620000,
  netCashFlow: 230000,
  currency: 'INR',
}

const mockExpiringSoon: dashboardApi.ExpiringSoonResponse[] = [
  {
    itemId: 'item-10',
    itemName: 'Cough Syrup 100ml',
    sku: 'MED-SYR-100',
    batchNumber: 'B-2024-X9',
    expiryDate: '2026-10-15',
    daysLeft: 41,
    quantityOnHand: 150,
  },
]

const mockRecentTransactions: dashboardApi.RecentTransactionResponse[] = [
  {
    id: 'tx-1',
    type: 'INVOICE',
    number: 'INV-2026-0891',
    customerName: 'Metro Healthcare Ltd',
    amount: 45000,
    paymentMode: 'BANK_TRANSFER',
    createdAt: '2026-09-04T10:30:00Z',
  },
]

const mockDailySummary: dashboardApi.DailySummaryResponse = {
  today: {
    totalSale: 154000,
    totalCost: 110000,
    earning: 44000,
    cashUpiIn: 84000,
    creditSale: 70000,
    billCount: 42,
  },
  daily: [
    { date: '2026-09-04', sale: 154000, cost: 110000, earning: 44000 },
  ],
  thisWeek: {
    totalSale: 890000,
    totalEarning: 260000,
    vsLastWeekSalePct: 12.5,
    vsLastWeekEarningPct: 18.2,
  },
  currency: 'INR',
}

const mockArAging: dashboardApi.AgeingReportResponse = {
  totalOutstanding: 620000,
  current: 350000,
  days1to30: 150000,
  days31to60: 70000,
  days61to90: 30000,
  days90plus: 20000,
}

const mockApAging: dashboardApi.ApAgeingReportResponse = {
  totalOutstanding: 450000,
  current: 250000,
  days1to30: 120000,
  days31to60: 50000,
  days61to90: 20000,
  days90plus: 10000,
}

const mockOutstandingReceivable: dashboardApi.OutstandingReceivableResponse = {
  totalOutstanding: 620000,
  overdueCount: 8,
  overdueAmount: 120000,
  currency: 'INR',
  topCustomers: [
    {
      contactId: 'c-1',
      name: 'Fortis Hospital Cunningham Road',
      outstanding: 280000,
      invoiceCount: 4,
    },
  ],
}

const mockRecentBills: dashboardApi.RecentBillResponse[] = [
  {
    id: 'bill-1',
    billNumber: 'BILL-2026-0412',
    vendorName: 'Sun Pharma Distribution Ltd',
    status: 'POSTED',
    totalAmount: 180000,
    billDate: '2026-09-01',
  },
]

const mockRecentJournals: dashboardApi.RecentJournalResponse[] = [
  {
    id: 'je-1',
    entryNumber: 'JE-2026-1029',
    effectiveDate: '2026-09-04',
    description: 'Bank payment to vendor',
    sourceModule: 'PAYMENT',
    status: 'POSTED',
    totalDebit: 50000,
  },
]

function renderDashboard(queryClient: QueryClient) {
  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter>
        <DashboardPage />
      </MemoryRouter>
    </QueryClientProvider>
  )
}

describe('DashboardPage', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    queryClient = new QueryClient({
      defaultOptions: {
        queries: { retry: false },
      },
    })
    vi.clearAllMocks()

    useSessionStore.setState({
      status: 'authenticated',
      user: {
        id: 'user-1',
        orgId: 'org-1',
        fullName: 'Vikram Mehta',
        email: 'vikram@example.com',
        phone: null,
        role: 'OWNER',
        orgName: 'Apex Distributors',
        industry: null,
        businessType: null,
        industryCode: null,
        onboardingCompleted: true,
        defaultLandingPage: '/',
      },
    })

    vi.mocked(dashboardApi.listBranches).mockResolvedValue(mockBranches)
    vi.mocked(dashboardApi.getTodaySales).mockResolvedValue(mockTodaySales)
    vi.mocked(dashboardApi.getArSummary).mockResolvedValue(mockArSummary)
    vi.mocked(dashboardApi.getApSummary).mockResolvedValue(mockApSummary)
    vi.mocked(dashboardApi.getMonthlyProfit).mockResolvedValue(mockMonthlyProfit)
    vi.mocked(dashboardApi.getSoAlerts).mockResolvedValue(mockSoAlerts)
    vi.mocked(dashboardApi.getTopSelling).mockResolvedValue(mockTopSelling)
    vi.mocked(dashboardApi.getRevenueTrend).mockResolvedValue(mockRevenueTrend)
    vi.mocked(dashboardApi.getCashFlow).mockResolvedValue(mockCashFlow)
    vi.mocked(dashboardApi.getExpiringSoon).mockResolvedValue(mockExpiringSoon)
    vi.mocked(dashboardApi.getRecentTransactions).mockResolvedValue(mockRecentTransactions)
    vi.mocked(dashboardApi.getDailySummary).mockResolvedValue(mockDailySummary)
    vi.mocked(dashboardApi.getArAging).mockResolvedValue(mockArAging)
    vi.mocked(dashboardApi.getApAging).mockResolvedValue(mockApAging)
    vi.mocked(dashboardApi.getOutstandingReceivable).mockResolvedValue(mockOutstandingReceivable)
    vi.mocked(dashboardApi.getRecentBills).mockResolvedValue(mockRecentBills)
    vi.mocked(dashboardApi.getRecentJournals).mockResolvedValue(mockRecentJournals)
  })

  it('renders executive greeting, quick action dock, and the four core KPI metric cards', async () => {
    renderDashboard(queryClient)

    expect(await screen.findByText(/Good (morning|afternoon|evening), Vikram/i)).toBeInTheDocument()
    expect(screen.getByText('Executive Overview • Apex Distributors')).toBeInTheDocument()

    // Quick action dock
    expect(screen.getByText('+ New Invoice')).toBeInTheDocument()
    expect(screen.getByText('+ Record Payment')).toBeInTheDocument()
    expect(screen.getByText('+ New Bill')).toBeInTheDocument()
    expect(screen.getByText('+ Point of Sale')).toBeInTheDocument()
    expect(screen.getByText('+ New Item')).toBeInTheDocument()

    // 4 KPI Cards
    expect(screen.getByText('Today’s sales')).toBeInTheDocument()
    expect(screen.getByText('Receivables')).toBeInTheDocument()
    expect(screen.getByText('Payables')).toBeInTheDocument()
    expect(screen.getByText('Monthly gross profit')).toBeInTheDocument()

    // KPI details
    expect(await screen.findByText(/42 transactions.*Cash.*UPI.*84000/i)).toBeInTheDocument()
    expect(screen.getByText(/8 overdue accounts/i)).toBeInTheDocument()
    expect(screen.getByText(/3 overdue bills/i)).toBeInTheDocument()
  })

  it('renders Global Filter bar with period presets and branch dropdown', async () => {
    renderDashboard(queryClient)

    expect(await screen.findByLabelText('Filter by branch')).toBeInTheDocument()
    expect(await screen.findByText('Main Warehouse (MB01) [Primary]')).toBeInTheDocument()
    expect(screen.getByText('City Pharmacy Outlet (SB02)')).toBeInTheDocument()

    const branchSelect = screen.getByLabelText('Filter by branch')
    fireEvent.change(branchSelect, { target: { value: 'branch-2' } })

    await waitFor(() => {
      expect(dashboardApi.getTodaySales).toHaveBeenCalledWith(expect.any(String), expect.any(String), 'branch-2')
    })
  })

  it('renders Aaj Ka Hisaab performance card with net margin and sales breakdown', async () => {
    renderDashboard(queryClient)

    expect(await screen.findByText('Aaj Ka Hisaab — Daily Performance Snapshot')).toBeInTheDocument()
    expect(await screen.findByText("Today's Net Earning / Margin")).toBeInTheDocument()
    expect(screen.getByText(/vs last week:/i)).toBeInTheDocument()
    expect(screen.getByText('18.2%')).toBeInTheDocument()
    expect(screen.getByText('42 bills today')).toBeInTheDocument()
    expect(screen.getByText('Total Cost (COGS)')).toBeInTheDocument()
    expect(screen.getByText('Cash / UPI Received')).toBeInTheDocument()
    expect(screen.getByText('Credit Sales')).toBeInTheDocument()
  })

  it('renders SO alerts banner and recent pending orders table', async () => {
    renderDashboard(queryClient)

    expect(await screen.findByText('Distribution & Fulfillment Telemetry')).toBeInTheDocument()
    expect(screen.getByText('14')).toBeInTheDocument()
    expect(screen.getByText(/pending dispatch/i)).toBeInTheDocument()
    expect(screen.getByText('3')).toBeInTheDocument()
    expect(screen.getByText(/on backorder/i)).toBeInTheDocument()
    expect(screen.getByText('4')).toBeInTheDocument()
    expect(screen.getByText(/delayed >2 days/i)).toBeInTheDocument()

    // Recent pending order
    expect(await screen.findByText('SO-2026-0042')).toBeInTheDocument()
    expect(screen.getByText('Apollo Hospital Indiranagar')).toBeInTheDocument()
    expect(screen.getByText('3d')).toBeInTheDocument()
  })

  it('renders AR & AP Aging segmented risk bar and supports tab switching', async () => {
    renderDashboard(queryClient)

    expect(await screen.findByText('Accounts Receivable Aging')).toBeInTheDocument()
    expect(screen.getByLabelText('Aging distribution bar')).toBeInTheDocument()
    expect(screen.getByText('Current (Not Due)')).toBeInTheDocument()
    expect(screen.getByText('1–30 Days')).toBeInTheDocument()
    expect(screen.getByText('31–60 Days')).toBeInTheDocument()
    expect(screen.getByText('61–90 Days')).toBeInTheDocument()
    expect(screen.getByText('90+ Days (Critical)')).toBeInTheDocument()

    // Top debtor customer
    expect(await screen.findByText('Top Debtors Outstanding')).toBeInTheDocument()
    expect(screen.getByText('Fortis Hospital Cunningham Road')).toBeInTheDocument()
    expect(screen.getByText('4 invoices')).toBeInTheDocument()

    // Switch to Payables Aging tab
    const apTab = screen.getByRole('tab', { name: /Payables Aging/i })
    fireEvent.click(apTab)

    expect(await screen.findByText('Accounts Payable Aging')).toBeInTheDocument()
  })

  it('renders interactive SVG revenue trend chart and top selling products', async () => {
    renderDashboard(queryClient)

    // SVG Chart
    expect(await screen.findByLabelText('Daily revenue trend chart')).toBeInTheDocument()
    expect(screen.getByText(/Period Total Revenue/i)).toBeInTheDocument()

    // Branch sales rollup
    expect(await screen.findByText('Branch Sales Rollup')).toBeInTheDocument()
    expect(screen.getByText('Main Warehouse')).toBeInTheDocument()
    expect(screen.getByText('City Pharmacy Outlet')).toBeInTheDocument()

    // Top selling
    expect(screen.getByText('Paracetamol 500mg Tablets')).toBeInTheDocument()
    expect(screen.getByText('MED-PAC-500')).toBeInTheDocument()
    expect(screen.getByText('Amoxicillin 250mg Capsules')).toBeInTheDocument()
  })

  it('renders bills to pay, general ledger activity, cash flow, and expiring soon', async () => {
    renderDashboard(queryClient)

    // Bills to pay
    expect(await screen.findByText('BILL-2026-0412')).toBeInTheDocument()
    expect(screen.getByText('Sun Pharma Distribution Ltd')).toBeInTheDocument()

    // Recent journals
    expect(await screen.findByText('JE-2026-1029')).toBeInTheDocument()
    expect(screen.getByText('Bank payment to vendor')).toBeInTheDocument()

    // Cash flow
    expect(screen.getByText('Cash In')).toBeInTheDocument()
    expect(screen.getByText('Cash Out')).toBeInTheDocument()
    expect(screen.getByText('Net Flow')).toBeInTheDocument()

    // Expiring soon
    expect(screen.getByText('Cough Syrup 100ml')).toBeInTheDocument()
    expect(screen.getByText('B-2024-X9')).toBeInTheDocument()
    expect(screen.getByText('41d left')).toBeInTheDocument()
  })

  it('triggers query invalidation when clicking the Refresh button', async () => {
    const invalidateSpy = vi.spyOn(queryClient, 'invalidateQueries')

    renderDashboard(queryClient)

    const refreshBtn = await screen.findByRole('button', { name: /refresh dashboard data/i })
    fireEvent.click(refreshBtn)

    expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ['dashboard'] })
    expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ['branches'] })
  })

  it('handles optional endpoint failure gracefully with dense zero-state fallback', async () => {
    vi.mocked(dashboardApi.getExpiringSoon).mockRejectedValue(new Error('BATCH_EXPIRY module disabled'))
    vi.mocked(dashboardApi.getRecentJournals).mockRejectedValue(new Error('Forbidden'))
    vi.mocked(dashboardApi.getRecentBills).mockRejectedValue(new Error('Network error'))

    renderDashboard(queryClient)

    expect(await screen.findByText('Today’s sales')).toBeInTheDocument()
    expect(screen.getByText('Receivables')).toBeInTheDocument()
    expect(screen.getByText(/100% stock shelf life compliant/i)).toBeInTheDocument()
    expect(screen.getByText(/All vendor obligations up to date/i)).toBeInTheDocument()
    expect(screen.getByText(/Ready for manual or system postings/i)).toBeInTheDocument()
  })
})
