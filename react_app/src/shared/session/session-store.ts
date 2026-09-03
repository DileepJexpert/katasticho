import { registerTokenRefresher } from '@/api/client/api-client'
import { clearSessionToken, setSessionToken } from '@/api/client/session-token'
import { loginBrowser, logoutBrowserSession, refreshBrowserSession, type LoginInput } from '@/features/auth/auth-api'
import type { UserInfo, WebAuthResponse } from '@/features/auth/auth-types'
import { create } from 'zustand'

type SessionStatus = 'booting' | 'anonymous' | 'authenticated'

type SessionState = {
  status: SessionStatus
  user: UserInfo | null
  restore: () => Promise<void>
  login: (input: LoginInput) => Promise<void>
  logout: () => Promise<void>
}

function applySession(response: WebAuthResponse) {
  setSessionToken(response.accessToken, response.user.orgId)
  return { status: 'authenticated' as const, user: response.user }
}

export const useSessionStore = create<SessionState>((set) => ({
  status: 'booting',
  user: null,
  restore: async () => {
    try {
      set(applySession(await refreshBrowserSession()))
    } catch {
      clearSessionToken()
      set({ status: 'anonymous', user: null })
    }
  },
  login: async (input) => {
    set(applySession(await loginBrowser(input)))
  },
  logout: async () => {
    try {
      await logoutBrowserSession()
    } finally {
      clearSessionToken()
      set({ status: 'anonymous', user: null })
    }
  },
}))

registerTokenRefresher(async () => {
  try {
    const response = await refreshBrowserSession()
    useSessionStore.setState(applySession(response))
    return response.accessToken
  } catch {
    clearSessionToken()
    useSessionStore.setState({ status: 'anonymous', user: null })
    return null
  }
})
