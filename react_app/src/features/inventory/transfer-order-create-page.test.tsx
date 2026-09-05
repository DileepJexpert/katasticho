import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, expect, it, vi } from 'vitest'
import { TransferOrderCreatePage } from './transfer-order-create-page'
import { createTransferOrder, type TransferOrder } from './transfer-orders-api'
import { listItems, type Item } from '@/features/items/items-api'
import { listWarehouses, type Warehouse } from '@/features/warehouses/warehouses-api'

vi.mock('./transfer-orders-api', () => ({ createTransferOrder: vi.fn() }))
vi.mock('@/features/items/items-api', () => ({ listItems: vi.fn() }))
vi.mock('@/features/warehouses/warehouses-api', () => ({ listWarehouses: vi.fn() }))
vi.mock('./inventory-access', () => ({ useInventoryAccess: () => ({ operate: true }) }))
vi.mock('./batch-allocation-picker', () => ({ BatchAllocationPicker: ({ value, onChange, warehouseId }: { value: string | null; onChange: (id: string) => void; warehouseId: string }) => <button type="button" onClick={() => onChange('batch-' + warehouseId)}>{value ?? 'Select source batch'}</button> }))

beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(listWarehouses).mockResolvedValue([
    { id: 'wh-source', name: 'Main', code: 'MAIN', active: true },
    { id: 'wh-dest', name: 'Branch', code: 'BRANCH', active: true },
    { id: 'wh-third', name: 'Overflow', code: 'OVERFLOW', active: true },
  ] as Warehouse[])
  vi.mocked(listItems).mockResolvedValue({ content: [{ id: 'item-id', name: 'Turmeric', sku: 'TUR', trackInventory: true, trackBatches: true, active: true, unitOfMeasure: 'PCS' } as Item], page: 0, size: 20, totalElements: 1, totalPages: 1, last: true })
  vi.mocked(createTransferOrder).mockResolvedValue({ id: 'transfer-id' } as TransferOrder)
})
function renderPage() { return render(<QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false, gcTime: 0 } } })}><MemoryRouter><TransferOrderCreatePage /></MemoryRouter></QueryClientProvider>) }

it('requires a source batch and clears it if the source warehouse changes', async () => {
  const user = userEvent.setup()
  renderPage()
  await waitFor(() => expect(screen.getByRole('combobox', { name: /Source warehouse/ })).toBeEnabled())
  await user.selectOptions(screen.getByRole('combobox', { name: /Source warehouse/ }), 'wh-source')
  await user.selectOptions(screen.getByRole('combobox', { name: /Destination warehouse/ }), 'wh-dest')
  await user.click(screen.getByRole('combobox', { name: 'Search items to add to transfer' }))
  await user.click(await screen.findByRole('option', { name: /Turmeric/ }))
  await user.click(screen.getByRole('button', { name: 'Create draft transfer' }))
  expect(screen.getByRole('alert')).toHaveTextContent('Select the source batch')
  expect(createTransferOrder).not.toHaveBeenCalled()
  await user.click(screen.getByRole('button', { name: 'Select source batch' }))
  await user.selectOptions(screen.getByRole('combobox', { name: /Source warehouse/ }), 'wh-third')
  expect(screen.getByRole('button', { name: 'Select source batch' })).toBeInTheDocument()
  await user.click(screen.getByRole('button', { name: 'Select source batch' }))
  fireEvent.change(screen.getByRole('spinbutton', { name: 'Quantity for Turmeric' }), { target: { value: '2' } })
  await user.click(screen.getByRole('button', { name: 'Create draft transfer' }))
  await waitFor(() => expect(createTransferOrder).toHaveBeenCalledWith(expect.objectContaining({ fromWarehouseId: 'wh-third', toWarehouseId: 'wh-dest', lines: [{ itemId: 'item-id', batchId: 'batch-wh-third', quantity: 2, notes: undefined }] })))
})
