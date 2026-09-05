import { fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter } from 'react-router-dom'
import { NcrsPage } from './ncrs-page'
import * as ncrsApi from './ncrs-api'
import * as itemsApi from '@/features/items/items-api'

vi.mock('./ncrs-api', () => ({
  listNcrs: vi.fn(),
  createNcr: vi.fn(),
}))

vi.mock('@/features/items/items-api', () => ({
  listItems: vi.fn(),
}))

const mockNcr: ncrsApi.NonConformanceReport = {
  id: 'ncr-001',
  ncrNumber: 'NCR-2026-0001',
  qcInspectionId: null,
  itemId: 'item-raw-1',
  itemName: 'Menthol Crystal USP',
  batchNumber: 'BATCH-2026-01',
  severity: 'CRITICAL',
  reason: 'Melting point below pharmacopoeial specification',
  description: 'Sample melted at 38C instead of 42-44C.',
  status: 'OPEN',
  correctiveAction: null,
  rootCause: null,
  closedAt: null,
  closedBy: null,
  createdAt: '2026-09-01T10:00:00Z',
}

describe('NcrsPage', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } })
    vi.clearAllMocks()

    vi.mocked(ncrsApi.listNcrs).mockResolvedValue({
      content: [mockNcr],
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
          <NcrsPage />
        </MemoryRouter>
      </QueryClientProvider>
    )
  }

  it('renders NCR directory and reports table', async () => {
    renderPage()

    await waitFor(() => {
      expect(screen.getByText('NCR-2026-0001')).toBeInTheDocument()
    })

    expect(screen.getByText('Menthol Crystal USP')).toBeInTheDocument()
    expect(screen.getByText('CRITICAL')).toBeInTheDocument()
    expect(screen.getByText('Melting point below pharmacopoeial specification')).toBeInTheDocument()
  })

  it('opens raise NCR modal with EntityPicker and creates NCR', async () => {
    vi.mocked(ncrsApi.createNcr).mockResolvedValue({ id: 'ncr-new' } as unknown as ncrsApi.NonConformanceReport)
    const user = userEvent.setup()
    renderPage()

    await waitFor(() => {
      expect(screen.getByText('NCR-2026-0001')).toBeInTheDocument()
    })

    const raiseBtn = screen.getByRole('button', { name: /Raise NCR/i })
    await user.click(raiseBtn)

    const modal = screen.getByRole('dialog', { name: /Raise Non-Conformance Report/i })
    expect(modal).toBeInTheDocument()

    // Select Item via EntityPicker
    await user.click(within(modal).getByRole('combobox', { name: 'Defective Item' }))
    const itemOption = await screen.findByRole('option', { name: /Menthol Crystal USP/i })
    await user.click(itemOption)

    // Severity
    fireEvent.change(within(modal).getByLabelText(/Defect Severity/i), {
      target: { value: 'CRITICAL' },
    })

    // Reason
    const reasonInput = within(modal).getByPlaceholderText(/e\.g\. Seal failure during blister packing/i)
    await user.type(reasonInput, 'Melting point below pharmacopoeial specification')

    // Description
    const descInput = within(modal).getByPlaceholderText(/Detailed inspection findings\.\.\./i)
    await user.type(descInput, 'Sample melted at 38C instead of 42-44C.')

    const submitBtn = within(modal).getByRole('button', { name: 'Raise NCR' })
    expect(submitBtn).toBeEnabled()
    await user.click(submitBtn)

    await waitFor(() => {
      expect(ncrsApi.createNcr).toHaveBeenCalledWith({
        itemId: 'item-raw-1',
        severity: 'CRITICAL',
        reason: 'Melting point below pharmacopoeial specification',
        description: 'Sample melted at 38C instead of 42-44C.',
      })
    })
  })
})
