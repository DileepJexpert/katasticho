import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { LorryReceiptsPage } from './lorry-receipts-page'
import * as transportApi from './transport-api'
import * as contactsApi from '@/features/contacts/contacts-api'

vi.mock('./transport-api', () => ({
  listLorryReceipts: vi.fn(),
  createLorryReceipt: vi.fn(),
}))

vi.mock('@/features/contacts/contacts-api', () => ({
  listContacts: vi.fn(),
}))

const mockReceipts: transportApi.LorryReceipt[] = [
  {
    id: 'lr-001',
    lrNumber: 'LR-2026-0001',
    lrDate: '2026-09-01',
    deliveryChallanId: null,
    invoiceId: null,
    transporterContactId: 'vendor-001',
    contactId: 'customer-001',
    ewayBillNo: '231098765432',
    vehicleNumber: 'MH12AB1234',
    driverName: 'Ramesh Patil',
    driverPhone: '9876543210',
    origin: 'Bhiwandi Hub',
    destination: 'Pune Central',
    distanceKm: 160,
    mode: 'ROAD',
    numPackages: 45,
    weightKg: 1200,
    declaredValue: 450000,
    freightAmount: 8500,
    freightBasis: 'TO_BE_BILLED',
    gstTreatment: 'RCM',
    freightGstRate: 5,
    freightBillId: null,
    status: 'ISSUED',
    notes: 'Direct transit',
  },
]

const mockContacts: contactsApi.Contact[] = [
  {
    id: 'vendor-001',
    contactType: 'VENDOR',
    displayName: 'Balaji Roadways Logistics',
    companyName: 'Balaji Roadways Pvt Ltd',
    email: 'ops@balajiroadways.com',
    phone: '9822011223',
    mobile: null,
    gstin: '27AABCB1234F1Z5',
    outstandingAr: 0,
    outstandingAp: 8500,
    active: true,
    supplierEnabled: false,
  },
  {
    id: 'customer-001',
    contactType: 'CUSTOMER',
    displayName: 'Pioneer Pharma Distributors',
    companyName: 'Pioneer Pharma',
    email: 'orders@pioneer.com',
    phone: '9822099887',
    mobile: null,
    gstin: '27AABCP9876M1Z2',
    outstandingAr: 50000,
    outstandingAp: 0,
    active: true,
    supplierEnabled: false,
  },
]

describe('LorryReceiptsPage', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    vi.clearAllMocks()
    queryClient = new QueryClient({
      defaultOptions: {
        queries: { retry: false },
      },
    })
    vi.mocked(transportApi.listLorryReceipts).mockResolvedValue(mockReceipts)
    vi.mocked(contactsApi.listContacts).mockResolvedValue({
      content: mockContacts,
      totalElements: 2,
      totalPages: 1,
      size: 20,
      number: 0,
    })
  })

  function renderPage() {
    return render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter>
          <LorryReceiptsPage />
        </MemoryRouter>
      </QueryClientProvider>
    )
  }

  it('renders lorry receipts directory, summary metrics, and data rows', async () => {
    renderPage()

    expect(await screen.findByRole('heading', { name: 'Lorry Receipts (LR)' })).toBeInTheDocument()
    expect(await screen.findByText('LR-2026-0001')).toBeInTheDocument()
    expect(screen.getByText(/Bhiwandi Hub.*Pune Central/)).toBeInTheDocument()
    expect(screen.getByText('MH12AB1234')).toBeInTheDocument()
    expect(screen.getByText('Total Lorry Receipts')).toBeInTheDocument()
  })

  it('opens New Lorry Receipt modal and creates LR with EntityPicker transporter selection', async () => {
    const user = userEvent.setup()
    vi.mocked(transportApi.createLorryReceipt).mockResolvedValue({
      ...mockReceipts[0]!,
      id: 'lr-002',
      lrNumber: 'LR-2026-0002',
    })

    renderPage()

    const newBtn = await screen.findByRole('button', { name: /New Lorry Receipt \(LR\)/i })
    await user.click(newBtn)

    expect(screen.getByRole('dialog')).toBeInTheDocument()
    expect(screen.getByText('Create Lorry Receipt (LR)')).toBeInTheDocument()

    await user.click(screen.getByRole('combobox', { name: 'Transporter / GTA Vendor' }))
    await user.click(await screen.findByText(mockContacts[0]!.displayName))
    const submitBtn = screen.getByRole('button', { name: 'Issue Lorry Receipt' })
    await user.click(submitBtn)

    await waitFor(() => {
      expect(transportApi.createLorryReceipt).toHaveBeenCalledWith(
        expect.objectContaining({
          transporterContactId: 'vendor-001',
          mode: 'ROAD',
        })
      )
    })
  })
})
