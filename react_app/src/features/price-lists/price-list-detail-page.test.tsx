import { beforeEach, describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { PriceListDetailPage } from './price-list-detail-page'
import * as priceListsApi from './price-lists-api'

vi.mock('./price-lists-api', async () => {
  const actual = await vi.importActual<typeof priceListsApi>('./price-lists-api')
  return {
    ...actual,
    getPriceList: vi.fn(),
    listPriceListCustomers: vi.fn(),
    listPriceListItems: vi.fn(),
  }
})

const mockPriceList: priceListsApi.PriceList = {
  id: 'price-list-1', name: 'Wholesale customers', description: 'Approved wholesale rates', currency: 'INR',
  isDefault: false, active: true, createdAt: '2026-09-04T09:00:00Z',
}

describe('PriceListDetailPage', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } })
    vi.clearAllMocks()
    vi.mocked(priceListsApi.getPriceList).mockResolvedValue(mockPriceList)
    vi.mocked(priceListsApi.listPriceListItems).mockResolvedValue([
      { id: 'tier-1', priceListId: mockPriceList.id, itemId: 'item-1', itemSku: 'MASALA-100G', itemName: 'Turmeric Masala 100g', minQuantity: 10, price: 40 },
    ])
    vi.mocked(priceListsApi.listPriceListCustomers).mockResolvedValue([])
  })

  function renderPage() {
    return render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter initialEntries={['/price-lists/price-list-1']}>
          <Routes><Route path="/price-lists/:priceListId" element={<PriceListDetailPage />} /></Routes>
        </MemoryRouter>
      </QueryClientProvider>,
    )
  }

  it('shows contract-backed facts without unsupported pricing controls', async () => {
    renderPage()

    expect(await screen.findByRole('heading', { name: 'Wholesale customers' })).toBeInTheDocument()
    expect(screen.getByText('Read-only review. Price-list and customer-assignment changes remain in Flutter during migration.')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /create|add item|assign customer|remove/i })).not.toBeInTheDocument()
  })

  it('loads item tiers only after the tab is selected', async () => {
    const user = userEvent.setup()
    renderPage()
    await screen.findByRole('heading', { name: 'Wholesale customers' })

    await user.click(screen.getByRole('tab', { name: 'Item tiers' }))

    expect(await screen.findByText('Turmeric Masala 100g')).toBeInTheDocument()
    expect(priceListsApi.listPriceListItems).toHaveBeenCalledWith('price-list-1')
  })

  it('shows a failure rather than an empty state when item tiers cannot be read', async () => {
    vi.mocked(priceListsApi.listPriceListItems).mockRejectedValue(new Error('Network error'))
    const user = userEvent.setup()
    renderPage()
    await screen.findByRole('heading', { name: 'Wholesale customers' })

    await user.click(screen.getByRole('tab', { name: 'Item tiers' }))

    expect(await screen.findByRole('alert')).toHaveTextContent('Item tiers could not be loaded.')
  })
})
