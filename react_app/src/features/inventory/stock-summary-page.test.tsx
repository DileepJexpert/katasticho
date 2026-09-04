import { fireEvent, render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { StockSummaryPage } from './stock-summary-page'
import * as stockSummaryApi from './stock-summary-api'

vi.mock('./stock-summary-api', () => ({
  getStockSummary: vi.fn(),
  getLowStockAlert: vi.fn(),
  getFifoValuation: vi.fn(),
  listWarehouses: vi.fn(),
}))

const mockStockSummary: stockSummaryApi.StockSummaryReport = {
  asOfDate: '2026-09-05',
  totalInventoryValue: 245000,
  itemCount: 3,
  lowStockCount: 1,
  outOfStockCount: 1,
  items: [
    {
      itemId: 'item-1',
      itemName: 'Amoxicillin 500mg',
      sku: 'MED-AMX-500',
      unit: 'Box',
      quantityOnHand: 150,
      purchasePrice: 120,
      averageCost: 115,
      inventoryValue: 17250,
      reorderLevel: 50,
      status: 'OPTIMAL',
      lastMovementAt: '2026-09-04T10:00:00Z',
    },
    {
      itemId: 'item-2',
      itemName: 'Paracetamol 650mg',
      sku: 'MED-PCM-650',
      unit: 'Strip',
      quantityOnHand: 20,
      purchasePrice: 25,
      averageCost: 25,
      inventoryValue: 500,
      reorderLevel: 50,
      status: 'LOW_STOCK',
      lastMovementAt: '2026-09-03T14:30:00Z',
    },
    {
      itemId: 'item-3',
      itemName: 'Cough Syrup 100ml',
      sku: 'MED-SYR-100',
      unit: 'Bottle',
      quantityOnHand: 0,
      purchasePrice: 65,
      averageCost: 65,
      inventoryValue: 0,
      reorderLevel: 25,
      status: 'OUT_OF_STOCK',
      lastMovementAt: null,
    },
  ],
}

const mockLowStockAlert: stockSummaryApi.LowStockAlertReport = {
  generatedAt: '2026-09-05',
  itemCount: 2,
  estimatedPurchaseCost: 15000,
  items: [
    {
      itemId: 'item-2',
      itemName: 'Paracetamol 650mg',
      sku: 'MED-PCM-650',
      currentStock: 20,
      reorderLevel: 50,
      reorderQuantity: 100,
      deficitQty: 30,
      supplierId: 'sup-1',
      supplierName: 'Sun Pharma Ltd',
      estimatedCost: 2500,
    },
  ],
}

const mockFifoValuation: stockSummaryApi.FifoValuationReport = {
  reportKey: 'fifo-valuation',
  title: 'FIFO Lot Valuation',
  description: 'FIFO cost lot valuation report',
  currency: 'INR',
  metrics: [
    { key: 'total_lots', label: 'Total Active Lots', value: 12, format: 'number' },
    { key: 'valuation', label: 'FIFO Valuation', value: 245000, format: 'amount' },
  ],
  columns: [
    { key: 'item_name', label: 'Item Name', type: 'string' },
    { key: 'sku', label: 'SKU', type: 'string' },
    { key: 'lot_number', label: 'Lot / Batch', type: 'string' },
    { key: 'remaining_qty', label: 'Lot Qty', type: 'quantity' },
    { key: 'unit_cost', label: 'Lot Unit Cost', type: 'amount' },
    { key: 'total_cost', label: 'Total Lot Value', type: 'amount' },
  ],
  rows: [
    {
      item_name: 'Amoxicillin 500mg',
      sku: 'MED-AMX-500',
      lot_number: 'LOT-2026-01',
      remaining_qty: 150,
      unit_cost: 115,
      total_cost: 17250,
    },
  ],
}

function renderStockSummary(queryClient: QueryClient) {
  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter>
        <StockSummaryPage />
      </MemoryRouter>
    </QueryClientProvider>
  )
}

