import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MyProfilePage } from './my-profile-page'
import * as hrApi from '@/features/hr/hr-api'

vi.mock('@/features/hr/hr-api', () => ({
  getMyProfile: vi.fn(),
  claimMyProfile: vi.fn(),
  updateMyProfile: vi.fn(),
  addMyFamily: vi.fn(),
  deleteMyFamily: vi.fn(),
  addMyEducation: vi.fn(),
  deleteMyEducation: vi.fn(),
  addMyExperience: vi.fn(),
  deleteMyExperience: vi.fn(),
}))

describe('MyProfilePage', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    vi.clearAllMocks()
    queryClient = new QueryClient({
      defaultOptions: { queries: { retry: false } },
    })
  })

  it('renders profile when employee is linked', async () => {
    vi.mocked(hrApi.getMyProfile).mockResolvedValue({
      employee: {
        id: 'emp-1',
        orgId: 'org-1',
        fullName: 'Aarav Mehta',
        employeeCode: 'EMP-0001',
        designation: 'Operations Lead',
        department: 'Logistics',
        phone: '+91 9988776655',
        personalEmail: 'aarav@example.com',
        employmentStatus: 'ACTIVE',
      },
      family: [
        { id: 'fam-1', name: 'Neha Mehta', relationship: 'SPOUSE', dependent: true },
      ],
      education: [],
      experience: [],
    })

    render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter>
          <MyProfilePage />
        </MemoryRouter>
      </QueryClientProvider>
    )

    await waitFor(() => {
      expect(screen.getByText('Aarav Mehta')).toBeInTheDocument()
      expect(screen.getByText('EMP-0001')).toBeInTheDocument()
      expect(screen.getByText('Operations Lead')).toBeInTheDocument()
    })

    // Check family tab
    fireEvent.click(screen.getByRole('tab', { name: /Family/i }))
    await waitFor(() => {
      expect(screen.getByText('Neha Mehta')).toBeInTheDocument()
    })
  })

  it('renders unlinked claim prompt when employee not linked', async () => {
    vi.mocked(hrApi.getMyProfile).mockRejectedValue(new Error('HR_EMPLOYEE_NOT_LINKED'))

    render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter>
          <MyProfilePage />
        </MemoryRouter>
      </QueryClientProvider>
    )

    await waitFor(() => {
      expect(screen.getByText('Employee Profile Not Linked')).toBeInTheDocument()
      expect(screen.getByText('Claim / Create My Profile')).toBeInTheDocument()
    })
  })
})
