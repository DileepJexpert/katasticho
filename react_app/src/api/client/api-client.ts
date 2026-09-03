import { getAccessToken, getOrganisationId } from '@/api/client/session-token'

type ApiEnvelope<T> = {
  success: boolean
  message: string | null
  data: T | null
  errors: string[] | null
}

type ApiRequest = Omit<RequestInit, 'body' | 'headers'> & {
  body?: unknown
  headers?: HeadersInit
  retryUnauthorized?: boolean
}

type TokenRefresher = () => Promise<string | null>

let tokenRefresher: TokenRefresher | null = null
let refreshInFlight: Promise<string | null> | null = null

export class ApiError extends Error {
  constructor(
    message: string,
    readonly status: number,
    readonly codes: string[] = [],
  ) {
    super(message)
    this.name = 'ApiError'
  }
}

export function registerTokenRefresher(refresher: TokenRefresher) {
  tokenRefresher = refresher
}

export async function apiFetch<T>(path: string, request: ApiRequest = {}): Promise<T> {
  return send<T>(path, request, request.retryUnauthorized ?? true)
}

async function send<T>(path: string, request: ApiRequest, canRetry: boolean): Promise<T> {
  const headers = new Headers(request.headers)
  const token = getAccessToken()
  const orgId = getOrganisationId()

  headers.set('Accept', 'application/json')
  if (request.body !== undefined) headers.set('Content-Type', 'application/json')
  if (token) headers.set('Authorization', `Bearer ${token}`)
  if (orgId) headers.set('X-Org-Id', orgId)

  const response = await fetch(path, {
    ...request,
    body: request.body === undefined ? undefined : JSON.stringify(request.body),
    credentials: 'include',
    headers,
  })

  if (response.status === 401 && canRetry && tokenRefresher) {
    refreshInFlight ??= tokenRefresher().finally(() => {
      refreshInFlight = null
    })
    if (await refreshInFlight) return send<T>(path, request, false)
  }

  const payload = await parseEnvelope<T>(response)
  if (!response.ok || !payload.success) {
    throw new ApiError(
      payload.message ?? 'The request could not be completed.',
      response.status,
      payload.errors ?? [],
    )
  }
  return payload.data === null ? undefined as T : payload.data
}

async function parseEnvelope<T>(response: Response): Promise<ApiEnvelope<T>> {
  const fallback: ApiEnvelope<T> = {
    success: false,
    message: response.statusText || 'The request could not be completed.',
    data: null,
    errors: [],
  }
  const contentType = response.headers.get('content-type') ?? ''
  if (!contentType.includes('application/json')) return fallback

  try {
    return (await response.json()) as ApiEnvelope<T>
  } catch {
    return fallback
  }
}
