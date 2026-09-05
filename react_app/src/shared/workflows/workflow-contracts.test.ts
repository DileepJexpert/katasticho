import { afterEach, beforeEach, expect, it, vi } from 'vitest'
import * as network from '@/features/partner-network/partner-network-api'
import * as supply from '@/features/supply-chain/supply-chain-api'
import * as portal from '@/features/portal-admin/portal-admin-api'
import { clearSessionToken, setSessionToken } from '@/api/client/session-token'

const fetchMock = vi.fn<typeof fetch>()
beforeEach(() => {
  vi.stubGlobal('fetch', fetchMock)
  fetchMock.mockReset()
  setSessionToken('test-access-token', 'org-1')
  reply({})
})
afterEach(() => { clearSessionToken(); vi.unstubAllGlobals() })
function reply(data: unknown) { fetchMock.mockImplementation(async () => new Response(JSON.stringify({ success: true, data }), { headers: { 'Content-Type': 'application/json' } })) }
function request() {
  const [path, init] = fetchMock.mock.calls.at(-1)!
  return { path, method: init?.method ?? 'GET', body: init?.body ? JSON.parse(String(init.body)) : undefined, headers: new Headers(init?.headers) }
}

it.each([
  [network.listPartners, '/api/v1/partner-network/partners'],
  [network.listCatalog, '/api/v1/partner-network/catalog'],
  [() => network.listNetworkOrders('incoming'), '/api/v1/partner-network/orders/incoming'],
  [() => network.listNetworkOrders('outgoing'), '/api/v1/partner-network/orders/outgoing'],
  [() => network.getNetworkOrder('order/1'), '/api/v1/partner-network/orders/order%2F1'],
  [() => network.getNetworkEvents('order/1'), '/api/v1/partner-network/orders/order%2F1/events'],
  [supply.getPlanningDashboard, '/api/v1/supply-chain/dashboard'],
  [supply.listReorderPolicies, '/api/v1/supply-chain/reorder-policies'],
  [supply.listSupplierRankings, '/api/v1/supply-chain/supplier-rankings'],
  [supply.listShipments, '/api/v1/supply-chain/shipments'],
  [() => supply.getShipment('shipment/1'), '/api/v1/supply-chain/shipments/shipment%2F1'],
  [() => supply.getRequisition('req/1'), '/api/v1/supply-chain/requisitions/req%2F1'],
  [() => supply.listItemSuppliers('item/1'), '/api/v1/supply-chain/item-suppliers/by-item/item%2F1'],
  [portal.listPortalAccounts, '/api/v1/portal-users'],
] as const)('reads the existing endpoint %s at %s with tenant context', async (run, path) => {
  await run()
  expect(request()).toMatchObject({ path, method: 'GET', body: undefined })
  expect(request().headers.get('X-Org-Id')).toBe('org-1')
})

it.each([supply.listRequisitions, supply.listSupplyAlerts, supply.listSupplyReturns])('passes real server page and status parameters', async (run) => {
  await run(2, 'APPROVED')
  const url = new URL(String(request().path), 'http://localhost')
  expect(Object.fromEntries(url.searchParams)).toEqual({ page: '2', size: '25', status: 'APPROVED' })
  await run()
  expect(String(request().path)).not.toContain('status=')
})

it('encodes supplier search without inventing a pagination contract', async () => {
  await network.searchSupplierCatalog('Tea & coffee')
  expect(request().path).toBe('/api/v1/partner-network/supplier-search?search=Tea+%26+coffee')
})

it('preserves all published metadata with a single JSON encoding', async () => {
  const body: network.CatalogRequest = { itemId: 'item-1', drugMasterId: 'drug-1', displayName: 'Tea', publishedSku: 'TEA', hsnCode: '0902', manufacturer: 'Grower', packSize: '100g', category: 'Beverages', description: 'Preserve', publishedMrp: 50, publishedPtr: 40, minOrderQty: 12, availabilityStatus: 'LIMITED' }
  await network.publishCatalogItem(body)
  expect(request()).toMatchObject({ path: '/api/v1/partner-network/catalog', method: 'POST', body })
})

it.each(['approve', 'reject', 'suspend'] as const)('uses partner %s action without a fictional payload', async (action) => {
  await network.partnerAction('partner/1', action)
  expect(request()).toMatchObject({ path: `/api/v1/partner-network/partners/partner%2F1/${action}`, method: 'POST', body: undefined })
})

it('unpublishes the catalog record rather than deleting the item', async () => {
  await network.unpublishCatalogItem('catalog/1')
  expect(request()).toMatchObject({ path: '/api/v1/partner-network/catalog/catalog%2F1/unpublish', method: 'POST' })
})

it.each(['cancel', 'reject', 'dispatch', 'deliver'] as const)('uses network %s tracking contract', async (action) => {
  await network.networkOrderAction('order-1', action, 'Cannot fulfil')
  expect(request()).toMatchObject({ path: `/api/v1/partner-network/orders/order-1/${action}`, method: 'POST', body: action === 'reject' ? { reason: 'Cannot fulfil' } : undefined })
})

