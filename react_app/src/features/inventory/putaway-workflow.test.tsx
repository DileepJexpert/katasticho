import { fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { beforeEach, expect, it, vi } from 'vitest'
import { PutawayCreatePage } from './putaway-create-page'
import { PutawayDetailPage } from './putaway-detail-page'
import { PutawayTasksPage } from './putaway-tasks-page'
import { cancelPutawayTask, confirmPutawayLine, createPutawayTask, getPutawayTask, listPutawayTasks, type PutawayTask } from './putaway-api'
import { getItem, type Item } from '@/features/items/items-api'
import { getStockReceipt, type StockReceipt } from '@/features/stock-receipts/stock-receipts-api'
import { listWarehouses, type Warehouse } from '@/features/warehouses/warehouses-api'
import { listRackLocations, type RackLocation } from '@/features/pharmacy/pharmacy-api'

const access = vi.hoisted(() => ({ operate: true }))
vi.mock('./inventory-access', () => ({ useInventoryAccess: () => access }))
vi.mock('./putaway-api', () => ({ cancelPutawayTask: vi.fn(), confirmPutawayLine: vi.fn(), createPutawayTask: vi.fn(), getPutawayTask: vi.fn(), listPutawayTasks: vi.fn() }))
vi.mock('@/features/items/items-api', () => ({ getItem: vi.fn(), listItems: vi.fn() }))
vi.mock('@/features/stock-receipts/stock-receipts-api', () => ({ getStockReceipt: vi.fn() }))
vi.mock('@/features/warehouses/warehouses-api', () => ({ listWarehouses: vi.fn() }))
vi.mock('@/features/pharmacy/pharmacy-api', () => ({ listRackLocations: vi.fn(), createRackLocation: vi.fn() }))

const task: PutawayTask = { id: 'task-id', orgId: 'org', taskNumber: 'PTW-001', warehouseId: 'main', goodsReceiptId: 'receipt-id', sourceLocation: 'RECEIVING_DOCK', status: 'PENDING', assignedTo: null, notes: null, createdAt: '2026-09-05T10:00:00Z', updatedAt: '2026-09-05T10:00:00Z', lines: [{ id: 'line-id', itemId: 'item-id', quantity: 5, batchNumber: 'B1', suggestedRackId: 'rack-id', confirmedRackId: null, status: 'PENDING', confirmedAt: null, confirmedBy: null }] }
beforeEach(() => {
  vi.clearAllMocks(); access.operate = true
  vi.mocked(getPutawayTask).mockResolvedValue(structuredClone(task))
  vi.mocked(listPutawayTasks).mockResolvedValue([structuredClone(task)])
  vi.mocked(createPutawayTask).mockResolvedValue(structuredClone(task))
  vi.mocked(confirmPutawayLine).mockImplementation(async () => {
    const completed = { ...task, status: 'COMPLETED' as const, lines: [{ ...task.lines[0]!, status: 'CONFIRMED' as const, confirmedRackId: 'rack-id' }] }
    vi.mocked(getPutawayTask).mockResolvedValue(completed)
    return completed
  })
  vi.mocked(cancelPutawayTask).mockResolvedValue({ ...task, status: 'CANCELLED' })
  vi.mocked(listWarehouses).mockResolvedValue([{ id: 'main', name: 'Main', code: 'MAIN', active: true }] as Warehouse[])
  vi.mocked(listRackLocations).mockResolvedValue([{ id: 'rack-id', code: 'A-01', warehouseId: 'main', active: true }] as RackLocation[])
  vi.mocked(getItem).mockResolvedValue({ id: 'item-id', name: 'Turmeric', unitOfMeasure: 'PCS', active: true } as Item)
  vi.mocked(getStockReceipt).mockResolvedValue({ id: 'receipt-id', receiptNumber: 'GRN-001', warehouseId: 'main', warehouseName: 'Main', status: 'RECEIVED', lines: [{ id: 'receipt-line', itemId: 'item-id', itemName: 'Turmeric', quantity: 5, unitOfMeasure: 'PCS', batchNumber: 'B1' }] } as StockReceipt)
})
function renderPage(path: string, component: React.ReactNode, entry = path) {
  return render(<QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false, gcTime: 0 } } })}><MemoryRouter initialEntries={[entry]}><Routes><Route path={path} element={component} /><Route path="/inventory/putaway-tasks/task-id" element={<p>Saved task</p>} /></Routes></MemoryRouter></QueryClientProvider>)
}

