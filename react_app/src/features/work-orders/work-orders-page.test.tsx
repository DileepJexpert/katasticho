import { fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter } from 'react-router-dom'
import { WorkOrdersPage } from './work-orders-page'
import * as workOrdersApi from './work-orders-api'
import * as itemsApi from '@/features/items/items-api'
import * as warehousesApi from '@/features/warehouses/warehouses-api'

vi.mock('./work-orders-api', () => ({
  listWorkOrders: vi.fn(),
  createWorkOrder: vi.fn(),
  autoCreateFromReorder: vi.fn(),
}))

vi.mock('@/features/items/items-api', () => ({
  listItems: vi.fn(),
}))

vi.mock('@/features/warehouses/warehouses-api', () => ({
  listWarehouses: vi.fn(),
}))

const mockWorkOrder: workOrdersApi.WorkOrder = {
  id: 'wo-101',
  workOrderNumber: 'WO-000101',
  finishedGoodId: 'item-fg-1',
  finishedGoodName: 'Ayurvedic Cough Syrup 100ml',
  warehouseId: 'wh-main',
  warehouseName: 'Central Plant Warehouse',
  quantityToProduce: 500,
  quantityProduced: 250,
  status: 'IN_PROGRESS',
  plannedStartDate: '2026-09-01',
  plannedEndDate: '2026-09-10',
  actualStartDate: '2026-09-02',
  actualEndDate: null,
  rawMaterialCost: 25000,
  directLaborCost: 5000,
  overheadCost: 2000,
  totalCost: 32000,
  unitCost: 64,
  salesOrderId: null,
  parentWorkOrderId: null,
  routingId: null,
  priority: 'HIGH',
  scrapQty: 5,
  scrapCost: 320,
  notes: 'Priority batch for regional stockist',
  journalEntryId: null,
  wipJournalEntryId: null,
  backflushMode: false,
  bomVersion: 1,
  approvalStatus: 'APPROVED',
  approvedBy: null,
  approvedAt: null,
  disassembly: false,
  lines: [],
}

describe('WorkOrdersPage', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } })
    vi.clearAllMocks()
    vi.mocked(workOrdersApi.listWorkOrders).mockResolvedValue({
      content: [mockWorkOrder],
      page: 0,
      size: 20,
      totalElements: 1,
      totalPages: 1,
      last: true,
    })
    vi.mocked(warehousesApi.listWarehouses).mockResolvedValue([
      { id: 'wh-main', name: 'Central Plant Warehouse', code: 'CPW', active: true },
    ] as unknown as warehousesApi.Warehouse[])
    vi.mocked(itemsApi.listItems).mockResolvedValue({
      content: [
        { id: 'item-fg-1', name: 'Ayurvedic Cough Syrup 100ml', sku: 'ACS-100', itemType: 'GOODS', unitOfMeasure: 'BTL', active: true } as unknown as itemsApi.Item,
      ],
      page: 0,
      size: 25,
      totalElements: 1,
      totalPages: 1,
      last: true,
    })
  })

  function renderPage() {
    return render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter>
          <WorkOrdersPage />
        </MemoryRouter>
      </QueryClientProvider>
    )
  }

  it('renders work orders directory and filters by search', async () => {
    renderPage()

    expect(await screen.findByText('WO-000101')).toBeInTheDocument()
    expect(screen.getByText('Ayurvedic Cough Syrup 100ml')).toBeInTheDocument()
    expect(screen.getByRole('tab', { name: 'In Progress' })).toBeInTheDocument()

    // Search filter
    fireEvent.change(screen.getByPlaceholderText(/Search by WO number/i), { target: { value: 'Syrup' } })
    expect(screen.getByText('WO-000101')).toBeInTheDocument()

    fireEvent.change(screen.getByPlaceholderText(/Search by WO number/i), { target: { value: 'Nonexistent' } })
    expect(screen.getByText('No work orders found.')).toBeInTheDocument()
  })

  it('opens create work order modal with EntityPicker and warehouse select', async () => {
    const user = userEvent.setup()
    vi.mocked(workOrdersApi.createWorkOrder).mockResolvedValue({ id: 'wo-102' } as unknown as workOrdersApi.WorkOrder)
    renderPage()

    await screen.findByText('WO-000101')
    await user.click(screen.getByRole('button', { name: /Create Work Order/i }))

    const modal = screen.getByRole('dialog', { name: /Create Manufacturing Work Order/i })
    expect(modal).toBeInTheDocument()

    // Select finished good via EntityPicker
    await user.click(within(modal).getByRole('combobox', { name: 'Finished Good Item' }))
    const option = await screen.findByRole('option', { name: /Ayurvedic Cough Syrup 100ml/i })
    await user.click(option)

    // Select warehouse
    fireEvent.change(within(modal).getByLabelText(/Production Facility \/ Warehouse/i), { target: { value: 'wh-main' } })

    // Set quantity
    fireEvent.change(within(modal).getByLabelText(/Quantity to Produce/i), { target: { value: '200' } })

    // Submit within modal
    const submitBtn = within(modal).getByRole('button', { name: 'Create Work Order' })
    expect(submitBtn).toBeEnabled()
    await user.click(submitBtn)

    await waitFor(() => {
      expect(workOrdersApi.createWorkOrder).toHaveBeenCalledWith(expect.objectContaining({
        finishedGoodId: 'item-fg-1',
        warehouseId: 'wh-main',
        quantityToProduce: 200,
        priority: 'NORMAL',
      }))
    })
  })
})