it('creates requisitions with exact line fields and preserves a null automatic result', async () => {
  const body = { notes: 'Restock', lines: [{ itemId: 'item-1', requiredQty: 2.5, estimatedUnitPrice: 30 }] }
  await supply.createRequisition(body)
  expect(request()).toMatchObject({ path: '/api/v1/supply-chain/requisitions', method: 'POST', body })
  reply(null)
  expect(await supply.autoRequisition()).toBeNull()
})

it.each(['submit', 'approve', 'reject'] as const)('uses requisition %s contract', async (action) => {
  await supply.requisitionAction('req-1', action)
  expect(request()).toMatchObject({ path: `/api/v1/supply-chain/requisitions/req-1/${action}`, method: 'POST' })
})

it('uses persisted forecast date filters and method-specific generation parameters', async () => {
  await supply.listForecasts('2026-09-01', '2026-12-31')
  expect(request().path).toBe('/api/v1/supply-chain/forecasts?from=2026-09-01&to=2026-12-31')
  for (const method of ['generate', 'generate-seasonal', 'generate-weighted'] as const) {
    await supply.generateForecast(method, 3, 6)
    expect(request().path).toBe(`/api/v1/supply-chain/forecasts/${method}?monthsAhead=3${method === 'generate-seasonal' ? '' : '&historyMonths=6'}`)
    expect(request().method).toBe('POST')
  }
})

it('keeps reorder calculations separate from purchase mutations', async () => {
  await supply.classifyAbc()
  expect(request().path).toBe('/api/v1/supply-chain/abc/run')
  await supply.calculateReorder('item/1', 'warehouse/1')
  expect(request().path).toBe('/api/v1/supply-chain/reorder-params/item%2F1?warehouseId=warehouse%2F1')
  await supply.calculateReorder('item-1')
  expect(request().path).toBe('/api/v1/supply-chain/reorder-params/item-1')
})

it('uses supplier IDs rather than contact IDs in item mapping payloads', async () => {
  const body = { itemId: 'item-1', supplierId: 'supplier-1', leadTimeDays: 7, minOrderQty: 10, unitPrice: 30, preferred: true, supplierSku: 'SUP-TEA' }
  await supply.addItemSupplier(body)
  expect(request().body).toEqual(body)
  await supply.setPreferredSupplier('item-1', 'supplier-1')
  expect(request()).toMatchObject({ path: '/api/v1/supply-chain/item-suppliers/item-1/preferred/supplier-1', method: 'POST' })
  await supply.removeItemSupplier('map-1')
  expect(request()).toMatchObject({ path: '/api/v1/supply-chain/item-suppliers/map-1', method: 'DELETE' })
})

it('scans and resolves supply alerts through their actual action endpoints', async () => {
  await supply.scanSupplyAlerts()
  expect(request().path).toBe('/api/v1/supply-chain/alerts/scan')
  await supply.resolveSupplyAlert('alert-1')
  expect(request()).toMatchObject({ path: '/api/v1/supply-chain/alerts/alert-1/resolve', method: 'POST' })
})

it('creates tracking records with shipment line fields', async () => {
  const body = { shipmentType: 'TRANSFER', originWarehouseId: 'from', destinationWarehouseId: 'to', carrier: 'Carrier', vehicleNumber: 'UP43A1234', freightCost: 100, notes: '', lines: [{ itemId: 'item-1', quantity: 2, packages: 1 }] }
  await supply.createShipment(body)
  expect(request()).toMatchObject({ path: '/api/v1/supply-chain/shipments', method: 'POST', body })
})

it.each(['dispatch', 'deliver', 'cancel'] as const)('uses shipment %s tracking action', async (action) => {
  await supply.shipmentAction('shipment-1', action)
  expect(request()).toMatchObject({ path: `/api/v1/supply-chain/shipments/shipment-1/${action}`, method: 'POST' })
})

it('invites a contact through portal-user administration, not employee login', async () => {
  const body = { contactId: 'contact-1', email: 'contact@example.test', fullName: 'Contact' }
  await portal.invitePortalAccount(body)
  expect(request()).toMatchObject({ path: '/api/v1/portal-users', method: 'POST', body })
  await portal.resendPortalInvite('portal/1')
  expect(request()).toMatchObject({ path: '/api/v1/portal-users/portal%2F1/resend-invite', method: 'POST' })
})

it.each(['suspend', 'reactivate', 'delete'] as const)('uses the portal %s contract', async (action) => {
  await portal.portalAccountAction('portal-1', action)
  expect(request()).toMatchObject({ path: `/api/v1/portal-users/portal-1${action === 'delete' ? '' : `/${action}`}`, method: action === 'delete' ? 'DELETE' : 'POST' })
})

it('surfaces server rejection without returning a fabricated success', async () => {
  fetchMock.mockResolvedValue(new Response(JSON.stringify({ success: false, message: 'No active partnership', errorCode: 'PARTNER_INACTIVE' }), { status: 400, headers: { 'Content-Type': 'application/json' } }))
  await expect(network.networkOrderAction('order-1', 'dispatch')).rejects.toThrow('No active partnership')
})
