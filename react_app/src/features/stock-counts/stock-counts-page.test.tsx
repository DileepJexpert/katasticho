import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { StockCountsPage } from './stock-counts-page'
import { StockCountDetailPage } from './stock-count-detail-page'
import * as stockCountsApi from './stock-counts-api'
import { useInventoryAccess } from '@/features/inventory/inventory-access'
import { listItems, type Item } from '@/features/items/items-api'

vi.mock('@/features/inventory/inventory-access', () => ({ useInventoryAccess: vi.fn() }))

vi.mock('./stock-counts-api', () => ({
  listStockCounts: vi.fn(),
  getStockCount: vi.fn(),
  createStockCount: vi.fn(),
  postStockCount: vi.fn(),
  cancelStockCount: vi.fn(),
}))

vi.mock('@/features/warehouses/warehouses-api', () => ({
  listWarehouses: vi.fn().mockResolvedValue([
    { id: 'wh-1', name: 'Central Warehouse', code: 'WH-01', active: true, isDefault: true },
  ]),
}))

vi.mock('@/features/items/items-api', () => ({
  listItems: vi.fn().mockResolvedValue({ content: [] }),
}))

const mockStockCounts: stockCountsApi.StockCount[] = [
  {
    id: 'sc-1',
    countNumber: 'SC-2026-0001',
    warehouseId: 'wh-1',
    warehouseName: 'Central Warehouse',
    countDate: '2026-09-04',
    status: 'DRAFT',
    notes: 'Q3 Physical Inventory Audit',
    createdAt: '2026-09-04T10:00:00Z',
    postedAt: null,
    lineCount: 2,
    varianceCount: 1,
    lines: [
      {
        id: 'line-1',
        itemId: 'item-1',
        itemName: 'Amoxicillin 500mg',
        sku: 'MED-AMX-500',
        expectedQuantity: 100,
        countedQuantity: 98,
        variance: -2,
        notes: 'Damaged packaging during transit',
      },
      {
        id: 'line-2',
        itemId: 'item-2',
        itemName: 'Paracetamol 650mg',
        sku: 'MED-PCM-650',
        expectedQuantity: 50,
        countedQuantity: 50,
        variance: 0,
        notes: null,
      },
    ],
  },
  {
    id: 'sc-2',
    countNumber: 'SC-2026-0002',
    warehouseId: 'wh-1',
    warehouseName: 'Central Warehouse',
    countDate: '2026-08-31',
    status: 'POSTED',
    notes: 'Year-End Reconciliation',
    createdAt: '2026-08-31T09:00:00Z',
    postedAt: '2026-08-31T17:00:00Z',
    lineCount: 0,
    varianceCount: 0,
    lines: [],
  },
]

function renderWithClient(ui: React.ReactElement, initialRoute = '/') {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false, gcTime: 0 },
      mutations: { retry: false },
    },
  })

  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter initialEntries={[initialRoute]}>
        {ui}
      </MemoryRouter>
    </QueryClientProvider>
  )
}

