import { beforeEach, describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { PaymentTermsPage } from './payment-terms-page'
import * as paymentTermsApi from './payment-terms-api'

vi.mock('./payment-terms-api', async () => {
  const actual = await vi.importActual<typeof paymentTermsApi>('./payment-terms-api')
  return { ...actual, listPaymentTerms: vi.fn() }
})

describe('PaymentTermsPage', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } })
    vi.clearAllMocks()
    vi.mocked(paymentTermsApi.listPaymentTerms).mockResolvedValue([
      {
        id: 'term-1', name: '30 days', description: 'Standard wholesale terms', isDefault: true, active: true,
        lines: [{ id: 'line-1', seq: 0, valueType: 'BALANCE', value: null, daysOffset: 30 }],
      },
      {
        id: 'term-2', name: 'Legacy terms', description: null, isDefault: false, active: false,
        lines: [{ id: 'line-2', seq: 0, valueType: 'PERCENT', value: 100, daysOffset: 0 }],
      },
    ])
  })

  function renderPage() {
    return render(
      <QueryClientProvider client={queryClient}>
        <PaymentTermsPage />
      </QueryClientProvider>,
    )
  }

  it('shows backend schedule lines without payment-term write controls', async () => {
    renderPage()

    expect(await screen.findByText('Remaining balance due in 30 days')).toBeInTheDocument()
    expect(screen.getByRole('heading', { name: 'Payment terms' })).toBeInTheDocument()
    expect(screen.getByText('100% due on invoice date')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /new term|create term|edit term|delete term/i })).not.toBeInTheDocument()
  })

  it('filters the already-loaded terms without changing the backend request', async () => {
    const user = userEvent.setup()
    renderPage()
    await screen.findByText('30 days')

    await user.click(screen.getByRole('tab', { name: /inactive/i }))

    expect(screen.queryByText('30 days')).not.toBeInTheDocument()
    expect(screen.getByText('Legacy terms')).toBeInTheDocument()
    expect(paymentTermsApi.listPaymentTerms).toHaveBeenCalledWith()
  })
})
