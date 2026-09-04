import { fireEvent, render, screen, within } from '@testing-library/react'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { FiscalPeriodsPage } from './fiscal-periods-page'
import * as fiscalPeriodsApi from './fiscal-periods-api'

vi.mock('./fiscal-periods-api', () => ({
  listPeriods: vi.fn(),
}))

const mockPeriods: fiscalPeriodsApi.FiscalPeriod[] = [
  {
    id: 'period-2026-04',
    periodYear: 2026,
    periodMonth: 4,
    status: 'CLOSED',
    closedAt: '2026-05-05T18:30:00Z',
    closedBy: 'user-cfo-1',
    createdAt: '2026-04-01T00:00:00Z',
    updatedAt: '2026-05-05T18:30:00Z',
  },
  {
    id: 'period-2026-05',
    periodYear: 2026,
    periodMonth: 5,
    status: 'LOCKED',
    closedAt: '2026-06-03T14:00:00Z',
    closedBy: 'user-cfo-1',
    createdAt: '2026-05-01T00:00:00Z',
    updatedAt: '2026-06-03T14:00:00Z',
  },
  {
    id: 'period-2026-06',
    periodYear: 2026,
    periodMonth: 6,
    status: 'OPEN',
    closedAt: null,
    closedBy: null,
    createdAt: '2026-06-01T00:00:00Z',
    updatedAt: '2026-06-01T00:00:00Z',
  },
  {
    id: 'period-2025-03',
    periodYear: 2025,
    periodMonth: 3,
    status: 'CLOSED',
    closedAt: '2025-04-04T12:00:00Z',
    closedBy: 'user-cfo-1',
    createdAt: '2025-03-01T00:00:00Z',
    updatedAt: '2025-04-04T12:00:00Z',
  },
]

describe('FiscalPeriodsPage', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    queryClient = new QueryClient({
      defaultOptions: {
        queries: { retry: false },
      },
    })
    vi.clearAllMocks()
    vi.mocked(fiscalPeriodsApi.listPeriods).mockResolvedValue(mockPeriods)
  })

  it('renders fiscal periods timeline and status chips without write controls', async () => {
    render(
      <QueryClientProvider client={queryClient}>
        <FiscalPeriodsPage />
      </QueryClientProvider>
    )

    expect(await screen.findByText('April 2026')).toBeInTheDocument()
    expect(screen.getByText('May 2026')).toBeInTheDocument()
    expect(screen.getByText('June 2026')).toBeInTheDocument()

    // Period numbers and quarters
    expect(screen.getByText('Period 4')).toBeInTheDocument()
    expect(screen.getByText('Period 5')).toBeInTheDocument()
    expect(screen.getByText('Period 6')).toBeInTheDocument()
    expect(screen.getAllByText('Q1 (Apr - Jun)').length).toBe(3)

    // Summary statistics for FY 2026
    expect(screen.getByText('Open periods')).toBeInTheDocument()
    expect(screen.getByText('Closed periods')).toBeInTheDocument()
    expect(screen.getByText('Locked periods')).toBeInTheDocument()

    // Status chips
    expect(screen.getByText('OPEN')).toBeInTheDocument()
    expect(screen.getByText('CLOSED')).toBeInTheDocument()
    expect(screen.getByText('LOCKED')).toBeInTheDocument()

    // Verify NO write controls are exposed
    expect(screen.queryByRole('button', { name: /close period/i })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /reopen period/i })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /lock period/i })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /year-end close/i })).not.toBeInTheDocument()
  })

  it('switches financial year using year picker tabs', async () => {
    render(
      <QueryClientProvider client={queryClient}>
        <FiscalPeriodsPage />
      </QueryClientProvider>
    )

    expect(await screen.findByText('April 2026')).toBeInTheDocument()

    // Switch to FY 2025
    const fy2025Tab = screen.getByRole('tab', { name: /fy 2025/i })
    fireEvent.click(fy2025Tab)

    expect(screen.getByText('March 2025')).toBeInTheDocument()
    expect(screen.queryByText('April 2026')).not.toBeInTheDocument()
  })

  it('filters periods by status tabs within the active year', async () => {
    render(
      <QueryClientProvider client={queryClient}>
        <FiscalPeriodsPage />
      </QueryClientProvider>
    )

    expect(await screen.findByText('April 2026')).toBeInTheDocument()

    // Filter to Open only
    const openTab = screen.getByRole('tab', { name: /^open/i })
    fireEvent.click(openTab)

    expect(screen.getByText('June 2026')).toBeInTheDocument()
    expect(screen.queryByText('April 2026')).not.toBeInTheDocument()
    expect(screen.queryByText('May 2026')).not.toBeInTheDocument()
  })

  it('opens and closes period details modal', async () => {
    render(
      <QueryClientProvider client={queryClient}>
        <FiscalPeriodsPage />
      </QueryClientProvider>
    )

    expect(await screen.findByText('April 2026')).toBeInTheDocument()

    const viewButtons = screen.getAllByRole('button', { name: /view details/i })
    fireEvent.click(viewButtons[0]!)

    const dialog = screen.getByRole('dialog')
    expect(dialog).toBeInTheDocument()
    expect(within(dialog).getByText('April 2026 (Period 4)')).toBeInTheDocument()
    expect(within(dialog).getByText('Financial year')).toBeInTheDocument()
    expect(within(dialog).getByText('Governance status')).toBeInTheDocument()
    expect(within(dialog).getByText('user-cfo-1')).toBeInTheDocument()

    // Close modal
    const closeBtn = screen.getByRole('button', { name: 'Close' })
    fireEvent.click(closeBtn)
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
  })

  it('renders empty state when search matches no periods', async () => {
    render(
      <QueryClientProvider client={queryClient}>
        <FiscalPeriodsPage />
      </QueryClientProvider>
    )

    expect(await screen.findByText('April 2026')).toBeInTheDocument()

    const searchInput = screen.getByPlaceholderText(/search period month or quarter/i)
    fireEvent.change(searchInput, { target: { value: 'Nonexistent Month' } })

    expect(screen.getByText('No periods found')).toBeInTheDocument()
  })
})