describe('StockSummaryPage', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    queryClient = new QueryClient({
      defaultOptions: {
        queries: { retry: false },
      },
    })
    vi.clearAllMocks()

    vi.mocked(stockSummaryApi.getStockSummary).mockResolvedValue(mockStockSummary)
    vi.mocked(stockSummaryApi.getLowStockAlert).mockResolvedValue(mockLowStockAlert)
    vi.mocked(stockSummaryApi.getFifoValuation).mockResolvedValue(mockFifoValuation)
    vi.mocked(stockSummaryApi.listWarehouses).mockResolvedValue([
      { id: 'wh-1', name: 'Main Warehouse', code: 'MW01', isDefault: true },
    ])
  })

  it('renders page header, valuation summary metrics, and item ledger table', async () => {
    renderStockSummary(queryClient)

    expect(await screen.findByText('Stock Summary & Valuation')).toBeInTheDocument()
    expect(screen.getByText('Total Inventory Valuation')).toBeInTheDocument()
    expect(screen.getByText('Total Units on Hand')).toBeInTheDocument()
    expect(screen.getByText('Low Stock Warnings')).toBeInTheDocument()
    expect(screen.getByText('Out of Stock SKUs')).toBeInTheDocument()

    // Items rendered
    expect(await screen.findByText('Amoxicillin 500mg')).toBeInTheDocument()
    expect(screen.getByText('MED-AMX-500')).toBeInTheDocument()
    expect(screen.getByText('Paracetamol 650mg')).toBeInTheDocument()
    expect(screen.getByText('Cough Syrup 100ml')).toBeInTheDocument()

    // Status chips
    expect(screen.getByText('Optimal')).toBeInTheDocument()
    expect(screen.getByText('Low stock')).toBeInTheDocument()
    expect(screen.getByText('Out of stock')).toBeInTheDocument()
  })

  it('renders replenishment and deficit advisory banner with deficit outlay', async () => {
    renderStockSummary(queryClient)

    expect(await screen.findByText('Replenishment & Deficit Advisory')).toBeInTheDocument()
    expect(screen.getByText(/2 item\(s\)/i)).toBeInTheDocument()
    expect(screen.getByText('Filter Low-Stock SKUs')).toBeInTheDocument()
  })

  it('filters items by search input', async () => {
    renderStockSummary(queryClient)

    expect(await screen.findByText('Amoxicillin 500mg')).toBeInTheDocument()

    const searchInput = screen.getByLabelText('Search by item name or SKU')
    fireEvent.change(searchInput, { target: { value: 'Paracetamol' } })

    expect(screen.getByText('Paracetamol 650mg')).toBeInTheDocument()
    expect(screen.queryByText('Amoxicillin 500mg')).not.toBeInTheDocument()
  })

  it('filters items by status filter tabs', async () => {
    renderStockSummary(queryClient)

    expect(await screen.findByText('Amoxicillin 500mg')).toBeInTheDocument()

    // Click Out of Stock tab
    const outOfStockTab = screen.getByRole('tab', { name: /Out of Stock/i })
    fireEvent.click(outOfStockTab)

    expect(screen.getByText('Cough Syrup 100ml')).toBeInTheDocument()
    expect(screen.queryByText('Amoxicillin 500mg')).not.toBeInTheDocument()
    expect(screen.queryByText('Paracetamol 650mg')).not.toBeInTheDocument()
  })

  it('switches valuation method to FIFO Lot Basis and renders FIFO lot table', async () => {
    renderStockSummary(queryClient)

    expect(await screen.findByText('On-Hand Inventory Ledger')).toBeInTheDocument()

    // Switch to FIFO tab
    const fifoTab = screen.getByRole('tab', { name: /FIFO Lot Basis/i })
    fireEvent.click(fifoTab)

    expect(await screen.findByText('FIFO Cost Lot Valuation Breakdown')).toBeInTheDocument()
    expect(await screen.findByText('LOT-2026-01')).toBeInTheDocument()
    expect(screen.getByText(/FIFO valuation tracks each goods receipt lot sequentially/i)).toBeInTheDocument()
  })

  it('triggers query invalidation on refresh button click', async () => {
    const invalidateSpy = vi.spyOn(queryClient, 'invalidateQueries')

    renderStockSummary(queryClient)

    const refreshBtn = await screen.findByRole('button', { name: /refresh stock summary data/i })
    fireEvent.click(refreshBtn)

    expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ['inventory', 'stock-summary'] })
  })
})
