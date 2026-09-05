import { fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter } from 'react-router-dom'
import { QcInspectionsPage } from './qc-inspections-page'
import * as qcInspectionsApi from './qc-inspections-api'
import * as itemsApi from '@/features/items/items-api'

vi.mock('./qc-inspections-api', () => ({
  listQcInspections: vi.fn(),
  createQcInspection: vi.fn(),
}))

vi.mock('@/features/items/items-api', () => ({
  listItems: vi.fn(),
}))

const mockQcInspection: qcInspectionsApi.QcInspection = {
  id: 'qc-001',
  inspectionNumber: 'QC-2026-0001',
  templateId: null,
  referenceType: null,
  referenceId: null,
  itemId: 'item-raw-1',
  itemName: 'Menthol Crystal USP',
  batchId: 'BATCH-2026-M1',
  inspectionType: 'INBOUND_GRN',
  status: 'PENDING',
  inspectedQty: 50,
  acceptedQty: 0,
  rejectedQty: 0,
  disposition: null,
  inspectorId: null,
  inspectorName: 'Quality Lead John',
  inspectedAt: '2026-09-01T10:00:00Z',
  notes: null,
  holdQty: null,
  quarantineZoneId: null,
  dispositionNotes: null,
  dispositionAt: null,
  dispositionBy: null,
  results: [],
}

describe('QcInspectionsPage', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } })
    vi.clearAllMocks()

    vi.mocked(qcInspectionsApi.listQcInspections).mockResolvedValue({
      content: [mockQcInspection],
      page: 0,
      size: 20,
      totalElements: 1,
      totalPages: 1,
      last: true,
    })

    vi.mocked(itemsApi.listItems).mockResolvedValue({
      content: [
        {
          id: 'item-raw-1',
          name: 'Menthol Crystal USP',
          sku: 'RM-MTH-01',
          unitOfMeasure: 'KG',
          active: true,
        } as unknown as itemsApi.Item,
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
          <QcInspectionsPage />
        </MemoryRouter>
      </QueryClientProvider>
    )
  }

  it('renders QC inspections directory and inspection table', async () => {
    renderPage()

    await waitFor(() => {
      expect(screen.getByText('QC-2026-0001')).toBeInTheDocument()
    })

    expect(screen.getByText('Menthol Crystal USP')).toBeInTheDocument()
    expect(screen.getAllByText(/Pending/i).length).toBeGreaterThan(0)
  })

  it('opens initiate inspection modal with EntityPicker and creates QC inspection', async () => {
    vi.mocked(qcInspectionsApi.createQcInspection).mockResolvedValue({ id: 'qc-new' } as unknown as qcInspectionsApi.QcInspection)
    const user = userEvent.setup()
    renderPage()

    await waitFor(() => {
      expect(screen.getByText('QC-2026-0001')).toBeInTheDocument()
    })

    const createBtn = screen.getByRole('button', { name: /New Inspection/i })
    await user.click(createBtn)

    const modal = screen.getByRole('dialog', { name: /Initiate QC Inspection/i })
    expect(modal).toBeInTheDocument()

    // Select Item via EntityPicker
    await user.click(within(modal).getByRole('combobox', { name: 'Item to Inspect' }))
    const itemOption = await screen.findByRole('option', { name: /Menthol Crystal USP/i })
    await user.click(itemOption)

    // Select Stage
    fireEvent.change(within(modal).getByLabelText(/Inspection Stage/i), {
      target: { value: 'IN_PROCESS' },
    })

    // Batch ID
    const batchInput = within(modal).getByPlaceholderText(/e\.g\. BATCH-2026-09/i)
    await user.type(batchInput, 'BATCH-2026-09A')

    // Sample Quantity
    const qtyInput = within(modal).getByLabelText(/Sample Inspection Quantity/i)
    fireEvent.change(qtyInput, { target: { value: '25' } })

    const submitBtn = within(modal).getByRole('button', { name: 'Initiate Inspection' })
    expect(submitBtn).toBeEnabled()
    await user.click(submitBtn)

    await waitFor(() => {
      expect(qcInspectionsApi.createQcInspection).toHaveBeenCalledWith({
        itemId: 'item-raw-1',
        inspectionType: 'IN_PROCESS',
        inspectedQty: 25,
        batchId: 'BATCH-2026-09A',
      })
    })
  })
})
