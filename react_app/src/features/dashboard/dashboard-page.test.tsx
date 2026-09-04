import { fireEvent, render, screen } from '@testing-library/react'
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
}))

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
  })

  it('renders executive greeting and the four core KPI metric cards', async () => {
    render(
      <QueryClientProvider client={queryClient}>
        <DashboardPage />
      </QueryClientProvider>
    )

    expect(await screen.findByText(/Good (morning|afternoon|evening), Vikram/i)).toBeInTheDocument()
    expect(screen.getByText('Executive Overview • Apex Distributors')).toBeInTheDocument()

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

  it('renders the distribution and fulfillment SO alerts banner with overdue indicators', async () => {
    render(
      <QueryClientProvider client={queryClient}>
        <DashboardPage />
      </QueryClientProvider>
    )

    expect(await screen.findByText('14')).toBeInTheDocument()
    expect(screen.getByText(/pending dispatch/i)).toBeInTheDocument()
    expect(screen.getByText('3')).toBeInTheDocument()
    expect(screen.getByText(/on backorder/i)).toBeInTheDocument()
    expect(screen.getByText('4')).toBeInTheDocument()
    expect(screen.getByText(/delayed >2 days/i)).toBeInTheDocument()
    expect(screen.getByText('5')).toBeInTheDocument()
    expect(screen.getByText(/challans in transit/i)).toBeInTheDocument()
  })

  it('renders top selling products table and recent transactions', async () => {
    render(
      <QueryClientProvider client={queryClient}>
        <DashboardPage />
      </QueryClientProvider>
    )

    // Top selling
    expect(await screen.findByText('Paracetamol 500mg Tablets')).toBeInTheDocument()
    expect(screen.getByText('MED-PAC-500')).toBeInTheDocument()
    expect(screen.getByText('Amoxicillin 250mg Capsules')).toBeInTheDocument()

    // Recent transactions
    expect(await screen.findByText('INV-2026-0891')).toBeInTheDocument()
    expect(screen.getByText('Metro Healthcare Ltd')).toBeInTheDocument()
  })

  it('switches revenue trend days filter tabs', async () => {
    render(
      <QueryClientProvider client={queryClient}>
        <DashboardPage />
      </QueryClientProvider>
    )

    expect(await screen.findByText(/Period revenue.*30 days/i)).toBeInTheDocument()

    const tab7d = screen.getByRole('tab', { name: /7 days/i })
    fireEvent.click(tab7d)

    expect(dashboardApi.getRevenueTrend).toHaveBeenCalledWith(7)
  })

  it('renders cash flow snapshot and near-expiry batch watch', async () => {
    render(
      <QueryClientProvider client={queryClient}>
        <DashboardPage />
      </QueryClientProvider>
    )

    // Cash flow
    expect(await screen.findByText('Cash In')).toBeInTheDocument()
    expect(screen.getByText('Cash Out')).toBeInTheDocument()
    expect(screen.getByText('Net Flow')).toBeInTheDocument()

    // Expiring soon
    expect(await screen.findByText('Cough Syrup 100ml')).toBeInTheDocument()
    expect(screen.getByText('B-2024-X9')).toBeInTheDocument()
    expect(screen.getByText('41d left')).toBeInTheDocument()
  })

  it('triggers query invalidation when clicking the Refresh button', async () => {
    const invalidateSpy = vi.spyOn(queryClient, 'invalidateQueries')

    render(
      <QueryClientProvider client={queryClient}>
        <DashboardPage />
      </QueryClientProvider>
    )

    const refreshBtn = await screen.findByRole('button', { name: /refresh dashboard data/i })
    fireEvent.click(refreshBtn)

    expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ['dashboard'] })
  })

  it('handles optional endpoint failure gracefully without breaking dashboard', async () => {
    // Simulate expiring-soon endpoint failing (e.g. 403 Forbidden or module disabled)
    vi.mocked(dashboardApi.getExpiringSoon).mockRejectedValue(new Error('BATCH_EXPIRY module disabled'))

    render(
      <QueryClientProvider client={queryClient}>
        <DashboardPage />
      </QueryClientProvider>
    )

    // Dashboard continues to render today's sales and other cards normally
    expect(await screen.findByText('Today’s sales')).toBeInTheDocument()
    expect(screen.getByText('Receivables')).toBeInTheDocument()
    expect(screen.getByText('No batches expiring soon')).toBeInTheDocument()
  })
})
