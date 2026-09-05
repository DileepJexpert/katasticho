import { act, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { afterEach, beforeEach, expect, it, vi } from 'vitest'
import { PortalPage } from './portal-page'
import { PortalAuthPage } from './portal-auth-page'
import { usePortalSession } from './portal-session'

const user = { id: 'portal-1', contactId: 'contact-1', kind: 'CUSTOMER' as const, email: 'customer@example.test', fullName: 'Test Customer', status: 'ACTIVE' }
const json = (data: unknown) => new Response(JSON.stringify({ success: true, data }))
beforeEach(() => { usePortalSession.getState().signIn({ token: 'portal-test-secret', portalUser: user }) })
afterEach(() => { vi.unstubAllGlobals(); usePortalSession.getState().signOut() })
function show() { return render(<MemoryRouter><PortalPage /></MemoryRouter>) }

it('shows limited server balances without calling ERP APIs', async () => {
  const fetch = vi.fn().mockImplementation(async () => json({ kind: 'CUSTOMER', outstanding: 277.9, openInvoiceCount: 1 })); vi.stubGlobal('fetch', fetch)
  show(); expect(await screen.findByText(/277.90/)).toBeInTheDocument()
  expect(screen.getByText(/up to 500/)).toBeInTheDocument()
  expect(fetch.mock.calls.every(([path]) => String(path).startsWith('/api/v1/portal/'))).toBe(true)
})
it('clears portal data and cart on sign out', async () => {
  vi.stubGlobal('fetch', vi.fn().mockImplementation(async () => json({ kind: 'CUSTOMER', outstanding: 277.9 })))
  show(); await screen.findByText(/277.90/)
  fireEvent.click(screen.getByRole('button', { name: 'Sign out' }))
  expect(usePortalSession.getState().session).toBeNull(); expect(screen.queryByText(/277.90/)).not.toBeInTheDocument()
})
it('does not offer customer reorder or call broken vendor PO lookup for vendors', async () => {
  usePortalSession.getState().signIn({ token: 'vendor-token', portalUser: { ...user, kind: 'VENDOR' } })
  const fetch = vi.fn().mockImplementation(async () => json({ kind: 'VENDOR', payableToYou: 100 })); vi.stubGlobal('fetch', fetch)
  show(); await screen.findByText(/100.00/)
  expect(screen.queryByRole('tab', { name: 'Quick reorder' })).not.toBeInTheDocument()
  fireEvent.click(screen.getByRole('tab', { name: 'Purchase orders' }))
  expect(screen.getByText('Purchase orders temporarily unavailable')).toBeInTheDocument()
  expect(fetch.mock.calls.some(([path]) => String(path).endsWith('/purchase-orders'))).toBe(false)
})
it('submits only reviewed quantities and shows server order totals', async () => {
  const fetch = vi.fn().mockImplementation(async (path: string) => path.endsWith('/dashboard') ? json({ kind: 'CUSTOMER', outstanding: 0 }) : path.includes('/catalog?') ? json({ items: [{ id: 'item-1', name: 'Turmeric', unitOfMeasure: 'PCS', salePrice: 45, inStock: true }], page: 0, totalPages: 1, totalElements: 1 }) : json({ id: 'order-1', salesorderNumber: 'SO-TEST', total: 477.9, status: 'DRAFT' }))
  vi.stubGlobal('fetch', fetch); show(); fireEvent.click(screen.getByRole('tab', { name: 'Quick reorder' }))
  fireEvent.click(await screen.findByRole('button', { name: 'Add Turmeric' }))
  fireEvent.change(screen.getByLabelText('Quantity for Turmeric'), { target: { value: '10' } })
  fireEvent.click(screen.getByRole('button', { name: 'Review order request' }))
  expect(fetch.mock.calls.some(([path]) => path.endsWith('/orders'))).toBe(false)
  fireEvent.click(screen.getByRole('button', { name: 'Submit order once' }))
  expect(await screen.findByText('Order saved: SO-TEST')).toBeInTheDocument()
  expect(screen.getByText(/477.90/)).toBeInTheDocument()
  const call = fetch.mock.calls.find(([path]) => path.endsWith('/orders'))!
  expect(JSON.parse((call[1] as RequestInit).body as string)).toEqual({ lines: [{ itemId: 'item-1', quantity: 10 }], notes: '', referenceNumber: '' })
})
it('requests a fresh sign in after a successful password change', async () => {
  vi.stubGlobal('fetch', vi.fn().mockImplementation(async () => json(null)))
  show(); fireEvent.click(screen.getByRole('tab', { name: 'Password' }))
  fireEvent.change(screen.getByLabelText('Current password'), { target: { value: 'oldpassword' } })
  fireEvent.change(screen.getByLabelText('New password'), { target: { value: 'newpassword' } })
  fireEvent.change(screen.getByLabelText('Confirm new password'), { target: { value: 'newpassword' } })
  fireEvent.click(screen.getByRole('button', { name: 'Change password' }))
  await waitFor(() => expect(usePortalSession.getState().session).toBeNull())
  expect(usePortalSession.getState().notice).toContain('Password changed')
})
it('does not sign in after an abandoned login completes', async () => {
  usePortalSession.getState().signOut()
  let finish!: (value: Response) => void
  vi.stubGlobal('fetch', vi.fn().mockImplementation(() => new Promise<Response>((resolve) => { finish = resolve })))
  const view = render(<MemoryRouter initialEntries={['/portal/login']}><PortalAuthPage /></MemoryRouter>)
  fireEvent.change(screen.getByLabelText('Email'), { target: { value: user.email } })
  fireEvent.change(screen.getByLabelText('Password'), { target: { value: 'password' } })
  fireEvent.click(screen.getByRole('button', { name: 'Sign in' })); view.unmount()
  await act(async () => finish(json({ token: 'late-token', portalUser: user })))
  expect(usePortalSession.getState().session).toBeNull()
})
