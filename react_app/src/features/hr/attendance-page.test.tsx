import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { enterpriseUser } from '@/features/accounting/enterprise-test-fixtures'
import { useSessionStore } from '@/shared/session/session-store'
import { AttendancePage } from './attendance-page'
import * as api from './hr-api'

vi.mock('./hr-api', () => ({
  approveRegularization: vi.fn(), getAttendanceSummary: vi.fn(), getAttendanceToday: vi.fn(),
  listMyRegularizations: vi.fn(), listPendingRegularizations: vi.fn(), recordAttendancePunch: vi.fn(),
  rejectRegularization: vi.fn(), requestRegularization: vi.fn(),
}))
vi.mock('@/features/settings/settings-api', () => ({ listOrgUsers: vi.fn().mockResolvedValue([]) }))

function renderPage() {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false }, mutations: { retry: false } } })
  return render(<QueryClientProvider client={client}><MemoryRouter><AttendancePage /></MemoryRouter></QueryClientProvider>)
}

describe('AttendancePage', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    useSessionStore.setState({ status: 'authenticated', user: enterpriseUser })
    vi.mocked(api.getAttendanceToday).mockResolvedValue(null)
    vi.mocked(api.getAttendanceSummary).mockResolvedValue({ presentDays: 7, absentDays: 2, leaveDays: 1, payableDays: 8, totalHours: 54, holidays: 3 })
    vi.mocked(api.recordAttendancePunch).mockResolvedValue({ id: 'attendance-1', workDate: '2026-09-05', punchInAt: '2026-09-05T03:30:00Z', punchOutAt: null })
  })

  it('renders only server attendance values and confirms a real punch', async () => {
    renderPage()

    expect(await screen.findByText('7')).toBeInTheDocument()
    expect(screen.getByText('54')).toBeInTheDocument()
    expect(screen.queryByText('22')).not.toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: 'Punch in' }))
    expect(screen.getByRole('heading', { name: 'Record punch in' })).toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: 'Confirm' }))
    await waitFor(() => expect(api.recordAttendancePunch).toHaveBeenCalledWith('punch-in'))
  })
})
