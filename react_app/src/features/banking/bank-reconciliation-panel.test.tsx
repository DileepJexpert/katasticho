import { beforeEach, describe, expect, it, vi } from 'vitest'
import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { BankReconciliationPanel } from './bank-reconciliation-panel'
import * as bankingApi from './banking-api'

vi.mock('./banking-api', async () => {
  const actual = await vi.importActual<typeof bankingApi>('./banking-api')
  return {
    ...actual,
    listBankTransactions: vi.fn(),
    getBankReconciliationSummary: vi.fn(),
    acceptPaymentMatch: vi.fn(),
    rejectPaymentMatch: vi.fn(),
    ignoreBankTransaction: vi.fn(),
    rerunBankMatches: vi.fn(),
    runAutoMatch: vi.fn(),
    importBankStatementFile: vi.fn(),
  }
})

const mockBankAccounts: bankingApi.BankAccount[] = [
  {
    id: 'bank-1',
    name: 'Primary Corporate Account',
    bankName: 'HDFC Bank',
    accountNumber: '50200012345678',
    ifsc: 'HDFC0001234',
    branch: 'Indiranagar',
    accountType: 'CURRENT',
    glAccountId: 'gl-101',
    glAccountCode: '1020',
    openingBalance: 1250000,
    isDefault: true,
    isActive: true,
  },
]

const mockTransactions: bankingApi.BankTransaction[] = [
  {
    id: 'tx-1',
    transactionDate: '2026-09-01',
    amount: 15000,
    direction: 'INFLOW',
    narration: 'NEFT CR ACME CORP PAYMENT',
    utr: 'HDFCN260901001',
    payerName: 'Acme Corp Ltd',
    payerVpa: null,
    status: 'UNRECONCILED',
    suggestedMatches: [
      {
        id: 'match-1',
        matchType: 'INVOICE',
        documentNumber: 'INV-2026-0042',
        contactName: 'Acme Corp',
        matchedAmount: 15000,
        confidence: 0.95,
        matchStatus: 'SUGGESTED',
      },
    ],
  },
  {
    id: 'tx-2',
    transactionDate: '2026-09-02',
    amount: 2500,
    direction: 'OUTFLOW',
    narration: 'UPI DR OFFICE SUPPLIES',
    utr: 'UPI260902002',
    payerName: 'Office Depot',
    payerVpa: 'officedepot@upi',
    status: 'UNRECONCILED',
    suggestedMatches: [],
  },
]

describe('BankReconciliationPanel', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    queryClient = new QueryClient({
      defaultOptions: {
        queries: { retry: false },
      },
    })
    vi.clearAllMocks()
    vi.mocked(bankingApi.getBankReconciliationSummary).mockResolvedValue({
      totalTransactions: 12,
      unreconciledCount: 5,
      reconciledCount: 6,
      ignoredCount: 1,
    })
    vi.mocked(bankingApi.listBankTransactions).mockResolvedValue({
      content: mockTransactions,
      totalElements: 2,
      totalPages: 1,
      number: 0,
      size: 20,
    })
    vi.mocked(bankingApi.acceptPaymentMatch).mockResolvedValue({
      ...mockTransactions[0]!,
      status: 'RECONCILED',
    })
  })

  function renderPanel() {
    return render(
      <QueryClientProvider client={queryClient}>
        <BankReconciliationPanel bankAccounts={mockBankAccounts} />
      </QueryClientProvider>
    )
  }

  it('renders reconciliation summary KPIs and bank transactions', async () => {
    renderPanel()

    expect(await screen.findByText('NEFT CR ACME CORP PAYMENT')).toBeInTheDocument()
    expect(screen.getByText('UTR: HDFCN260901001')).toBeInTheDocument()
    expect(screen.getByText('UPI DR OFFICE SUPPLIES')).toBeInTheDocument()
    expect(screen.getByText(/INV-2026-0042/)).toBeInTheDocument()
    expect(screen.getByText(/95% match/)).toBeInTheDocument()

    // KPI counts
    expect(screen.getByText('5')).toBeInTheDocument()
    expect(screen.getByText('6')).toBeInTheDocument()
  })

  it('calls acceptPaymentMatch when Accept button is clicked', async () => {
    renderPanel()

    const acceptBtn = await screen.findByRole('button', { name: /accept match/i })
    fireEvent.click(acceptBtn)

    await waitFor(() => {
      expect(bankingApi.acceptPaymentMatch).toHaveBeenCalledWith('match-1', 'bank-1')
    })
  })

  it('calls ignoreBankTransaction when Ignore button is clicked', async () => {
    vi.mocked(bankingApi.ignoreBankTransaction).mockResolvedValue({
      ...mockTransactions[0]!,
      status: 'IGNORED',
    })

    renderPanel()

    const ignoreButtons = await screen.findAllByRole('button', { name: /ignore transaction/i })
    fireEvent.click(ignoreButtons[0]!)

    await waitFor(() => {
      expect(bankingApi.ignoreBankTransaction).toHaveBeenCalledWith('tx-1')
    })
  })
})
