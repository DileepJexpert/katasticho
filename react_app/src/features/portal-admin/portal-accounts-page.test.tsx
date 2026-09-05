import { act, render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, expect, it, vi } from 'vitest'
import { enterpriseContact, enterpriseUser } from '@/features/accounting/enterprise-test-fixtures'
import { useSessionStore } from '@/shared/session/session-store'
import * as contacts from '@/features/contacts/contacts-api'
import * as api from './portal-admin-api'
import { PortalAccountsPage } from './portal-accounts-page'

vi.mock('./portal-admin-api', () => ({ listPortalAccounts: vi.fn(), invitePortalAccount: vi.fn(), resendPortalInvite: vi.fn(), portalAccountAction: vi.fn() }))
vi.mock('@/features/contacts/contacts-api', () => ({ listContacts: vi.fn() }))
const account: api.PortalAccount = { id: 'portal-1', contactId: 'contact-1', kind: 'CUSTOMER', email: 'kirana@example.test', fullName: 'Kirana Customer', status: 'INVITED', lastLoginAt: null }
const invitation: api.PortalInvite = { ...account, inviteToken: 'one-time-test-secret', inviteExpiresAt: '2026-09-12T00:00:00Z' }
beforeEach(() => {
  vi.clearAllMocks()
  useSessionStore.setState({ status: 'authenticated', user: enterpriseUser })
  vi.mocked(api.listPortalAccounts).mockResolvedValue([account])
  vi.mocked(api.invitePortalAccount).mockResolvedValue(invitation)
  vi.mocked(api.resendPortalInvite).mockResolvedValue(invitation)
  vi.mocked(api.portalAccountAction).mockResolvedValue({})
  vi.mocked(contacts.listContacts).mockResolvedValue({ content: [{ ...enterpriseContact, email: account.email }], totalElements: 1, totalPages: 1, size: 25, number: 0 })
})
function show() {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false }, mutations: { retry: false } } })
  render(<QueryClientProvider client={client}><MemoryRouter><PortalAccountsPage /></MemoryRouter></QueryClientProvider>)
  return client
}

it('creates a named contact invite without putting the token in query or mutation caches', async () => {
  const client = show()
  await userEvent.click(screen.getByRole('button', { name: 'Invite contact' }))
  expect(screen.getByRole('button', { name: 'Create invite' })).toBeDisabled()
  await userEvent.click(screen.getByRole('combobox', { name: 'Portal contact' }))
  await userEvent.click(await screen.findByRole('option', { name: /Kirana Customer/ }))
  expect(screen.getByLabelText('Email')).toHaveValue(account.email)
  await userEvent.click(screen.getByRole('button', { name: 'Create invite' }))
  expect(await screen.findByRole('dialog', { name: 'Portal activation token' })).toBeInTheDocument()
  expect(api.invitePortalAccount).toHaveBeenCalledWith({ contactId: 'contact-1', email: account.email, fullName: 'Kirana Customer' })
  expect(screen.getByLabelText('One-time activation token')).toHaveAttribute('type', 'password')
  await userEvent.click(screen.getByRole('button', { name: 'Reveal token' }))
  expect(screen.getByLabelText('One-time activation token')).toHaveValue(invitation.inviteToken)
  expect(JSON.stringify(client.getQueryCache().getAll().map((query) => query.state.data))).not.toContain(invitation.inviteToken)
  expect(JSON.stringify(client.getMutationCache().getAll().map((mutation) => mutation.state.data))).not.toContain(invitation.inviteToken)
  expect(JSON.stringify(localStorage)).not.toContain(invitation.inviteToken)
  expect(JSON.stringify(sessionStorage)).not.toContain(invitation.inviteToken)
  await userEvent.click(screen.getByRole('button', { name: 'Close and clear token' }))
  expect(screen.queryByLabelText('One-time activation token')).not.toBeInTheDocument()
})

it('clears an invite token on organisation switch and never shows a late previous-tenant token', async () => {
  show()
  await userEvent.click(await screen.findByRole('button', { name: 'Regenerate invite' }))
  await userEvent.click(screen.getByRole('button', { name: 'Confirm' }))
  await screen.findByLabelText('One-time activation token')
  act(() => useSessionStore.setState({ user: { ...enterpriseUser, orgId: 'org-2' } }))
  expect(screen.queryByLabelText('One-time activation token')).not.toBeInTheDocument()
  let resolve!: (value: api.PortalInvite) => void
  vi.mocked(api.resendPortalInvite).mockImplementation(() => new Promise((done) => { resolve = done }))
  await userEvent.click(await screen.findByRole('button', { name: 'Regenerate invite' }))
  await userEvent.click(screen.getByRole('button', { name: 'Confirm' }))
  act(() => useSessionStore.setState({ user: { ...enterpriseUser, orgId: 'org-3' } }))
  await act(async () => resolve(invitation))
  expect(screen.queryByLabelText('One-time activation token')).not.toBeInTheDocument()
})

it('shows reactivation rejection and does not pretend an unaccepted invite is active', async () => {
  vi.mocked(api.listPortalAccounts).mockResolvedValue([{ ...account, status: 'SUSPENDED' }])
  vi.mocked(api.portalAccountAction).mockRejectedValue(new Error('Accept the invite first'))
  show()
  await userEvent.click(await screen.findByRole('button', { name: 'Reactivate Kirana Customer' }))
  await userEvent.click(screen.getByRole('button', { name: 'Confirm' }))
  expect(await screen.findByText('Accept the invite first')).toBeInTheDocument()
  expect(screen.getByRole('dialog')).toBeInTheDocument()
  expect(api.listPortalAccounts).toHaveBeenCalledTimes(1)
})

it('confirms removal and refetches accounts without mutating the contact', async () => {
  show()
  await userEvent.click(await screen.findByRole('button', { name: 'Remove Kirana Customer' }))
  expect(api.portalAccountAction).not.toHaveBeenCalled()
  await userEvent.click(screen.getByRole('button', { name: 'Confirm' }))
  await waitFor(() => expect(api.portalAccountAction).toHaveBeenCalledWith('portal-1', 'delete'))
  await waitFor(() => expect(api.listPortalAccounts).toHaveBeenCalledTimes(2))
})

it('does not load portal accounts for operators', () => {
  useSessionStore.setState({ user: { ...enterpriseUser, role: 'OPERATOR' } })
  show()
  expect(api.listPortalAccounts).not.toHaveBeenCalled()
  expect(screen.queryByRole('button', { name: 'Invite contact' })).not.toBeInTheDocument()
})
