import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { TaxDeclarationPage } from './tax-declaration-page'
import * as payrollApi from '@/features/payroll/payroll-api'

vi.mock('@/features/payroll/payroll-api', () => ({
  getMyTaxDeclaration: vi.fn(),
  saveMyTaxDeclaration: vi.fn(),
  submitTaxDeclaration: vi.fn(),
  listTaxDeclarations: vi.fn(),
  verifyTaxDeclaration: vi.fn(),
  getForm12BbPdfUrl: vi.fn((id: string) => `/api/v1/payroll/tax-declarations/${id}/pdf`),
}))

describe('TaxDeclarationPage', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    vi.clearAllMocks()
    queryClient = new QueryClient({
      defaultOptions: { queries: { retry: false } },
    })
  })

  it('renders My Declaration with regime options and deduction inputs', async () => {
    vi.mocked(payrollApi.getMyTaxDeclaration).mockResolvedValue({
      id: 'decl-1',
      orgId: 'org-1',
      employeeId: 'emp-1',
      fiscalYear: '2026-27',
      taxRegime: 'OLD',
      deduction80c: 120000,
      hraRentPaid: 180000,
      status: 'DRAFT',
    })

    render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter>
          <TaxDeclarationPage />
        </MemoryRouter>
      </QueryClientProvider>
    )

    expect(screen.getByText('Tax Declaration (Form 12BB)')).toBeInTheDocument()

    await waitFor(() => {
      expect(screen.getByRole('radio', { name: /Old Regime/i })).toBeInTheDocument()
      expect(screen.getByDisplayValue('120000')).toBeInTheDocument()
      expect(screen.getByText('Save Draft')).toBeInTheDocument()
    })
  })

  it('switches to HR Review tab and lists declarations', async () => {
    vi.mocked(payrollApi.getMyTaxDeclaration).mockResolvedValue(null)
    vi.mocked(payrollApi.listTaxDeclarations).mockResolvedValue([
      {
        id: 'decl-2',
        orgId: 'org-1',
        employeeId: 'emp-2',
        fiscalYear: '2026-27',
        taxRegime: 'NEW',
        deduction80c: 0,
        status: 'SUBMITTED',
      },
    ])

    render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter>
          <TaxDeclarationPage />
        </MemoryRouter>
      </QueryClientProvider>
    )

    fireEvent.click(screen.getByText(/HR Review & Verification/i))

    await waitFor(() => {
      expect(screen.getByText('emp-2')).toBeInTheDocument()
      expect(screen.getByText('NEW Regime')).toBeInTheDocument()
      expect(screen.getByText('Verify')).toBeInTheDocument()
    })
  })
})
