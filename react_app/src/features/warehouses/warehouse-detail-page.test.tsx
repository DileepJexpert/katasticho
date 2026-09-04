import { beforeEach, describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { WarehouseDetailPage } from './warehouse-detail-page'
import * as warehousesApi from './warehouses-api'

vi.mock('./warehouses-api', async () => {
  const actual = await vi.importActual<typeof warehousesApi>('./warehouses-api')
  return {
    ...actual,
    getWarehouse: vi.fn(),
    listWarehouseZones: vi.fn(),
  }
})

const mockWarehouse: warehousesApi.Warehouse = {
  id: 'warehouse-1', code: 'MAIN', name: 'Main Warehouse', addressLine1: 'Industrial Area', addressLine2: null,
  city: 'Lucknow', state: 'Uttar Pradesh', stateCode: '09', postalCode: '226010', country: 'IN',
  isDefault: true, active: true, createdAt: '2026-09-04T09:00:00Z',
}

describe('WarehouseDetailPage', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } })
    vi.clearAllMocks()
    vi.mocked(warehousesApi.getWarehouse).mockResolvedValue(mockWarehouse)
    vi.mocked(warehousesApi.listWarehouseZones).mockResolvedValue([
      { id: 'zone-1', warehouseId: mockWarehouse.id, code: 'STORAGE-A', name: 'Bulk storage', zoneType: 'STORAGE', capacity: 500, currentUtilization: 120, temperatureControlled: false, notes: null },
    ])
  })

  function renderPage() {
    return render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter initialEntries={['/warehouses/warehouse-1']}>
          <Routes><Route path="/warehouses/:warehouseId" element={<WarehouseDetailPage />} /></Routes>
        </MemoryRouter>
      </QueryClientProvider>,
    )
  }

  it('shows exact facility facts without warehouse or putaway controls', async () => {
    renderPage()

    expect(await screen.findByRole('heading', { name: 'Main Warehouse' })).toBeInTheDocument()
    expect(screen.getByText('Read-only review. Warehouse and zone changes remain in Flutter during migration.')).toBeInTheDocument()
    expect(screen.getByText('Industrial Area')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /add warehouse|add zone|confirm putaway/i })).not.toBeInTheDocument()
  })

  it('loads storage zones only when their tab is selected', async () => {
    const user = userEvent.setup()
    renderPage()
    await screen.findByRole('heading', { name: 'Main Warehouse' })

    await user.click(screen.getByRole('tab', { name: 'Storage zones' }))

    expect(await screen.findByText('Bulk storage')).toBeInTheDocument()
    expect(warehousesApi.listWarehouseZones).toHaveBeenCalledWith('warehouse-1')
  })

  it('distinguishes a zone-query failure from an empty warehouse', async () => {
    vi.mocked(warehousesApi.listWarehouseZones).mockRejectedValue(new Error('Network error'))
    const user = userEvent.setup()
    renderPage()
    await screen.findByRole('heading', { name: 'Main Warehouse' })

    await user.click(screen.getByRole('tab', { name: 'Storage zones' }))

    expect(await screen.findByRole('alert')).toHaveTextContent('Storage zones could not be loaded.')
  })
})
