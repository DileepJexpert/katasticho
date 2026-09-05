import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, expect, it, vi } from 'vitest'
import { ShortbookPage } from './shortbook-page'
import { getItem, getShortbook, type Item } from '@/features/items/items-api'
import { createPurchaseOrder, type PurchaseOrder } from '@/features/purchase-orders/purchase-orders-api'
import { listSelectableSuppliers, type Supplier } from '@/features/suppliers/suppliers-api'
import { listWarehouses, type Warehouse } from '@/features/warehouses/warehouses-api'

vi.mock('@/features/items/items-api', () => ({ getItem: vi.fn(), getShortbook: vi.fn(), listItems: vi.fn() }))
vi.mock('@/features/purchase-orders/purchase-orders-api', () => ({ createPurchaseOrder: vi.fn() }))
vi.mock('@/features/suppliers/suppliers-api', () => ({ listSelectableSuppliers: vi.fn() }))
vi.mock('@/features/warehouses/warehouses-api', () => ({ listWarehouses: vi.fn() }))
vi.mock('./inventory-access', () => ({ useInventoryAccess: () => ({ manage: true }) }))

beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(getShortbook).mockResolvedValue([{ itemId: 'item-id', itemName: 'Turmeric', sku: 'TUR', hsnCode: null, currentStock: 2, reorderLevel: 10, reorderQuantity: 20, backordered: 5, suggestOrderQty: 25, reason: 'BOTH' }])
  vi.mocked(getItem).mockResolvedValue({ id: 'item-id', name: 'Turmeric', active: true, purchasePrice: 30, defaultTaxGroupId: 'tax-id' } as Item)
  vi.mocked(listSelectableSuppliers).mockResolvedValue({ content: [{ id: 'supplier-uuid', name: 'Annapurna', phone: '9000000000' } as Supplier], page: 0, size: 25, totalElements: 1, totalPages: 1, last: true })
  vi.mocked(listWarehouses).mockResolvedValue([{ id: 'warehouse-uuid', code: 'MAIN', name: 'Main warehouse', active: true } as Warehouse])
  vi.mocked(createPurchaseOrder).mockResolvedValue({ id: 'po-id' } as PurchaseOrder)
})

function renderPage() {
  return render(<QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false, gcTime: 0 } } })}><MemoryRouter><ShortbookPage /></MemoryRouter></QueryClientProvider>)
}

it('uses server suggested quantity and real supplier/warehouse UUIDs for the draft PO', async () => {
  const user = userEvent.setup()
  renderPage()
  await user.click(await screen.findByRole('checkbox', { name: 'Select Turmeric' }))
  await user.click(screen.getByRole('button', { name: 'Create draft PO (1)' }))
  const dialog = screen.getByRole('dialog', { name: 'Create replenishment PO' })
  expect(await within(dialog).findByRole('spinbutton', { name: 'Order quantity for Turmeric' })).toHaveValue(25)
  await user.click(within(dialog).getByRole('combobox', { name: 'Search inventory supplier' }))
  await user.click(await within(dialog).findByRole('option', { name: /Annapurna/ }))
  await user.click(within(dialog).getByRole('combobox', { name: 'Select inventory warehouse' }))
  await user.click(within(dialog).getByRole('option', { name: /Main warehouse/ }))
  await user.click(within(dialog).getByRole('button', { name: 'Create draft PO' }))
  await waitFor(() => expect(createPurchaseOrder).toHaveBeenCalledWith(expect.objectContaining({
    supplierId: 'supplier-uuid', warehouseId: 'warehouse-uuid',
    lines: [{ itemId: 'item-id', quantity: 25, unitPrice: 30, description: 'Turmeric', taxGroupId: 'tax-id' }],
  })))
})

it('does not treat a failed shortbook request as healthy stock', async () => {
  vi.mocked(getShortbook).mockRejectedValue(new Error('Inventory unavailable'))
  renderPage()
  expect(await screen.findByRole('alert')).toHaveTextContent('Inventory unavailable')
  expect(screen.queryByText('The server returned no replenishment suggestions.')).not.toBeInTheDocument()
  expect(screen.getByRole('button', { name: 'Create draft PO (0)' })).toBeDisabled()
})

it('does not silently create a zero-price PO when the item purchase rate is missing', async () => {
  vi.mocked(getItem).mockResolvedValue({ id: 'item-id', name: 'Turmeric', active: true, purchasePrice: null } as Item)
  const user = userEvent.setup()
  renderPage()
  await user.click(await screen.findByRole('checkbox', { name: 'Select Turmeric' }))
  await user.click(screen.getByRole('button', { name: 'Create draft PO (1)' }))
  expect(await screen.findByRole('alert')).toHaveTextContent('no valid purchase rate')
  expect(screen.getByRole('button', { name: 'Create draft PO' })).toBeDisabled()
  expect(createPurchaseOrder).not.toHaveBeenCalled()
})
