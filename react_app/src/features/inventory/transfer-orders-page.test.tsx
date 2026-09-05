import { fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { TransferOrderDetailPage } from './transfer-order-detail-page'
import { TransferOrdersPage } from './transfer-orders-page'
import * as transferOrdersApi from './transfer-orders-api'

vi.mock('./transfer-orders-api', () => ({
  listTransferOrders: vi.fn(),
  getTransferOrder: vi.fn(),
  createTransferOrder: vi.fn(),
  shipTransferOrder: vi.fn(),
  receiveTransferOrder: vi.fn(),
  cancelTransferOrder: vi.fn(),
}))

const draftTransfer: transferOrdersApi.TransferOrder = {
  id: 'to-1',
  transferNumber: 'TO-2026-000001',
  fromWarehouseId: 'wh-1',
  fromWarehouseName: 'Central Warehouse',
  toWarehouseId: 'wh-2',
  toWarehouseName: 'North Branch',
  transferDate: '2026-09-05',
  status: 'DRAFT',
  notes: null,
  shippedAt: null,
  receivedAt: null,
  lineCount: 1,
  lines: [{
    id: 'line-1',
    itemId: 'item-1',
    itemName: 'Turmeric Masala Test 100g',
    sku: 'MASALA-TURMERIC-TEST-100G',
    batchId: null,
    batchNumber: null,
    quantity: 10,
    receivedQuantity: 0,
    notes: null,
  }],
  createdAt: '2026-09-05T10:00:00Z',
}

const inTransitTransfer: transferOrdersApi.TransferOrder = {
  ...draftTransfer,
  id: 'to-2',
  transferNumber: 'TO-2026-000002',
  status: 'IN_TRANSIT',
  shippedAt: '2026-09-05T11:00:00Z',
}

function renderWithClient(ui: React.ReactElement, initialRoute = '/') {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false, gcTime: 0 },
      mutations: { retry: false },
    },
  })

  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter initialEntries={[initialRoute]}>{ui}</MemoryRouter>
    </QueryClientProvider>,
  )
}

describe('Transfer orders', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(transferOrdersApi.listTransferOrders).mockResolvedValue({
      content: [draftTransfer, inTransitTransfer],
      page: 0,
      size: 25,
      totalElements: 2,
      totalPages: 1,
      last: true,
    })
  })

  it('renders server lifecycle states in the transfer register', async () => {
    renderWithClient(<TransferOrdersPage />)

    expect(screen.getByText('Transfer Orders')).toBeInTheDocument()
    expect(await screen.findByText('TO-2026-000001')).toBeInTheDocument()
    expect(screen.getByText('TO-2026-000002')).toBeInTheDocument()
    expect(screen.getByText('In Transit')).toBeInTheDocument()
  })

  it('requires confirmation before dispatching a draft transfer', async () => {
    vi.mocked(transferOrdersApi.getTransferOrder).mockResolvedValue(draftTransfer)
    vi.mocked(transferOrdersApi.shipTransferOrder).mockResolvedValue({
      ...draftTransfer,
      status: 'IN_TRANSIT',
      shippedAt: '2026-09-05T11:00:00Z',
    })

    renderWithClient(
      <Routes><Route element={<TransferOrderDetailPage />} path="/transfer-orders/:transferOrderId" /></Routes>,
      '/transfer-orders/to-1',
    )

    expect(await screen.findByText('TO-2026-000001')).toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: 'Dispatch transfer' }))

    const dialog = screen.getByRole('dialog', { name: 'Dispatch this transfer?' })
    expect(dialog).toBeInTheDocument()
    expect(transferOrdersApi.shipTransferOrder).not.toHaveBeenCalled()

    fireEvent.click(within(dialog).getByRole('button', { name: 'Dispatch transfer' }))
    await waitFor(() => expect(transferOrdersApi.shipTransferOrder).toHaveBeenCalledWith('to-1'))
  })

  it('requires confirmation before receiving an in-transit transfer', async () => {
    vi.mocked(transferOrdersApi.getTransferOrder).mockResolvedValue(inTransitTransfer)
    vi.mocked(transferOrdersApi.receiveTransferOrder).mockResolvedValue({
      ...inTransitTransfer,
      status: 'RECEIVED',
      receivedAt: '2026-09-05T12:00:00Z',
      lines: inTransitTransfer.lines.map((line) => ({ ...line, receivedQuantity: 10 })),
    })

    renderWithClient(
      <Routes><Route element={<TransferOrderDetailPage />} path="/transfer-orders/:transferOrderId" /></Routes>,
      '/transfer-orders/to-2',
    )

    expect(await screen.findByText('TO-2026-000002')).toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: 'Receive transfer' }))

    const dialog = screen.getByRole('dialog', { name: 'Receive this transfer?' })
    expect(dialog).toBeInTheDocument()
    expect(transferOrdersApi.receiveTransferOrder).not.toHaveBeenCalled()

    fireEvent.click(within(dialog).getByRole('button', { name: 'Receive transfer' }))
    await waitFor(() => expect(transferOrdersApi.receiveTransferOrder).toHaveBeenCalledWith('to-2'))
  })

  it('requires confirmation before cancelling an in-transit transfer', async () => {
    vi.mocked(transferOrdersApi.getTransferOrder).mockResolvedValue(inTransitTransfer)
    vi.mocked(transferOrdersApi.cancelTransferOrder).mockResolvedValue(undefined)

    renderWithClient(
      <Routes><Route element={<TransferOrderDetailPage />} path="/transfer-orders/:transferOrderId" /></Routes>,
      '/transfer-orders/to-2',
    )

    expect(await screen.findByText('TO-2026-000002')).toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: 'Cancel' }))

    const dialog = screen.getByRole('dialog', { name: 'Cancel in-transit transfer?' })
    expect(dialog).toBeInTheDocument()
    expect(transferOrdersApi.cancelTransferOrder).not.toHaveBeenCalled()

    fireEvent.click(within(dialog).getByRole('button', { name: 'Cancel transfer' }))
    await waitFor(() => expect(transferOrdersApi.cancelTransferOrder).toHaveBeenCalledWith('to-2'))
  })
})
