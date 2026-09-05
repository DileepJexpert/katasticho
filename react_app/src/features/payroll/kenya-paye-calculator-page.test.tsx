import { render, screen, waitFor } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { KenyaPayeCalculatorPage } from './kenya-paye-calculator-page'
import * as payrollApi from '@/features/payroll/payroll-api'

vi.mock('@/features/payroll/payroll-api', () => ({
  calculateKenyaPaye: vi.fn(),
}))

describe('KenyaPayeCalculatorPage', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    vi.clearAllMocks()
    queryClient = new QueryClient({
      defaultOptions: { queries: { retry: false } },
    })
  })

  it('calculates Kenya PAYE breakdown and updates on salary preset click', async () => {
    vi.mocked(payrollApi.calculateKenyaPaye).mockResolvedValue({
      grossSalary: 85000,
      nssfTier1: 480,
      nssfTier2: 1680,
      totalNssf: 2160,
      taxablePay: 82840,
      grossPaye: 18972,
      personalRelief: 2400,
      insuranceRelief: 0,
      netPaye: 16572,
      shifAmount: 2337.5,
      housingLevyAmount: 1275,
      totalDeductions: 22344.5,
      netPay: 62655.5,
    })

    render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter>
          <KenyaPayeCalculatorPage />
        </MemoryRouter>
      </QueryClientProvider>
    )

    expect(screen.getByText('Kenya PAYE & Statutory Salary Calculator')).toBeInTheDocument()

    await waitFor(() => {
      expect(screen.getByText('KRA Verified')).toBeInTheDocument()
      expect(screen.getByText(/Total Statutory Deductions/i)).toBeInTheDocument()
      expect(screen.getByText(/Net Take-Home Salary/i)).toBeInTheDocument()
    })
  })
})
