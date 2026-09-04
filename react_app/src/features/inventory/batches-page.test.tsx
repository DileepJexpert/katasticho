import { fireEvent, render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { BatchesPage } from './batches-page'
import * as batchesApi from './batches-api'

vi.mock('./batches-api', () => ({
  getExpirySummary: vi.fn(),
  getNearExpiryBatches: vi.fn(),
  getBatch: vi.fn(),
  listBatchesByItem: vi.fn(),
}))

const mockSummary: batchesApi.ExpirySummary = {
  expired: 2,
  within7Days: 1,
  within30Days: 4,
  within90Days: 10,
}

const mockBatches: batchesApi.ExpiryBatch[] = [
  {
    batchId: 'b-1',
    itemId: 'item-1',
    itemName: 'Amoxicillin 500mg',
    batchNumber: 'BAT-AMX-001',
    expiryDate: '2026-08-30',
    quantityOnHand: 40,
    daysUntilExpiry: -6,
    urgency: 'EXPIRED',
  },
  {
    batchId: 'b-2',
    itemId: 'item-2',
    itemName: 'Paracetamol 650mg',
    batchNumber: 'BAT-PCM-002',
    expiryDate: '2026-09-10',
    quantityOnHand: 15,
    daysUntilExpiry: 5,
    urgency: 'CRITICAL',
  },
  {
    batchId: 'b-3',
    itemId: 'item-3',
    itemName: 'Azithromycin 250mg',
    batchNumber: 'BAT-AZI-003',
    expiryDate: '2026-09-28',
    quantityOnHand: 60,
    daysUntilExpiry: 23,
    urgency: 'WARNING',
  },
  {
    batchId: 'b-4',
    itemId: 'item-4',
    itemName: 'Vitamin C 500mg',
    batchNumber: 'BAT-VTC-004',
    expiryDate: '2026-11-15',
    quantityOnHand: 120,
    daysUntilExpiry: 71,
    urgency: 'OK',
  },
]

function renderWithClient(ui: React.ReactElement) {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false, gcTime: 0 },
    },
  })

  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter>
        {ui}
      </MemoryRouter>
    </QueryClientProvider>
  )
}

describe('Batches & Expiry Watch Workspace', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(batchesApi.getExpirySummary).mockResolvedValue(mockSummary)
    vi.mocked(batchesApi.getNearExpiryBatches).mockResolvedValue(mockBatches)
  })

  it('renders summary metrics and urgency counts', async () => {
    renderWithClient(<BatchesPage />)

    expect(screen.getByText('Batch & Expiry Watch')).toBeInTheDocument()
    expect(await screen.findByText('BAT-AMX-001')).toBeInTheDocument()

    // Metric values check
    expect(screen.getByText('Expired Stock')).toBeInTheDocument()
    expect(screen.getByText('Critical (≤ 7 Days)')).toBeInTheDocument()
    expect(screen.getByText('Expiring (≤ 30 Days)')).toBeInTheDocument()
    expect(screen.getByText('Watchlist (≤ 90 Days)')).toBeInTheDocument()

    // Advisory banner check
    expect(screen.getByText(/3 batches require immediate management/i)).toBeInTheDocument()
  })

  it('renders the batches table with item information and actions', async () => {
    renderWithClient(<BatchesPage />)

    expect(await screen.findByText('BAT-AMX-001')).toBeInTheDocument()
    expect(screen.getByText('Amoxicillin 500mg')).toBeInTheDocument()
    expect(screen.getByText('Paracetamol 650mg')).toBeInTheDocument()
    expect(screen.getByText('Azithromycin 250mg')).toBeInTheDocument()
    expect(screen.getByText('Vitamin C 500mg')).toBeInTheDocument()
  })

  it('filters batches by search term', async () => {
    renderWithClient(<BatchesPage />)

    await screen.findByText('BAT-AMX-001')

    const searchInput = screen.getByPlaceholderText('Search batch # or item name...')
    fireEvent.change(searchInput, { target: { value: 'Paracetamol' } })

    expect(screen.queryByText('Amoxicillin 500mg')).not.toBeInTheDocument()
    expect(screen.getByText('Paracetamol 650mg')).toBeInTheDocument()
  })

  it('filters batches by urgency tabs', async () => {
    renderWithClient(<BatchesPage />)

    await screen.findByText('BAT-AMX-001')

    const expiredTab = screen.getByRole('tab', { name: 'Expired' })
    fireEvent.click(expiredTab)

    expect(screen.getByText('BAT-AMX-001')).toBeInTheDocument()
    expect(screen.queryByText('BAT-PCM-002')).not.toBeInTheDocument()
    expect(screen.queryByText('BAT-AZI-003')).not.toBeInTheDocument()
    expect(screen.queryByText('BAT-VTC-004')).not.toBeInTheDocument()
  })

  it('triggers re-query when changing the horizon selector', async () => {
    renderWithClient(<BatchesPage />)

    await screen.findByText('BAT-AMX-001')

    const select = screen.getByRole('combobox', { name: /horizon days selector/i })
    fireEvent.change(select, { target: { value: '30' } })

    expect(batchesApi.getNearExpiryBatches).toHaveBeenCalledWith(30)
  })
})
