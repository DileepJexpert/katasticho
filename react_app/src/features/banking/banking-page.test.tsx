import { fireEvent, render, screen } from '@testing-library/react'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { BankingPage } from './banking-page'
import * as bankingApi from './banking-api'

vi.mock('./banking-api', () => ({
  listBankAccounts: vi.fn(),
  getBankAccount: vi.fn(),
}))

const mockBankAccounts: bankingApi.BankAccount[] = [
  {
    id: 'bank-1',
    name: 'Primary Corporate Account',
    bankName: 'HDFC Bank',
    accountNumber: '50200012345678',
    ifsc: 'HDFC0001234',
    branch: 'Indiranagar, Bangalore',
    accountType: 'CURRENT',
    glAccountId: 'gl-101',
    glAccountCode: '1020',
    openingBalance: 1250000,
    isDefault: true,
    isActive: true,
    notes: 'Main operating current account for payouts and receipts',
  },
  {
    id: 'bank-2',
    name: 'Tax & Reserve Account',
    bankName: 'State Bank of India',
    accountNumber: '30400098765432',
    ifsc: 'SBIN0004567',
    branch: 'Koramangala, Bangalore',
    accountType: 'SAVINGS',
    glAccountId: 'gl-102',
    glAccountCode: '1021',
    openingBalance: 450000,
    isDefault: false,
    isActive: true,
    notes: 'Statutory tax liability reserve',
  },
  {
    id: 'bank-3',
    name: 'Working Capital Line',
    bankName: 'ICICI Bank',
    accountNumber: '00110055443322',
    ifsc: 'ICIC0000011',
    branch: 'MG Road, Bangalore',
    accountType: 'OVERDRAFT',
    glAccountId: null,
    glAccountCode: null,
    openingBalance: 0,
    isDefault: false,
    isActive: false,
    notes: null,
  },
]

describe('BankingPage', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    queryClient = new QueryClient({
      defaultOptions: {
        queries: { retry: false },
      },
    })
    vi.clearAllMocks()
    vi.mocked(bankingApi.listBankAccounts).mockResolvedValue(mockBankAccounts)
  })

  it('renders bank accounts with masked numbers, IFSC codes, and GL bindings without write controls', async () => {
    render(
      <QueryClientProvider client={queryClient}>
        <BankingPage />
      </QueryClientProvider>
    )

    expect(await screen.findByText('Primary Corporate Account')).toBeInTheDocument()
    expect(screen.getByText('HDFC Bank • Indiranagar, Bangalore')).toBeInTheDocument()
    expect(screen.getByText('Tax & Reserve Account')).toBeInTheDocument()
    expect(screen.getByText('Working Capital Line')).toBeInTheDocument()

    // Masked account numbers
    expect(screen.getByText('•••• •••• 5678')).toBeInTheDocument()
    expect(screen.getByText('•••• •••• 5432')).toBeInTheDocument()
    expect(screen.getByText('•••• •••• 3322')).toBeInTheDocument()

    // IFSC codes and GL bindings
    expect(screen.getByText('HDFC0001234')).toBeInTheDocument()
    expect(screen.getByText('GL: 1020')).toBeInTheDocument()
    expect(screen.getByText('GL: 1021')).toBeInTheDocument()
    expect(screen.getByText('Unassigned')).toBeInTheDocument()

    // Summary cards
    expect(screen.getByText('Total accounts')).toBeInTheDocument()
    expect(screen.getByText('Active accounts')).toBeInTheDocument()
    expect(screen.getByText('Default account')).toBeInTheDocument()

    // Status chips
    expect(screen.getAllByText('Active').length).toBeGreaterThanOrEqual(2)
    expect(screen.getByText('Default')).toBeInTheDocument()

    // Verify NO write buttons are rendered
    expect(screen.queryByRole('button', { name: /add account/i })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /new account/i })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /create/i })).not.toBeInTheDocument()
  })

  it('filters bank accounts by search query', async () => {
    render(
      <QueryClientProvider client={queryClient}>
        <BankingPage />
      </QueryClientProvider>
    )

    expect(await screen.findByText('Primary Corporate Account')).toBeInTheDocument()

    const searchInput = screen.getByPlaceholderText(/search by bank, account, number, or ifsc/i)
    fireEvent.change(searchInput, { target: { value: 'SBIN0004567' } })

    expect(screen.getByText('Tax & Reserve Account')).toBeInTheDocument()
    expect(screen.queryByText('Primary Corporate Account')).not.toBeInTheDocument()
    expect(screen.queryByText('Working Capital Line')).not.toBeInTheDocument()
  })

  it('filters bank accounts by account type tabs', async () => {
    render(
      <QueryClientProvider client={queryClient}>
        <BankingPage />
      </QueryClientProvider>
    )

    expect(await screen.findByText('Primary Corporate Account')).toBeInTheDocument()

    const savingsTab = screen.getByRole('tab', { name: /savings/i })
    fireEvent.click(savingsTab)

    expect(screen.getByText('Tax & Reserve Account')).toBeInTheDocument()
    expect(screen.queryByText('Primary Corporate Account')).not.toBeInTheDocument()
    expect(screen.queryByText('Working Capital Line')).not.toBeInTheDocument()
  })

  it('opens and closes the account details modal', async () => {
    render(
      <QueryClientProvider client={queryClient}>
        <BankingPage />
      </QueryClientProvider>
    )

    expect(await screen.findByText('Primary Corporate Account')).toBeInTheDocument()

    const viewButtons = screen.getAllByRole('button', { name: /view details/i })
    fireEvent.click(viewButtons[0]!)

    expect(screen.getByRole('dialog')).toBeInTheDocument()
    // In modal, full unmasked account number is visible
    expect(screen.getByText('50200012345678')).toBeInTheDocument()
    expect(screen.getByText('Main operating current account for payouts and receipts')).toBeInTheDocument()
    expect(screen.getByText('Yes (Primary)')).toBeInTheDocument()

    // Close modal
    const closeBtn = screen.getByRole('button', { name: 'Close' })
    fireEvent.click(closeBtn)
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
  })

  it('renders empty state when search matches no bank accounts', async () => {
    render(
      <QueryClientProvider client={queryClient}>
        <BankingPage />
      </QueryClientProvider>
    )

    expect(await screen.findByText('Primary Corporate Account')).toBeInTheDocument()

    const searchInput = screen.getByPlaceholderText(/search by bank, account, number, or ifsc/i)
    fireEvent.change(searchInput, { target: { value: 'Nonexistent Bank Query' } })

    expect(screen.getByText('No bank accounts found')).toBeInTheDocument()
    expect(screen.getByText('No bank accounts match the active filter criteria.')).toBeInTheDocument()
  })
})
