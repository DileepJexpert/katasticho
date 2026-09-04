import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi, beforeEach } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { ContactDetailPage } from './contact-detail-page'
import * as contactsApi from './contacts-api'

vi.mock('./contacts-api', async () => {
  const actual = await vi.importActual<typeof contactsApi>('./contacts-api')
  return {
    ...actual,
    getContact: vi.fn(),
  }
})

const mockNavigate = vi.fn()
vi.mock('react-router-dom', async () => {
  const actual = await vi.importActual<typeof import('react-router-dom')>('react-router-dom')
  return {
    ...actual,
    useNavigate: () => mockNavigate,
  }
})

const mockContact: contactsApi.Contact = {
  id: 'c-123',
  displayName: 'Apex Pharma Distributors',
  contactType: 'BOTH',
  companyName: 'Apex Pharmaceuticals Pvt Ltd',
  email: 'accounts@apexpharma.com',
  phone: '022-25551234',
  mobile: '9876543210',
  website: 'https://apexpharma.com',
  gstin: '27AABCA1234A1Z5',
  pan: 'AABCA1234A',
  gstTreatment: 'REGULAR',
  placeOfSupply: '27-Maharashtra',
  billingAddressLine1: 'Plot 42, MIDC',
  billingCity: 'Mumbai',
  billingState: 'Maharashtra',
  billingPostalCode: '400093',
  billingCountry: 'India',
  shippingAddressLine1: 'Warehouse 3, Bhiwandi',
  shippingCity: 'Thane',
  shippingState: 'Maharashtra',
  shippingPostalCode: '421302',
  shippingCountry: 'India',
  currency: 'INR',
  paymentTermsDays: 30,
  creditLimit: 500000,
  outstandingAr: 125000,
  outstandingAp: 45000,
  salesHold: false,
  tdsApplicable: true,
  tdsSection: '194C',
  tdsRate: 2,
  bankName: 'HDFC Bank',
  bankAccountNo: '50200012345678',
  bankIfsc: 'HDFC0000123',
  upiId: 'apex@hdfcbank',
  active: true,
  supplierEnabled: true,
  persons: [
    {
      id: 'cp-1',
      salutation: 'Mr.',
      firstName: 'Rahul',
      lastName: 'Sharma',
      designation: 'Accounts Manager',
      department: 'Finance',
      email: 'rahul@apexpharma.com',
      phone: '9876500001',
      mobile: null,
      primary: true,
    },
  ],
}

describe('ContactDetailPage', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    queryClient = new QueryClient({
      defaultOptions: {
        queries: { retry: false },
      },
    })
    vi.clearAllMocks()
  })

  function renderWithRouter(contactId = 'c-123') {
    return render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter initialEntries={[`/contacts/${contactId}`]}>
          <Routes>
            <Route path="/contacts/:contactId" element={<ContactDetailPage />} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>,
    )
  }

  it('renders contact profile, facts, balances, and contact persons', async () => {
    vi.mocked(contactsApi.getContact).mockResolvedValue(mockContact)

    renderWithRouter()

    expect(await screen.findByRole('heading', { name: 'Apex Pharma Distributors' })).toBeInTheDocument()
    expect(screen.getAllByText('Apex Pharmaceuticals Pvt Ltd').length).toBeGreaterThan(0)
    expect(screen.getByText('Customer · Vendor · Supplier')).toBeInTheDocument()
    expect(screen.getByText('27AABCA1234A1Z5')).toBeInTheDocument()
    expect(screen.getByText('HDFC Bank')).toBeInTheDocument()
    expect(screen.getByText('Mr. Rahul Sharma')).toBeInTheDocument()
    expect(screen.getByText('Finance · Accounts Manager')).toBeInTheDocument()
    expect(screen.getByText('Active')).toBeInTheDocument()
  })

  it('navigates to statement when View statement button is clicked', async () => {
    const user = userEvent.setup()
    vi.mocked(contactsApi.getContact).mockResolvedValue(mockContact)

    renderWithRouter()

    const statementButton = await screen.findByRole('button', { name: /view statement/i })
    await user.click(statementButton)

    expect(mockNavigate).toHaveBeenCalledWith('/contacts/c-123/statement')
  })

  it('navigates back to contacts list on Back button', async () => {
    const user = userEvent.setup()
    vi.mocked(contactsApi.getContact).mockResolvedValue(mockContact)

    renderWithRouter()

    const backButton = await screen.findByRole('button', { name: /back to contacts/i })
    await user.click(backButton)

    expect(mockNavigate).toHaveBeenCalledWith('/contacts')
  })

  it('renders error state when contact fetch fails', async () => {
    vi.mocked(contactsApi.getContact).mockRejectedValue(new Error('Network error'))

    renderWithRouter()

    expect(await screen.findByRole('alert')).toBeInTheDocument()
    expect(screen.getByText(/contact details could not be loaded/i)).toBeInTheDocument()
  })
})
