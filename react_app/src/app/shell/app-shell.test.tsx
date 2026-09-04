import { fireEvent, render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { AppShell } from './app-shell'
import { useSessionStore } from '@/shared/session/session-store'
import { useThemeStore } from '@/shared/theme/theme-store'

vi.mock('@/shared/navigation/navigation-settings', () => ({
  getDisabledNavigationIds: vi.fn().mockResolvedValue([]),
}))

describe('AppShell - Theme and Accessibility Integration', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    queryClient = new QueryClient({
      defaultOptions: {
        queries: { retry: false },
      },
    })
    vi.clearAllMocks()
    useThemeStore.getState().setThemeMode('light')
    useSessionStore.setState({
      status: 'authenticated',
      user: {
        id: 'user-1',
        orgId: 'org-1',
        fullName: 'Test Operator',
        email: 'op@example.com',
        phone: null,
        role: 'OWNER',
        orgName: 'Katasticho Demo Org',
        industry: null,
        businessType: null,
        industryCode: null,
        onboardingCompleted: true,
        defaultLandingPage: '/',
      },
    })
  })

  it('renders topbar theme switcher and keyboard shortcuts button', () => {
    render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter>
          <AppShell />
        </MemoryRouter>
      </QueryClientProvider>
    )

    const themeToggle = screen.getByRole('button', { name: /toggle light.*dark theme/i })
    const shortcutsBtn = screen.getByRole('button', { name: /keyboard shortcuts/i })

    expect(themeToggle).toBeInTheDocument()
    expect(shortcutsBtn).toBeInTheDocument()
  })

  it('cycles theme mode when theme toggle button is clicked', () => {
    render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter>
          <AppShell />
        </MemoryRouter>
      </QueryClientProvider>
    )

    const themeToggle = screen.getByRole('button', { name: /toggle light.*dark theme/i })
    expect(useThemeStore.getState().themeMode).toBe('light')

    fireEvent.click(themeToggle)
    expect(useThemeStore.getState().themeMode).toBe('dark')

    fireEvent.click(themeToggle)
    expect(useThemeStore.getState().themeMode).toBe('system')
  })

  it('opens keyboard shortcuts modal when clicking the shortcuts button', () => {
    render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter>
          <AppShell />
        </MemoryRouter>
      </QueryClientProvider>
    )

    const shortcutsBtn = screen.getByRole('button', { name: /keyboard shortcuts/i })
    fireEvent.click(shortcutsBtn)

    expect(screen.getByRole('dialog')).toBeInTheDocument()
    expect(screen.getByText('Keyboard shortcuts')).toBeInTheDocument()
    expect(screen.getByText('Navigation & Search')).toBeInTheDocument()

    // Close the modal
    const closeBtn = screen.getByRole('button', { name: 'Close' })
    fireEvent.click(closeBtn)
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
  })

  it('opens keyboard shortcuts modal when pressing ? key', () => {
    render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter>
          <AppShell />
        </MemoryRouter>
      </QueryClientProvider>
    )

    fireEvent.keyDown(window, { key: '?' })
    expect(screen.getByRole('dialog')).toBeInTheDocument()
    expect(screen.getByText('Keyboard shortcuts')).toBeInTheDocument()
  })
})
