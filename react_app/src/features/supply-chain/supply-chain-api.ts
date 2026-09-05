import { apiFetch } from '@/api/client/api-client'
type Amount = number | string
export const planningRoles = ['OWNER', 'ADMIN', 'ACCOUNTANT'] as const
export const planningReadRoles = [...planningRoles, 'OPERATOR'] as const
export type Page<T> = { content: T[]; totalPages: number; totalElements: number }
export type Requisition = { id: string; requisitionNumber: string; status: string; supplierId: string | null; warehouseId: string | null; requiredByDate: string | null; totalAmount: Amount; source: string; purchaseOrderId: string | null; notes: string | null; lines: { id: string; itemId: string; requiredQty: Amount; estimatedUnitPrice: Amount; estimatedLineTotal: Amount }[] }
export type RequisitionRequest = { supplierId?: string; warehouseId?: string; requiredByDate?: string; notes: string; lines: { itemId: string; requiredQty: number; estimatedUnitPrice: number }[] }
export type SupplyAlert = { id: string; alertType: string; severity: string; title: string; description: string | null; status: string; createdAt: string }
export type Forecast = { id: string; itemId: string; forecastMonth: string; forecastQty: Amount; actualQty: Amount | null; method: string; confidence: Amount | null }
export type ReorderPolicy = { id: string; itemId: string; itemName: string | null; warehouseId: string | null; safetyStock: Amount; reorderPoint: Amount; reorderQty: Amount; eoq: Amount; abcClass: string | null; leadTimeDays: number; lastCalculated: string | null }
export type ItemSupplier = { id: string; itemId: string; supplierId: string; leadTimeDays: number; minOrderQty: Amount; unitPrice: Amount; preferred: boolean; supplierSku: string | null }
export type ItemSupplierRequest = { itemId: string; supplierId: string; leadTimeDays: number; minOrderQty: number; unitPrice: number; preferred: boolean; supplierSku: string }
export type SupplierPerformance = { id: string; supplierId: string; supplierName: string | null; periodStart: string; periodEnd: string; totalOrders: number; totalQtyOrdered: Amount; totalQtyReceived: Amount; totalQtyRejected: Amount; totalAmount: Amount; qualityRate: Amount; overallScore: Amount }
export type SupplyReturn = { id: string; returnNumber: string; returnType: string; status: string; totalAmount: Amount; netRefund: Amount; reasonCode: string | null; reasonNotes: string | null; lines: { id: string; itemId: string; quantity: Amount; unitPrice: Amount; lineTotal: Amount; condition: string; restock: boolean }[] }
export type Shipment = { id: string; shipmentNumber: string; shipmentType: string; status: string; originWarehouseId: string | null; destinationWarehouseId: string | null; carrier: string | null; vehicleNumber: string | null; estimatedDeparture: string | null; estimatedArrival: string | null; actualDeparture: string | null; actualArrival: string | null; freightCost: Amount; notes: string | null; lines: { id: string; itemId: string; quantity: Amount; weight: Amount | null; packages: number; notes: string | null }[] }
export type ShipmentRequest = { shipmentType: string; originWarehouseId?: string; destinationWarehouseId?: string; carrier: string; vehicleNumber: string; freightCost: number; estimatedDeparture?: string; estimatedArrival?: string; notes: string; lines: { itemId: string; quantity: number; packages: number; weight?: number; notes?: string }[] }
export type InventoryTurnover = { itemId: string; itemName: string; cogs: Amount; avgInventoryValue: Amount; turnoverRatio: Amount; daysOnHand: Amount }
export type PlanningDashboard = { openAlerts: number; lowStockCount: number; abcClassification: { A: number; B: number; C: number }; totalInventoryValue: Amount; autoReorderItems: number }
const root = '/api/v1/supply-chain'
function pageParams(page: number, status: string) { return new URLSearchParams({ page: String(page), size: '25', ...(status ? { status } : {}) }) }
export const getPlanningDashboard = () => apiFetch<PlanningDashboard>(`${root}/dashboard`)
export const getInventoryTurnover = (months: number) => apiFetch<InventoryTurnover[]>(`${root}/analytics/turnover?${new URLSearchParams({ months: String(months) })}`)
export const listRequisitions = (page = 0, status = '') => apiFetch<Page<Requisition>>(`${root}/requisitions?${pageParams(page, status)}`)
export const getRequisition = (id: string) => apiFetch<Requisition>(`${root}/requisitions/${encodeURIComponent(id)}`)
export const createRequisition = (body: RequisitionRequest) => apiFetch<Requisition>(`${root}/requisitions`, { method: 'POST', body })
export const autoRequisition = async () => (await apiFetch<Requisition | null>(`${root}/requisitions/auto`, { method: 'POST' })) ?? null
export const requisitionAction = (id: string, action: 'submit' | 'approve' | 'reject') => apiFetch<Requisition>(`${root}/requisitions/${encodeURIComponent(id)}/${action}`, { method: 'POST' })
export const listSupplyAlerts = (page = 0, status = '') => apiFetch<Page<SupplyAlert>>(`${root}/alerts?${pageParams(page, status)}`)
export const resolveSupplyAlert = (id: string) => apiFetch<SupplyAlert>(`${root}/alerts/${encodeURIComponent(id)}/resolve`, { method: 'POST' })
export const scanSupplyAlerts = () => apiFetch<SupplyAlert[]>(`${root}/alerts/scan`, { method: 'POST' })
export const listForecasts = (from: string, to: string) => apiFetch<Forecast[]>(`${root}/forecasts?${new URLSearchParams({ from, to })}`)
export const generateForecast = (method: 'generate' | 'generate-seasonal' | 'generate-weighted', monthsAhead: number, historyMonths: number) => apiFetch<Forecast[]>(`${root}/forecasts/${method}?${new URLSearchParams({ monthsAhead: String(monthsAhead), ...(method === 'generate-seasonal' ? {} : { historyMonths: String(historyMonths) }) })}`, { method: 'POST' })
export const listReorderPolicies = () => apiFetch<ReorderPolicy[]>(`${root}/reorder-policies`)
export const classifyAbc = () => apiFetch<ReorderPolicy[]>(`${root}/abc/run`, { method: 'POST' })
export const calculateReorder = (itemId: string, warehouseId?: string) => apiFetch<ReorderPolicy>(`${root}/reorder-params/${encodeURIComponent(itemId)}${warehouseId ? `?${new URLSearchParams({ warehouseId })}` : ''}`, { method: 'POST' })
export const listItemSuppliers = (itemId: string) => apiFetch<ItemSupplier[]>(`${root}/item-suppliers/by-item/${encodeURIComponent(itemId)}`)
export const addItemSupplier = (body: ItemSupplierRequest) => apiFetch<ItemSupplier>(`${root}/item-suppliers`, { method: 'POST', body })
export const setPreferredSupplier = (itemId: string, supplierId: string) => apiFetch<ItemSupplier>(`${root}/item-suppliers/${encodeURIComponent(itemId)}/preferred/${encodeURIComponent(supplierId)}`, { method: 'POST' })
export const removeItemSupplier = (id: string) => apiFetch<void>(`${root}/item-suppliers/${encodeURIComponent(id)}`, { method: 'DELETE' })
export const listSupplierRankings = () => apiFetch<SupplierPerformance[]>(`${root}/supplier-rankings`)
export const listSupplyReturns = (page = 0, status = '') => apiFetch<Page<SupplyReturn>>(`${root}/returns?${pageParams(page, status)}`)
export const listShipments = () => apiFetch<Shipment[]>(`${root}/shipments`)
export const getShipment = (id: string) => apiFetch<Shipment>(`${root}/shipments/${encodeURIComponent(id)}`)
export const createShipment = (body: ShipmentRequest) => apiFetch<Shipment>(`${root}/shipments`, { method: 'POST', body })
export const shipmentAction = (id: string, action: 'dispatch' | 'deliver' | 'cancel') => apiFetch<Shipment>(`${root}/shipments/${encodeURIComponent(id)}/${action}`, { method: 'POST' })
