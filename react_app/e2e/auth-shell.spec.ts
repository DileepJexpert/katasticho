import { expect, test, type Page, type Route } from '@playwright/test'

const user = {
  id: '00000000-0000-0000-0000-000000000001',
  orgId: '00000000-0000-0000-0000-000000000002',
  fullName: 'QA Owner',
  email: 'owner@example.test',
  phone: null,
  role: 'OWNER',
  orgName: 'QA Organisation',
  industry: 'DISTRIBUTOR',
  businessType: 'DISTRIBUTOR',
  industryCode: 'FMCG_DISTRIBUTOR',
  onboardingCompleted: true,
  defaultLandingPage: null,
}

function envelope(data: unknown, success = true, message: string | null = null) {
  return { success, message, data, errors: [] }
}

async function json(route: Route, data: unknown, status = 200) {
  await route.fulfill({
    status,
    contentType: 'application/json',
    body: JSON.stringify(data),
  })
}

async function mockAnonymousSession(page: Page) {
  await page.route('**/api/v1/auth/web/refresh', (route) =>
    json(route, envelope(null, false, 'No active browser session.'), 401),
  )
}

function dashboardData(pathname: string): unknown {
  if (pathname.endsWith('/branches')) return []
  if (pathname.includes('/top-selling') || pathname.includes('/expiring-soon') || pathname.includes('/recent-')) return []
  if (pathname.includes('/today-sales')) return { totalSales: 0, cashUpiTotal: 0, creditTotal: 0, posSalesTotal: 0, paidInvoiceTotal: 0, transactionCount: 0, posTransactionCount: 0, invoiceTransactionCount: 0, currency: 'INR', byBranch: [] }
  if (pathname.includes('/receivables') || pathname.includes('/ap-summary')) return { totalOutstanding: 0, overdueCount: 0, dueThisWeek: 0, dueThisWeekCount: 0, currency: 'INR', byBranch: [] }
  if (pathname.includes('/monthly-profit')) return { revenue: 0, cogs: 0, grossProfit: 0, currency: 'INR' }
  if (pathname.includes('/so-alerts')) return { confirmedCount: 0, backorderCount: 0, partiallyShippedCount: 0, overdueCount: 0, draftChallanCount: 0, dispatchedChallanCount: 0, deliveredChallanCount: 0, recentOrders: [] }
  if (pathname.includes('/revenue-trend')) return { days: 30, totalRevenue: 0, currency: 'INR', trend: [] }
  if (pathname.includes('/cash-flow')) return { cashIn: 0, cashOut: 0, netCashFlow: 0, currency: 'INR' }
  if (pathname.includes('/daily-summary')) return { today: { totalSale: 0, totalCost: 0, earning: 0, cashUpiIn: 0, creditSale: 0, billCount: 0 }, daily: [], thisWeek: { totalSale: 0, totalEarning: 0, vsLastWeekSalePct: 0, vsLastWeekEarningPct: 0 }, currency: 'INR' }
  if (pathname.includes('/outstanding-receivable')) return { totalOutstanding: 0, overdueCount: 0, overdueAmount: 0, currency: 'INR', topCustomers: [] }
  if (pathname.includes('/reports/ageing')) return { totalOutstanding: 0, current: 0, days1to30: 0, days31to60: 0, days61to90: 0, days90plus: 0 }
  return {}
}

test('protected routes redirect an anonymous browser to sign in', async ({ page }) => {
  await mockAnonymousSession(page)
  await page.goto('/accounts')

  await expect(page).toHaveURL(/\/login$/)
  await expect(page.getByRole('heading', { name: 'Sign in to your business' })).toBeVisible()
})

test('login reports required fields without sending credentials', async ({ page }) => {
  let loginRequests = 0
  await mockAnonymousSession(page)
  await page.route('**/api/v1/auth/web/login', async (route) => {
    loginRequests += 1
    await json(route, envelope(null, false, 'Unexpected request.'), 400)
  })
  await page.goto('/login')

  await page.getByRole('button', { name: 'Sign in' }).click()

  await expect(page.getByText('Enter your phone number or email address.')).toBeVisible()
  await expect(page.getByText('Enter your password.')).toBeVisible()
  expect(loginRequests).toBe(0)
})

