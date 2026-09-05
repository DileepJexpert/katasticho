import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, expect, it, vi } from 'vitest'
import { SerialNumbersPage } from './serial-numbers-page'
import { listAvailableSerials, listSerialNumbers, type SerialNumberRecord } from './serial-numbers-api'
import { getItem, type Item } from '@/features/items/items-api'
import { listWarehouses, type Warehouse } from '@/features/warehouses/warehouses-api'

vi.mock('./serial-numbers-api', () => ({ listAvailableSerials: vi.fn(), listSerialNumbers: vi.fn() }))
vi.mock('@/features/items/items-api', () => ({ getItem: vi.fn(), listItems: vi.fn() }))
vi.mock('@/features/warehouses/warehouses-api', () => ({ listWarehouses: vi.fn() }))
const serial: SerialNumberRecord = { id: 'serial-id', itemId: 'item-id', serial: 'SN-001', warehouseId: 'main', batchId: null, status: 'SOLD', receivedAt: '2026-09-01T10:00:00Z', soldAt: '2026-09-05T10:00:00Z', receiptLineId: 'receipt-line', invoiceLineId: 'invoice-line', notes: null }
beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(getItem).mockResolvedValue({ id: 'item-id', name: 'Scanner', active: false } as Item)
  vi.mocked(listWarehouses).mockResolvedValue([{ id: 'main', name: 'Main', code: 'MAIN', active: true }] as Warehouse[])
  vi.mocked(listSerialNumbers).mockResolvedValue({ content: [serial], totalElements: 26, totalPages: 2, last: false })
  vi.mocked(listAvailableSerials).mockResolvedValue([])
})
function renderPage(entry = '/inventory/serial-numbers?itemId=item-id') {
  return render(<QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false, gcTime: 0 } } })}><MemoryRouter initialEntries={[entry]}><SerialNumbersPage /></MemoryRouter></QueryClientProvider>)
}

it('shows source references and pages the serial register for historical items', async () => {
  const user = userEvent.setup()
  renderPage()
  expect(await screen.findByText('SN-001')).toBeInTheDocument()
  expect(screen.getByText('Invoice: invoice-line')).toBeInTheDocument()
  expect(screen.getByText(/Read-only review/)).toBeInTheDocument()
  expect(screen.queryByRole('button', { name: /Receive serials|Mark damaged|Assign sale/ })).not.toBeInTheDocument()
  await user.click(screen.getByRole('button', { name: 'Next serials' }))
  await waitFor(() => expect(listSerialNumbers).toHaveBeenLastCalledWith('item-id', 1))
})

it('loads available serials in the selected warehouse without sending unsupported status filters', async () => {
  const user = userEvent.setup()
  renderPage()
  await screen.findByText('SN-001')
  await user.selectOptions(screen.getByRole('combobox', { name: 'Serial view' }), 'available')
  await user.selectOptions(screen.getByRole('combobox', { name: 'Serial warehouse' }), 'main')
  await waitFor(() => expect(listAvailableSerials).toHaveBeenLastCalledWith('item-id', 'main'))
})

it('waits for an item and distinguishes query errors from an empty register', async () => {
  const view = renderPage('/inventory/serial-numbers')
  expect(screen.getByText('Select an item to review its serial history.')).toBeInTheDocument()
  expect(listSerialNumbers).not.toHaveBeenCalled()
  view.unmount()
  vi.mocked(listSerialNumbers).mockRejectedValue(new Error('Serial access denied'))
  renderPage()
  expect(await screen.findByText('Serial access denied')).toBeInTheDocument()
  expect(screen.queryByText(/No serial records match/)).not.toBeInTheDocument()
})
