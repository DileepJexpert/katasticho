import { beforeEach, describe, expect, it, vi } from 'vitest'
import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { WarehouseDetailPage } from './warehouse-detail-page'
import * as warehousesApi from './warehouses-api'
import { useInventoryAccess } from '@/features/inventory/inventory-access'

vi.mock('@/features/inventory/inventory-access', () => ({ useInventoryAccess: vi.fn() }))

vi.mock('./warehouses-api', async () => {
  const actual = await vi.importActual<typeof warehousesApi>('./warehouses-api')
  return {
    ...actual,
    getWarehouse: vi.fn(),
    listWarehouseZones: vi.fn(),
    updateWarehouse: vi.fn(),
    createWarehouseZone: vi.fn(),
    updateWarehouseZone: vi.fn(),
    deleteWarehouseZone: vi.fn(),
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
    vi.mocked(useInventoryAccess).mockReturnValue({ operate: true, manage: true, administer: true, readZones: true })
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

  it('shows warehouse maintenance without promising putaway controls', async () => {
    renderPage()

    expect(await screen.findByRole('heading', { name: 'Main Warehouse' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Edit warehouse' })).toBeInTheDocument()
    expect(screen.getByText('Industrial Area')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /remove warehouse|confirm putaway/i })).not.toBeInTheDocument()
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

  it('keeps the default warehouse active and sends its full edit contract', async () => {
    vi.mocked(warehousesApi.updateWarehouse).mockResolvedValue({ ...mockWarehouse, name: 'Central Depot' })
    const user = userEvent.setup()
    renderPage()
    await user.click(await screen.findByRole('button', { name: 'Edit warehouse' }))
    const dialog = screen.getByRole('dialog', { name: 'Edit warehouse' })
    expect(within(dialog).getByRole('checkbox', { name: 'Default warehouse' })).toBeDisabled()
    expect(within(dialog).getByRole('checkbox', { name: 'Active' })).toBeDisabled()
    await user.clear(within(dialog).getByRole('textbox', { name: /^Name/ }))
    await user.type(within(dialog).getByRole('textbox', { name: /^Name/ }), 'Central Depot')
    await user.click(within(dialog).getByRole('button', { name: 'Save warehouse' }))
    await waitFor(() => expect(warehousesApi.updateWarehouse).toHaveBeenCalledWith('warehouse-1', expect.objectContaining({ name: 'Central Depot', code: 'MAIN', isDefault: true, active: true, country: 'IN', stateCode: '09' })))
  })

  it.each([
    { label: 'ACCOUNTANT', operate: true, manage: true },
    { label: 'VIEWER', operate: false, manage: false },
  ])('does not offer forbidden zone queries to $label', async ({ operate, manage }) => {
    vi.mocked(useInventoryAccess).mockReturnValue({ operate, manage, administer: false, readZones: false })
    renderPage()
    await screen.findByRole('heading', { name: 'Main Warehouse' })
    expect(screen.queryByRole('tab', { name: 'Storage zones' })).not.toBeInTheDocument()
    expect(warehousesApi.listWarehouseZones).not.toHaveBeenCalled()
  })

  it('creates a zone with the current warehouse UUID and configuration fields', async () => {
    vi.mocked(warehousesApi.createWarehouseZone).mockResolvedValue({ id: 'zone-new', warehouseId: 'warehouse-1', code: 'QC', name: 'Quality check', zoneType: 'STORAGE', capacity: null, currentUtilization: 0, temperatureControlled: false, notes: '' })
    const user = userEvent.setup()
    renderPage()
    await screen.findByRole('heading', { name: 'Main Warehouse' })
    await user.click(screen.getByRole('tab', { name: 'Storage zones' }))
    await user.click(screen.getByRole('button', { name: 'Add storage zone' }))
    const dialog = screen.getByRole('dialog', { name: 'Add storage zone' })
    await user.type(within(dialog).getByRole('textbox', { name: /Zone code/ }), 'QC')
    await user.type(within(dialog).getByRole('textbox', { name: /Zone name/ }), 'Quality check')
    await user.click(within(dialog).getByRole('button', { name: 'Save zone' }))
    await waitFor(() => expect(warehousesApi.createWarehouseZone).toHaveBeenCalledWith({ warehouseId: 'warehouse-1', code: 'QC', name: 'Quality check', zoneType: 'STORAGE', capacity: undefined, temperatureControlled: false, notes: '' }))
  })

  it('does not pretend a saved zone capacity can be cleared', async () => {
    const user = userEvent.setup()
    renderPage()
    await screen.findByRole('heading', { name: 'Main Warehouse' })
    await user.click(screen.getByRole('tab', { name: 'Storage zones' }))
    await user.click(await screen.findByRole('button', { name: 'Edit STORAGE-A' }))
    const dialog = screen.getByRole('dialog', { name: 'Edit storage zone' })
    expect(within(dialog).getByRole('textbox', { name: /Zone code/ })).toBeDisabled()
    await user.clear(within(dialog).getByRole('spinbutton', { name: 'Capacity' }))
    await user.click(within(dialog).getByRole('button', { name: 'Save zone' }))
    expect(within(dialog).getByRole('alert')).toHaveTextContent('cannot clear a saved capacity')
    expect(warehousesApi.updateWarehouseZone).not.toHaveBeenCalled()
  })
})
