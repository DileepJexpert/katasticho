import { beforeEach, describe, expect, it, vi } from 'vitest'
import { apiFetch } from '@/api/client/api-client'
import { addPriceListTier, assignPriceListCustomer, createPriceList, deletePriceList, deletePriceListTier, unassignPriceListCustomer } from '@/features/price-lists/price-lists-api'
import { createScheme, deleteScheme, evaluateScheme, listApplicableSchemes, updateScheme, validateScheme, type SchemeRequest } from './schemes-api'
import { listAvailableBatches } from '@/features/inventory/batches-api'
import { getStockValuation } from '@/features/inventory/stock-summary-api'

vi.mock('@/api/client/api-client', () => ({ apiFetch: vi.fn() }))
const request: SchemeRequest = {
  name: 'Wholesale promotion', schemeType: 'BUY_X_GET_Y', itemId: 'item-1', supplierId: 'supplier-1',
  buyQuantity: 10, freeQuantity: 1, discountPercent: null, minOrderQuantity: 5,
  validFrom: '2026-09-01', validTo: '2026-09-30', active: true, allowHalfScheme: true,
  halfSchemeMinQty: 5, companySubsidyPercent: 75, specialNetRate: null, maxFreeQuantityCap: 10,
}

describe('Frozen pricing and inventory contracts', () => {
  beforeEach(() => vi.clearAllMocks())
  it('sends plain objects for price-list and tier creation', async () => {
    const list = { name: 'Wholesale', description: null, currency: 'INR', isDefault: true }
    await createPriceList(list)
    expect(apiFetch).toHaveBeenLastCalledWith('/api/v1/price-lists', { method: 'POST', body: list })
    await addPriceListTier('list-1', { itemId: 'item-1', minQuantity: 10, price: 40 })
    expect(apiFetch).toHaveBeenLastCalledWith('/api/v1/price-lists/list-1/items', { method: 'POST', body: { itemId: 'item-1', minQuantity: 10, price: 40 } })
  })
  it('uses tier-row IDs and scoped assignment paths for removals', async () => {
    await deletePriceListTier('tier-1')
    expect(apiFetch).toHaveBeenLastCalledWith('/api/v1/price-lists/items/tier-1', { method: 'DELETE' })
    await assignPriceListCustomer('list-1', 'contact-1')
    expect(apiFetch).toHaveBeenLastCalledWith('/api/v1/price-lists/list-1/customers/contact-1', { method: 'POST' })
    await unassignPriceListCustomer('list-1', 'contact-1')
    expect(apiFetch).toHaveBeenLastCalledWith('/api/v1/price-lists/list-1/customers/contact-1', { method: 'DELETE' })
    await deletePriceList('list-1')
    expect(apiFetch).toHaveBeenLastCalledWith('/api/v1/price-lists/list-1', { method: 'DELETE' })
  })
  it('preserves every scheme field on create and replacement updates', async () => {
    await createScheme(request)
    expect(apiFetch).toHaveBeenLastCalledWith('/api/v1/schemes', { method: 'POST', body: request })
    await updateScheme('scheme-1', { ...request, active: false })
    expect(apiFetch).toHaveBeenLastCalledWith('/api/v1/schemes/scheme-1', { method: 'PUT', body: { ...request, active: false } })
    await deleteScheme('scheme-1')
    expect(apiFetch).toHaveBeenLastCalledWith('/api/v1/schemes/scheme-1', { method: 'DELETE' })
  })
  it('asks the server to evaluate the selected inputs', async () => {
    await listApplicableSchemes('item-1', 5)
    expect(apiFetch).toHaveBeenLastCalledWith('/api/v1/schemes/applicable?itemId=item-1&quantity=5')
    const input = { itemId: 'item-1', quantity: 5, unitPrice: 45, schemeId: null }
    await evaluateScheme(input)
    expect(apiFetch).toHaveBeenLastCalledWith('/api/v1/schemes/evaluate', { method: 'POST', body: input })
  })
  it('scopes batch availability to the issuing warehouse and uses the costing report', async () => {
    await listAvailableBatches('item-1', 'warehouse-2')
    expect(apiFetch).toHaveBeenLastCalledWith('/api/v1/batches/item/item-1/available?warehouseId=warehouse-2')
    await listAvailableBatches('item-1')
    expect(apiFetch).toHaveBeenLastCalledWith('/api/v1/batches/item/item-1/available')
    await getStockValuation()
    expect(apiFetch).toHaveBeenLastCalledWith('/api/v1/reports/stock-summary')
  })
  it('rejects invalid funding, inverted dates, and missing commercial terms', () => {
    expect(validateScheme(request)).toBeNull()
    expect(validateScheme({ ...request, companySubsidyPercent: 101 })).toMatch(/Percentages/)
    expect(validateScheme({ ...request, validTo: '2026-08-31' })).toMatch(/end date/)
    expect(validateScheme({ ...request, buyQuantity: 0 })).toMatch(/positive/)
    expect(validateScheme({ ...request, schemeType: 'SPECIAL_NET_RATE', specialNetRate: null })).toMatch(/net rate/)
    expect(validateScheme({ ...request, minOrderQuantity: NaN })).toMatch(/finite/)
  })
})
