import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { PayrollRunsPage } from './payroll-runs-page'
import * as payrollApi from '@/features/payroll/payroll-api'

vi.mock('@/features/payroll/payroll-api', () => ({
  listPayrollRuns: vi.fn(),
  createPayrollRun: vi.fn(),
}))

const mockPayrollRunsPage = {
  content: [
    {
      id: 'run-1',
      orgId: 'org-1',
      periodStart: '2026-08-01',
      periodEnd: '2026-08-31',
      status: 'POSTED',
      employeeCount: 42,
      grossTotal: 1850000,
      deductionTotal: 245000,
      employerContributionTotal: 140000,
      netPayTotal: 1605000,
    },
    {
      id: 'run-2',
      orgId: 'org-1',
      periodStart: '2026-09-01',
      periodEnd: '2026-09-30',
      status: 'DRAFT',
      employeeCount: 45,
      grossTotal: 1980000,
      deductionTotal: 260000,
      employerContributionTotal: 152000,
      netPayTotal: 1720000,
    },
  ],
  totalElements: 2,
  totalPages: 1,
  size: 50,
  page: 0,
  last: true,
}

function renderWithClient(ui: React.ReactElement) {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false },
    },
  })
  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter>{ui}</MemoryRouter>
    </QueryClientProvider>,
  )
}

describe('PayrollRunsPage', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(payrollApi.listPayrollRuns).mockResolvedValue(mockPayrollRunsPage as unknown as Awaited<ReturnType<typeof payrollApi.listPayrollRuns>>)
  })

  it('renders payroll runs directory with summary metrics and table rows', async () => {
    renderWithClient(<PayrollRunsPage />)

    expect(screen.getByRole('heading', { name: 'Payroll Runs' })).toBeInTheDocument()
    expect(screen.getByText('Payroll Cycles')).toBeInTheDocument()
    expect(screen.getByText('Posted to GL')).toBeInTheDocument()

    // Table rows
    expect(await screen.findByText(/42 Staff/i)).toBeInTheDocument()
    expect(screen.getByText(/45 Staff/i)).toBeInTheDocument()
    expect(screen.getAllByText('Posted').length).toBeGreaterThan(0)
    expect(screen.getAllByText('Draft').length).toBeGreaterThan(0)
  })

  it('filters runs by status tabs', async () => {
    renderWithClient(<PayrollRunsPage />)

    expect(await screen.findByText(/42 Staff/i)).toBeInTheDocument()
    expect(screen.getByText(/45 Staff/i)).toBeInTheDocument()

    // Click Draft tab
    const draftTab = screen.getByRole('tab', { name: 'Draft' })
    fireEvent.click(draftTab)

    expect(screen.queryByText(/42 Staff/i)).not.toBeInTheDocument()
    expect(screen.getByText(/45 Staff/i)).toBeInTheDocument()
  })

  it('opens modal and initializes new payroll run', async () => {
    vi.mocked(payrollApi.createPayrollRun).mockResolvedValue({ id: 'run-3' } as unknown as Awaited<ReturnType<typeof payrollApi.createPayrollRun>>)

    renderWithClient(<PayrollRunsPage />)

    const newBtn = await screen.findByRole('button', { name: /New Payroll Run/i })
    fireEvent.click(newBtn)

    expect(await screen.findByRole('heading', { name: 'Start New Payroll Run' })).toBeInTheDocument()

    const submitBtn = screen.getByRole('button', { name: 'Initialize Run' })
    fireEvent.click(submitBtn)

    await waitFor(() => {
      expect(payrollApi.createPayrollRun).toHaveBeenCalled()
    })
  })
})
