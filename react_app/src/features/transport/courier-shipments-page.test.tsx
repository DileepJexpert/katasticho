import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { CourierShipmentsPage } from './courier-shipments-page'
import * as transportApi from './transport-api'
import * as contactsApi from '@/features/contacts/contacts-api'

vi.mock('./transport-api', () => ({
  listCourierShipments: vi.fn(),
  createCourierShipment: vi.fn(),
  syncAllCourierShipments: vi.fn(),
}))

vi.mock('@/features/contacts/contacts-api', () => ({
  listContacts: vi.fn(),
}))

const mockShipments: transportApi.CourierShipment[] = [
  {
    id: 'cs-001',
    courierShipmentNumber: 'CS-2026-0001',
    deliveryChallanId: null,
    invoiceId: 'inv-001',
    contactId: 'contact-001',
    courierPartner: 'BLUEDART',
    courierService: 'Air Express',
    awbNumber: 'BD12345678',
    status: 'IN_TRANSIT',
    cod: true,
    codAmount: 2500,
    codRemittanceLineId: null,
    freightAmount: 180,
    codFee: 50,
    transporterContactId: null,
    weightKg: 1.5,
    declaredValue: 2500,
    bookedAt: '2026-09-01T10:00:00Z',
    deliveredAt: null,
    rtoInitiatedAt: null,
    rtoDeliveredAt: null,
    notes: 'Fragile package',
    events: [],
  },
  {
    id: 'cs-002',
    courierShipmentNumber: 'CS-2026-0002',
    deliveryChallanId: null,
    invoiceId: null,
    contactId: 'contact-002',
    courierPartner: 'DELHIVERY',
    courierService: 'Surface Standard',
    awbNumber: 'DEL98765432',
    status: 'DELIVERED',
    cod: false,
    codAmount: null,
    codRemittanceLineId: null,
    freightAmount: 120,
    codFee: null,
    transporterContactId: null,
    weightKg: 0.8,
    declaredValue: 1200,
    bookedAt: '2026-08-28T10:00:00Z',
    deliveredAt: '2026-08-31T15:30:00Z',
    rtoInitiatedAt: null,
    rtoDeliveredAt: null,
    notes: null,
    events: [],
  },
]

const mockContacts: contactsApi.Contact[] = [
  {
    id: 'contact-001',
    contactType: 'CUSTOMER',
    displayName: 'Acme Retailers',
    companyName: 'Acme Retailers Pvt Ltd',
    email: 'contact@acme.com',
    phone: '9876543210',
    mobile: null,
    gstin: null,
    outstandingAr: 0,
    outstandingAp: 0,
    active: true,
    supplierEnabled: false,
  },
]

describe('CourierShipmentsPage', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    vi.clearAllMocks()
    queryClient = new QueryClient({
      defaultOptions: {
        queries: { retry: false },
      },
    })
    vi.mocked(transportApi.listCourierShipments).mockResolvedValue(mockShipments)
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
          <CourierShipmentsPage />
        </MemoryRouter>
      </QueryClientProvider>
    )
  }

  it('renders courier shipments directory, KPI cards, and shipment records', async () => {
    renderPage()

    expect(await screen.findByRole('heading', { name: 'Courier Shipments' })).toBeInTheDocument()
    expect(await screen.findByText('CS-2026-0001')).toBeInTheDocument()
    expect(screen.getByText('In Transit / Pickup')).toBeInTheDocument()
    expect(screen.getByText(/BD12345678/)).toBeInTheDocument()
    expect(screen.getByText('CS-2026-0002')).toBeInTheDocument()
  })

  it('triggers live tracking sync for all active shipments', async () => {
    const user = userEvent.setup()
    vi.mocked(transportApi.syncAllCourierShipments).mockResolvedValue({
      updated: 1,
    })

    renderPage()

    const syncBtn = await screen.findByRole('button', { name: /Sync All Tracking/i })
    await user.click(syncBtn)

    await waitFor(() => {
      expect(transportApi.syncAllCourierShipments).toHaveBeenCalled()
      expect(screen.getByText(/Live sync finished: 1 shipment\(s\) updated/i)).toBeInTheDocument()
    })
  })

  it('opens book shipment modal and submits booking with EntityPicker customer selection', async () => {
    const user = userEvent.setup()
    vi.mocked(transportApi.createCourierShipment).mockResolvedValue({
      ...mockShipments[0]!,
      id: 'cs-003',
      courierShipmentNumber: 'CS-2026-0003',
    })

    renderPage()

    const bookBtn = await screen.findByRole('button', { name: /Book Shipment/i })
    await user.click(bookBtn)

    expect(screen.getByRole('dialog')).toBeInTheDocument()
    expect(screen.getByText('Book Courier Shipment')).toBeInTheDocument()

    await user.click(screen.getByRole('combobox', { name: 'Consignee / Customer' }))
    await user.click(await screen.findByText(mockContacts[0]!.displayName))
    const submitBtn = screen.getByRole('button', { name: 'Create Shipment' })
    await user.click(submitBtn)

    await waitFor(() => {
      expect(transportApi.createCourierShipment).toHaveBeenCalledWith(
        expect.objectContaining({
          contactId: 'contact-001',
          courierPartner: 'BLUEDART',
        })
      )
    })
  })
  it('searches the server for customers outside the initial result page', async () => {
    const distant = { ...mockContacts[0]!, id: 'outside-first-page', displayName: 'Remote Market' }
    vi.mocked(contactsApi.listContacts).mockImplementation(async (params) => ({ content: params?.search === 'Remote' ? [distant] : [], number: 0, size: 25, totalElements: 1, totalPages: 1 }))
    const user = userEvent.setup(); renderPage()
    await user.click(await screen.findByRole('button', { name: /Book Shipment/i }))
    await user.type(screen.getByRole('combobox', { name: 'Consignee / Customer' }), 'Remote')
    await user.click(await screen.findByText('Remote Market'))
    expect(contactsApi.listContacts).toHaveBeenCalledWith({ search: 'Remote', filter: 'CUSTOMER' })
    expect(screen.getByText('Remote Market')).toBeInTheDocument()
    vi.mocked(transportApi.createCourierShipment).mockResolvedValue(mockShipments[0]!)
    await user.click(screen.getByRole('button', { name: 'Create Shipment' }))
    await waitFor(() => expect(transportApi.createCourierShipment).toHaveBeenCalledWith(expect.objectContaining({ contactId: 'outside-first-page' })))
  })

})
