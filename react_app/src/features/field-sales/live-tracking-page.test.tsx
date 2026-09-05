import { fireEvent, render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { LiveTrackingPage } from './live-tracking-page'
import * as fieldSalesApi from '@/features/field-sales/field-sales-api'

vi.mock('@/features/field-sales/field-sales-api', () => ({
  getLiveLocations: vi.fn(),
  getLocationTrail: vi.fn(),
}))

const mockUsers: fieldSalesApi.LiveLocationUser[] = [
  {
    userId: 'user-1',
    salespersonId: 'sp-1',
    salespersonName: 'Amit Verma',
    executionId: 'exec-1',
    routeName: 'Central Hub Beat',
    latitude: 19.076,
    longitude: 72.8777,
    accuracy: 8,
    batteryLevel: 85,
    updatedAt: '2026-09-04T10:30:00Z',
  },
  {
    userId: 'user-2',
    salespersonId: 'sp-2',
    salespersonName: 'Priya Nair',
    executionId: 'exec-2',
    routeName: 'North District Beat',
    latitude: 28.6139,
    longitude: 77.209,
    accuracy: 12,
    batteryLevel: 42,
    updatedAt: '2026-09-04T10:32:00Z',
  },
]

const mockTrail: fieldSalesApi.LocationTrail = {
  executionId: 'exec-1',
  salespersonId: 'sp-1',
  salespersonName: 'Amit Verma',
  executionDate: '2026-09-04',
  trail: [
    {
      latitude: 19.076,
      longitude: 72.8777,
      timestamp: '2026-09-04T10:00:00Z',
      activity: 'Beat Start',
    },
    {
      latitude: 19.078,
      longitude: 72.879,
      timestamp: '2026-09-04T10:15:00Z',
      activity: 'Customer Visit',
    },
  ],
}

function renderLiveTracking() {
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
        <LiveTrackingPage />
      </MemoryRouter>
    </QueryClientProvider>,
  )
}

describe('LiveTrackingPage', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(fieldSalesApi.getLiveLocations).mockResolvedValue(mockUsers)
    vi.mocked(fieldSalesApi.getLocationTrail).mockResolvedValue(mockTrail)
  })

  it('renders live tracking title and connected reps', async () => {
    renderLiveTracking()

    expect(screen.getByText('Field Live Tracking & GPS Trails')).toBeInTheDocument()
    expect(await screen.findByText('Amit Verma')).toBeInTheDocument()
    expect(screen.getByText('Priya Nair')).toBeInTheDocument()
    expect(screen.getByText('Central Hub Beat')).toBeInTheDocument()
  })

  it('filters reps by search query', async () => {
    renderLiveTracking()

    await screen.findByText('Amit Verma')

    const searchInput = screen.getByPlaceholderText(/Search rep or assigned route/i)
    fireEvent.change(searchInput, { target: { value: 'Priya' } })

    expect(screen.getByText('Priya Nair')).toBeInTheDocument()
    expect(screen.queryByText('Amit Verma')).not.toBeInTheDocument()
  })

  it('opens breadcrumb trail modal when view trail button is clicked', async () => {
    renderLiveTracking()

    await screen.findByText('Amit Verma')

    const trailButtons = screen.getAllByRole('button', { name: /View Trail/i })
    expect(trailButtons.length).toBeGreaterThan(0)
    fireEvent.click(trailButtons[0]!)

    expect(await screen.findByText('Execution Location Trail')).toBeInTheDocument()
    expect(fieldSalesApi.getLocationTrail).toHaveBeenCalledWith('exec-1')
  })
})
