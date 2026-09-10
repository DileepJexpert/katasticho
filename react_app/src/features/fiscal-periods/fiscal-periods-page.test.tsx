import { fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { FiscalPeriodsPage } from './fiscal-periods-page'
import * as fiscalPeriodsApi from './fiscal-periods-api'

vi.mock('./fiscal-periods-api', () => ({
  listPeriods: vi.fn(),
  closePeriod: vi.fn(),
  reopenPeriod: vi.fn(),
  lockPeriod: vi.fn(),
  closeYear: vi.fn(),
  reopenYear: vi.fn(),
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
    vi.mocked(fiscalPeriodsApi.closePeriod).mockResolvedValue({
      id: 'period-2026-06',
      periodYear: 2026,
      periodMonth: 6,
      status: 'CLOSED',
    })
    vi.mocked(fiscalPeriodsApi.reopenPeriod).mockResolvedValue({
      id: 'period-2026-04',
      periodYear: 2026,
      periodMonth: 4,
      status: 'OPEN',
    })
    vi.mocked(fiscalPeriodsApi.lockPeriod).mockResolvedValue({
      id: 'period-2026-04',
      periodYear: 2026,
      periodMonth: 4,
      status: 'LOCKED',
    })
    vi.mocked(fiscalPeriodsApi.closeYear).mockResolvedValue({})
    vi.mocked(fiscalPeriodsApi.reopenYear).mockResolvedValue({
      reversalEntryId: 'entry-rev-1',
      reversalEntryNumber: 'JV-REV-2026',
    })
  })

  it('renders fiscal periods timeline and governance controls', async () => {
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

    // Verify write controls ARE exposed
    expect(screen.getByRole('button', { name: /year-end close/i })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /reopen fy/i })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /close period/i })).toBeInTheDocument()
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

    const detailsButtons = screen.getAllByRole('button', { name: /^details$/i })
    fireEvent.click(detailsButtons[0]!)

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

  it('executes Close Period confirmation flow', async () => {
    render(
      <QueryClientProvider client={queryClient}>
        <FiscalPeriodsPage />
      </QueryClientProvider>
    )

    expect(await screen.findByText('June 2026')).toBeInTheDocument()

    // Click "Close Period" for June 2026 (period 6)
    const closePeriodBtn = screen.getByRole('button', { name: /close period/i })
    fireEvent.click(closePeriodBtn)

    // Check confirmation modal opens
    expect(screen.getByText('Close Period 6')).toBeInTheDocument()
    const confirmBtn = screen.getByRole('button', { name: /confirm close/i })
    fireEvent.click(confirmBtn)

    await waitFor(() => {
      expect(fiscalPeriodsApi.closePeriod).toHaveBeenCalledWith(2026, 6)
    })
    expect(await screen.findByText(/has been closed/i)).toBeInTheDocument()
  })

  it('executes Reopen Period confirmation flow', async () => {
    render(
      <QueryClientProvider client={queryClient}>
        <FiscalPeriodsPage />
      </QueryClientProvider>
    )

    expect(await screen.findByText('April 2026')).toBeInTheDocument()

    // April 2026 is CLOSED, so it has Reopen and Lock buttons
    const reopenBtns = screen.getAllByRole('button', { name: /^reopen$/i })
    fireEvent.click(reopenBtns[0]!)

    expect(screen.getByText('Reopen Period 4')).toBeInTheDocument()
    const confirmBtn = screen.getByRole('button', { name: /confirm reopen/i })
    fireEvent.click(confirmBtn)

    await waitFor(() => {
      expect(fiscalPeriodsApi.reopenPeriod).toHaveBeenCalledWith(2026, 4)
    })
    expect(await screen.findByText(/has been reopened/i)).toBeInTheDocument()
  })

  it('executes Lock Period confirmation flow', async () => {
    render(
      <QueryClientProvider client={queryClient}>
        <FiscalPeriodsPage />
      </QueryClientProvider>
    )

    expect(await screen.findByText('April 2026')).toBeInTheDocument()

    const lockBtn = screen.getByRole('button', { name: /^lock$/i })
    fireEvent.click(lockBtn)

    expect(screen.getByText('Lock Period 4')).toBeInTheDocument()
    const confirmBtn = screen.getByRole('button', { name: /confirm lock/i })
    fireEvent.click(confirmBtn)

    await waitFor(() => {
      expect(fiscalPeriodsApi.lockPeriod).toHaveBeenCalledWith(2026, 4)
    })
    expect(await screen.findByText(/has been locked/i)).toBeInTheDocument()
  })

  it('executes Year-End Close confirmation flow', async () => {
    render(
      <QueryClientProvider client={queryClient}>
        <FiscalPeriodsPage />
      </QueryClientProvider>
    )

    expect(await screen.findByText('April 2026')).toBeInTheDocument()

    const yearCloseBtn = screen.getByRole('button', { name: /year-end close \(fy 2026\)/i })
    fireEvent.click(yearCloseBtn)

    expect(screen.getByText('Year-End Close for FY 2026')).toBeInTheDocument()
    const postCloseBtn = screen.getByRole('button', { name: /post year-end close/i })
    fireEvent.click(postCloseBtn)

    await waitFor(() => {
      expect(fiscalPeriodsApi.closeYear).toHaveBeenCalledWith(2026)
    })
    expect(await screen.findByText(/financial year 2026 has been closed/i)).toBeInTheDocument()
  })

  it('executes Reopen FY confirmation flow', async () => {
    render(
      <QueryClientProvider client={queryClient}>
        <FiscalPeriodsPage />
      </QueryClientProvider>
    )

    expect(await screen.findByText('April 2026')).toBeInTheDocument()

    const reopenYearBtn = screen.getByRole('button', { name: /reopen fy 2026/i })
    fireEvent.click(reopenYearBtn)

    expect(screen.getByText('Reopen Financial Year FY 2026')).toBeInTheDocument()
    const confirmBtn = screen.getByRole('button', { name: /confirm reopen fy/i })
    fireEvent.click(confirmBtn)

    await waitFor(() => {
      expect(fiscalPeriodsApi.reopenYear).toHaveBeenCalledWith(2026)
    })
    expect(await screen.findByText(/financial year 2026 has been reopened/i)).toBeInTheDocument()
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
