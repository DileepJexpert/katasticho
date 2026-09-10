import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, expect, it, vi } from 'vitest'
import { SerialNumbersPage } from './serial-numbers-page'
import {
  listAvailableSerials,
  listSerialNumbers,
  markSerialDamaged,
  markSerialReturned,
  receiveSerials,
  type SerialNumberRecord,
} from './serial-numbers-api'
import { getItem, type Item } from '@/features/items/items-api'
import { listWarehouses, type Warehouse } from '@/features/warehouses/warehouses-api'
import { useSessionStore } from '@/shared/session/session-store'

vi.mock('./serial-numbers-api', () => ({
  listAvailableSerials: vi.fn(),
  listSerialNumbers: vi.fn(),
  receiveSerials: vi.fn(),
  markSerialDamaged: vi.fn(),
  markSerialReturned: vi.fn(),
}))
vi.mock('@/features/items/items-api', () => ({ getItem: vi.fn(), listItems: vi.fn() }))
vi.mock('@/features/warehouses/warehouses-api', () => ({ listWarehouses: vi.fn() }))

const serial: SerialNumberRecord = {
  id: 'serial-id',
  itemId: 'item-id',
  serial: 'SN-001',
  warehouseId: 'main',
  batchId: null,
  status: 'SOLD',
  receivedAt: '2026-09-01T10:00:00Z',
  soldAt: '2026-09-05T10:00:00Z',
  receiptLineId: 'receipt-line',
  invoiceLineId: 'invoice-line',
  notes: null,
}

beforeEach(() => {
  vi.clearAllMocks()
  useSessionStore.setState({ status: 'anonymous', user: null })
  vi.mocked(getItem).mockResolvedValue({ id: 'item-id', name: 'Scanner', active: false } as Item)
  vi.mocked(listWarehouses).mockResolvedValue([
    { id: 'main', name: 'Main', code: 'MAIN', active: true },
  ] as Warehouse[])
  vi.mocked(listSerialNumbers).mockResolvedValue({
    content: [serial],
    totalElements: 26,
    totalPages: 2,
    last: false,
  })
  vi.mocked(listAvailableSerials).mockResolvedValue([])
  vi.mocked(receiveSerials).mockResolvedValue([])
  vi.mocked(markSerialDamaged).mockResolvedValue(serial)
  vi.mocked(markSerialReturned).mockResolvedValue(serial)
})

function renderPage(entry = '/inventory/serial-numbers?itemId=item-id') {
  return render(
    <QueryClientProvider
      client={
        new QueryClient({ defaultOptions: { queries: { retry: false, gcTime: 0 } } })
      }
    >
      <MemoryRouter initialEntries={[entry]}>
        <SerialNumbersPage />
      </MemoryRouter>
    </QueryClientProvider>
  )
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

it('allows receiving serial numbers when user has operate permission', async () => {
  useSessionStore.setState({
    status: 'authenticated',
    user: {
      id: 'u-1',
      orgId: 'o-1',
      fullName: 'Admin User',
      email: 'admin@test.com',
      phone: null,
      role: 'OWNER',
      orgName: 'Org',
      industry: null,
      businessType: null,
      industryCode: null,
      onboardingCompleted: true,
      defaultLandingPage: null,
    },
  })

  const user = userEvent.setup()
  renderPage()
  expect(await screen.findByText('SN-001')).toBeInTheDocument()

  const receiveBtn = screen.getByRole('button', { name: 'Receive serials' })
  expect(receiveBtn).toBeInTheDocument()
  await user.click(receiveBtn)

  const dialog = screen.getByRole('dialog')
  expect(dialog).toBeInTheDocument()
  expect(within(dialog).getByText('Receive serial numbers')).toBeInTheDocument()

  const textarea = within(dialog).getByRole('textbox', { name: 'Serial numbers' })
  await user.type(textarea, 'SN-2001, SN-2002')

  const submitBtn = within(dialog).getByRole('button', { name: 'Receive serials' })
  await user.click(submitBtn)

  await waitFor(() => {
    expect(receiveSerials).toHaveBeenCalledWith({
      itemId: 'item-id',
      warehouseId: undefined,
      serials: ['SN-2001', 'SN-2002'],
    })
  })
})

it('allows marking a sold serial as returned', async () => {
  useSessionStore.setState({
    status: 'authenticated',
    user: {
      id: 'u-1',
      orgId: 'o-1',
      fullName: 'Admin User',
      email: 'admin@test.com',
      phone: null,
      role: 'ADMIN',
      orgName: 'Org',
      industry: null,
      businessType: null,
      industryCode: null,
      onboardingCompleted: true,
      defaultLandingPage: null,
    },
  })

  const user = userEvent.setup()
  renderPage()
  expect(await screen.findByText('SN-001')).toBeInTheDocument()

  const markReturnedBtn = screen.getByRole('button', { name: 'Mark returned' })
  await user.click(markReturnedBtn)

  expect(screen.getByRole('dialog')).toBeInTheDocument()
  expect(screen.getByText('Return serial SN-001')).toBeInTheDocument()

  const confirmBtn = screen.getByRole('button', { name: 'Confirm return' })
  await user.click(confirmBtn)

  await waitFor(() => {
    expect(markSerialReturned).toHaveBeenCalledWith('serial-id')
  })
})

it('allows marking an in-stock serial as damaged', async () => {
  useSessionStore.setState({
    status: 'authenticated',
    user: {
      id: 'u-1',
      orgId: 'o-1',
      fullName: 'Admin User',
      email: 'admin@test.com',
      phone: null,
      role: 'ADMIN',
      orgName: 'Org',
      industry: null,
      businessType: null,
      industryCode: null,
      onboardingCompleted: true,
      defaultLandingPage: null,
    },
  })

  const inStockSerial: SerialNumberRecord = {
    ...serial,
    id: 'serial-stock-1',
    serial: 'SN-002',
    status: 'IN_STOCK',
    soldAt: null,
    invoiceLineId: null,
  }

  vi.mocked(listSerialNumbers).mockResolvedValue({
    content: [inStockSerial],
    totalElements: 1,
    totalPages: 1,
    last: true,
  })

  const user = userEvent.setup()
  renderPage()
  expect(await screen.findByText('SN-002')).toBeInTheDocument()

  const markDamagedBtn = screen.getByRole('button', { name: 'Mark damaged' })
  await user.click(markDamagedBtn)

  expect(screen.getByRole('dialog')).toBeInTheDocument()
  expect(screen.getByText('Mark SN-002 damaged')).toBeInTheDocument()

  const notesInput = screen.getByRole('textbox', { name: 'Damage notes' })
  await user.type(notesInput, 'Dropped during inspection')

  const confirmBtn = screen.getByRole('button', { name: 'Confirm damaged' })
  await user.click(confirmBtn)

  await waitFor(() => {
    expect(markSerialDamaged).toHaveBeenCalledWith('serial-stock-1', 'Dropped during inspection')
  })
})
