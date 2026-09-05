import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter } from 'react-router-dom'
import { NearExpiryPage } from './near-expiry-page'
import * as pharmacyApi from './pharmacy-api'

vi.mock('./pharmacy-api', () => ({
  getExpirySummary: vi.fn(),
  getNearExpiryBatches: vi.fn(),
}))

const mockBatches: pharmacyApi.ExpiryBatch[] = [
  {
    batchId: 'batch-1',
    itemId: 'item-1',
    itemName: 'Amoxicillin Trihydrate 500mg',
    batchNumber: 'BT-AMX-2025-01',
    expiryDate: '2026-09-15',
    quantityOnHand: 450,
    daysUntilExpiry: 10,
    urgency: 'CRITICAL',
  },
]

describe('NearExpiryPage', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } })
    vi.clearAllMocks()

    vi.mocked(pharmacyApi.getExpirySummary).mockResolvedValue({
      expired: 12,
      within7Days: 5,
      within30Days: 24,
      within90Days: 80,
    })

    vi.mocked(pharmacyApi.getNearExpiryBatches).mockResolvedValue(mockBatches)
  })

  function renderPage() {
    return render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter>
          <NearExpiryPage />
        </MemoryRouter>
      </QueryClientProvider>
    )
  }

  it('renders expiry risk summary cards and batch table', async () => {
    renderPage()

    await waitFor(() => {
      expect(screen.getByText('Amoxicillin Trihydrate 500mg')).toBeInTheDocument()
    })

    expect(screen.getByText('BT-AMX-2025-01')).toBeInTheDocument()
    expect(screen.getByText('2026-09-15')).toBeInTheDocument()
    expect(screen.getByText(/Critical \(10d\)/i)).toBeInTheDocument()
    expect(screen.getByText('Already Expired')).toBeInTheDocument()
  })

  it('filters batches by search input', async () => {
    const user = userEvent.setup()
    renderPage()

    await waitFor(() => {
      expect(screen.getByText('Amoxicillin Trihydrate 500mg')).toBeInTheDocument()
    })

    const searchInput = screen.getByPlaceholderText(/Search item or batch\.\.\./i)
    await user.type(searchInput, 'NonExistentDrug')

    await waitFor(() => {
      expect(screen.queryByText('Amoxicillin Trihydrate 500mg')).not.toBeInTheDocument()
    })
  })
})
