import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { LaborPayPreviewPage } from './labor-pay-preview-page'
import * as payrollApi from '@/features/payroll/payroll-api'

vi.mock('@/features/payroll/payroll-api', () => ({
  listEmployees: vi.fn(),
  previewLaborPay: vi.fn(),
}))

describe('LaborPayPreviewPage', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    vi.clearAllMocks()
    queryClient = new QueryClient({
      defaultOptions: { queries: { retry: false } },
    })
  })

  it('renders worker selector and displays computed preview upon selection', async () => {
    vi.mocked(payrollApi.listEmployees).mockResolvedValue({
      content: [
        {
          id: 'worker-1',
          orgId: 'org-1',
          fullName: 'Vikram Singh',
          employeeCode: 'WRK-001',
          designation: 'Machine Operator',
          status: 'ACTIVE',
        },
      ],
      page: 0,
      size: 50,
      totalElements: 1,
      totalPages: 1,
      last: true,
    })

    vi.mocked(payrollApi.previewLaborPay).mockResolvedValue({
      totalHours: 160,
      totalPieces: 450,
      jobCardCount: 18,
      amount: 22500,
      payType: 'PIECE_RATE',
    })

    render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter>
          <LaborPayPreviewPage />
        </MemoryRouter>
      </QueryClientProvider>
    )

    expect(screen.getByText('Production Labor Pay & Piece-Rate Preview')).toBeInTheDocument()

    await waitFor(() => {
      expect(screen.getByText(/Vikram Singh/i)).toBeInTheDocument()
    })

    fireEvent.change(screen.getByLabelText(/Select Worker/i), {
      target: { value: 'worker-1' },
    })

    fireEvent.click(screen.getByText('Preview Wages'))

    await waitFor(() => {
      expect(screen.getByText('160 hrs')).toBeInTheDocument()
      expect(screen.getByText('450 units')).toBeInTheDocument()
      expect(screen.getByText('18')).toBeInTheDocument()
    })
  })
})
