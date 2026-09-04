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

const sensitiveFieldPattern = /password|token|secret|authorization|api[_-]?key|otp/i

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
  const method = request.method ?? 'GET'

  headers.set('Accept', 'application/json')
  if (request.body !== undefined) headers.set('Content-Type', 'application/json')
  if (token) headers.set('Authorization', `Bearer ${token}`)
  if (orgId) headers.set('X-Org-Id', orgId)

  traceRequest(method, path, request.body)

  let response: Response
  try {
    response = await fetch(path, {
      ...request,
      body:
        request.body === undefined
          ? undefined
          : typeof request.body === 'string'
          ? request.body
          : JSON.stringify(request.body),
      credentials: 'include',
      headers,
    })
  } catch (error) {
    traceNetworkError(method, path, error)
    throw error
  }

  if (response.status === 401 && canRetry && tokenRefresher) {
    traceResponse(method, path, response.status, 'Refreshing the access token before retrying.')
    refreshInFlight ??= tokenRefresher().finally(() => {
      refreshInFlight = null
    })
    if (await refreshInFlight) return send<T>(path, request, false)
  }

  const payload = await parseEnvelope<T>(response)
  traceResponse(method, path, response.status, payload)
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

function traceRequest(method: string, path: string, body: unknown) {
  if (!import.meta.env.DEV) return

  console.groupCollapsed(`[API ->] ${method} ${path}`)
  if (body !== undefined) console.info('Request body:', redactForLog(body))
  console.groupEnd()
}

function traceResponse(method: string, path: string, status: number, payload: unknown) {
  if (!import.meta.env.DEV) return

  const label = status >= 400 ? '[API x]' : '[API <-]'
  console.groupCollapsed(`${label} ${status} ${method} ${path}`)
  console.info('Response:', redactForLog(payload))
  console.groupEnd()
}

function traceNetworkError(method: string, path: string, error: unknown) {
  if (!import.meta.env.DEV) return

  console.error(`[API x] Network error ${method} ${path}`, error)
}

function redactForLog(value: unknown): unknown {
  if (typeof value === 'string') {
    try {
      return redactForLog(JSON.parse(value))
    } catch {
      return value
    }
  }
  if (Array.isArray(value)) return value.map(redactForLog)
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value).map(([key, entry]) => [
        key,
        sensitiveFieldPattern.test(key) ? '[REDACTED]' : redactForLog(entry),
      ]),
    )
  }
  return value
}
