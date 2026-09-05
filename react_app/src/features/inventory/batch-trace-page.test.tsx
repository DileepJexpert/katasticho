import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, expect, it, vi } from 'vitest'
import { BatchTracePage } from './batch-trace-page'
import * as api from './batches-api'
import { listItems, type Item } from '@/features/items/items-api'
import { useInventoryAccess } from './inventory-access'

vi.mock('./batches-api', () => ({ getBatch: vi.fn(), listBatchesByItem: vi.fn(), getBatchTraceHistory: vi.fn(), getBatchRecallReport: vi.fn() }))
vi.mock('@/features/items/items-api', () => ({ listItems: vi.fn() }))
vi.mock('./inventory-access', () => ({ useInventoryAccess: vi.fn() }))

const batchId = '00000000-0000-4000-8000-000000000001'
beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(useInventoryAccess).mockReturnValue({ operate: true, manage: true, administer: true, readZones: true })
  vi.mocked(listItems).mockResolvedValue({ content: [{ id: 'item-id', name: 'Retired turmeric pack', sku: 'TUR', active: false } as Item], page: 0, size: 25, totalElements: 1, totalPages: 1, last: true })
  const batch: api.BatchDetail = { id: batchId, itemId: 'item-id', batchNumber: 'HIST-001', expiryDate: '2025-01-01', active: false, unitCost: 30, quantityAvailable: 0, supplierId: null }
  vi.mocked(api.listBatchesByItem).mockResolvedValue([batch])
  vi.mocked(api.getBatch).mockResolvedValue(batch)
  vi.mocked(api.getBatchTraceHistory).mockResolvedValue({ backward: [], forward: [] })
})
function renderPage(route = '/batch-trace') { return render(<QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false, gcTime: 0 } } })}><MemoryRouter initialEntries={[route]}><BatchTracePage /></MemoryRouter></QueryClientProvider>) }

it('selects a historical batch by name without requiring the operator to know its UUID', async () => {
  const user = userEvent.setup()
  renderPage()
  await user.click(screen.getByRole('combobox', { name: 'Search inventory item' }))
  await user.click(await screen.findByRole('option', { name: /Retired turmeric pack/ }))
  await waitFor(() => expect(screen.getByRole('combobox', { name: 'Select batch to trace' })).toBeEnabled())
  await user.click(screen.getByRole('combobox', { name: 'Select batch to trace' }))
  await user.click(screen.getByRole('option', { name: /HIST-001/ }))
  await waitFor(() => expect(api.getBatchTraceHistory).toHaveBeenCalledWith(batchId))
  expect(listItems).toHaveBeenCalledWith(expect.objectContaining({ activeOnly: false }))
  expect(api.listBatchesByItem).toHaveBeenCalledWith('item-id')
})

it('does not issue forbidden trace requests for viewers, including deep links', () => {
  vi.mocked(useInventoryAccess).mockReturnValue({ operate: false, manage: false, administer: false, readZones: false })
  renderPage('/batch-trace?batchId=' + batchId)
  expect(screen.getByText(/trace API is available to/)).toBeInTheDocument()
  expect(api.getBatch).not.toHaveBeenCalled()
  expect(api.getBatchTraceHistory).not.toHaveBeenCalled()
  expect(api.getBatchRecallReport).not.toHaveBeenCalled()
})
