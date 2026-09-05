import { beforeEach, describe, expect, it, vi } from 'vitest'
import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { ItemFormPage } from './item-form-page'
import * as itemsApi from '@/features/items/items-api'
import { getUoms } from '@/features/inventory/uoms-api'
import { listWarehouses } from '@/features/warehouses/warehouses-api'

vi.mock('@/features/items/items-api', async () => {
  const actual = await vi.importActual<typeof itemsApi>('@/features/items/items-api')
  return {
    ...actual,
    createItem: vi.fn(),
    getItem: vi.fn(),
    updateItem: vi.fn(),
  }
})

vi.mock('@/features/inventory/uoms-api', () => ({
  getUoms: vi.fn(),
}))

vi.mock('@/features/warehouses/warehouses-api', () => ({
  listWarehouses: vi.fn(),
}))

const item: itemsApi.Item = {
  id: 'item-1', sku: 'MASALA-100G', barcode: null, name: 'Turmeric Masala 100g', description: null,
  itemType: 'GOODS', category: 'Spices', brand: null, manufacturer: null, hsnCode: '0910', unitOfMeasure: 'PCS',
  purchasePrice: 30, salePrice: 45, mrp: 50, gstRate: 18, defaultTaxGroupId: null, trackInventory: true, trackBatches: false,
  reorderLevel: 20, reorderQuantity: 100, preferredVendorId: null, preferredVendorName: null, rackLocationId: null,
  rackLocationCode: null, rackLocationName: null, weight: null, weightUnit: null, length: null, width: null,
  height: null, dimensionUnit: null, drugSchedule: null, composition: null, dosageForm: null, packSize: null,
  storageCondition: null, prescriptionRequired: false, weightBasedBilling: false, revenueAccountCode: null, cogsAccountCode: null,
  inventoryAccountCode: null, active: true, totalOnHand: 0, createdAt: '2026-09-04T09:00:00Z', groupId: null,
  variantAttributes: null, groupName: null, purchaseUom: null, purchaseUomConversion: null, purchasePricePerUom: null, secondaryUnits: [],
}

describe('ItemFormPage', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } })
    vi.clearAllMocks()
    vi.mocked(getUoms).mockResolvedValue([
      { id: 'uom-pcs', name: 'Pieces', abbreviation: 'PCS', category: 'COUNT', base: true, active: true },
      { id: 'uom-box', name: 'Box', abbreviation: 'BOX', category: 'COUNT', base: false, active: true },
    ])
    vi.mocked(listWarehouses).mockResolvedValue([
      {
        id: 'warehouse-1', code: 'MAIN', name: 'Main Warehouse', addressLine1: null, addressLine2: null,
        city: null, state: null, stateCode: null, postalCode: null, country: 'IN', isDefault: true,
        active: true, createdAt: null,
      },
    ])
    vi.mocked(itemsApi.createItem).mockResolvedValue(item)
    vi.mocked(itemsApi.getItem).mockResolvedValue(item)
    vi.mocked(itemsApi.updateItem).mockResolvedValue(item)
  })

  function renderPage(path: string) {
    return render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter initialEntries={[path]}>
          <Routes>
            <Route path="/items/new" element={<ItemFormPage />} />
            <Route path="/items/:itemId/edit" element={<ItemFormPage />} />
            <Route path="/items/:itemId" element={<div>Item detail</div>} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>,
    )
  }

  it('creates a batch-tracked item with audited opening stock fields', async () => {
    const user = userEvent.setup()
    renderPage('/items/new')

    fireEvent.change(screen.getByLabelText(/Item name/i), { target: { value: 'Turmeric Masala Test 100g' } })
    fireEvent.change(screen.getByLabelText(/SKU/i), { target: { value: 'MASALA-TURMERIC-TEST-100G' } })
    await user.click(screen.getByRole('checkbox', { name: /Track batches and expiry/i }))
    fireEvent.change(screen.getByLabelText(/Opening quantity/), { target: { value: '100' } })
    fireEvent.change(screen.getByLabelText(/Opening batch number/), { target: { value: 'TUM-SEP-26-A' } })
    await user.click(screen.getByRole('button', { name: 'Create item' }))

    await waitFor(() => {
      expect(itemsApi.createItem).toHaveBeenCalledWith(expect.objectContaining({
        sku: 'MASALA-TURMERIC-TEST-100G',
        name: 'Turmeric Masala Test 100g',
        itemType: 'GOODS',
        unitOfMeasure: 'PCS',
        trackInventory: true,
        trackBatches: true,
        openingStock: 100,
        openingBatchNumber: 'TUM-SEP-26-A',
      }))
    })
    expect(screen.queryByLabelText(/serial/i)).not.toBeInTheDocument()
  })

  it('uses the update contract without opening-stock fields', async () => {
    const user = userEvent.setup()
    renderPage('/items/item-1/edit')

    expect(await screen.findByDisplayValue('MASALA-100G')).toBeInTheDocument()
    fireEvent.change(screen.getByLabelText(/Sale price/i), { target: { value: '48' } })
    await user.click(screen.getByRole('button', { name: 'Save item' }))

    await waitFor(() => {
      expect(itemsApi.updateItem).toHaveBeenCalledWith('item-1', expect.objectContaining({
        sku: 'MASALA-100G',
        salePrice: 48,
      }))
    })
    expect(vi.mocked(itemsApi.updateItem).mock.calls[0]?.[1]).not.toHaveProperty('openingStock')
  })
})
