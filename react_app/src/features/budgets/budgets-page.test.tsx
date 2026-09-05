import { act, cleanup, render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { afterEach, beforeEach, expect, it, vi } from 'vitest'
import { useSessionStore } from '@/shared/session/session-store'
import { enterpriseAccount, enterpriseUser } from '@/features/accounting/enterprise-test-fixtures'
import { listAccounts } from '@/features/accounts/accounts-api'
import * as api from './budgets-api'
import { BudgetsPage } from './budgets-page'
vi.mock('./budgets-api', () => ({ listBudget: vi.fn(), saveBudget: vi.fn(), getBudgetVariance: vi.fn() }))
vi.mock('@/features/accounts/accounts-api', () => ({ listAccounts: vi.fn() }))
const lines: api.BudgetLine[] = [
  { accountCode: '5270', accountName: 'Depreciation Expense', annualAmount: '1200.00', notes: 'Keep this note' },
  { accountCode: '1900', accountName: 'Archived account', annualAmount: 0, notes: 'Keep even if not selectable' },
]
beforeEach(() => {
  vi.resetAllMocks(); useSessionStore.setState({ user: enterpriseUser, status: 'authenticated' })
  vi.mocked(api.listBudget).mockResolvedValue(lines)
  vi.mocked(listAccounts).mockResolvedValue([enterpriseAccount])
  vi.mocked(api.saveBudget).mockResolvedValue(lines)
  vi.mocked(api.getBudgetVariance).mockResolvedValue({ description: 'Server report', rows: [{ code: '5270', account: 'Depreciation Expense', budget: 1200, actual: 500, variance: -700, usagePct: 41.7 }] })
})
afterEach(cleanup)
function view() { render(<QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false }, mutations: { retry: false } } })}><BudgetsPage /></QueryClientProvider>) }
it('preserves the full backend-shaped budget on unchanged save, including zeros and notes', async () => {
  const user = userEvent.setup(); view()
  const open = screen.getByRole('button', { name: 'Configure Budget' }); await waitFor(() => expect(open).toBeEnabled()); await user.click(open)
  expect(screen.getByLabelText('Budget for 5270')).toHaveValue(1200)
  await user.click(screen.getByRole('button', { name: 'Save Budget Targets' }))
  await waitFor(() => expect(api.saveBudget).toHaveBeenCalledWith(expect.any(Number), [{ ...lines[0], annualAmount: 1200 }, lines[1]]))
})
it('updates only the entered amount and retains other lines', async () => {
  const user = userEvent.setup(); view()
  const open = screen.getByRole('button', { name: 'Configure Budget' }); await waitFor(() => expect(open).toBeEnabled()); await user.click(open)
  await user.clear(screen.getByLabelText('Budget for 5270')); await user.type(screen.getByLabelText('Budget for 5270'), '2500')
  await user.click(screen.getByRole('button', { name: 'Save Budget Targets' }))
  await waitFor(() => expect(api.saveBudget).toHaveBeenCalledWith(expect.any(Number), [{ ...lines[0], annualAmount: 2500 }, lines[1]]))
})
it('shows actuals from the report and does not invent zeros on failure', async () => {
  vi.mocked(api.getBudgetVariance).mockRejectedValue(new Error('Report unavailable')); view()
  expect(await screen.findByText(/Actuals unavailable/)).toBeInTheDocument()
  expect(screen.queryByRole('table', { name: 'Budget variance' })).not.toBeInTheDocument()
})
it('keeps failed saves open for correction', async () => {
  vi.mocked(api.saveBudget).mockRejectedValue(new Error('Save rejected')); const user = userEvent.setup(); view()
  const open = screen.getByRole('button', { name: 'Configure Budget' }); await waitFor(() => expect(open).toBeEnabled()); await user.click(open)
  await user.click(screen.getByRole('button', { name: 'Save Budget Targets' }))
  expect(await within(screen.getByRole('dialog')).findByRole('alert')).toHaveTextContent('Save rejected')
})
it('denies viewer budget access without requesting protected data', () => {
  useSessionStore.setState({ user: { ...enterpriseUser, role: 'VIEWER' } }); view(); expect(api.listBudget).not.toHaveBeenCalled()
})
it('discards the old company draft when the organisation changes', async () => {
  const user = userEvent.setup(); view()
  const open = screen.getByRole('button', { name: 'Configure Budget' })
  await waitFor(() => expect(open).toBeEnabled()); await user.click(open)
  expect(screen.getByRole('dialog')).toBeInTheDocument()
  act(() => useSessionStore.setState({ user: { ...enterpriseUser, orgId: 'org-2' } }))
  expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
  expect(api.saveBudget).not.toHaveBeenCalled()
})
