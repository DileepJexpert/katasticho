import { fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { beforeEach, expect, it, vi } from 'vitest'
import { CreatePicklistModal } from './picklist-create-modal'
import { PicklistDetailPage } from './picklist-detail-page'
import * as api from './picklists-api'
import * as orders from '@/features/sales-orders/sales-orders-api'
import * as warehouses from '@/features/warehouses/warehouses-api'
import { useInventoryAccess } from '@/features/inventory/inventory-access'

vi.mock('./picklists-api', () => ({ createPicklist: vi.fn(), getPicklist: vi.fn(), startPicklist: vi.fn(), completePicklist: vi.fn(), cancelPicklist: vi.fn(), updatePicklistLines: vi.fn() }))
vi.mock('@/features/sales-orders/sales-orders-api', () => ({ getSalesOrder: vi.fn(), listSalesOrders: vi.fn() }))
vi.mock('@/features/warehouses/warehouses-api', () => ({ listWarehouses: vi.fn() }))
vi.mock('@/features/inventory/inventory-access', () => ({ useInventoryAccess: vi.fn() }))
vi.mock('@/features/inventory/batch-allocation-picker', () => ({ BatchAllocationPicker: ({ onChange, allowClear }: { onChange: (id: string) => void; allowClear: boolean }) => <button type="button" data-clearable={String(allowClear)} onClick={() => onChange('batch-uuid')}>Choose actual batch</button> }))

const order = {
  id: 'order-uuid', salesOrderNumber: 'SO-2026-001', status: 'CONFIRMED', warehouseId: 'warehouse-uuid', contactName: 'Ganesh Kirana',
  lines: [
    { id: 'order-line-uuid', itemId: 'item-uuid', itemName: 'Turmeric', quantity: 10, quantityShipped: 2, quantityBackordered: 3, unit: 'PCS' },
    { id: 'shipped-line', itemId: 'item-other', itemName: 'Already shipped', quantity: 2, quantityShipped: 2, quantityBackordered: 0 },
    { id: 'service-line', itemId: null, description: 'Delivery fee', quantity: 1, quantityShipped: 0, quantityBackordered: 0 },
  ],
} as unknown as orders.SalesOrder

const picklist: api.Picklist = {
  id: 'pick-uuid', picklistNumber: 'PICK-001', salesOrderId: order.id, salesOrderNumber: order.salesOrderNumber, warehouseId: 'warehouse-uuid', warehouseName: 'Main', status: 'PENDING', assignedTo: null,
  lineCount: 1, pickedCount: 0, notes: null, createdAt: '2026-09-05T00:00:00Z', startedAt: null, completedAt: null,
  lines: [{ id: 'pick-line-uuid', salesOrderLineId: 'order-line-uuid', itemId: 'item-uuid', itemName: 'Turmeric', sku: 'TUR', requiredQuantity: 5, pickedQuantity: 0, batchId: null, batchNumber: null, rackLocationId: null, rackLocationCode: 'A-01', notes: null }],
}

beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(useInventoryAccess).mockReturnValue({ operate: true, manage: true, administer: true, readZones: true })
  vi.mocked(orders.listSalesOrders).mockResolvedValue({ content: [order], page: 0, size: 25, totalElements: 1, totalPages: 1, last: true })
  vi.mocked(orders.getSalesOrder).mockResolvedValue(order)
  vi.mocked(warehouses.listWarehouses).mockResolvedValue([{ id: 'warehouse-uuid', name: 'Main', code: 'MAIN', active: true } as warehouses.Warehouse])
  vi.mocked(api.getPicklist).mockResolvedValue(picklist)
  vi.mocked(api.createPicklist).mockResolvedValue(picklist)
  vi.mocked(api.startPicklist).mockResolvedValue({ ...picklist, status: 'IN_PROGRESS' })
  vi.mocked(api.updatePicklistLines).mockResolvedValue(picklist)
  vi.mocked(api.completePicklist).mockResolvedValue({ ...picklist, status: 'COMPLETED' })
})

