import { act, fireEvent, render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { beforeEach, expect, it, vi } from 'vitest'
import { enterpriseUser } from '@/features/accounting/enterprise-test-fixtures'
import { useSessionStore } from '@/shared/session/session-store'
import * as items from '@/features/items/items-api'
import * as suppliers from '@/features/suppliers/suppliers-api'
import * as warehouses from '@/features/warehouses/warehouses-api'
import * as api from './supply-chain-api'
import { RequisitionsPage, RequisitionDetailPage } from './requisitions-page'
import { SupplyShipmentsPage, SupplyShipmentDetailPage } from './shipments-page'
import { ForecastsPage } from './forecasts-page'
import { SupplyReturnsPage } from './supply-returns-page'
import { ItemSuppliersPage } from './item-suppliers-page'

vi.mock('./supply-chain-api', async (importOriginal) => ({ ...await importOriginal<typeof api>(), listRequisitions: vi.fn(), getRequisition: vi.fn(), createRequisition: vi.fn(), autoRequisition: vi.fn(), requisitionAction: vi.fn(), listShipments: vi.fn(), getShipment: vi.fn(), createShipment: vi.fn(), shipmentAction: vi.fn(), listForecasts: vi.fn(), generateForecast: vi.fn(), listSupplyReturns: vi.fn(), listItemSuppliers: vi.fn(), addItemSupplier: vi.fn() }))
vi.mock('@/features/items/items-api', () => ({ listItems: vi.fn(), getItem: vi.fn() }))
vi.mock('@/features/suppliers/suppliers-api', () => ({ listSelectableSuppliers: vi.fn(), getSupplier: vi.fn() }))
vi.mock('@/features/warehouses/warehouses-api', () => ({ listWarehouses: vi.fn() }))
const item = { id: 'item-1', name: 'Turmeric test', sku: 'TURMERIC', purchasePrice: 30 } as items.Item
const supplier = { id: 'supplier-1', name: 'Annapurna Supplier', active: true } as suppliers.Supplier
const requisition: api.Requisition = { id: 'req-1', requisitionNumber: 'PR-001', status: 'DRAFT', supplierId: null, warehouseId: null, requiredByDate: null, totalAmount: 300, source: 'MANUAL', purchaseOrderId: null, notes: null, lines: [{ id: 'line-1', itemId: 'item-1', requiredQty: 10, estimatedUnitPrice: 30, estimatedLineTotal: 300 }] }
const shipment: api.Shipment = { id: 'shipment-1', shipmentNumber: 'SHP-001', shipmentType: 'OUTBOUND', status: 'DRAFT', originWarehouseId: null, destinationWarehouseId: null, carrier: 'Test carrier', vehicleNumber: null, estimatedDeparture: null, estimatedArrival: null, actualDeparture: null, actualArrival: null, freightCost: 0, notes: null, lines: [] }
beforeEach(() => {
  vi.clearAllMocks()
  useSessionStore.setState({ status: 'authenticated', user: enterpriseUser })
  vi.mocked(api.listRequisitions).mockResolvedValue({ content: [requisition], totalPages: 2, totalElements: 26 })
  vi.mocked(api.getRequisition).mockResolvedValue(requisition)
  vi.mocked(api.createRequisition).mockResolvedValue(requisition)
  vi.mocked(api.autoRequisition).mockResolvedValue(null)
  vi.mocked(api.listShipments).mockResolvedValue([shipment])
  vi.mocked(api.getShipment).mockResolvedValue(shipment)
  vi.mocked(api.createShipment).mockResolvedValue(shipment)
  vi.mocked(api.listForecasts).mockResolvedValue([])
  vi.mocked(api.generateForecast).mockResolvedValue([])
  vi.mocked(api.listSupplyReturns).mockResolvedValue({ content: [], totalPages: 0, totalElements: 0 })
  vi.mocked(api.listItemSuppliers).mockResolvedValue([])
  vi.mocked(api.addItemSupplier).mockResolvedValue({} as api.ItemSupplier)
  vi.mocked(items.listItems).mockResolvedValue({ content: [item], totalPages: 1, totalElements: 1, size: 25, page: 0, last: true })
  vi.mocked(items.getItem).mockResolvedValue(item)
  vi.mocked(suppliers.listSelectableSuppliers).mockResolvedValue({ content: [supplier], totalPages: 1, totalElements: 1, size: 25, page: 0, last: true })
  vi.mocked(warehouses.listWarehouses).mockResolvedValue([{ id: 'warehouse-1', name: 'Main warehouse', code: 'MAIN', active: true } as warehouses.Warehouse])
})
function show(page: React.ReactNode, path = '/') {
  return render(<QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false }, mutations: { retry: false } } })}><MemoryRouter initialEntries={[path]}><Routes><Route path="/" element={page} /><Route path="/supply-chain/requisitions/:requisitionId" element={<RequisitionDetailPage />} /><Route path="/supply-chain/shipments/:shipmentId" element={<SupplyShipmentDetailPage />} /></Routes></MemoryRouter></QueryClientProvider>)
}
async function pick(label: string, name: string) { await userEvent.click(screen.getByRole('combobox', { name: label })); await userEvent.click(await screen.findByRole('option', { name: new RegExp(name) })) }

