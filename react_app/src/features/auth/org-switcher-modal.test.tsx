import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import { describe, expect, it, vi, beforeEach } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { OrgSwitcherModal } from './org-switcher-modal'
import * as authApi from './auth-api'
import { useSessionStore } from '@/shared/session/session-store'

vi.mock('./auth-api', () => ({
  listMyOrganisations: vi.fn(),
  switchOrganisation: vi.fn(),
  loginBrowser: vi.fn(),
  refreshBrowserSession: vi.fn(),
  logoutBrowserSession: vi.fn(),
}))

describe('OrgSwitcherModal', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    queryClient = new QueryClient({
      defaultOptions: {
        queries: { retry: false },
      },
    })
    vi.clearAllMocks()
    useSessionStore.setState({
      status: 'authenticated',
      user: {
        id: 'user-1',
        orgId: 'org-1',
        fullName: 'Test User',
        email: 'test@example.com',
        phone: null,
        role: 'OWNER',
        orgName: 'Primary Org',
        industry: null,
        businessType: null,
        industryCode: null,
        onboardingCompleted: true,
        defaultLandingPage: '/',
      },
    })
  })

  it('renders organisation list with Current badge on active organisation', async () => {
    vi.mocked(authApi.listMyOrganisations).mockResolvedValue([
      { orgId: 'org-1', orgName: 'Primary Org', userId: 'user-1', role: 'OWNER' },
      { orgId: 'org-2', orgName: 'Branch Two', userId: 'user-1', role: 'ADMIN' },
    ])

    render(
      <QueryClientProvider client={queryClient}>
        <OrgSwitcherModal isOpen={true} onClose={vi.fn()} />
      </QueryClientProvider>
    )

    expect(await screen.findByText('Primary Org')).toBeInTheDocument()
    expect(screen.getByText('Branch Two')).toBeInTheDocument()
    expect(screen.getByText('Current')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /switch/i })).toBeInTheDocument()
  })

  it('calls switchOrg and invalidates queries on selecting another organisation', async () => {
    vi.mocked(authApi.listMyOrganisations).mockResolvedValue([
      { orgId: 'org-1', orgName: 'Primary Org', userId: 'user-1', role: 'OWNER' },
      { orgId: 'org-2', orgName: 'Branch Two', userId: 'user-1', role: 'ADMIN' },
    ])
    vi.mocked(authApi.switchOrganisation).mockResolvedValue({
      accessToken: 'new-token',
      user: {
        id: 'user-1',
        orgId: 'org-2',
        fullName: 'Test User',
        email: 'test@example.com',
        phone: null,
        role: 'ADMIN',
        orgName: 'Branch Two',
        industry: null,
        businessType: null,
        industryCode: null,
        onboardingCompleted: true,
        defaultLandingPage: '/',
      },
    })

    const onClose = vi.fn()
    const invalidateSpy = vi.spyOn(queryClient, 'invalidateQueries')

    render(
      <QueryClientProvider client={queryClient}>
        <OrgSwitcherModal isOpen={true} onClose={onClose} />
      </QueryClientProvider>
    )

    const switchBtn = await screen.findByRole('button', { name: /switch/i })
    fireEvent.click(switchBtn)

    await waitFor(() => {
      expect(authApi.switchOrganisation).toHaveBeenCalledWith('org-2')
      expect(invalidateSpy).toHaveBeenCalled()
      expect(onClose).toHaveBeenCalled()
    })
  })
})
