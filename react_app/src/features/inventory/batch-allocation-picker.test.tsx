import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, expect, it, vi } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { BatchAllocationPicker } from './batch-allocation-picker'
import { getItem, type Item } from '@/features/items/items-api'
import { listAvailableBatches } from './batches-api'

vi.mock('@/features/items/items-api', () => ({ getItem: vi.fn() }))
vi.mock('./batches-api', () => ({ listAvailableBatches: vi.fn() }))
beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(getItem).mockResolvedValue({ id: 'item-1', trackBatches: true } as Item)
  vi.mocked(listAvailableBatches).mockResolvedValue([
    { id: 'batch-early', itemId: 'item-1', batchNumber: 'EARLY', expiryDate: '2027-01-01', unitCost: 30, supplierId: null, active: true, quantityAvailable: 2 },
    { id: 'batch-later', itemId: 'item-1', batchNumber: 'LATER', expiryDate: '2027-02-01', unitCost: 32, supplierId: null, active: true, quantityAvailable: 20 },
  ])
})
function renderPicker(onChange = vi.fn(), automatic = false, value: string | null = null) {
  render(<QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}><BatchAllocationPicker itemId="item-1" value={value} warehouseId="warehouse-2" quantity={10} onChange={onChange} automatic={automatic} /></QueryClientProvider>)
}
it('loads only on request, uses the issuing warehouse, and selects a batch UUID', async () => {
  const user = userEvent.setup()
  const onChange = vi.fn()
  renderPicker(onChange)
  expect(listAvailableBatches).not.toHaveBeenCalled()
  await user.click(screen.getByRole('button', { name: 'Select batch' }))
  const table = await screen.findByRole('table', { name: 'Available batches in FEFO order' })
  expect(listAvailableBatches).toHaveBeenCalledWith('item-1', 'warehouse-2')
  expect(within(table).getByRole('button', { name: 'Insufficient for line' })).toBeDisabled()
  await user.click(within(table).getByRole('button', { name: /^Select$/ }))
  expect(onChange).toHaveBeenCalledWith('batch-later', expect.objectContaining({ batchNumber: 'LATER' }))
})
it('does not present automatic allocation on a challan', async () => {
  const user = userEvent.setup()
  renderPicker()
  await user.click(screen.getByRole('button', { name: 'Select batch' }))
  expect(screen.queryByRole('button', { name: 'Use automatic FEFO' })).not.toBeInTheDocument()
})
it('clears an explicit batch for invoice or POS automatic selection', async () => {
  const user = userEvent.setup()
  const onChange = vi.fn()
  renderPicker(onChange, true, 'batch-later')
  await user.click(screen.getByRole('button', { name: 'Batch selected' }))
  await user.click(screen.getByRole('button', { name: 'Use automatic FEFO' }))
  expect(onChange).toHaveBeenCalledWith(undefined, undefined)
})
it('allows clearing a challan batch without promising automatic allocation', async () => {
  const user = userEvent.setup()
  const onChange = vi.fn()
  renderPicker(onChange, false, 'batch-later')
  await user.click(screen.getByRole('button', { name: 'Batch selected' }))
  await user.click(screen.getByRole('button', { name: 'Clear batch selection' }))
  expect(onChange).toHaveBeenCalledWith(undefined, undefined)
})