it('uses server pagination and resets it when a status filter changes', async () => {
  show(<RequisitionsPage />)
  await screen.findByText('PR-001')
  await userEvent.click(screen.getByRole('button', { name: 'Next page' }))
  await waitFor(() => expect(api.listRequisitions).toHaveBeenLastCalledWith(1, ''))
  await userEvent.click(screen.getByRole('tab', { name: 'APPROVED' }))
  await waitFor(() => expect(api.listRequisitions).toHaveBeenLastCalledWith(0, 'APPROVED'))
})

it('creates a draft using named item selection and numeric line fields', async () => {
  show(<RequisitionsPage />)
  await userEvent.click(screen.getByRole('button', { name: 'New requisition' }))
  expect(screen.getByRole('button', { name: 'Create draft' })).toBeDisabled()
  await pick('Item 1', 'Turmeric test')
  fireEvent.change(screen.getByLabelText('Quantity 1'), { target: { value: '10' } })
  await userEvent.click(screen.getByRole('button', { name: 'Create draft' }))
  await waitFor(() => expect(api.createRequisition).toHaveBeenCalledWith({ supplierId: undefined, warehouseId: undefined, requiredByDate: undefined, notes: '', lines: [{ itemId: 'item-1', requiredQty: 10, estimatedUnitPrice: 30 }] }))
  expect(await screen.findByRole('heading', { name: 'PR-001' })).toBeInTheDocument()
})

it('blocks duplicate items and invalid quantities in requisition drafts', async () => {
  show(<RequisitionsPage />)
  await userEvent.click(screen.getByRole('button', { name: 'New requisition' }))
  await pick('Item 1', 'Turmeric test')
  fireEvent.change(screen.getByLabelText('Quantity 1'), { target: { value: '0' } })
  expect(screen.getByRole('button', { name: 'Create draft' })).toBeDisabled()
  fireEvent.change(screen.getByLabelText('Quantity 1'), { target: { value: '2' } })
  await userEvent.click(screen.getByRole('button', { name: 'Add line' }))
  await pick('Item 2', 'Turmeric test')
  expect(screen.getByRole('button', { name: 'Create draft' })).toBeDisabled()
  expect(api.createRequisition).not.toHaveBeenCalled()
})

it('does not announce a created requisition when the automatic scan returns null', async () => {
  show(<RequisitionsPage />)
  await userEvent.click(screen.getByRole('button', { name: 'Draft from low stock' }))
  expect(api.autoRequisition).not.toHaveBeenCalled()
  await userEvent.click(screen.getByRole('button', { name: 'Confirm' }))
  expect(await screen.findByText('No eligible low-stock items were found.')).toBeInTheDocument()
})

it('lets accountants submit but not approve or reject requisitions', async () => {
  useSessionStore.setState({ user: { ...enterpriseUser, role: 'ACCOUNTANT' } })
  show(null, '/supply-chain/requisitions/req-1')
  expect(await screen.findByRole('button', { name: 'Submit requisition' })).toBeInTheDocument()
  expect(screen.queryByRole('button', { name: 'Approve requisition' })).not.toBeInTheDocument()
  expect(screen.queryByRole('button', { name: 'Reject requisition' })).not.toBeInTheDocument()
})

it('does not navigate into an old organisation after an in-flight draft completes', async () => {
  let resolve!: (record: api.Requisition) => void
  vi.mocked(api.createRequisition).mockImplementation(() => new Promise((done) => { resolve = done }))
  show(<RequisitionsPage />)
  await userEvent.click(screen.getByRole('button', { name: 'New requisition' }))
  await pick('Item 1', 'Turmeric test')
  await userEvent.click(screen.getByRole('button', { name: 'Create draft' }))
  act(() => useSessionStore.setState({ user: { ...enterpriseUser, orgId: 'org-2' } }))
  await act(async () => resolve(requisition))
  expect(screen.queryByRole('heading', { name: 'PR-001' })).not.toBeInTheDocument()
  expect(screen.getByRole('heading', { name: 'Purchase requisitions' })).toBeInTheDocument()
})

