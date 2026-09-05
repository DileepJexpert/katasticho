import { fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { beforeEach, expect, it, vi } from 'vitest'
import { ConsignmentsPage } from './consignments-page'
import * as api from './consignment-api'

vi.mock('./consignment-api', () => ({ getConsignmentStock: vi.fn(), getUnsettledConsignmentSales: vi.fn(), receiveConsignment: vi.fn(), recordConsignmentSale: vi.fn(), settleConsignment: vi.fn() }))
vi.mock('./inventory-access', () => ({ useInventoryAccess: () => ({ operate: true, manage: true }) }))
vi.mock('@/features/items/items-api', () => ({ getItem: vi.fn().mockResolvedValue({ name: 'Turmeric', sku: 'TUR' }), listItems: vi.fn() }))
vi.mock('@/features/suppliers/suppliers-api', () => ({ getSupplier: vi.fn().mockResolvedValue({ name: 'Annapurna' }), listSelectableSuppliers: vi.fn() }))
vi.mock('@/features/warehouses/warehouses-api', () => ({ getWarehouse: vi.fn().mockResolvedValue({ name: 'Main' }), listWarehouses: vi.fn() }))

beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(api.getConsignmentStock).mockResolvedValue([{ id: 'stock-id', itemId: 'item-id', warehouseId: 'warehouse-id', supplierId: 'supplier-id', quantity: '7.5', unitCost: '30', consignmentDate: '2026-09-05', status: 'ACTIVE', settlementMethod: 'ON_SALE' }])
  vi.mocked(api.getUnsettledConsignmentSales).mockResolvedValue([{ id: 'settlement-id', consignmentStockId: 'stock-id', settlementNumber: 'SET-001', quantitySold: 2, unitCost: 30, totalAmount: 60, settlementDate: '2026-09-05', status: 'DRAFT' }])
  vi.mocked(api.settleConsignment).mockResolvedValue({ id: 'settlement-id', status: 'SETTLED' } as api.ConsignmentSettlement)
})
function renderPage() { return render(<QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false, gcTime: 0 } } })}><ConsignmentsPage /></QueryClientProvider>) }

it('uses actual remaining quantity and settles a settlement, not its stock record', async () => {
  renderPage()
  await screen.findByText('Turmeric')
  expect(screen.getByRole('table')).toHaveTextContent('7.5')
  expect(screen.getByText(/do not post warehouse stock movements/)).toBeInTheDocument()
  fireEvent.click(screen.getByRole('button', { name: 'Supplier settlements' }))
  const dialog = screen.getByRole('dialog', { name: 'Supplier settlements' })
  fireEvent.click(await within(dialog).findByRole('button', { name: 'Mark settled' }))
  expect(api.getUnsettledConsignmentSales).toHaveBeenCalledWith('supplier-id')
  expect(api.settleConsignment).not.toHaveBeenCalled()
  expect(dialog).toHaveTextContent('does not pay the supplier')
  fireEvent.click(within(dialog).getByRole('button', { name: 'Confirm settlement' }))
  await waitFor(() => expect(api.settleConsignment).toHaveBeenCalledWith('settlement-id'))
})

it('prevents a sale quantity above the current consignment register balance', async () => {
  renderPage()
  fireEvent.click(await screen.findByRole('button', { name: 'Record sale' }))
  const dialog = screen.getByRole('dialog', { name: 'Record consignment sale' })
  fireEvent.change(within(dialog).getByRole('spinbutton', { name: /Quantity sold/ }), { target: { value: '8' } })
  expect(within(dialog).getByRole('button', { name: 'Confirm sale' })).toBeDisabled()
  expect(api.recordConsignmentSale).not.toHaveBeenCalled()
})

it('renders read failures as errors, not an empty register', async () => {
  vi.mocked(api.getConsignmentStock).mockRejectedValue(new Error('Consignments unavailable'))
  renderPage()
  expect(await screen.findByRole('alert')).toHaveTextContent('Consignments unavailable')
  expect(screen.queryByText('No consignment records on this page.')).not.toBeInTheDocument()
})
