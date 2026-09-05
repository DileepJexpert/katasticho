import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { VehicleLogsPage } from './vehicle-logs-page'
import * as transportApi from './transport-api'
import * as contactsApi from '@/features/contacts/contacts-api'

vi.mock('./transport-api', () => ({
  listVehicleLogs: vi.fn(),
  createVehicleLog: vi.fn(),
  deleteVehicleLog: vi.fn(),
  getVehicleTcoSummary: vi.fn(),
}))

vi.mock('@/features/contacts/contacts-api', () => ({
  listContacts: vi.fn(),
}))

const mockLogs: transportApi.VehicleLog[] = [
  {
    id: 'log-001',
    vanId: null,
    vehicleNumber: 'MH12AB1234',
    logType: 'FUEL',
    logDate: '2026-09-01',
    odometerKm: 45200,
    quantity: 65,
    amount: 6175,
    vendorContactId: 'vendor-fuel-01',
    referenceNo: 'RCP-98124',
    notes: 'HPCL Station Highway filling',
  },
]

const mockContacts: contactsApi.Contact[] = [
  {
    id: 'vendor-fuel-01',
    contactType: 'VENDOR',
    displayName: 'HPCL Auto Care Centre',
    companyName: 'HPCL Auto Care',
    email: 'hpcl@autocare.com',
    phone: '9822334455',
    mobile: null,
    gstin: '27AAACH1234G1Z1',
    outstandingAr: 0,
    outstandingAp: 0,
    active: true,
    supplierEnabled: false,
  },
]

describe('VehicleLogsPage', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    vi.clearAllMocks()
    queryClient = new QueryClient({
      defaultOptions: {
        queries: { retry: false },
      },
    })
    vi.mocked(transportApi.listVehicleLogs).mockResolvedValue(mockLogs)
    vi.mocked(contactsApi.listContacts).mockResolvedValue({
      content: mockContacts,
      totalElements: 1,
      totalPages: 1,
      size: 20,
      number: 0,
    })
  })

  function renderPage() {
    return render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter>
          <VehicleLogsPage />
        </MemoryRouter>
      </QueryClientProvider>
    )
  }

  it('renders vehicle log records, expense table, and summary stats', async () => {
    renderPage()

    expect(await screen.findByRole('heading', { name: 'Vehicle Logs & TCO' })).toBeInTheDocument()
    expect(await screen.findByText('MH12AB1234')).toBeInTheDocument()
    expect(screen.getByText('HPCL Station Highway filling')).toBeInTheDocument()
    expect(screen.getByText('Vehicle TCO Analytics')).toBeInTheDocument()
  })

  it('opens new log entry modal and records vehicle expense with vendor EntityPicker', async () => {
    const user = userEvent.setup()
    vi.mocked(transportApi.createVehicleLog).mockResolvedValue({
      ...mockLogs[0]!,
      id: 'log-002',
    })

    renderPage()

    const addBtn = await screen.findByRole('button', { name: 'Log Vehicle Expense' })
    await user.click(addBtn)

    expect(screen.getByRole('dialog')).toBeInTheDocument()
    expect(screen.getByText('Log Vehicle Running Expense')).toBeInTheDocument()

    const vehicleInput = screen.getByLabelText(/Vehicle Registration Number/i)
    await user.type(vehicleInput, 'MH14CD5678')

    const amountInput = screen.getByLabelText(/Expense Amount/i)
    await user.type(amountInput, '3500')

    const submitBtn = screen.getByRole('button', { name: 'Save Expense' })
    await user.click(submitBtn)

    await waitFor(() => {
      expect(transportApi.createVehicleLog).toHaveBeenCalledWith(
        expect.objectContaining({
          vehicleNumber: 'MH14CD5678',
          amount: 3500,
        })
      )
    })
  })
})
