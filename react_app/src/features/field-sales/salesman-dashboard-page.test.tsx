import { fireEvent, render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { SalesmanDashboardPage } from './salesman-dashboard-page'
import * as fieldSalesApi from '@/features/field-sales/field-sales-api'

vi.mock('@/features/field-sales/field-sales-api', () => ({
  getSecondaryDashboard: vi.fn(),
  listExecutions: vi.fn(),
  listSalesmanTargets: vi.fn(),
}))

const mockDashboardData: Partial<fieldSalesApi.SecondaryDashboardData> = {
  totalBookedAmount: 185000,
  totalOrdersBooked: 24,
  totalVisitsPlanned: 40,
  totalVisitsActual: 36,
  averageOrderValue: 7708.33,
  strikeRatePercent: 66.7,
  activeSalespersons: 5,
  totalOrdersValue: 185000,
  totalCollections: 125000,
}

const mockTargets = {
  content: [
    {
      id: 'target-1',
      salespersonId: 'sp-1',
      salespersonName: 'Rohan Sharma',
      periodType: 'MONTHLY',
      periodStart: '2026-09-01',
      periodEnd: '2026-09-30',
      targetType: 'REVENUE',
      targetValue: 250000,
      achievedValue: 185000,
      achievementPercent: 74,
      targetPeriod: 'Sep 2026',
      metricType: 'Secondary Revenue',
    },
  ],
  totalElements: 1,
  totalPages: 1,
  size: 10,
  number: 0,
}

const mockExecutions = {
  content: [
    {
      id: 'exec-1',
      executionNumber: 'EX-20260904-01',
      routeId: 'route-1',
      routeName: 'South Metro Beat Route',
      salespersonId: 'sp-1',
      salespersonName: 'Rohan Sharma',
      executionDate: '2026-09-04',
      status: 'IN_PROGRESS',
      totalStops: 12,
      completedStops: 8,
      ordersBooked: 6,
      totalOrderValue: 42000,
    },
  ],
  totalElements: 1,
  totalPages: 1,
  size: 10,
  number: 0,
}

function renderDashboard() {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: {
        retry: false,
      },
    },
  })

  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter>
        <SalesmanDashboardPage />
      </MemoryRouter>
    </QueryClientProvider>,
  )
}

describe('SalesmanDashboardPage', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(fieldSalesApi.getSecondaryDashboard).mockResolvedValue(
      mockDashboardData as unknown as fieldSalesApi.SecondaryDashboardData
    )
    vi.mocked(fieldSalesApi.listSalesmanTargets).mockResolvedValue(
      mockTargets as unknown as fieldSalesApi.PageResponse<fieldSalesApi.SalesmanTarget>
    )
    vi.mocked(fieldSalesApi.listExecutions).mockResolvedValue(
      mockExecutions as unknown as fieldSalesApi.PageResponse<fieldSalesApi.RouteExecution>
    )
  })

  it('renders dashboard title, KPI cards, and executions table', async () => {
    renderDashboard()

    expect(screen.getByText('Field Sales Dashboard')).toBeInTheDocument()
    expect(await screen.findByText('South Metro Beat Route')).toBeInTheDocument()
    expect(screen.getAllByText('Rohan Sharma').length).toBeGreaterThan(0)
    expect(screen.getByText('Call Productivity')).toBeInTheDocument()
    expect(screen.getByText('Target Achievement Matrix')).toBeInTheDocument()
  })

  it('refetches dashboard when date range inputs are changed', async () => {
    renderDashboard()

    await screen.findByText('South Metro Beat Route')
    expect(fieldSalesApi.getSecondaryDashboard).toHaveBeenCalledTimes(1)

    const fromInput = screen.getByLabelText('From date')
    fireEvent.change(fromInput, { target: { value: '2026-08-01' } })

    expect(fieldSalesApi.getSecondaryDashboard).toHaveBeenCalledWith('2026-08-01', expect.any(String))
  })

  it('renders refresh button and triggers refresh on click', async () => {
    renderDashboard()

    const refreshButton = screen.getByRole('button', { name: /Refresh dashboard data/i })
    expect(refreshButton).toBeInTheDocument()
    fireEvent.click(refreshButton)

    expect(fieldSalesApi.getSecondaryDashboard).toHaveBeenCalled()
  })
})
