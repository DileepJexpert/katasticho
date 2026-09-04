import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { StockCountsPage } from './stock-counts-page'
import { StockCountDetailPage } from './stock-count-detail-page'
import * as stockCountsApi from './stock-counts-api'

vi.mock('./stock-counts-api', () => ({
  listStockCounts: vi.fn(),
  getStockCount: vi.fn(),
  createStockCount: vi.fn(),
  updateStockCountLines: vi.fn(),
  postStockCount: vi.fn(),
  cancelStockCount: vi.fn(),
}))

vi.mock('@/features/warehouses/warehouses-api', () => ({
  listWarehouses: vi.fn().mockResolvedValue([
    { id: 'wh-1', name: 'Central Warehouse', code: 'WH-01' },
  ]),
}))

const mockStockCounts: stockCountsApi.StockCount[] = [
  {
    id: 'sc-1',
    countNumber: 'SC-2026-0001',
    warehouseId: 'wh-1',
    warehouseName: 'Central Warehouse',
    status: 'IN_PROGRESS',
    notes: 'Q3 Physical Inventory Audit',
    createdAt: '2026-09-04T10:00:00Z',
    postedAt: null,
    lines: [
      {
        id: 'line-1',
        itemId: 'item-1',
        itemName: 'Amoxicillin 500mg',
        itemSku: 'MED-AMX-500',
        systemQuantity: 100,
        countedQuantity: 98,
        discrepancyQuantity: -2,
        discrepancyValue: -230,
        notes: 'Damaged packaging during transit',
      },
      {
        id: 'line-2',
        itemId: 'item-2',
        itemName: 'Paracetamol 650mg',
        itemSku: 'MED-PCM-650',
        systemQuantity: 50,
        countedQuantity: 50,
        discrepancyQuantity: 0,
        discrepancyValue: 0,
        notes: null,
      },
    ],
  },
  {
    id: 'sc-2',
    countNumber: 'SC-2026-0002',
    warehouseId: 'wh-1',
    warehouseName: 'Central Warehouse',
    status: 'POSTED',
    notes: 'Year-End Reconciliation',
    createdAt: '2026-08-31T09:00:00Z',
    postedAt: '2026-08-31T17:00:00Z',
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

    expect(screen.getByText('Physical Stock Counts & Audits')).toBeInTheDocument()
    expect(await screen.findByText('SC-2026-0001')).toBeInTheDocument()
    expect(screen.getByText('SC-2026-0002')).toBeInTheDocument()
    expect(screen.getAllByText('Central Warehouse').length).toBeGreaterThan(0)
  })

  it('opens create modal when clicking Start Stock Count', async () => {
    renderWithClient(<StockCountsPage />)

    await screen.findByText('SC-2026-0001')

    const startBtn = screen.getByRole('button', { name: /start stock count/i })
    fireEvent.click(startBtn)

    expect(screen.getByText('Start Physical Stock Count')).toBeInTheDocument()
  })

  it('renders stock count detail view with variance matrix', async () => {
    vi.mocked(stockCountsApi.getStockCount).mockResolvedValue(mockStockCounts[0])

    renderWithClient(
      <Routes>
        <Route path="/stock-counts/:countId" element={<StockCountDetailPage />} />
      </Routes>,
      '/stock-counts/sc-1'
    )

    expect(await screen.findByText('SC-2026-0001')).toBeInTheDocument()
    expect(screen.getByText('Amoxicillin 500mg')).toBeInTheDocument()
    expect(screen.getByText('Paracetamol 650mg')).toBeInTheDocument()
    expect(screen.getByText('Post & Reconcile Journal')).toBeInTheDocument()
    expect(screen.getByText('Cancel Audit')).toBeInTheDocument()
  })

  it('allows posting and reconciling journal for in-progress count', async () => {
    vi.mocked(stockCountsApi.getStockCount).mockResolvedValue(mockStockCounts[0])
    vi.mocked(stockCountsApi.postStockCount).mockResolvedValue({
      ...mockStockCounts[0],
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

    const postBtn = screen.getByRole('button', { name: /post & reconcile journal/i })
    fireEvent.click(postBtn)

    await waitFor(() => {
      expect(stockCountsApi.postStockCount).toHaveBeenCalledWith('sc-1')
    })
  })
})
