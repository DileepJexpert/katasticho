import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { TransferOrdersPage } from './transfer-orders-page'
import { TransferOrderDetailPage } from './transfer-order-detail-page'
import * as transferOrdersApi from './transfer-orders-api'

vi.mock('./transfer-orders-api', () => ({
  listTransferOrders: vi.fn(),
  getTransferOrder: vi.fn(),
  createTransferOrder: vi.fn(),
  shipTransferOrder: vi.fn(),
  receiveTransferOrder: vi.fn(),
  cancelTransferOrder: vi.fn(),
  listWarehouses: vi.fn(),
  listCatalogItems: vi.fn(),
}))

const mockTransferOrders: transferOrdersApi.TransferOrder[] = [
  {
    id: 'to-1',
    transferNumber: 'TR-2026-0001',
    fromWarehouseId: 'wh-1',
    fromWarehouseName: 'Central Logistics Hub',
    toWarehouseId: 'wh-2',
    toWarehouseName: 'North Distribution Depot',
    transferDate: '2026-09-04',
    status: 'DRAFT',
    lineCount: 2,
    createdAt: '2026-09-04T10:00:00Z',
    lines: [
      {
        id: 'line-1',
        itemId: 'item-1',
        itemName: 'Amoxicillin 500mg',
        sku: 'MED-AMX-500',
        quantity: 100,
        batchNumber: 'BAT-2026-A',
      },
    ],
  },
  {
    id: 'to-2',
    transferNumber: 'TR-2026-0002',
    fromWarehouseId: 'wh-1',
    fromWarehouseName: 'Central Logistics Hub',
    toWarehouseId: 'wh-3',
    toWarehouseName: 'Airport Transit Station',
    transferDate: '2026-09-03',
    status: 'SHIPPED',
    lineCount: 1,
    shippedAt: '2026-09-03T15:00:00Z',
    createdAt: '2026-09-03T11:00:00Z',
  },
  {
    id: 'to-3',
    transferNumber: 'TR-2026-0003',
    fromWarehouseId: 'wh-2',
    fromWarehouseName: 'North Distribution Depot',
    toWarehouseId: 'wh-1',
    toWarehouseName: 'Central Logistics Hub',
    transferDate: '2026-09-01',
    status: 'RECEIVED',
    lineCount: 3,
    shippedAt: '2026-09-01T12:00:00Z',
    receivedAt: '2026-09-02T09:00:00Z',
    createdAt: '2026-09-01T08:00:00Z',
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

describe('TransferOrders Workspace', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(transferOrdersApi.listTransferOrders).mockResolvedValue({
      content: mockTransferOrders,
      totalElements: 3,
      totalPages: 1,
      pageNumber: 0,
      pageSize: 50,
    })
    vi.mocked(transferOrdersApi.listWarehouses).mockResolvedValue([
      { id: 'wh-1', name: 'Central Logistics Hub', code: 'WH-CENTRAL' },
      { id: 'wh-2', name: 'North Distribution Depot', code: 'WH-NORTH' },
    ])
    vi.mocked(transferOrdersApi.listCatalogItems).mockResolvedValue([
      { id: 'item-1', name: 'Amoxicillin 500mg', sku: 'MED-AMX-500', unit: 'Box' },
    ])
  })

  it('renders the transfer orders register with summary metrics', async () => {
    renderWithClient(<TransferOrdersPage />)

    expect(screen.getByText('Stock Transfer Orders')).toBeInTheDocument()
    expect(await screen.findByText('TR-2026-0001')).toBeInTheDocument()
    expect(screen.getByText('TR-2026-0002')).toBeInTheDocument()
    expect(screen.getByText('TR-2026-0003')).toBeInTheDocument()

    // Status chips check
    expect(screen.getByText('Multi-Branch Transit')).toBeInTheDocument()
  })

  it('filters orders by search term', async () => {
    renderWithClient(<TransferOrdersPage />)

    await screen.findByText('TR-2026-0001')

    const searchInput = screen.getByPlaceholderText('Search transfer # or warehouse...')
    fireEvent.change(searchInput, { target: { value: 'TR-2026-0002' } })

    expect(screen.queryByText('TR-2026-0001')).not.toBeInTheDocument()
    expect(screen.getByText('TR-2026-0002')).toBeInTheDocument()
  })

  it('filters orders by status tabs', async () => {
    renderWithClient(<TransferOrdersPage />)

    await screen.findByText('TR-2026-0001')

    const inTransitTab = screen.getByRole('tab', { name: 'In Transit' })
    fireEvent.click(inTransitTab)

    expect(screen.queryByText('TR-2026-0001')).not.toBeInTheDocument()
    expect(screen.getByText('TR-2026-0002')).toBeInTheDocument()
    expect(screen.queryByText('TR-2026-0003')).not.toBeInTheDocument()
  })

  it('renders detail view and allows dispatching a draft order', async () => {
    vi.mocked(transferOrdersApi.getTransferOrder).mockResolvedValue(mockTransferOrders[0])
    vi.mocked(transferOrdersApi.shipTransferOrder).mockResolvedValue({
      ...mockTransferOrders[0],
      status: 'SHIPPED',
      shippedAt: '2026-09-05T00:00:00Z',
    })

    renderWithClient(
      <Routes>
        <Route path="/transfer-orders/:transferOrderId" element={<TransferOrderDetailPage />} />
      </Routes>,
      '/transfer-orders/to-1'
    )

    const matches = await screen.findAllByText('TR-2026-0001')
    expect(matches.length).toBeGreaterThan(0)
    expect(screen.getByText('Origin warehouse')).toBeInTheDocument()

    const dispatchBtn = screen.getByRole('button', { name: /dispatch shipment/i })
    expect(dispatchBtn).toBeInTheDocument()

    fireEvent.click(dispatchBtn)

    await waitFor(() => {
      expect(transferOrdersApi.shipTransferOrder).toHaveBeenCalledWith('to-1')
    })
  })

  it('renders detail view and allows receiving an in-transit order', async () => {
    vi.mocked(transferOrdersApi.getTransferOrder).mockResolvedValue(mockTransferOrders[1])
    vi.mocked(transferOrdersApi.receiveTransferOrder).mockResolvedValue({
      ...mockTransferOrders[1],
      status: 'RECEIVED',
      receivedAt: '2026-09-05T01:00:00Z',
    })

    renderWithClient(
      <Routes>
        <Route path="/transfer-orders/:transferOrderId" element={<TransferOrderDetailPage />} />
      </Routes>,
      '/transfer-orders/to-2'
    )

    const matches = await screen.findAllByText('TR-2026-0002')
    expect(matches.length).toBeGreaterThan(0)

    const receiveBtn = screen.getByRole('button', { name: /confirm receipt/i })
    expect(receiveBtn).toBeInTheDocument()

    fireEvent.click(receiveBtn)

    await waitFor(() => {
      expect(transferOrdersApi.receiveTransferOrder).toHaveBeenCalledWith('to-2')
    })
  })
})
