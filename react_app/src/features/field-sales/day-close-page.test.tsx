import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { enterpriseUser } from '@/features/accounting/enterprise-test-fixtures'
import { useSessionStore } from '@/shared/session/session-store'
import { DayClosePage } from './day-close-page'
import * as api from './field-sales-api'

vi.mock('./field-sales-api', () => ({
  approveDayClose: vi.fn(), getDayClose: vi.fn(), getExecution: vi.fn(), initiateDayClose: vi.fn(),
  rejectDayClose: vi.fn(), submitDayClose: vi.fn(),
}))

function renderPage() {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false }, mutations: { retry: false } } })
  return render(<QueryClientProvider client={client}><MemoryRouter initialEntries={['/field-sales/day-close?dayCloseId=close-1']}><DayClosePage /></MemoryRouter></QueryClientProvider>)
}

describe('DayClosePage', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    useSessionStore.setState({ status: 'authenticated', user: enterpriseUser })
    vi.mocked(api.getDayClose).mockResolvedValue({ id: 'close-1', routeExecutionId: 'exec-1', salespersonId: 'user-1', status: 'PENDING', openingCash: 100, cashCollections: 250, totalCollections: 300, cashExpenses: 20, closingCash: 0, cashDeposited: 0, cashVariance: 0, closeDate: '2026-09-05' })
    vi.mocked(api.submitDayClose).mockResolvedValue({ id: 'close-1', status: 'SUBMITTED' } as Awaited<ReturnType<typeof api.submitDayClose>>)
  })

  it('shows actual cash fields and submits counted values for server variance calculation', async () => {
    renderPage()

    expect(await screen.findByText('₹250.00')).toBeInTheDocument()
    expect(screen.getByText('₹20.00')).toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: 'Reconcile and submit' }))
    fireEvent.change(screen.getByLabelText('Actual closing cash'), { target: { value: '330' } })
    fireEvent.change(screen.getByLabelText('Actual cash deposited'), { target: { value: '300' } })
    fireEvent.change(screen.getByLabelText('Reconciliation notes'), { target: { value: 'Count checked' } })
    fireEvent.click(screen.getByRole('button', { name: 'Confirm submission' }))
    await waitFor(() => expect(api.submitDayClose).toHaveBeenCalledWith('close-1', { closingCash: 330, cashDeposited: 300, notes: 'Count checked' }))
  })
})
