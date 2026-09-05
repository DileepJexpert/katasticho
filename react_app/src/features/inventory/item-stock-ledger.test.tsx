import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import { beforeEach, expect, it, vi } from 'vitest'
import { getItemMovements, type StockMovement } from '@/features/items/items-api'
import { ItemStockLedger } from './item-stock-ledger'

vi.mock('@/features/items/items-api', () => ({ getItemMovements: vi.fn() }))
const movement: StockMovement = {
  id: 'movement-1', itemId: 'item-1', itemName: 'Test item', itemSku: 'SKU-1', warehouseId: 'warehouse-1', warehouseName: 'Main store',
  movementDate: '2026-09-05', createdAt: '2026-09-05T10:00:00Z', movementType: 'REVERSAL', quantity: '-2', unitCost: '30', totalCost: '60',
  referenceType: 'STOCK_RECEIPT', referenceId: 'receipt-1', referenceNumber: 'GRN-001', reversal: true, reversalOfId: 'original-1', reversed: false,
  notes: 'Damaged delivery correction', batchId: 'batch-1', batchNumber: 'B-001', batchExpiryDate: '2027-01-01',
}
beforeEach(() => { vi.clearAllMocks(); vi.mocked(getItemMovements).mockResolvedValue([movement]) })
function setup() {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false, gcTime: 0 } } })
  return render(<QueryClientProvider client={client}><ItemStockLedger itemId="item-1" unit="PCS" /></QueryClientProvider>)
}

it('opens an audit view with the real movement, source and reversal references', async () => {
  setup()
  fireEvent.click(await screen.findByRole('button', { name: 'Audit movement movement-1' }))
  const dialog = within(screen.getByRole('dialog'))
  expect(dialog.getByText('receipt-1')).toBeInTheDocument()
  expect(dialog.getByText('original-1')).toBeInTheDocument()
  expect(dialog.getByText('Damaged delivery correction')).toBeInTheDocument()
  expect(dialog.getByText('batch-1')).toBeInTheDocument()
  expect(screen.queryByRole('button', { name: /reverse|adjust/i })).not.toBeInTheDocument()
})

it('loads older pages instead of silently truncating the ledger to 50 movements', async () => {
  vi.mocked(getItemMovements).mockImplementation(async (_id, page) => page === 0
    ? Array.from({ length: 50 }, (_, index) => ({ ...movement, id: `movement-${index}` })) : [])
  setup()
  await screen.findByRole('button', { name: 'Audit movement movement-0' })
  fireEvent.click(screen.getByRole('button', { name: 'Next movements' }))
  await waitFor(() => expect(getItemMovements).toHaveBeenLastCalledWith('item-1', 1))
  expect(await screen.findByText(/End of the stock ledger/)).toBeInTheDocument()
  expect(screen.getByRole('button', { name: 'Next movements' })).toBeDisabled()
  fireEvent.click(screen.getByRole('button', { name: 'Previous movements' }))
  expect(await screen.findByRole('button', { name: 'Audit movement movement-0' })).toBeInTheDocument()
})

it('distinguishes a failed ledger request from zero stock movements and permits retry', async () => {
  vi.mocked(getItemMovements).mockRejectedValueOnce(new Error('Stock ledger unavailable'))
  setup()
  expect(await screen.findByRole('alert')).toHaveTextContent('Stock ledger unavailable')
  expect(screen.queryByText(/No stock movements have been recorded/)).not.toBeInTheDocument()
  fireEvent.click(screen.getByRole('button', { name: 'Retry ledger' }))
  expect(await screen.findByRole('button', { name: 'Audit movement movement-1' })).toBeInTheDocument()
})

it('labels search as page-local and does not claim a filtered global count', async () => {
  setup()
  await screen.findByRole('button', { name: 'Audit movement movement-1' })
  fireEvent.change(screen.getByPlaceholderText('Search movements on this page'), { target: { value: 'not-found' } })
  expect(screen.getByText('No matching movements on this page.')).toBeInTheDocument()
  expect(screen.getByText(/API does not return a total count/)).toBeInTheDocument()
})
