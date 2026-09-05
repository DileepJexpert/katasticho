import { afterEach, describe, expect, it, vi } from 'vitest'
import { createPortalApi, portalRequest } from './portal-api'
import { usePortalSession } from './portal-session'

afterEach(() => { vi.unstubAllGlobals(); usePortalSession.getState().signOut() })
const response = (data: unknown) => new Response(JSON.stringify({ success: true, data }), { headers: { 'Content-Type': 'application/json' } })
describe('isolated portal API', () => {
  it('uses only the portal bearer and omits all browser cookies', async () => {
    const fetch = vi.fn().mockResolvedValue(response([])); vi.stubGlobal('fetch', fetch)
    await createPortalApi('portal-secret', () => true, vi.fn()).invoices()
    expect(fetch).toHaveBeenCalledWith('/api/v1/portal/invoices', expect.objectContaining({ credentials: 'omit', cache: 'no-store', headers: { Accept: 'application/json', Authorization: 'Bearer portal-secret' } }))
  })
  it('does not send authorization during public login', async () => {
    const fetch = vi.fn().mockResolvedValue(response({})); vi.stubGlobal('fetch', fetch)
    await portalRequest('/api/v1/portal/auth/login', { body: { email: 'a@b.test', password: 'secret' } })
    expect(fetch.mock.calls[0]![1].headers).not.toHaveProperty('Authorization')
    expect(fetch.mock.calls[0]![1].headers).not.toHaveProperty('X-Org-Id')
  })
  it('rejects endpoints outside the portal boundary', async () => {
    const fetch = vi.fn(); vi.stubGlobal('fetch', fetch)
    await expect(portalRequest('/api/v1/users')).rejects.toThrow('within the portal API')
    expect(fetch).not.toHaveBeenCalled()
  })
  it('expires a portal session on raw filter 401 without retry or ERP refresh', async () => {
    const fetch = vi.fn().mockResolvedValue(new Response(JSON.stringify({ error: 'PORTAL_SESSION_EXPIRED', message: 'Expired' }), { status: 401 })); vi.stubGlobal('fetch', fetch)
    const expire = vi.fn()
    await expect(createPortalApi('p', () => true, expire).orders()).rejects.toThrow('Expired')
    expect(expire).toHaveBeenCalledOnce(); expect(fetch).toHaveBeenCalledOnce()
  })
  it('does not expire a new session when an old request fails', async () => {
    let current = true
    const fetch = vi.fn().mockImplementation(async () => { current = false; return new Response(JSON.stringify({ message: 'Expired' }), { status: 401 }) }); vi.stubGlobal('fetch', fetch)
    const expire = vi.fn()
    await expect(createPortalApi('old', () => current, expire).orders()).rejects.toThrow()
    expect(expire).not.toHaveBeenCalled()
  })
  it('discards late successful data after sign out', async () => {
    let current = true
    vi.stubGlobal('fetch', vi.fn().mockImplementation(async () => { current = false; return response([{ number: 'private' }]) }))
    await expect(createPortalApi('old', () => current, vi.fn()).invoices()).rejects.toThrow('session has ended')
  })
  it('keeps the session on an incorrect current password, but expires invalid tokens', async () => {
    const fetch = vi.fn().mockResolvedValueOnce(new Response(JSON.stringify({ success: false, message: 'Wrong password' }), { status: 401 })).mockResolvedValueOnce(new Response(JSON.stringify({ error: 'PORTAL_SESSION_EXPIRED', message: 'Expired' }), { status: 401 })); vi.stubGlobal('fetch', fetch)
    const expire = vi.fn(); const api = createPortalApi('p', () => true, expire)
    await expect(api.changePassword('wrong', 'newpassword')).rejects.toThrow('Wrong password'); expect(expire).not.toHaveBeenCalled()
    await expect(api.changePassword('wrong', 'newpassword')).rejects.toThrow('Expired'); expect(expire).toHaveBeenCalledOnce()
  })
  it('sends quantities, not client prices, contacts or calculated totals', async () => {
    const fetch = vi.fn().mockResolvedValue(response({ total: 477.9 })); vi.stubGlobal('fetch', fetch)
    const body = { lines: [{ itemId: 'item/1', quantity: 10 }], notes: 'Deliver', referenceNumber: 'TEST', expectedShipmentDate: '2026-09-10' }
    expect(await createPortalApi('p', () => true, vi.fn()).placeOrder(body)).toEqual({ total: 477.9 })
    expect(JSON.parse(fetch.mock.calls[0]![1].body)).toEqual(body)
  })
  it('encodes document identifiers and searches', async () => {
    const fetch = vi.fn().mockImplementation(async () => response({})); vi.stubGlobal('fetch', fetch)
    const api = createPortalApi('p', () => true, vi.fn())
    await api.order('a/b'); await api.catalog('tea & milk', 2)
    expect(fetch.mock.calls[0]![0]).toBe('/api/v1/portal/orders/a%2Fb')
    expect(fetch.mock.calls[1]![0]).toBe('/api/v1/portal/catalog?search=tea+%26+milk&page=2&size=25')
  })
  it('does not persist the portal token across memory session changes', () => {
    const beforeLocal = JSON.stringify(localStorage); const beforeSession = JSON.stringify(sessionStorage)
    usePortalSession.getState().signIn({ token: 'private-token', portalUser: { id: 'p', contactId: 'c', kind: 'CUSTOMER', email: 'a@b.test', fullName: 'Customer', status: 'ACTIVE' } })
    usePortalSession.getState().signOut()
    expect(usePortalSession.getState().session).toBeNull()
    expect(JSON.stringify(localStorage)).toBe(beforeLocal); expect(JSON.stringify(sessionStorage)).toBe(beforeSession)
  })
})