describe('Stock Counts & Audits Workspace', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(useInventoryAccess).mockReturnValue({ operate: true, manage: true, administer: true, readZones: true })
    vi.mocked(stockCountsApi.listStockCounts).mockResolvedValue({
      content: mockStockCounts,
      page: 0,
      size: 25,
      totalElements: 2,
      totalPages: 1,
      last: true,
    })
  })

  it('renders the stock count audit register', async () => {
    renderWithClient(<StockCountsPage />)

    expect(screen.getByText('Physical Stock Counts')).toBeInTheDocument()
    expect(await screen.findByText('SC-2026-0001')).toBeInTheDocument()
    expect(screen.getByText('SC-2026-0002')).toBeInTheDocument()
    expect(screen.getAllByText('Central Warehouse').length).toBeGreaterThan(0)
  })

  it('opens create modal when clicking Start Stock Count', async () => {
    renderWithClient(<StockCountsPage />)

    await screen.findByText('SC-2026-0001')

    const startBtn = screen.getByRole('button', { name: /new stock count/i })
    fireEvent.click(startBtn)

    expect(screen.getByText('New physical stock count')).toBeInTheDocument()
  })

  it('renders stock count detail view with variance matrix', async () => {
    vi.mocked(stockCountsApi.getStockCount).mockResolvedValue(mockStockCounts[0]!)

    renderWithClient(
      <Routes>
        <Route path="/stock-counts/:countId" element={<StockCountDetailPage />} />
      </Routes>,
      '/stock-counts/sc-1'
    )

    expect(await screen.findByText('SC-2026-0001')).toBeInTheDocument()
    expect(screen.getByText('Amoxicillin 500mg')).toBeInTheDocument()
    expect(screen.getByText('Paracetamol 650mg')).toBeInTheDocument()
    expect(screen.getByText('Post adjustments')).toBeInTheDocument()
    expect(screen.getByText('Cancel draft')).toBeInTheDocument()
  })

  it('requires confirmation before posting a draft count', async () => {
    vi.mocked(stockCountsApi.getStockCount).mockResolvedValue(mockStockCounts[0]!)
    vi.mocked(stockCountsApi.postStockCount).mockResolvedValue({
      ...mockStockCounts[0]!,
      status: 'POSTED',
      postedAt: '2026-09-05T00:00:00Z',
    })

    renderWithClient(
      <Routes>
        <Route path="/stock-counts/:countId" element={<StockCountDetailPage />} />
      </Routes>,
      '/stock-counts/sc-1'
    )

    await screen.findByText('SC-2026-0001')

    const postBtn = screen.getByRole('button', { name: /post adjustments/i })
    fireEvent.click(postBtn)

    expect(screen.getByText('Post stock count adjustments?')).toBeInTheDocument()
    fireEvent.click(screen.getAllByRole('button', { name: /post adjustments/i })[1]!)

    await waitFor(() => {
      expect(stockCountsApi.postStockCount).toHaveBeenCalledWith('sc-1')
    })
  })

  it('does not allow operators to post or cancel counts', async () => {
    vi.mocked(useInventoryAccess).mockReturnValue({ operate: true, manage: false, administer: false, readZones: true })
    vi.mocked(stockCountsApi.getStockCount).mockResolvedValue(mockStockCounts[0]!)
    renderWithClient(<Routes><Route path="/stock-counts/:countId" element={<StockCountDetailPage />} /></Routes>, '/stock-counts/sc-1')
    await screen.findByText('SC-2026-0001')
    expect(screen.queryByRole('button', { name: 'Post adjustments' })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Cancel draft' })).not.toBeInTheDocument()
    expect(screen.queryByText('Net variance')).not.toBeInTheDocument()
  })

  it('hides both creation entry points for viewers, including the empty register', async () => {
    vi.mocked(useInventoryAccess).mockReturnValue({ operate: false, manage: false, administer: false, readZones: false })
    vi.mocked(stockCountsApi.listStockCounts).mockResolvedValue({ content: [], page: 0, size: 25, totalElements: 0, totalPages: 0, last: true })
    renderWithClient(<StockCountsPage />)
    await screen.findByText('No stock counts recorded')
    expect(screen.queryByRole('button', { name: /new stock count|start a count/i })).not.toBeInTheDocument()
  })

  it('blocks batch-tracked counts instead of creating a draft that cannot post a variance', async () => {
    vi.mocked(listItems).mockResolvedValue({ content: [{ id: 'batched-item', name: 'Tracked spice', active: true, trackInventory: true, trackBatches: true } as Item], page: 0, size: 20, totalElements: 1, totalPages: 1, last: true })
    renderWithClient(<StockCountsPage />)
    fireEvent.click(screen.getByRole('button', { name: /new stock count/i }))
    fireEvent.focus(screen.getByRole('combobox', { name: 'Search items to add to stock count' }))
    fireEvent.click(await screen.findByRole('option', { name: /Tracked spice/ }))
    expect(screen.getByRole('alert')).toHaveTextContent('not supported by the existing stock-count API')
    expect(screen.queryByRole('spinbutton', { name: 'Physical quantity for Tracked spice' })).not.toBeInTheDocument()
    expect(stockCountsApi.createStockCount).not.toHaveBeenCalled()
  })

  it('preserves an explicit zero physical count in the draft request', async () => {
    vi.mocked(listItems).mockResolvedValue({ content: [{ id: 'plain-item', name: 'Loose spice', active: true, trackInventory: true, trackBatches: false } as Item], page: 0, size: 20, totalElements: 1, totalPages: 1, last: true })
    vi.mocked(stockCountsApi.createStockCount).mockResolvedValue(mockStockCounts[0]!)
    renderWithClient(<StockCountsPage />)
    fireEvent.click(screen.getByRole('button', { name: /new stock count/i }))
    fireEvent.focus(screen.getByRole('combobox', { name: 'Search items to add to stock count' }))
    fireEvent.click(await screen.findByRole('option', { name: /Loose spice/ }))
    fireEvent.change(screen.getByRole('spinbutton', { name: 'Physical quantity for Loose spice' }), { target: { value: '0' } })
    fireEvent.click(screen.getByRole('button', { name: 'Create draft count' }))
    await waitFor(() => expect(stockCountsApi.createStockCount).toHaveBeenCalledWith(expect.objectContaining({ warehouseId: 'wh-1', lines: [{ itemId: 'plain-item', countedQuantity: 0, notes: undefined }] })))
  })
})
