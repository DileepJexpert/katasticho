import { fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { WorkOrderDetailPage } from './work-order-detail-page'
import * as workOrdersApi from './work-orders-api'
import * as bmrApi from '@/features/manufacturing/bmr-api'
import * as itemsApi from '@/features/items/items-api'

vi.mock('./work-orders-api', () => ({
  getWorkOrder: vi.fn(),
  getJobCardsForWorkOrder: vi.fn(),
  issueToProduction: vi.fn(),
  receiveFinishedGoods: vi.fn(),
  updateWorkOrderCosts: vi.fn(),
  cancelWorkOrder: vi.fn(),
  createSubAssemblyWos: vi.fn(),
  listChildWorkOrders: vi.fn(),
  getScrapForWorkOrder: vi.fn(),
  startJobCard: vi.fn(),
  completeJobCard: vi.fn(),
  recordProductionScrap: vi.fn(),
}))

vi.mock('@/features/manufacturing/bmr-api', () => ({
  listBmrStepRecords: vi.fn(),
  recordBmrStep: vi.fn(),
  listBmrSignoffs: vi.fn(),
  signoffBmr: vi.fn(),
  listBmrDeviations: vi.fn(),
  raiseBmrDeviation: vi.fn(),
  resolveBmrDeviation: vi.fn(),
  getYieldReconciliation: vi.fn(),
  downloadBmrPdf: vi.fn(),
}))

vi.mock('@/features/items/items-api', () => ({
  listItems: vi.fn(),
}))

const mockWorkOrderInProgress: workOrdersApi.WorkOrder = {
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
  lines: [
    {
      id: 'line-1',
      workOrderId: 'wo-101',
      itemId: 'item-raw-1',
      itemName: 'Adhatoda Vasica Extract',
      requiredQty: 50,
      issuedQty: 50,
      unitCost: 200,
      lineCost: 10000,
      totalCost: 10000,
      status: 'ISSUED',
      batchId: 'batch-1',
      batchNumber: 'BT-VAS-01',
    },
  ],
}

describe('WorkOrderDetailPage', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } })
    vi.clearAllMocks()

    vi.mocked(workOrdersApi.getWorkOrder).mockResolvedValue(mockWorkOrderInProgress)
    vi.mocked(workOrdersApi.getJobCardsForWorkOrder).mockResolvedValue([
      {
        id: 'jc-1',
        jobCardNumber: 'JC-001',
        workOrderId: 'wo-101',
        operationNumber: 1,
        operationName: 'Decoction & Extraction',
        status: 'PENDING',
        plannedQuantity: 500,
        completedQuantity: 0,
        scrapQuantity: 0,
        assignedTo: 'Operator John',
        timeLoggedMinutes: 0,
      } as unknown as workOrdersApi.JobCard,
    ])
    vi.mocked(workOrdersApi.listChildWorkOrders).mockResolvedValue([])
    vi.mocked(workOrdersApi.getScrapForWorkOrder).mockResolvedValue([])

    vi.mocked(bmrApi.listBmrStepRecords).mockResolvedValue([
      {
        id: 'step-1',
        workOrderId: 'wo-101',
        stepNumber: 1,
        operationName: 'Granulation',
        parameterKey: 'Moisture',
        parameterName: 'Moisture Content',
        parameterValue: '2.4',
        targetValue: '2.5',
        minValue: '2.0',
        maxValue: '3.0',
        measuredValue: '2.4',
        unit: '%',
        notes: 'Passed within spec',
      },
    ])
    vi.mocked(bmrApi.listBmrSignoffs).mockResolvedValue([
      {
        id: 'sig-1',
        workOrderId: 'wo-101',
        stageName: 'Granulation',
        role: 'SUPERVISOR',
        remarks: 'Batch verified',
      },
    ])
    vi.mocked(bmrApi.listBmrDeviations).mockResolvedValue([])
    vi.mocked(bmrApi.getYieldReconciliation).mockResolvedValue({
      workOrderId: 'wo-101',
      theoreticalYield: 500,
      actualYield: 250,
      yieldPercentage: 50,
      minAcceptableYieldPercentage: 95,
      maxAcceptableYieldPercentage: 102,
      scrapQty: 5,
      scrapPercentage: 1,
      status: 'UNDER_INVESTIGATION',
    })

    vi.mocked(itemsApi.listItems).mockResolvedValue({
      content: [
        { id: 'item-raw-1', name: 'Adhatoda Vasica Extract', sku: 'RM-VAS-01', unitOfMeasure: 'KG', active: true } as unknown as itemsApi.Item,
      ],
      page: 0,
      size: 25,
      totalElements: 1,
      totalPages: 1,
      last: true,
    })
  })

  function renderPage(orderId = 'wo-101') {
    return render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter initialEntries={[`/work-orders/${orderId}`]}>
          <Routes>
            <Route path="/work-orders/:workOrderId" element={<WorkOrderDetailPage />} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    )
  }

  it('renders work order header details and line items', async () => {
    renderPage()

    await waitFor(() => {
      expect(screen.getByText('WO-000101')).toBeInTheDocument()
    })

    expect(screen.getAllByText(/Ayurvedic Cough Syrup 100ml/i).length).toBeGreaterThan(0)
    expect(screen.getByText('In Progress')).toBeInTheDocument()
    expect(screen.getByText('Adhatoda Vasica Extract')).toBeInTheDocument()
  })

  it('allows receiving finished goods batch into inventory', async () => {
    vi.mocked(workOrdersApi.receiveFinishedGoods).mockResolvedValue({} as unknown as workOrdersApi.WorkOrder)
    const user = userEvent.setup()
    renderPage()

    await waitFor(() => {
      expect(screen.getByText('WO-000101')).toBeInTheDocument()
    })

    const receiveBtn = screen.getByRole('button', { name: /Receive Finished Goods/i })
    await user.click(receiveBtn)

    const modal = screen.getByRole('dialog', { name: /Receive Finished Goods Batch/i })
    expect(modal).toBeInTheDocument()

    const batchInput = within(modal).getByPlaceholderText(/e\.g\. BT-2026-09A/i)
    await user.type(batchInput, 'BATCH-2026-01')

    const dateInput = within(modal).getByLabelText(/Expiry Date/i)
    fireEvent.change(dateInput, { target: { value: '2028-09-01' } })

    const submitBtn = within(modal).getByRole('button', { name: /^Receive Batch$/i })
    await user.click(submitBtn)

    await waitFor(() => {
      expect(workOrdersApi.receiveFinishedGoods).toHaveBeenCalledWith('wo-101', {
        quantityReceived: 100,
        batchNumber: 'BATCH-2026-01',
        expiryDate: '2028-09-01',
      })
    })
  })

  it('records scrap using EntityPicker to select component item', async () => {
    vi.mocked(workOrdersApi.recordProductionScrap).mockResolvedValue({} as unknown as workOrdersApi.ProductionScrap)
    const user = userEvent.setup()
    renderPage()

    await waitFor(() => {
      expect(screen.getByText('WO-000101')).toBeInTheDocument()
    })

    const scrapBtn = screen.getByRole('button', { name: /Record Scrap/i })
    await user.click(scrapBtn)

    const modal = screen.getByRole('dialog', { name: /Record Production Scrap \/ Wastage/i })
    expect(modal).toBeInTheDocument()

    // Select component item via EntityPicker
    await user.click(within(modal).getByRole('combobox', { name: 'Scrapped Item' }))
    const option = await screen.findByRole('option', { name: /Adhatoda Vasica Extract/i })
    await user.click(option)

    // Notes
    const notesInput = within(modal).getByPlaceholderText(/Defective mold, packaging tear\.\.\./i)
    await user.type(notesInput, 'Spillage during filtration')

    const submitBtn = within(modal).getByRole('button', { name: /^Record Scrap$/i })
    await user.click(submitBtn)

    await waitFor(() => {
      expect(workOrdersApi.recordProductionScrap).toHaveBeenCalledWith('wo-101', {
        itemId: 'item-raw-1',
        scrapQty: 1,
        notes: 'Spillage during filtration',
      })
    })
  })

  it('navigates to WHO-GMP BMR tab and displays parameter steps and signoffs', async () => {
    const user = userEvent.setup()
    renderPage()

    await waitFor(() => {
      expect(screen.getByText('WO-000101')).toBeInTheDocument()
    })

    const bmrTab = screen.getByRole('tab', { name: /Pharma BMR & Quality Records/i })
    await user.click(bmrTab)

    expect(screen.getByText('Moisture Content')).toBeInTheDocument()
    expect(screen.getByText('Batch verified')).toBeInTheDocument()
    expect(screen.getByText(/50\.0%/i)).toBeInTheDocument() // actual yield reconciliation
  })
})
