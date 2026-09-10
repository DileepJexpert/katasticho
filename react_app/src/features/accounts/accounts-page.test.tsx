import { beforeEach, describe, expect, it, vi } from 'vitest'
import { fireEvent, render, screen } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter } from 'react-router-dom'
import { AccountsPage } from './accounts-page'
import * as accountsApi from './accounts-api'

vi.mock('./accounts-api', async () => {
  const actual = await vi.importActual<typeof accountsApi>('./accounts-api')
  return {
    ...actual,
    listAccounts: vi.fn(),
    createAccount: vi.fn(),
    seedAccountTemplate: vi.fn(),
  }
})

const mockAccounts: accountsApi.Account[] = [
  {
    id: 'acc-1',
    code: '1010',
    name: 'Cash on Hand',
    type: 'ASSET',
    subType: 'CURRENT_ASSET',
    parentId: null,
    parentAccountName: null,
    level: 1,
    isSystem: true,
    isInvolvedInTransaction: true,
    hasChildren: false,
    childCount: 0,
    description: 'Petty cash',
    openingBalance: 5000,
    currency: 'INR',
    isActive: true,
  },
  {
    id: 'acc-2',
    code: '2010',
    name: 'Accounts Payable',
    type: 'LIABILITY',
    subType: 'CURRENT_LIABILITY',
    parentId: null,
    parentAccountName: null,
    level: 1,
    isSystem: true,
    isInvolvedInTransaction: false,
    hasChildren: false,
    childCount: 0,
    description: 'Trade payables',
    openingBalance: 0,
    currency: 'INR',
    isActive: true,
  },
]

describe('AccountsPage', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } })
    vi.clearAllMocks()
    vi.mocked(accountsApi.listAccounts).mockResolvedValue(mockAccounts)
  })

  function renderPage() {
    return render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter>
          <AccountsPage />
        </MemoryRouter>
      </QueryClientProvider>,
    )
  }

  it('renders accounts list and filter tabs', async () => {
    renderPage()

    expect(await screen.findByText('Cash on Hand')).toBeInTheDocument()
    expect(screen.getByText('Accounts Payable')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /new account/i })).toBeInTheDocument()
  })

  it('filters accounts by type when clicking tab', async () => {
    renderPage()

    expect(await screen.findByText('Cash on Hand')).toBeInTheDocument()

    const liabilityTab = screen.getByRole('tab', { name: /liabilities/i })
    fireEvent.click(liabilityTab)

    expect(screen.queryByText('Cash on Hand')).not.toBeInTheDocument()
    expect(screen.getByText('Accounts Payable')).toBeInTheDocument()
  })

  it('opens the create account modal on clicking New Account', async () => {
    renderPage()

    const newBtn = await screen.findByRole('button', { name: /new account/i })
    fireEvent.click(newBtn)

    expect(await screen.findByRole('dialog')).toBeInTheDocument()
    expect(screen.getByText('Create New Account')).toBeInTheDocument()
    expect(screen.getByPlaceholderText('e.g. 1010, 5020')).toBeInTheDocument()
    expect(screen.getByPlaceholderText('e.g. Petty Cash, Office Supplies')).toBeInTheDocument()
  })
})
