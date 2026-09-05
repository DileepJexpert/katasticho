import { fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { JobWorkDetailPage } from './job-work-detail-page'
import * as jobWorkApi from './job-work-api'

vi.mock('./job-work-api', () => ({
  getJobWorkOrder: vi.fn(),
  sendJobWorkMaterials: vi.fn(),
  receiveJobWorkGoods: vi.fn(),
  cancelJobWorkOrder: vi.fn(),
}))

const mockDetailJobWork: jobWorkApi.JobWorkOrder = {
  id: 'jw-101',
  jobWorkNumber: 'JW-2026-0001',
  challanNumber: 'CH-45-0012',
  vendorId: 'vendor-1',
  vendorName: 'Apex Precision Coatings Ltd',
  warehouseId: 'wh-main',
  warehouseName: 'Central Plant Warehouse',
  workOrderId: null,
  status: 'DISPATCHED',
  processingCharges: 1500,
  totalMaterialCost: 13500,
  totalCost: 15000,
  plannedSendDate: '2026-09-01',
  plannedReturnDate: '2026-10-01',
  actualSendDate: '2026-09-01',
  actualReturnDate: null,
  gstReturnDeadline: '2027-09-01',
  notes: null,
  lines: [
    {
      id: 'line-mat-1',
      jobWorkOrderId: 'jw-101',
      itemId: 'item-raw-1',
      itemName: 'Raw Sheet Metal',
      lineType: 'MATERIAL_SENT',
      sentQty: 100,
      receivedQty: 0,
      wastageQty: 0,
      unitCost: 100,
      lineCost: 10000,
      status: 'DISPATCHED',
    },
    {
      id: 'line-out-1',
      jobWorkOrderId: 'jw-101',
      itemId: 'item-out-1',
      itemName: 'Coated Sheet Metal',
      lineType: 'EXPECTED_OUTPUT',
      sentQty: 0,
      receivedQty: 0,
      wastageQty: 0,
      unitCost: 150,
      lineCost: 14250,
      status: 'PENDING_RECEIPT',
    },
  ],
}

describe('JobWorkDetailPage', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } })
    vi.clearAllMocks()
    vi.mocked(jobWorkApi.getJobWorkOrder).mockResolvedValue(mockDetailJobWork)
  })

  function renderPage(orderId = 'jw-101') {
    return render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter initialEntries={[`/job-work/${orderId}`]}>
          <Routes>
            <Route path="/job-work/:jobWorkId" element={<JobWorkDetailPage />} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    )
  }

  it('renders job work details, line items, and challan 45 number', async () => {
    renderPage()

    await waitFor(() => {
      expect(screen.getByText('JW-2026-0001')).toBeInTheDocument()
    })

    expect(screen.getByText('Challan 45: CH-45-0012')).toBeInTheDocument()
    expect(screen.getByText('Raw Sheet Metal')).toBeInTheDocument()
    expect(screen.getByText('Coated Sheet Metal')).toBeInTheDocument()
  })

  it('allows receiving processed goods against expected output line', async () => {
    vi.mocked(jobWorkApi.receiveJobWorkGoods).mockResolvedValue({} as unknown as jobWorkApi.JobWorkOrder)
    const user = userEvent.setup()
    renderPage()

    await waitFor(() => {
      expect(screen.getByText('JW-2026-0001')).toBeInTheDocument()
    })

    const receiveBtn = screen.getByRole('button', { name: /Receive Processed Goods/i })
    await user.click(receiveBtn)

    const modal = screen.getByRole('dialog', { name: /Receive Processed Goods from Job Worker/i })
    expect(modal).toBeInTheDocument()

    // Select output line from dropdown
    const itemSelect = within(modal).getByLabelText(/Received Output Item/i)
    fireEvent.change(itemSelect, { target: { value: 'item-out-1' } })

    // Set received qty & wastage
    const qtyInput = within(modal).getByLabelText(/Received Good Quantity/i)
    fireEvent.change(qtyInput, { target: { value: '95' } })

    const wastageInput = within(modal).getByLabelText(/Scrap \/ Process Wastage/i)
    fireEvent.change(wastageInput, { target: { value: '5' } })

    const submitBtn = within(modal).getByRole('button', { name: /^Record Inward Receipt$/i })
    await user.click(submitBtn)

    await waitFor(() => {
      expect(jobWorkApi.receiveJobWorkGoods).toHaveBeenCalledWith('jw-101', [
        {
          itemId: 'item-out-1',
          receivedQty: 95,
          wastageQty: 5,
        },
      ])
    })
  })
})