it('keeps shipment tracking read-only for operators', async () => {
  useSessionStore.setState({ user: { ...enterpriseUser, role: 'OPERATOR' } })
  show(null, '/supply-chain/shipments/shipment-1')
  expect(await screen.findByRole('heading', { name: 'SHP-001' })).toBeInTheDocument()
  expect(screen.queryByRole('button', { name: 'Mark in transit' })).not.toBeInTheDocument()
  expect(screen.queryByRole('button', { name: 'Cancel tracking record' })).not.toBeInTheDocument()
  expect(screen.getByText(/do not reserve, issue, receive or transfer stock/)).toBeInTheDocument()
})

it('does not allow terminal shipments to be dispatched or cancelled again', async () => {
  vi.mocked(api.getShipment).mockResolvedValue({ ...shipment, status: 'DELIVERED' })
  show(null, '/supply-chain/shipments/shipment-1')
  await screen.findByRole('heading', { name: 'SHP-001' })
  expect(screen.queryByRole('button', { name: /Mark|Cancel tracking/ })).not.toBeInTheDocument()
})

it('requires distinct warehouses for a transfer tracking draft', async () => {
  show(<SupplyShipmentsPage />)
  await userEvent.click(screen.getByRole('button', { name: 'New tracking record' }))
  await userEvent.selectOptions(screen.getByRole('combobox', { name: 'Shipment type' }), 'TRANSFER')
  await pick('Shipment item 1', 'Turmeric test')
  expect(screen.getByRole('button', { name: 'Create tracking draft' })).toBeDisabled()
  await pick('Origin warehouse', 'Main warehouse')
  await pick('Destination warehouse', 'Main warehouse')
  expect(screen.getByRole('button', { name: 'Create tracking draft' })).toBeDisabled()
})

it('blocks invalid forecast ranges and ignores hidden history for seasonal generation', async () => {
  show(<ForecastsPage />)
  fireEvent.change(screen.getByLabelText('From'), { target: { value: '2026-12-31' } })
  fireEvent.change(screen.getByLabelText('To'), { target: { value: '2026-09-01' } })
  expect(screen.getByRole('button', { name: 'Apply range' })).toBeDisabled()
  fireEvent.change(screen.getByLabelText('History months'), { target: { value: '' } })
  expect(screen.getByRole('button', { name: 'Generate forecasts' })).toBeDisabled()
  await userEvent.selectOptions(screen.getByRole('combobox', { name: 'Forecast method' }), 'generate-seasonal')
  await userEvent.click(screen.getByRole('button', { name: 'Generate forecasts' }))
  expect(api.generateForecast).not.toHaveBeenCalled()
  expect(screen.getByText(/display date range does not limit generation/)).toBeInTheDocument()
  await userEvent.click(screen.getByRole('button', { name: 'Confirm' }))
  await waitFor(() => expect(api.generateForecast).toHaveBeenCalledWith('generate-seasonal', 3, 0))
})

it('offers no misleading return processing or refund action', async () => {
  show(<SupplyReturnsPage />)
  expect(await screen.findByText('No return requests found.')).toBeInTheDocument()
  expect(screen.getByText(/recorded refund amount is not a payment/)).toBeInTheDocument()
  expect(screen.queryByRole('button', { name: /Process|Refund|Approve/ })).not.toBeInTheDocument()
})

it('uses selectable supplier projections and validates mapping lead time', async () => {
  show(<ItemSuppliersPage />)
  await pick('Item', 'Turmeric test')
  await userEvent.click(screen.getByRole('button', { name: 'Add supplier mapping' }))
  await pick('Supplier', 'Annapurna Supplier')
  fireEvent.change(screen.getByLabelText('Lead time days'), { target: { value: '1.5' } })
  expect(screen.getByRole('button', { name: 'Save mapping' })).toBeDisabled()
  fireEvent.change(screen.getByLabelText('Lead time days'), { target: { value: '7' } })
  await userEvent.click(screen.getByRole('button', { name: 'Save mapping' }))
  await waitFor(() => expect(api.addItemSupplier).toHaveBeenCalledWith(expect.objectContaining({ itemId: 'item-1', supplierId: 'supplier-1', leadTimeDays: 7, unitPrice: 30 })))
})