it('creates receipt-linked placement with quantity and batch reference preserved', async () => {
  const user = userEvent.setup()
  renderPage('/new', <PutawayCreatePage />, '/new?receiptId=receipt-id')
  expect(await screen.findByDisplayValue('B1')).toHaveAttribute('readonly')
  expect(screen.getByDisplayValue('Main')).toHaveAttribute('readonly')
  const quantity = screen.getByRole('spinbutton', { name: 'Quantity for Turmeric' })
  fireEvent.change(quantity, { target: { value: '3' } })
  await waitFor(() => expect(screen.getByRole('button', { name: 'Create putaway task' })).toBeEnabled())
  await user.click(screen.getByRole('button', { name: 'Create putaway task' }))
  await waitFor(() => expect(vi.mocked(createPutawayTask).mock.calls[0]?.[0]).toEqual({ goodsReceiptId: 'receipt-id', warehouseId: 'main', sourceLocation: 'RECEIVING_DOCK', notes: undefined, lines: [{ itemId: 'item-id', quantity: 3, batchNumber: 'B1', suggestedRackId: undefined }] }))
})

it('blocks an unreceived source document', async () => {
  vi.mocked(getStockReceipt).mockResolvedValue({ status: 'DRAFT' } as StockReceipt)
  renderPage('/new', <PutawayCreatePage />, '/new?receiptId=receipt-id')
  expect(await screen.findByRole('alert')).toHaveTextContent('Only a received goods receipt')
  expect(createPutawayTask).not.toHaveBeenCalled()
})

it('confirms the line and actual rack after checking the current task state', async () => {
  const user = userEvent.setup()
  renderPage('/tasks/:taskId', <PutawayDetailPage />, '/tasks/task-id')
  await user.click(await screen.findByRole('button', { name: 'Confirm Turmeric' }))
  const dialog = within(screen.getByRole('dialog'))
  await waitFor(() => expect(dialog.getByText('A-01')).toBeInTheDocument())
  await user.click(dialog.getByRole('button', { name: 'Record placement' }))
  await waitFor(() => expect(confirmPutawayLine).toHaveBeenCalledWith('task-id', 'line-id', 'rack-id'))
  expect(await screen.findByText('COMPLETED')).toBeInTheDocument()
})

it('does not confirm a cancelled task discovered during the preflight read', async () => {
  const user = userEvent.setup()
  renderPage('/tasks/:taskId', <PutawayDetailPage />, '/tasks/task-id')
  await user.click(await screen.findByRole('button', { name: 'Confirm Turmeric' }))
  await waitFor(() => expect(screen.getByRole('dialog')).toBeInTheDocument())
  vi.mocked(getPutawayTask).mockResolvedValue({ ...task, status: 'CANCELLED' })
  await user.click(screen.getByRole('button', { name: 'Record placement' }))
  expect(await screen.findByRole('alert')).toHaveTextContent('no longer open')
  expect(confirmPutawayLine).not.toHaveBeenCalled()
})

it('requires cancellation confirmation and warns that placements are not reversed', async () => {
  const user = userEvent.setup()
  renderPage('/tasks/:taskId', <PutawayDetailPage />, '/tasks/task-id')
  await user.click(await screen.findByRole('button', { name: 'Cancel task' }))
  expect(screen.getByRole('dialog')).toHaveTextContent('not reversed')
  expect(cancelPutawayTask).not.toHaveBeenCalled()
  await user.click(screen.getByRole('button', { name: 'Confirm cancellation' }))
  await waitFor(() => expect(cancelPutawayTask).toHaveBeenCalledWith('task-id'))
})

it('does not issue putaway queries for viewers', () => {
  access.operate = false
  renderPage('/tasks', <PutawayTasksPage />)
  expect(listPutawayTasks).not.toHaveBeenCalled()
})
