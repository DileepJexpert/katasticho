import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { useSessionStore } from '@/shared/session/session-store'
import { enterpriseUser } from '@/features/accounting/enterprise-test-fixtures'
import { AmortizationPage } from './amortization-page'
import * as amortizationApi from './amortization-api'
import * as accountsApi from '@/features/accounts/accounts-api'

vi.mock('./amortization-api', () => ({
  listAmortizationSchedules: vi.fn(),
  createAmortizationSchedule: vi.fn(),
  getAmortizationSchedule: vi.fn(),
}))

vi.mock('@/features/accounts/accounts-api', () => ({
  listAccounts: vi.fn(),
}))

const mockAccounts: accountsApi.Account[] = [
  {
    id: 'acc-5270',
    code: '5270',
    name: 'Amortization Expense',
    type: 'EXPENSE',
    subType: 'PREPAID',
    parentId: null,
    parentAccountName: null,
    level: 2,
    isSystem: true,
    isInvolvedInTransaction: true,
    hasChildren: false,
    childCount: 0,
    description: null,
    openingBalance: 0,
    currency: 'INR',
    isActive: true,
  },
  {
    id: 'acc-1510',
    code: '1510',
    name: 'Prepaid Asset',
    type: 'ASSET',
    subType: 'CHECKING',
    parentId: null,
    parentAccountName: null,
    level: 2,
    isSystem: true,
    isInvolvedInTransaction: true,
    hasChildren: false,
    childCount: 0,
    description: null,
    openingBalance: 0,
    currency: 'INR',
    isActive: true,
  },
]

const mockSchedules: amortizationApi.AmortizationSchedule[] = [
  {
    id: 'sched-001',
    orgId: 'org-01',
    scheduleType: 'PREPAID',
    description: 'AWS Annual Reserved Cloud Hosting',
    reference: 'PO-2026-0044',
    totalAmount: 120000,
    recognizedAmount: 30000,
    startYear: 2026,
    startMonth: 4,
    numberOfPeriods: 12,
    debitAccountCode: '5270',
    creditAccountCode: '1510',
    status: 'ACTIVE',
    notes: null,
  },
  {
    id: 'sched-002',
    orgId: 'org-01',
    scheduleType: 'DEFERRED_INCOME',
    description: 'Annual Software Maintenance Contract AMC',
    reference: 'INV-2026-908',
    totalAmount: 60000,
    recognizedAmount: 10000,
    startYear: 2026,
    startMonth: 1,
    numberOfPeriods: 12,
    debitAccountCode: '1510',
    creditAccountCode: '2030',
    status: 'ACTIVE',
    notes: null,
  },
]

describe('AmortizationPage', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    vi.clearAllMocks()
    useSessionStore.setState({ user: enterpriseUser, status: 'authenticated' })
    queryClient = new QueryClient({
      defaultOptions: {
        queries: { retry: false },
      },
    })
    vi.mocked(amortizationApi.listAmortizationSchedules).mockResolvedValue(mockSchedules)
    vi.mocked(accountsApi.listAccounts).mockResolvedValue(mockAccounts)
  })

  function renderPage() {
    return render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter>
          <AmortizationPage />
        </MemoryRouter>
      </QueryClientProvider>
    )
  }

  it('renders amortization schedules list and KPI summary cards', async () => {
    renderPage()

    expect(await screen.findByRole('heading', { name: 'Amortization & Prepaids' })).toBeInTheDocument()
    expect(await screen.findByText('AWS Annual Reserved Cloud Hosting')).toBeInTheDocument()
    expect(screen.getByText('Annual Software Maintenance Contract AMC')).toBeInTheDocument()
    expect(screen.getByText('Total Scheduled')).toBeInTheDocument()
    expect(screen.getByText('Recognized to Date')).toBeInTheDocument()
  })

  it('filters schedules by schedule type tabs', async () => {
    const user = userEvent.setup()
    renderPage()

    expect(await screen.findByText('AWS Annual Reserved Cloud Hosting')).toBeInTheDocument()
    expect(screen.getByText('Annual Software Maintenance Contract AMC')).toBeInTheDocument()

    const deferredTab = screen.getByRole('button', { name: 'Deferred income' })
    await user.click(deferredTab)

    expect(screen.queryByText('AWS Annual Reserved Cloud Hosting')).not.toBeInTheDocument()
    expect(screen.getByText('Annual Software Maintenance Contract AMC')).toBeInTheDocument()
  })

  it('opens new amortization schedule modal and creates schedule with EntityPicker accounts', async () => {
    const user = userEvent.setup()
    vi.mocked(amortizationApi.createAmortizationSchedule).mockResolvedValue({
      ...mockSchedules[0]!,
      id: 'sched-003',
      description: 'Office Lease Advance Rent',
    })

    renderPage()

    const addBtn = await screen.findByRole('button', { name: /New Amortization Schedule/i })
    await user.click(addBtn)

    expect(screen.getByRole('dialog')).toBeInTheDocument()
    expect(screen.getByText('Create Amortization Schedule')).toBeInTheDocument()

    const descInput = screen.getByPlaceholderText(/e\.g\. AWS Annual Cloud Hosting Contract/i)
    await user.type(descInput, 'Office Lease Advance Rent')

    const amountInput = screen.getByPlaceholderText('0.00')
    await user.type(amountInput, '120000')

    const refInput = screen.getByPlaceholderText(/PO-9912 or INV-1002/i)
    await user.type(refInput, 'AGR-2026-RENT')

    // Select Debit Account via EntityPicker
    const debitPicker = screen.getByRole('combobox', { name: 'Debit Account' })
    await user.click(debitPicker)
    const debitOption = await screen.findByText(/5270 - Amortization Expense/i)
    await user.click(debitOption)

    // Select Credit Account via EntityPicker
    const creditPicker = screen.getByRole('combobox', { name: 'Credit Account' })
    await user.click(creditPicker)
    const creditOption = await screen.findByText(/1510 - Prepaid Asset/i)
    await user.click(creditOption)

    const submitBtn = screen.getByRole('button', { name: 'Create Schedule' })
    await user.click(submitBtn)

    await waitFor(() => {
      expect(amortizationApi.createAmortizationSchedule).toHaveBeenCalledWith(
        expect.objectContaining({
          description: 'Office Lease Advance Rent',
          totalAmount: 120000,
          reference: 'AGR-2026-RENT',
          debitAccountCode: '5270',
          creditAccountCode: '1510',
        })
      )
    })
  })
  it('never substitutes Cash or TDS accounts when no recognition accounts are selected', async () => {
    const user = userEvent.setup()
    renderPage()
    await user.click(await screen.findByRole('button', { name: /New Amortization Schedule/i }))
    await user.type(screen.getByPlaceholderText(/e.g. AWS Annual Cloud Hosting Contract/i), 'Prepaid')
    await user.type(screen.getByPlaceholderText('0.00'), '1200')
    expect(screen.getByRole('button', { name: 'Create Schedule' })).toBeDisabled()
    expect(screen.getByRole('combobox', { name: 'Debit Account' })).toHaveValue('')
    expect(screen.getByRole('combobox', { name: 'Credit Account' })).toHaveValue('')
    expect(amortizationApi.createAmortizationSchedule).not.toHaveBeenCalled()
  })
})