test('a valid browser session reaches the role-aware ERP shell', async ({ page }) => {
  await page.route('**/api/v1/**', (route) => {
    const pathname = new URL(route.request().url()).pathname
    return json(route, envelope(dashboardData(pathname)))
  })
  await mockAnonymousSession(page)
  await page.route('**/api/v1/auth/web/login', (route) =>
    json(route, envelope({ accessToken: 'short-lived-access-token', user })),
  )
  await page.route('**/api/v1/settings/nav.disabled', (route) =>
    json(route, { 'nav.disabled': '[]' }),
  )

  await page.goto('/login')
  await page.getByLabel('Phone or email').fill('owner@example.test')
  await page.getByLabel('Password').fill('correct-password')
  await page.getByRole('button', { name: 'Sign in' }).click()

  await expect(page).toHaveURL(/\/$/)
  await expect(page.getByRole('button', { name: 'QA Owner' })).toBeVisible()
  const navigation = page.getByRole('complementary', { name: 'Main navigation' })
  await expect(navigation).toBeVisible()
  await expect(navigation.getByRole('button', { name: 'Quick Create' })).toBeVisible()
})

test('an operator cannot load the owner-only user workspace', async ({ page }) => {
  let userDirectoryRequests = 0
  const operator = { ...user, role: 'OPERATOR', fullName: 'QA Operator' }
  await page.route('**/api/v1/**', (route) => {
    const pathname = new URL(route.request().url()).pathname
    if (pathname.startsWith('/api/v1/org/users')) userDirectoryRequests += 1
    return json(route, envelope(dashboardData(pathname)))
  })
  await page.route('**/api/v1/auth/web/refresh', (route) =>
    json(route, envelope({ accessToken: 'operator-access-token', user: operator })),
  )
  await page.route('**/api/v1/settings/nav.disabled', (route) =>
    json(route, { 'nav.disabled': '[]' }),
  )

  await page.goto('/settings/users')

  await expect(page.getByRole('alert')).toContainText('cannot access this workspace')
  expect(userDirectoryRequests).toBe(0)
})

test('organisation switching clears tenant context before new requests run', async ({ page }) => {
  const branchUser = { ...user, orgId: '00000000-0000-0000-0000-000000000003', orgName: 'Branch Two', role: 'ADMIN' }
  let switched = false
  const postSwitchOrgHeaders: string[] = []

  await page.route('**/api/v1/**', (route) => {
    const pathname = new URL(route.request().url()).pathname
    if (switched) postSwitchOrgHeaders.push(route.request().headers()['x-org-id'] ?? '')
    return json(route, envelope(dashboardData(pathname)))
  })
  await page.route('**/api/v1/auth/web/refresh', (route) =>
    json(route, envelope({ accessToken: 'owner-access-token', user })),
  )
  await page.route('**/api/v1/settings/nav.disabled', (route) =>
    json(route, { 'nav.disabled': '[]' }),
  )
  await page.route('**/api/v1/users/me/organisations', (route) =>
    json(route, envelope([
      { orgId: user.orgId, orgName: user.orgName, userId: user.id, role: user.role },
      { orgId: branchUser.orgId, orgName: branchUser.orgName, userId: branchUser.id, role: branchUser.role },
    ])),
  )
  await page.route('**/api/v1/users/me/switch-org', async (route) => {
    expect(route.request().postDataJSON()).toEqual({ targetOrgId: branchUser.orgId })
    switched = true
    await json(route, envelope({ accessToken: 'branch-access-token', user: branchUser }))
  })

  await page.goto('/')
  await page.getByRole('button', { name: 'QA Owner' }).click()
  await page.getByRole('button', { name: 'Switch Organisation' }).click()
  await page.getByRole('button', { name: 'Switch', exact: true }).click()

  await expect(page.getByRole('dialog', { name: 'Switch Organisation' })).not.toBeVisible()
  await page.getByRole('button', { name: 'QA Owner' }).click()
  await expect(page.getByText('Branch Two', { exact: true })).toBeVisible()
  await expect.poll(() => postSwitchOrgHeaders.filter(Boolean).length).toBeGreaterThan(0)
  expect(postSwitchOrgHeaders.filter(Boolean)).toEqual(
    expect.arrayContaining([branchUser.orgId]),
  )
  expect(postSwitchOrgHeaders.filter(Boolean)).not.toContain(user.orgId)
})
