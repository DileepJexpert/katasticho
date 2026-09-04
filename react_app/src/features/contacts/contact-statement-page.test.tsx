import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi, beforeEach } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { ContactStatementPage } from './contact-statement-page'
import * as contactsApi from './contacts-api'

vi.mock('./contacts-api', async () => {
  const actual = await vi.importActual<typeof contactsApi>('./contacts-api')
  return {
    ...actual,
    getContactLedger: vi.fn(),
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

const mockLedger: contactsApi.ContactLedger = {
  contactId: 'c-123',
  contactName: 'Apex Pharma Distributors',
  contactType: 'CUSTOMER',
  openingBalance: 50000,
  closingBalance: 125000,
  totalInvoiced: 150000,
  totalPaid: 75000,
  entries: [
    {
      date: '2026-01-15',
      type: 'INVOICE',
      number: 'INV-2026-001',
      referenceId: 'inv-1',
      description: 'Pharmaceutical supply batch #104',
      debit: 150000,
      credit: 0,
      runningBalance: 200000,
    },
    {
      date: '2026-01-28',
      type: 'PAYMENT',
      number: 'PAY-2026-001',
      referenceId: 'pay-1',
      description: 'Bank transfer NEFT-88991',
      debit: 0,
      credit: 75000,
      runningBalance: 125000,
    },
  ],
}

describe('ContactStatementPage', () => {
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
        <MemoryRouter initialEntries={[`/contacts/${contactId}/statement`]}>
          <Routes>
            <Route path="/contacts/:contactId/statement" element={<ContactStatementPage />} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>,
    )
  }

  it('renders statement header, date range controls, summary cards, and ledger rows', async () => {
    vi.mocked(contactsApi.getContactLedger).mockResolvedValue(mockLedger)

    renderWithRouter()

    expect(await screen.findByRole('heading', { name: 'Apex Pharma Distributors' })).toBeInTheDocument()
    expect(screen.getByText(/statement period/i)).toBeInTheDocument()
    expect(screen.getByText('INV-2026-001')).toBeInTheDocument()
    expect(screen.getByText('PAY-2026-001')).toBeInTheDocument()
    expect(screen.getByText('Pharmaceutical supply batch #104')).toBeInTheDocument()
    expect(screen.getByText('Bank transfer NEFT-88991')).toBeInTheDocument()
  })

  it('navigates back to contact detail when Back button is clicked', async () => {
    const user = userEvent.setup()
    vi.mocked(contactsApi.getContactLedger).mockResolvedValue(mockLedger)

    renderWithRouter()

    const backButton = await screen.findByRole('button', { name: /back to contact/i })
    await user.click(backButton)

    expect(mockNavigate).toHaveBeenCalledWith('/contacts/c-123')
  })

  it('shows empty state when no entries exist in the selected period', async () => {
    vi.mocked(contactsApi.getContactLedger).mockResolvedValue({
      ...mockLedger,
      entries: [],
    })

    renderWithRouter()

    expect(await screen.findByText(/no transactions were recorded in this period/i)).toBeInTheDocument()
  })

  it('renders error state when statement fetch fails', async () => {
    vi.mocked(contactsApi.getContactLedger).mockRejectedValue(new Error('Network error'))

    renderWithRouter()

    expect(await screen.findByRole('alert')).toBeInTheDocument()
    expect(screen.getByText(/statement could not be loaded/i)).toBeInTheDocument()
  })
})
