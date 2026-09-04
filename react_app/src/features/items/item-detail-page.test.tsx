import { beforeEach, describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { ItemDetailPage } from './item-detail-page'
import * as itemsApi from './items-api'

vi.mock('./items-api', async () => {
  const actual = await vi.importActual<typeof itemsApi>('./items-api')
  return {
    ...actual,
    getItem: vi.fn(),
    getItemBalances: vi.fn(),
    getItemBatches: vi.fn(),
    getItemMovements: vi.fn(),
    listPackagingBarcodes: vi.fn(),
  }
})

const mockItem: itemsApi.Item = {
  id: 'item-1', sku: 'MASALA-100G', barcode: '890000000001', name: 'Turmeric Masala 100g', description: null,
  itemType: 'GOODS', category: 'Spices', brand: 'Katasticho', manufacturer: null, hsnCode: '0910', unitOfMeasure: 'PCS',
  purchasePrice: 30, salePrice: 45, mrp: 50, gstRate: 18, defaultTaxGroupId: null, trackInventory: true, trackBatches: true,
  reorderLevel: 20, reorderQuantity: 100, preferredVendorId: null, preferredVendorName: null, rackLocationId: null,
  rackLocationCode: 'A-01', rackLocationName: 'Main rack', weight: null, weightUnit: null, length: null, width: null,
  height: null, dimensionUnit: null, drugSchedule: null, composition: null, dosageForm: null, packSize: '100g',
  storageCondition: null, prescriptionRequired: false, weightBasedBilling: false, revenueAccountCode: null, cogsAccountCode: null,
  inventoryAccountCode: null, active: true, totalOnHand: 90, createdAt: '2026-09-04T09:00:00Z', groupId: null,
  variantAttributes: null, groupName: null, purchaseUom: null, purchaseUomConversion: null, purchasePricePerUom: null, secondaryUnits: [],
}

describe('ItemDetailPage', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } })
    vi.clearAllMocks()
    vi.mocked(itemsApi.getItem).mockResolvedValue(mockItem)
    vi.mocked(itemsApi.getItemBalances).mockResolvedValue([
      { itemId: 'item-1', itemSku: 'MASALA-100G', itemName: mockItem.name, warehouseId: 'wh-1', warehouseName: 'Main Warehouse', quantityOnHand: 90, averageCost: 30, reorderLevel: 20, lowStock: false, lastMovementAt: '2026-09-04T09:00:00Z' },
    ])
    vi.mocked(itemsApi.getItemMovements).mockResolvedValue([])
    vi.mocked(itemsApi.getItemBatches).mockResolvedValue([])
    vi.mocked(itemsApi.listPackagingBarcodes).mockResolvedValue([])
  })

  function renderPage() {
    return render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter initialEntries={['/items/item-1']}>
          <Routes><Route path="/items/:itemId" element={<ItemDetailPage />} /></Routes>
        </MemoryRouter>
      </QueryClientProvider>,
    )
  }

  it('renders verified item facts without operational controls', async () => {
    renderPage()

    expect(await screen.findByRole('heading', { name: 'Turmeric Masala 100g' })).toBeInTheDocument()
    expect(screen.getByText('MASALA-100G')).toBeInTheDocument()
    expect(screen.getByText('Read-only review. Stock and master-data changes remain in Flutter during migration.')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /adjust stock|reverse|add barcode|mark damaged/i })).not.toBeInTheDocument()
  })

  it('loads warehouse balances only when that review tab is selected', async () => {
    const user = userEvent.setup()
    renderPage()
    await screen.findByRole('heading', { name: 'Turmeric Masala 100g' })

    await user.click(screen.getByRole('tab', { name: 'Warehouse balances' }))

    expect(await screen.findByText('Main Warehouse')).toBeInTheDocument()
    expect(itemsApi.getItemBalances).toHaveBeenCalledWith('item-1')
  })

  it('shows an actionable error state when the item cannot be read', async () => {
    vi.mocked(itemsApi.getItem).mockRejectedValue(new Error('Network error'))
    renderPage()

    expect(await screen.findByRole('alert')).toHaveTextContent('Item details could not be loaded.')
  })
})