function renderView(view: React.ReactNode) {
  return render(<QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false, gcTime: 0 }, mutations: { retry: false } } })}><MemoryRouter initialEntries={['/picklists/pick-uuid']}>{view}</MemoryRouter></QueryClientProvider>)
}
function renderDetail() { return renderView(<Routes><Route path="/picklists/:picklistId" element={<PicklistDetailPage />} /></Routes>) }

it('creates only shippable item lines with UUIDs and required quantities', async () => {
  const saved = vi.fn()
  renderView(<CreatePicklistModal onClose={vi.fn()} onSuccess={saved} />)
  fireEvent.click(await screen.findByRole('button', { name: 'Choose SO-2026-001' }))
  const quantity = await screen.findByRole('spinbutton', { name: 'Pick quantity for Turmeric' })
  expect(quantity).toHaveValue(5)
  expect(screen.queryByText('Already shipped')).not.toBeInTheDocument()
  expect(screen.queryByText('Delivery fee')).not.toBeInTheDocument()
  await waitFor(() => expect(screen.getByRole('button', { name: 'Create picklist' })).toBeEnabled())
  fireEvent.click(screen.getByRole('button', { name: 'Create picklist' }))
  await waitFor(() => expect(api.createPicklist).toHaveBeenCalledTimes(1))
  expect(vi.mocked(api.createPicklist).mock.calls[0]?.[0]).toEqual({ salesOrderId: 'order-uuid', warehouseId: 'warehouse-uuid', notes: undefined, lines: [{ salesOrderLineId: 'order-line-uuid', requiredQuantity: 5 }] })
})

it('starts a PENDING picklist only after confirmation', async () => {
  renderDetail()
  fireEvent.click(await screen.findByRole('button', { name: 'Start picking' }))
  expect(api.startPicklist).not.toHaveBeenCalled()
  fireEvent.click(within(screen.getByRole('dialog')).getByRole('button', { name: 'Confirm start' }))
  await waitFor(() => expect(api.startPicklist).toHaveBeenCalledWith('pick-uuid'))
})

it('preserves zero picked quantity and sends batchId inside the lines wrapper', async () => {
  vi.mocked(api.getPicklist).mockResolvedValue({ ...picklist, status: 'IN_PROGRESS' })
  renderDetail()
  fireEvent.click(await screen.findByRole('button', { name: 'Update Turmeric' }))
  const dialog = screen.getByRole('dialog', { name: 'Record picked quantity' })
  expect(within(dialog).getByRole('spinbutton', { name: /Picked quantity/ })).toHaveValue(0)
  const batch = within(dialog).getByRole('button', { name: 'Choose actual batch' })
  expect(batch).toHaveAttribute('data-clearable', 'false')
  fireEvent.click(batch)
  fireEvent.click(within(dialog).getByRole('button', { name: 'Save picked quantity' }))
  await waitFor(() => expect(api.updatePicklistLines).toHaveBeenCalledWith('pick-uuid', { lines: [{ lineId: 'pick-line-uuid', pickedQuantity: 0, batchId: 'batch-uuid', notes: '' }] }))
})

it('makes partial completion explicit without claiming shipment', async () => {
  vi.mocked(api.getPicklist).mockResolvedValue({ ...picklist, status: 'IN_PROGRESS' })
  renderDetail()
  fireEvent.click(await screen.findByRole('button', { name: 'Complete picklist' }))
  const dialog = screen.getByRole('dialog', { name: 'Complete picklist' })
  expect(dialog).toHaveTextContent('1 line(s) are below their required quantity')
  expect(dialog).toHaveTextContent('does not mean the sales order has shipped')
  expect(api.completePicklist).not.toHaveBeenCalled()
})

it('shows actual SKU and rack fields but no mutation controls to a viewer', async () => {
  vi.mocked(useInventoryAccess).mockReturnValue({ operate: false, manage: false, administer: false, readZones: false })
  renderDetail()
  expect(await screen.findByText('TUR')).toBeInTheDocument()
  expect(screen.getByText('A-01')).toBeInTheDocument()
  expect(screen.queryByRole('button', { name: /start picking|cancel picklist|update Turmeric/i })).not.toBeInTheDocument()
})
