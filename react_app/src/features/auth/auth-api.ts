import { apiFetch } from '@/api/client/api-client'
import type { WebAuthResponse } from '@/features/auth/auth-types'

export type LoginInput = {
  identifier: string
  password: string
}

export function loginBrowser(input: LoginInput) {
  return apiFetch<WebAuthResponse>('/api/v1/auth/web/login', {
    method: 'POST',
    body: input,
    retryUnauthorized: false,
  })
}

export function refreshBrowserSession() {
  return apiFetch<WebAuthResponse>('/api/v1/auth/web/refresh', {
    method: 'POST',
    retryUnauthorized: false,
  })
}

export function logoutBrowserSession() {
  return apiFetch<void>('/api/v1/auth/web/logout', {
    method: 'POST',
    retryUnauthorized: false,
  })
}
