import { cleanup, render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { afterEach, beforeEach, expect, it, vi } from 'vitest'
import { useSessionStore } from '@/shared/session/session-store'
import { enterpriseUser, enterpriseContact } from '@/features/accounting/enterprise-test-fixtures'
import { listContacts } from '@/features/contacts/contacts-api'
import * as api from './loyalty-api'
import { LoyaltyPage } from './loyalty-page'
vi.mock('@/features/contacts/contacts-api', () => ({ listContacts: vi.fn() }))
vi.mock('./loyalty-api', () => ({ getWallet: vi.fn(), getWalletTransactions: vi.fn(), getWalletRedeemable: vi.fn() }))
beforeEach(() => {
  vi.resetAllMocks(); useSessionStore.setState({ user: enterpriseUser, status: 'authenticated' })
  vi.mocked(listContacts).mockResolvedValue({ content: [enterpriseContact], totalElements: 1, totalPages: 1, number: 0, size: 25 })
  vi.mocked(api.getWallet).mockResolvedValue({ id: 'wallet-1', contactId: enterpriseContact.id, balance: 100, totalEarned: 150, totalRedeemed: 50, maxRedeemable: 100 })
  vi.mocked(api.getWalletTransactions).mockResolvedValue([])
})
afterEach(cleanup)
function view() { render(<QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}><LoyaltyPage /></QueryClientProvider>) }
it('uses server customer search and clears the active wallet rather than choosing the first customer', async () => {
  const user = userEvent.setup(); view(); expect(api.getWallet).not.toHaveBeenCalled()
  const picker = screen.getByRole('combobox', { name: 'Select customer to view wallet' })
  await user.type(picker, 'Kirana')
  await user.click(await screen.findByText('Kirana Customer'))
  await waitFor(() => expect(api.getWallet).toHaveBeenCalledWith(enterpriseContact.id))
  expect(listContacts).toHaveBeenCalledWith({ filter: 'CUSTOMER', search: 'Kirana' })
  await user.click(screen.getByRole('button', { name: 'Clear selection' }))
  expect(screen.getByText('Select a customer to view their wallet.')).toBeInTheDocument()
})
it('does not offer unsupported bonus or standalone redemption mutations', () => {
  view(); expect(screen.getByText(/Standalone bonus adjustments/)).toBeInTheDocument()
  expect(screen.queryByRole('button', { name: /Award|Redeem/i })).not.toBeInTheDocument()
})
it('honours the backend wallet role gate', () => {
  useSessionStore.setState({ user: { ...enterpriseUser, role: 'ACCOUNTANT' } }); view(); expect(screen.getByRole('alert')).toHaveTextContent('Operator access'); expect(api.getWallet).not.toHaveBeenCalled()
})
