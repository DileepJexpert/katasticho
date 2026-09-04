import { afterEach, describe, expect, it, vi } from 'vitest'
import { apiFetch, apiFetchRawJson } from '@/api/client/api-client'

describe('apiFetch', () => {
  afterEach(() => {
    vi.restoreAllMocks()
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
