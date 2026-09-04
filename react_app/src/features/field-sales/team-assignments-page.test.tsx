import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { TeamAssignmentsPage } from './team-assignments-page'
import * as fieldSalesApi from '@/features/field-sales/field-sales-api'

vi.mock('@/features/field-sales/field-sales-api', () => ({
  listAssignments: vi.fn(),
  listRoutes: vi.fn(),
  listBeats: vi.fn(),
  listVans: vi.fn(),
  createAssignment: vi.fn(),
  endAssignment: vi.fn(),
}))

const mockAssignments = [
  {
    id: 'assign-1',
    salespersonId: 'sp-1',
    salespersonName: 'Rohan Sharma',
    routeId: 'route-1',
    routeName: 'South Metro Route',
    beatId: 'beat-1',
    beatName: 'Koramangala Beat',
    vanId: 'van-1',
    vanPlateNumber: 'KA-01-AB-1234',
    startDate: '2026-09-01',
    active: true,
  },
]

const mockRoutes = {
  content: [
    {
      id: 'route-1',
      code: 'R-001',
      name: 'South Metro Route',
      routeType: 'DISTRIBUTION',
      active: true,
    },
  ],
  totalElements: 1,
  totalPages: 1,
  size: 100,
  number: 0,
}

const mockBeats = {
  content: [
    {
      id: 'beat-1',
      code: 'B-001',
      name: 'Koramangala Beat',
      dayOfWeek: 1,
      customerCount: 15,
      active: true,
    },
  ],
  totalElements: 1,
  totalPages: 1,
  size: 100,
  number: 0,
}

const mockVans = {
  content: [
    {
      id: 'van-1',
      registrationNumber: 'KA-01-AB-1234',
      model: 'Tata Ace Gold',
      active: true,
    },
  ],
  totalElements: 1,
  totalPages: 1,
  size: 100,
  number: 0,
}

function renderAssignments() {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: {
        retry: false,
      },
    },
  })

  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter>
        <TeamAssignmentsPage />
      </MemoryRouter>
    </QueryClientProvider>,
  )
}

describe('TeamAssignmentsPage', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(fieldSalesApi.listAssignments).mockResolvedValue(
      mockAssignments as unknown as fieldSalesApi.FieldSalesAssignment[]
    )
    vi.mocked(fieldSalesApi.listRoutes).mockResolvedValue(
      mockRoutes as unknown as fieldSalesApi.PageResponse<fieldSalesApi.SalesRoute>
    )
    vi.mocked(fieldSalesApi.listBeats).mockResolvedValue(
      mockBeats as unknown as fieldSalesApi.PageResponse<fieldSalesApi.SalesBeat>
    )
    vi.mocked(fieldSalesApi.listVans).mockResolvedValue(
      mockVans as unknown as fieldSalesApi.PageResponse<fieldSalesApi.SalesVan>
    )
    vi.mocked(fieldSalesApi.createAssignment).mockResolvedValue(
      mockAssignments[0] as unknown as fieldSalesApi.FieldSalesAssignment
    )
    vi.mocked(fieldSalesApi.endAssignment).mockResolvedValue(
      mockAssignments[0] as unknown as fieldSalesApi.FieldSalesAssignment
    )
  })

  it('renders assignment title, assignments table, and rep info', async () => {
    renderAssignments()

    expect(screen.getByText('Team Route & Beat Assignments')).toBeInTheDocument()
    expect(await screen.findByText('Rohan Sharma')).toBeInTheDocument()
    expect(screen.getByText('South Metro Route')).toBeInTheDocument()
    expect(screen.getByText('KA-01-AB-1234')).toBeInTheDocument()
  })

  it('opens new assignment modal on clicking New Assignment button', async () => {
    renderAssignments()

    await screen.findByText('Rohan Sharma')

    const newAssignButton = screen.getByRole('button', { name: /New Assignment/i })
    fireEvent.click(newAssignButton)

    expect(screen.getByText('New Territory Assignment')).toBeInTheDocument()
    expect(screen.getByLabelText(/Salesperson ID/i)).toBeInTheDocument()
  })

  it('triggers end assignment mutation when end button is clicked', async () => {
    renderAssignments()

    await screen.findByText('Rohan Sharma')

    const endButton = screen.getByRole('button', { name: /^End$/i })
    fireEvent.click(endButton)

    await waitFor(() => {
      expect(fieldSalesApi.endAssignment).toHaveBeenCalledWith('assign-1', expect.any(String))
    })
  })
})
