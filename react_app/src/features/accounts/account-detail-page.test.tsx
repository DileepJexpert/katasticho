import { beforeEach, describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { AccountDetailPage } from './account-detail-page'
import * as accountsApi from './accounts-api'

vi.mock('./accounts-api', async () => {
  const actual = await vi.importActual<typeof accountsApi>('./accounts-api')
  return {
    ...actual,
    getAccount: vi.fn(),
    getAccountTransactions: vi.fn(),
  }
})

const mockAccount: accountsApi.Account = {
  id: 'account-1', code: '1010', name: 'Cash in hand', type: 'ASSET', subType: 'CURRENT_ASSET', parentId: null,
  parentAccountName: null, level: 1, isSystem: true, isInvolvedInTransaction: true, hasChildren: false,
  childCount: 0, description: 'Cash held at the business', openingBalance: 1000, currency: 'INR', isActive: true,
}

describe('AccountDetailPage', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } })
    vi.clearAllMocks()
    vi.mocked(accountsApi.getAccount).mockResolvedValue(mockAccount)
    vi.mocked(accountsApi.getAccountTransactions).mockResolvedValue([
      { lineId: 'line-1', journalEntryId: 'journal-1', entryNumber: 'JV-2026-0001', effectiveDate: '2026-09-04', sourceModule: 'ACCOUNTING', entryDescription: 'Opening cash', lineDescription: null, debit: 1000, credit: 0, currency: 'INR', baseDebit: 1000, baseCredit: 0 },
    ])
  })

  function renderPage() {
    return render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter initialEntries={['/accounts/account-1']}>
          <Routes><Route path="/accounts/:accountId" element={<AccountDetailPage />} /></Routes>
        </MemoryRouter>
      </QueryClientProvider>,
    )
  }

  it('shows account facts, ledger transactions, and maintenance controls for authorized roles', async () => {
    renderPage()

    expect(await screen.findByRole('heading', { name: 'Cash in hand' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /edit account/i })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /deactivate/i })).toBeInTheDocument()
    expect(await screen.findByText('JV-2026-0001')).toBeInTheDocument()
  })

  it('opens the edit modal when clicking Edit Account', async () => {
    renderPage()

    const editBtn = await screen.findByRole('button', { name: /edit account/i })
    editBtn.click()

    expect(await screen.findByRole('dialog')).toBeInTheDocument()
    expect(screen.getByText('Edit Account: Cash in hand')).toBeInTheDocument()
  })

  it('shows an explicit ledger failure state', async () => {
    vi.mocked(accountsApi.getAccountTransactions).mockRejectedValue(new Error('Network error'))
    renderPage()

    expect(await screen.findByRole('alert')).toHaveTextContent('Ledger transactions could not be loaded.')
  })
})
