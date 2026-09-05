import { render, screen, waitFor } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { HrAnalyticsPage } from './hr-analytics-page'
import * as hrApi from '@/features/hr/hr-api'

vi.mock('@/features/hr/hr-api', () => ({
  getHrAnalyticsDashboard: vi.fn(),
}))

describe('HrAnalyticsPage', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    vi.clearAllMocks()
    queryClient = new QueryClient({
      defaultOptions: { queries: { retry: false } },
    })
  })

  it('renders workforce metrics and department breakdown', async () => {
    vi.mocked(hrApi.getHrAnalyticsDashboard).mockResolvedValue({
      headcount: 42,
      byDepartment: { Engineering: 20, Operations: 15, Sales: 7 },
      onLeaveToday: 3,
      pendingLeaves: 5,
      pendingRegularizations: 2,
      pendingTimesheets: 8,
      openTickets: 4,
      documentsExpiringIn30Days: 1,
    })

    render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter>
          <HrAnalyticsPage />
        </MemoryRouter>
      </QueryClientProvider>
    )

    expect(screen.getByText('HR Analytics & Workforce Pulse')).toBeInTheDocument()

    await waitFor(() => {
      expect(screen.getByText('42')).toBeInTheDocument()
      expect(screen.getByText('Engineering')).toBeInTheDocument()
      expect(screen.getByText('Operations')).toBeInTheDocument()
    })
  })
})
