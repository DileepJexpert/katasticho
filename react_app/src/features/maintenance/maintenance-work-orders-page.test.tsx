import { render, screen, waitFor } from '@testing-library/react'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter } from 'react-router-dom'
import { MaintenanceWorkOrdersPage } from './maintenance-work-orders-page'
import * as maintenanceApi from './maintenance-api'

vi.mock('./maintenance-api', () => ({
  listMaintenanceWorkOrders: vi.fn(),
}))

const mockMwo: maintenanceApi.MaintenanceWorkOrder = {
  id: 'mwo-001',
  mwoNumber: 'MWO-2026-0001',
  workstationId: 'ws-granulator-1',
  workstationName: 'Fluid Bed Granulator #1',
  title: 'Replace hydraulic seal and recalibrate thermal probes',
  maintenanceType: 'PREVENTIVE',
  priority: 'HIGH',
  status: 'IN_PROGRESS',
  reportedAt: '2026-09-01T08:00:00Z',
  downtimeMinutes: 270,
  cost: 1500,
}

describe('MaintenanceWorkOrdersPage', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } })
    vi.clearAllMocks()
    vi.mocked(maintenanceApi.listMaintenanceWorkOrders).mockResolvedValue([mockMwo])
  })

  function renderPage() {
    return render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter>
          <MaintenanceWorkOrdersPage />
        </MemoryRouter>
      </QueryClientProvider>
    )
  }

  it('renders maintenance work orders directory, equipment name, and status', async () => {
    renderPage()

    await waitFor(() => {
      expect(screen.getByText('MWO-2026-0001')).toBeInTheDocument()
    })

    expect(screen.getByText('Fluid Bed Granulator #1')).toBeInTheDocument()
    expect(screen.getByText('Replace hydraulic seal and recalibrate thermal probes')).toBeInTheDocument()
    expect(screen.getByText('PREVENTIVE')).toBeInTheDocument()
    expect(screen.getByText('In Progress')).toBeInTheDocument()
  })
})
