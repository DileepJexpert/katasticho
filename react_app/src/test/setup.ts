import '@testing-library/jest-dom/vitest'
import { cleanup } from '@testing-library/react'
import { afterEach, beforeEach } from 'vitest'
import { useSessionStore } from '@/shared/session/session-store'

beforeEach(() => {
  useSessionStore.setState({
    status: 'authenticated',
    user: {
      id: 'test-user-1',
      orgId: 'org-test',
      fullName: 'Test Admin',
      email: 'admin@example.com',
      phone: null,
      role: 'ADMIN',
      orgName: 'Test Org',
      industry: null,
      businessType: null,
      industryCode: null,
      onboardingCompleted: true,
      defaultLandingPage: null,
    },
  })
})

afterEach(() => {
  cleanup()
})
