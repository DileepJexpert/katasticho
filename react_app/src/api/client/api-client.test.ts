import { afterEach, describe, expect, it, vi } from 'vitest'
import { apiFetch, apiFetchBlob, apiFetchRawJson } from '@/api/client/api-client'

describe('apiFetch', () => {
  afterEach(() => {
    vi.restoreAllMocks()
    vi.unstubAllGlobals()
  })

  it('keeps multipart uploads intact without forcing a JSON content type', async () => {
    const fetchMock = vi.fn().mockResolvedValue(new Response(JSON.stringify({ success: true, data: { totalRows: 1 } }), { headers: { 'Content-Type': 'application/json' } }))
    vi.stubGlobal('fetch', fetchMock)
    const body = new FormData()
    body.append('file', new File(['sku,name'], 'items.csv'))
    await apiFetch('/api/v1/items/import/preview', { method: 'POST', body })
    const request = fetchMock.mock.calls[0]![1] as RequestInit
    expect(request.body).toBe(body)
    expect(new Headers(request.headers).has('Content-Type')).toBe(false)
    expect(request.credentials).toBe('include')
  })

  it('requests the server CSV template as a blob without dropping session request options', async () => {
    const fetchMock = vi.fn().mockResolvedValue(new Response('sku,name\n', { headers: { 'Content-Type': 'text/csv' } }))
    vi.stubGlobal('fetch', fetchMock)
    const blob = await apiFetchBlob('/api/v1/items/import/template', 'text/csv')
    expect(blob.type).toBe('text/csv')
    const request = fetchMock.mock.calls[0]![1] as RequestInit
    expect(new Headers(request.headers).get('Accept')).toBe('text/csv')
    expect(request.credentials).toBe('include')
  })

  it('surfaces file-endpoint JSON failures rather than downloading an error as CSV', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response(JSON.stringify({ success: false, message: 'Access denied', errors: ['FORBIDDEN'] }), { status: 403, headers: { 'Content-Type': 'application/json' } })))
    await expect(apiFetchBlob('/api/v1/items/import/template', 'text/csv')).rejects.toMatchObject({ message: 'Access denied', status: 403 })
  })

  it('accepts a successful command response with no data payload', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response(JSON.stringify({
      success: true,
      message: 'Logged out',
      data: null,
      errors: null,
    }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })))

    await expect(apiFetch<void>('/api/v1/auth/web/logout', {
      method: 'POST',
      retryUnauthorized: false,
    })).resolves.toBeUndefined()
  })

  it('reads a direct JSON response without interpreting it as an ApiResponse envelope', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response(JSON.stringify({
      'nav.disabled': '["sales.orders"]',
    }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })))

    await expect(apiFetchRawJson<Record<string, string>>('/api/v1/settings/nav.disabled')).resolves.toEqual({
      'nav.disabled': '["sales.orders"]',
    })
  })
})
