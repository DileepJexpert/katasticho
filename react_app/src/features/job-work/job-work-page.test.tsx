import { fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter } from 'react-router-dom'
import { JobWorkPage } from './job-work-page'
import * as jobWorkApi from './job-work-api'
import * as contactsApi from '@/features/contacts/contacts-api'
import * as warehousesApi from '@/features/warehouses/warehouses-api'
import * as itemsApi from '@/features/items/items-api'

vi.mock('./job-work-api', () => ({
  listJobWorkOrders: vi.fn(),
  getJobWorkGstAlerts: vi.fn(),
  createJobWorkOrder: vi.fn(),
}))

vi.mock('@/features/contacts/contacts-api', () => ({
  listContacts: vi.fn(),
}))

vi.mock('@/features/warehouses/warehouses-api', () => ({
  listWarehouses: vi.fn(),
}))

vi.mock('@/features/items/items-api', () => ({
  listItems: vi.fn(),
}))

const mockJobWorkOrder: jobWorkApi.JobWorkOrder = {
  id: 'jw-001',
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
  lines: [],
}

describe('JobWorkPage', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } })
    vi.clearAllMocks()

    vi.mocked(jobWorkApi.listJobWorkOrders).mockResolvedValue({
      content: [mockJobWorkOrder],
      page: 0,
      size: 20,
      totalElements: 1,
      totalPages: 1,
      last: true,
    })

    vi.mocked(jobWorkApi.getJobWorkGstAlerts).mockResolvedValue([mockJobWorkOrder])

    vi.mocked(contactsApi.listContacts).mockResolvedValue({
      content: [
        {
          id: 'vendor-1',
          displayName: 'Apex Precision Coatings Ltd',
          companyName: 'Apex Precision Coatings Ltd',
          contactType: 'VENDOR',
          gstin: '27AABCA1234F1Z5',
          active: true,
          supplierEnabled: true,
          outstandingAr: 0,
          outstandingAp: 0,
          email: null,
          phone: null,
          mobile: null,
        },
      ],
      totalElements: 1,
      totalPages: 1,
      number: 0,
      size: 25,
    })

    vi.mocked(warehousesApi.listWarehouses).mockResolvedValue([
      { id: 'wh-main', name: 'Central Plant Warehouse', code: 'CPW', active: true } as unknown as warehousesApi.Warehouse,
    ])

    vi.mocked(itemsApi.listItems).mockResolvedValue({
      content: [
        { id: 'item-raw-1', name: 'Raw Sheet Metal', sku: 'RM-SHT-01', unitOfMeasure: 'PCS', active: true } as unknown as itemsApi.Item,
        { id: 'item-out-1', name: 'Coated Sheet Metal', sku: 'FG-SHT-01', unitOfMeasure: 'PCS', active: true } as unknown as itemsApi.Item,
      ],
      page: 0,
      size: 25,
      totalElements: 2,
      totalPages: 1,
      last: true,
    })
  })

  function renderPage() {
    return render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter>
          <JobWorkPage />
        </MemoryRouter>
      </QueryClientProvider>
    )
  }

  it('renders job work directory, orders table, and GST ITC-04 statutory alert', async () => {
    renderPage()

    await waitFor(() => {
      expect(screen.getByText('JW-2026-0001')).toBeInTheDocument()
    })

    expect(screen.getByText('CH-45-0012')).toBeInTheDocument()
    expect(screen.getByText('Apex Precision Coatings Ltd')).toBeInTheDocument()
    expect(screen.getByText(/GST ITC-04 Statutory Deadline Alert/i)).toBeInTheDocument()
  })

  it('opens create modal with EntityPickers and creates job work order', async () => {
    vi.mocked(jobWorkApi.createJobWorkOrder).mockResolvedValue({ id: 'jw-new' } as unknown as jobWorkApi.JobWorkOrder)
    const user = userEvent.setup()
    renderPage()

    await waitFor(() => {
      expect(screen.getByText('JW-2026-0001')).toBeInTheDocument()
    })

    const createBtn = screen.getByRole('button', { name: /Create Job Work Order/i })
    await user.click(createBtn)

    const modal = screen.getByRole('dialog', { name: /Create Job Work Order \(Challan 45\)/i })
    expect(modal).toBeInTheDocument()

    // Pick Vendor
    await user.click(within(modal).getByRole('combobox', { name: 'Job Worker / Vendor' }))
    const vendorOption = await screen.findByRole('option', { name: /Apex Precision Coatings Ltd/i })
    await user.click(vendorOption)

    // Select Warehouse
    fireEvent.change(within(modal).getByLabelText(/Dispatch Facility \/ Warehouse/i), {
      target: { value: 'wh-main' },
    })

    // Pick Raw Material Item
    await user.click(within(modal).getByRole('combobox', { name: 'Raw Material Item' }))
    const rawOption = await screen.findByRole('option', { name: /Raw Sheet Metal/i })
    await user.click(rawOption)

    // Pick Expected Output Item
    await user.click(within(modal).getByRole('combobox', { name: 'Expected Output Item' }))
    const outOption = await screen.findByRole('option', { name: /Coated Sheet Metal/i })
    await user.click(outOption)

    // Submit
    const submitBtn = within(modal).getByRole('button', { name: 'Create Job Work Order' })
    expect(submitBtn).toBeEnabled()
    await user.click(submitBtn)

    await waitFor(() => {
      expect(jobWorkApi.createJobWorkOrder).toHaveBeenCalledWith({
        vendorId: 'vendor-1',
        warehouseId: 'wh-main',
        processingCharges: 1500,
        materials: [{ itemId: 'item-raw-1', qty: 100 }],
        outputs: [{ itemId: 'item-out-1', qty: 95 }],
      })
    })
  })
})
