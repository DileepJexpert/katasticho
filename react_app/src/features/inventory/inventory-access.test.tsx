import { renderHook } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import { useInventoryAccess } from './inventory-access'
import { useSessionStore } from '@/shared/session/session-store'

describe('inventory action permissions match the frozen controllers', () => {
  it.each([
    ['OWNER', true, true, true, true],
    ['ADMIN', true, true, true, true],
    ['ACCOUNTANT', true, true, false, false],
    ['OPERATOR', true, false, false, true],
    ['VIEWER', false, false, false, false],
    ['PLATFORM_ADMIN', false, false, false, false],
    ['', false, false, false, false],
  ] as const)('%s', (role, operate, manage, administer, readZones) => {
    useSessionStore.setState({
      status: role ? 'authenticated' : 'anonymous',
      user: role ? {
        id: 'u-1',
        orgId: 'o-1',
        fullName: 'User',
        email: 'user@test.com',
        phone: null,
        role,
        orgName: 'Org',
        industry: null,
        businessType: null,
        industryCode: null,
        onboardingCompleted: true,
        defaultLandingPage: null,
      } : null,
    })
    const { result } = renderHook(() => useInventoryAccess())
    expect(result.current).toEqual({ operate, manage, administer, readZones })
  })
})
