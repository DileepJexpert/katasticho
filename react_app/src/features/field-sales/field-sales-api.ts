import { apiFetch } from '@/api/client/api-client'

export type Beat = {
  id: string
  code: string
  name: string
  area: string | null
  city: string | null
  state: string | null
  description: string | null
  isActive: boolean
  createdAt?: string
}

export type SalesBeat = Beat
export type SalesRoute = RouteSummary
export type SalesVan = Van

export type BeatCustomer = {
  id: string
  beatId: string
  contactId: string
  contactName: string
  companyName: string | null
  phone: string | null
  visitSequence: number | null
  visitFrequency: string | null
  active: boolean
}

export type RouteSummary = {
  id: string
  code: string
  name: string
  dayOfWeek: string | null
  frequency: string | null
  warehouseId: string | null
  warehouseName?: string | null
  estimatedDistanceKm: number | string | null
  estimatedDurationMinutes: number | null
  active: boolean
  beatCount: number
}

export type Route = {
  id: string
  code: string
  name: string
  dayOfWeek: string | null
  frequency: string | null
  warehouseId: string | null
  warehouseName?: string | null
  estimatedDistanceKm: number | string | null
  estimatedDurationMinutes: number | null
  active: boolean
  beatCount?: number
  createdAt?: string
}

export type RouteBeat = {
  id: string
  routeId: string
  beatId: string
  beatCode?: string
  beatName?: string
  sequence: number
}

export type Van = {
  id: string
  code: string
  vehicleNumber: string
  plateNumber?: string
  name: string | null
  vehicleType: string | null
  sourceWarehouseId: string | null
  sourceWarehouseName?: string | null
  capacityWeightKg: number | string | null
  capacityVolumeLitre: number | string | null
  isActive: boolean
  createdAt?: string
}

export type VanStockBalance = {
  id: string
  vanId: string
  itemId: string
  itemName?: string | null
  itemCode?: string | null
  batchId: string | null
  batchNumber?: string | null
  quantityOnHand: number | string
  averageCost: number | string | null
  lastMovementAt: string | null
}

export type VanStockTransfer = {
  id: string
  vanId: string
  warehouseId: string
  routeExecutionId?: string | null
  transferType: 'LOAD' | 'RETURN' | string
  status: 'DRAFT' | 'CONFIRMED' | 'CANCELLED' | string
  totalItems?: number
  totalQuantity?: number | string
  createdAt?: string
  confirmedAt?: string | null
}

export type VanStockTransferLine = {
  id: string
  transferId: string
  itemId: string
  itemName?: string
  batchId?: string | null
  batchNumber?: string | null
  quantity: number | string
  unitCost?: number | string | null
}

export type FieldSalesAssignment = {
  id: string
  salespersonId: string
  salespersonName?: string
  routeId?: string | null
  routeName?: string | null
  beatId?: string | null
  beatName?: string | null
  vanId?: string | null
  vanCode?: string | null
  vanPlateNumber?: string | null
  territory?: string | null
  effectiveFrom: string
  effectiveTo?: string | null
  startDate?: string
  endDate?: string | null
  isActive: boolean
  active?: boolean
}

export type RouteExecution = {
  id: string
  executionNumber?: string
  routeId: string
  routeName?: string
  salespersonId: string
  salespersonName?: string
  vanId?: string | null
  vanCode?: string | null
  executionDate: string
  status: 'SCHEDULED' | 'IN_PROGRESS' | 'COMPLETED' | 'CANCELLED' | string
  startedAt?: string | null
  completedAt?: string | null
  totalVisits?: number
  plannedVisits?: number
  completedVisits?: number
  totalOrdersCount?: number
  totalOrderValue?: number | string
  totalOrdersValue?: number | string
  totalCollections?: number | string
  overrideReason?: string | null
  notes?: string | null
}

export type FieldVisit = {
  id: string
  routeExecutionId: string
  contactId: string
  contactName?: string
  visitSequence?: number
  sequenceNumber?: number
  status: 'PENDING' | 'CHECKED_IN' | 'COMPLETED' | 'SKIPPED' | string
  checkInTime?: string | null
  checkOutTime?: string | null
  latitude?: number | string | null
  longitude?: number | string | null
  salesOrderId?: string | null
  orderValue?: number | string | null
  collectionAmount?: number | string | null
  notes?: string | null
  skipReason?: string | null
  customerReceiptId?: string | null
  geoVerified?: boolean | null
  geoDistanceM?: number | string | null
}

export type DayClose = {
  id: string
  routeExecutionId: string
  salespersonId?: string
  salespersonName?: string
  date?: string
  openingCash?: number | string
  closingCash?: number | string | null
  cashDeposited?: number | string | null
  totalCollections?: number | string
  totalExpenses?: number | string
  cashCollections?: number | string
  cashExpenses?: number | string
  cashVariance?: number | string
  closeDate?: string
  status: 'DRAFT' | 'SUBMITTED' | 'APPROVED' | 'REJECTED' | string
  notes?: string | null
  rejectionReason?: string | null
  submittedAt?: string | null
  approvedAt?: string | null
}

export type SalesmanTarget = {
  id: string
  salespersonId: string
  salespersonName?: string
  periodType: 'MONTHLY' | 'QUARTERLY' | 'ANNUAL' | string
  targetPeriod?: string
  periodStart: string
  periodEnd: string
  targetType: 'REVENUE' | 'VISITS' | 'NEW_ACCOUNTS' | string
  metricType?: string
  targetValue: number | string
  achievedValue: number | string
  incentiveRate?: number | string
  status?: string
}

export type StoreMerchandisingAudit = {
  id: string
  storeId?: string
  contactId: string
  contactName?: string
  fieldVisitId?: string | null
  routeExecutionId?: string | null
  auditDate: string
  auditType: 'PLANOGRAM' | 'SHELF_SPACE' | 'COMPETITOR_PRICING' | 'DISPLAY_STAND' | string
  planogramCompliancePercent?: number | string | null
  shareOfShelfPercent?: number | string | null
  photoUrl?: string | null
  competitorPriceCapture?: Record<string, unknown> | null
  remarks?: string | null
  createdAt?: string
}

export type TourPlan = {
  id: string
  salespersonId: string
  salespersonName?: string
  planMonth: string
  status: 'DRAFT' | 'SUBMITTED' | 'APPROVED' | 'REJECTED' | string
  notes?: string | null
  rejectionReason?: string | null
  createdAt?: string
  entries?: TourPlanEntry[]
}

export type TourPlanEntry = {
  id: string
  tourPlanId: string
  planDate: string
  activityType: 'FIELD_VISIT' | 'JOINT_FIELD_WORK' | 'HQ_DAY' | 'CONFERENCE' | 'LEAVE' | string
  beatId?: string | null
  beatName?: string | null
  area?: string | null
  notes?: string | null
}

export type DcrReport = {
  id: string
  salespersonId: string
  salespersonName?: string
  reportDate: string
  workType: 'FIELD_WORK' | 'NON_FIELD' | 'LEAVE' | 'MEETING' | string
  beatId?: string | null
  beatName?: string | null
  status: 'DRAFT' | 'SUBMITTED' | 'APPROVED' | 'REJECTED' | string
  totalCalls?: number
  totalDoctorCalls?: number
  totalChemistCalls?: number
  totalPobValue?: number | string
  notes?: string | null
  rejectionReason?: string | null
  createdAt?: string
}

export type DcrDoctorCall = {
  id: string
  dcrId: string
  doctorId: string
  doctorName?: string
  specialty?: string | null
  callType?: string
  productsDetailed?: string[]
  samplesGiven?: Array<{ itemId?: string; productName: string; quantity: number }>
  pobAmount?: number | string | null
  nextFollowUpDate?: string | null
  remarks?: string | null
}

export type DetailAid = {
  id: string
  name: string
  productName: string
  specialtyTarget?: string | null
  slideCount: number
  slides?: Array<{ slideNumber: number; title: string; imageUrl?: string; notes?: string }>
  active: boolean
  createdAt?: string
}

export type FieldSampleTxn = {
  id: string
  salespersonId: string
  salespersonName?: string
  itemId?: string | null
  productName: string
  quantity: number
  txnType: 'ISSUE' | 'RETURN' | 'DISTRIBUTION' | string
  date: string
  notes?: string | null
}

export type RcpaAudit = {
  id: string
  chemistContactId: string
  chemistName?: string
  auditDate: string
  fieldVisitId?: string | null
  remarks?: string | null
  salespersonName?: string
  createdAt?: string
  lines?: RcpaLine[]
}

export type RcpaLine = {
  id: string
  auditId: string
  productName: string
  brandType: 'OWN' | 'COMPETITOR' | string
  competitorName?: string | null
  ourItemId?: string | null
  quantity?: number | string | null
  value?: number | string | null
}

export type StockistSalesStatement = {
  id: string
  stockistContactId: string
  stockistName?: string
  periodMonth: string
  status: 'DRAFT' | 'SUBMITTED' | 'VERIFIED' | string
  notes?: string | null
  submittedAt?: string | null
  createdAt?: string
  lines?: StockistSalesLine[]
}

export type StockistSalesLine = {
  id: string
  statementId: string
  itemId?: string | null
  productName: string
  openingQty?: number | string | null
  purchaseQty?: number | string | null
  salesQty?: number | string | null
  returnQty?: number | string | null
  salesValue?: number | string | null
}

export type PageResponse<T> = {
  content: T[]
  page: number
  size: number
  totalElements: number
  totalPages: number
  last: boolean
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// BEATS & CUSTOMERS API
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

export async function listBeats(page = 0, size = 25) {
  return apiFetch<PageResponse<Beat>>(`/api/v1/field-sales/beats?page=${page}&size=${size}`)
}

export async function getBeat(id: string) {
  return apiFetch<Beat>(`/api/v1/field-sales/beats/${id}`)
}

export async function createBeat(data: {
  code: string
  name: string
  area?: string | null
  city?: string | null
  state?: string | null
  description?: string | null
  customers?: Array<{ contactId: string; visitSequence?: number; visitFrequency?: string }>
}) {
  return apiFetch<Beat>('/api/v1/field-sales/beats', { method: 'POST', body: JSON.stringify(data) })
}

export async function updateBeat(id: string, data: {
  code: string
  name: string
  area?: string | null
  city?: string | null
  state?: string | null
  description?: string | null
  customers?: Array<{ contactId: string; visitSequence?: number; visitFrequency?: string }>
}) {
  return apiFetch<Beat>(`/api/v1/field-sales/beats/${id}`, { method: 'PUT', body: JSON.stringify(data) })
}

export async function deleteBeat(id: string) {
  return apiFetch<void>(`/api/v1/field-sales/beats/${id}`, { method: 'DELETE' })
}

export async function getBeatCustomers(beatId: string) {
  return apiFetch<BeatCustomer[]>(`/api/v1/field-sales/beats/${beatId}/customers`)
}

export async function addCustomerToBeat(beatId: string, data: {
  contactId: string
  visitSequence?: number
  visitFrequency?: string
}) {
  return apiFetch<BeatCustomer>(`/api/v1/field-sales/beats/${beatId}/customers`, {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

export async function removeCustomerFromBeat(beatId: string, contactId: string) {
  return apiFetch<void>(`/api/v1/field-sales/beats/${beatId}/customers/${contactId}`, {
    method: 'DELETE',
  })
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// ROUTES & ROUTE BEATS API
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

export async function listRoutes(page = 0, size = 25) {
  return apiFetch<PageResponse<RouteSummary>>(`/api/v1/field-sales/routes?page=${page}&size=${size}`)
}

export async function getRoute(id: string) {
  return apiFetch<Route>(`/api/v1/field-sales/routes/${id}`)
}

export async function createRoute(data: {
  code: string
  name: string
  dayOfWeek?: string | null
  frequency?: string | null
  warehouseId?: string | null
  beatIds?: string[]
}) {
  return apiFetch<Route>('/api/v1/field-sales/routes', { method: 'POST', body: JSON.stringify(data) })
}

export async function updateRoute(id: string, data: {
  code: string
  name: string
  dayOfWeek?: string | null
  frequency?: string | null
  warehouseId?: string | null
  beatIds?: string[]
}) {
  return apiFetch<Route>(`/api/v1/field-sales/routes/${id}`, { method: 'PUT', body: JSON.stringify(data) })
}

export async function deleteRoute(id: string) {
  return apiFetch<void>(`/api/v1/field-sales/routes/${id}`, { method: 'DELETE' })
}

export async function getRouteBeats(routeId: string) {
  return apiFetch<RouteBeat[]>(`/api/v1/field-sales/routes/${routeId}/beats`)
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// VANS & VAN TRANSFERS API
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

export async function listVans(page = 0, size = 25) {
  return apiFetch<PageResponse<Van>>(`/api/v1/field-sales/vans?page=${page}&size=${size}`)
}

export async function getVan(id: string) {
  return apiFetch<Van>(`/api/v1/field-sales/vans/${id}`)
}

export async function createVan(data: {
  code: string
  vehicleNumber: string
  name?: string | null
  vehicleType?: string | null
  sourceWarehouseId?: string | null
  capacityWeightKg?: number | string | null
  capacityVolumeLitre?: number | string | null
}) {
  return apiFetch<Van>('/api/v1/field-sales/vans', { method: 'POST', body: JSON.stringify(data) })
}

export async function updateVan(id: string, data: {
  code: string
  vehicleNumber: string
  name?: string | null
  vehicleType?: string | null
  sourceWarehouseId?: string | null
  capacityWeightKg?: number | string | null
  capacityVolumeLitre?: number | string | null
}) {
  return apiFetch<Van>(`/api/v1/field-sales/vans/${id}`, { method: 'PUT', body: JSON.stringify(data) })
}

export async function deleteVan(id: string) {
  return apiFetch<void>(`/api/v1/field-sales/vans/${id}`, { method: 'DELETE' })
}

export async function getVanStock(vanId: string) {
  return apiFetch<VanStockBalance[]>(`/api/v1/field-sales/vans/${vanId}/stock`)
}

export async function listVanTransfers(vanId: string) {
  return apiFetch<VanStockTransfer[]>(`/api/v1/field-sales/van-transfers/van/${vanId}`)
}

export async function getTransferLines(transferId: string) {
  return apiFetch<VanStockTransferLine[]>(`/api/v1/field-sales/van-transfers/${transferId}/lines`)
}

export async function createVanLoad(data: {
  vanId: string
  warehouseId: string
  lines: Array<{ itemId: string; batchId?: string | null; quantity: number }>
}) {
  return apiFetch<VanStockTransfer>('/api/v1/field-sales/van-transfers/load', {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

export async function confirmVanLoad(transferId: string) {
  return apiFetch<VanStockTransfer>(`/api/v1/field-sales/van-transfers/${transferId}/confirm-load`, {
    method: 'POST',
  })
}

export async function createVanReturn(data: {
  vanId: string
  warehouseId: string
  routeExecutionId?: string | null
  lines: Array<{ itemId: string; batchId?: string | null; quantity: number }>
}) {
  return apiFetch<VanStockTransfer>('/api/v1/field-sales/van-transfers/return', {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

export async function confirmVanReturn(transferId: string) {
  return apiFetch<VanStockTransfer>(`/api/v1/field-sales/van-transfers/${transferId}/confirm-return`, {
    method: 'POST',
  })
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// ASSIGNMENTS API
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

export async function listAssignments(includeInactive = false) {
  return apiFetch<FieldSalesAssignment[]>(`/api/v1/field-sales/assignments?includeInactive=${includeInactive}`)
}

export const getMyAssignments = (effectiveOn: string) => apiFetch<FieldSalesAssignment[]>(`/api/v1/field-sales/assignments/me?${new URLSearchParams({ effectiveOn })}`)

export async function createAssignment(data: {
  salespersonId: string
  routeId?: string | null
  beatId?: string | null
  vanId?: string | null
  territory?: string | null
  effectiveFrom?: string
  effectiveTo?: string | null
  startDate?: string
  endDate?: string | null
}) {
  const payload = {
    ...data,
    effectiveFrom: data.effectiveFrom || data.startDate || new Date().toISOString().slice(0, 10),
    effectiveTo: data.effectiveTo !== undefined ? data.effectiveTo : data.endDate,
  }
  return apiFetch<FieldSalesAssignment>('/api/v1/field-sales/assignments', {
    method: 'POST',
    body: JSON.stringify(payload),
  })
}

export const createFieldSalesAssignment = createAssignment
export const updateFieldAssignment = (id: string, body: { salespersonId: string; routeId: string; vanId?: string | null; territory: string; effectiveFrom: string; effectiveTo: string | null }) => apiFetch<FieldSalesAssignment>(`/api/v1/field-sales/assignments/${encodeURIComponent(id)}`, { method: 'PUT', body })

export async function endAssignment(id: string, endDate?: string) {
  return apiFetch<FieldSalesAssignment>(`/api/v1/field-sales/assignments/${id}/end`, {
    method: 'POST',
    body: JSON.stringify({ endDate: endDate || new Date().toISOString().slice(0, 10) }),
  })
}

export async function deleteAssignment(id: string) {
  return apiFetch<void>(`/api/v1/field-sales/assignments/${id}`, { method: 'DELETE' })
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// ROUTE EXECUTIONS & VISITS API
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

export async function listExecutions(page = 0, size = 25) {
  return apiFetch<PageResponse<RouteExecution>>(`/api/v1/field-sales/executions?page=${page}&size=${size}`)
}

export async function getExecution(id: string) {
  return apiFetch<RouteExecution>(`/api/v1/field-sales/executions/${id}`)
}

export async function getMyTodayExecutions() {
  return apiFetch<RouteExecution[]>('/api/v1/field-sales/executions/me/today')
}

export async function startExecution(data: {
  routeId: string
  salespersonId: string
  vanId?: string | null
  executionDate: string
  overrideReason?: string | null
}) {
  return apiFetch<RouteExecution>('/api/v1/field-sales/executions', {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

export async function startRoute(id: string) {
  return apiFetch<RouteExecution>(`/api/v1/field-sales/executions/${id}/start`, { method: 'POST' })
}

export async function completeRoute(id: string) {
  return apiFetch<RouteExecution>(`/api/v1/field-sales/executions/${id}/complete`, { method: 'POST' })
}

export async function getExecutionVisits(executionId: string) {
  return apiFetch<FieldVisit[]>(`/api/v1/field-sales/executions/${executionId}/visits`)
}

export async function checkInVisit(visitId: string, latitude: number, longitude: number) {
  return apiFetch<FieldVisit>(`/api/v1/field-sales/visits/${visitId}/check-in`, {
    method: 'POST',
    body: JSON.stringify({ latitude, longitude }),
  })
}

export async function checkOutVisit(visitId: string, notes: string | undefined, latitude: number, longitude: number) {
  return apiFetch<FieldVisit>(`/api/v1/field-sales/visits/${visitId}/check-out`, {
    method: 'POST',
    body: JSON.stringify({ notes, latitude, longitude }),
  })
}

export async function skipVisit(visitId: string, skipReason: string) {
  return apiFetch<FieldVisit>(`/api/v1/field-sales/visits/${visitId}/skip`, {
    method: 'POST',
    body: JSON.stringify({ skipReason }),
  })
}

export async function recordVisitOrder(visitId: string, salesOrderId?: string | null, orderValue = 0) {
  return apiFetch<FieldVisit>(`/api/v1/field-sales/visits/${visitId}/record-order`, {
    method: 'POST',
    body: JSON.stringify({ salesOrderId, orderValue }),
  })
}

export async function recordVisitCollection(visitId: string, collectionAmount: number, paymentMethod = 'CASH', referenceNumber?: string) {
  return apiFetch<Record<string, unknown>>(`/api/v1/field-sales/visits/${visitId}/record-collection`, {
    method: 'POST',
    body: JSON.stringify({ collectionAmount, paymentMethod, referenceNumber }),
  })
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// DAY CLOSE & TARGETS API
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

export async function initiateDayClose(routeExecutionId: string, openingCash = 0) {
  return apiFetch<DayClose>(`/api/v1/field-sales/day-close/initiate/${routeExecutionId}`, {
    method: 'POST',
    body: JSON.stringify({ openingCash }),
  })
}

export async function getDayClose(id: string) {
  return apiFetch<DayClose>(`/api/v1/field-sales/day-close/${id}`)
}

export async function submitDayClose(id: string, data: {
  closingCash?: number
  cashDeposited?: number
  notes?: string
}) {
  return apiFetch<DayClose>(`/api/v1/field-sales/day-close/${id}/submit`, {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

export async function approveDayClose(id: string) {
  return apiFetch<DayClose>(`/api/v1/field-sales/day-close/${id}/approve`, { method: 'POST' })
}

export async function rejectDayClose(id: string, reason: string) {
  return apiFetch<DayClose>(`/api/v1/field-sales/day-close/${id}/reject`, {
    method: 'POST',
    body: JSON.stringify({ reason }),
  })
}

export async function listSalesmanTargets(page = 0, size = 25) {
  return apiFetch<PageResponse<SalesmanTarget>>(`/api/v1/field-sales/targets?page=${page}&size=${size}`)
}

export async function createSalesmanTarget(data: {
  salespersonId: string
  periodType: string
  periodStart: string
  periodEnd: string
  targetType: string
  targetValue: number
  incentiveRate?: number
}) {
  return apiFetch<SalesmanTarget>('/api/v1/field-sales/targets', {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

export async function updateTargetAchievement(id: string, achievedValue: number) {
  return apiFetch<SalesmanTarget>(`/api/v1/field-sales/targets/${id}/achievement`, {
    method: 'PUT',
    body: JSON.stringify({ achievedValue }),
  })
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// STORE MERCHANDISING API
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

export async function listRecentMerchandisingAudits() {
  return apiFetch<StoreMerchandisingAudit[]>('/api/v1/field-sales/merchandising/recent')
}

export async function recordMerchandisingAudit(data: {
  contactId: string
  fieldVisitId?: string | null
  routeExecutionId?: string | null
  auditDate: string
  auditType: string
  planogramCompliancePercent?: number
  shareOfShelfPercent?: number
  photoUrl?: string
  competitorPriceCapture?: Record<string, unknown>
  remarks?: string
}) {
  return apiFetch<StoreMerchandisingAudit>('/api/v1/field-sales/merchandising', {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// MR REPORTING: TOUR PLANS, DCR, VISUAL AIDS, RCPA, SSS API
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

export async function listMyTourPlans() {
  return apiFetch<TourPlan[]>('/api/v1/mr/tour-plans/me')
}

export async function listPendingTourPlans() {
  return apiFetch<TourPlan[]>('/api/v1/mr/tour-plans/pending')
}

export async function getTourPlan(id: string) {
  return apiFetch<TourPlan>(`/api/v1/mr/tour-plans/${id}`)
}

export async function createTourPlan(planMonth: string, notes?: string) {
  return apiFetch<TourPlan>('/api/v1/mr/tour-plans', {
    method: 'POST',
    body: JSON.stringify({ planMonth, notes }),
  })
}

export async function addTourPlanEntry(planId: string, data: {
  planDate: string
  activityType: string
  beatId?: string | null
  area?: string
  notes?: string
}) {
  return apiFetch<TourPlanEntry>(`/api/v1/mr/tour-plans/${planId}/entries`, {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

export async function removeTourPlanEntry(entryId: string) {
  return apiFetch<void>(`/api/v1/mr/tour-plans/entries/${entryId}`, { method: 'DELETE' })
}

export async function submitTourPlan(planId: string) {
  return apiFetch<TourPlan>(`/api/v1/mr/tour-plans/${planId}/submit`, { method: 'POST' })
}

export async function approveTourPlan(planId: string) {
  return apiFetch<TourPlan>(`/api/v1/mr/tour-plans/${planId}/approve`, { method: 'POST' })
}

export async function rejectTourPlan(planId: string, reason: string) {
  return apiFetch<TourPlan>(`/api/v1/mr/tour-plans/${planId}/reject`, {
    method: 'POST',
    body: JSON.stringify({ reason }),
  })
}

// DCR Endpoints
export async function listMyDcrs() {
  return apiFetch<DcrReport[]>('/api/v1/mr/dcr/me')
}

export async function getDcr(id: string) {
  return apiFetch<DcrReport>(`/api/v1/mr/dcr/${id}`)
}

export async function createDcr(data: {
  reportDate: string
  workType: string
  beatId?: string | null
  notes?: string
}) {
  return apiFetch<DcrReport>('/api/v1/mr/dcr', {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

export async function addDcrDoctorCall(dcrId: string, data: {
  doctorId: string
  doctorName?: string
  specialty?: string
  productsDetailed?: string[]
  samplesGiven?: Array<{ itemId?: string; productName: string; quantity: number }>
  pobAmount?: number
  nextFollowUpDate?: string
  remarks?: string
}) {
  return apiFetch<DcrDoctorCall>(`/api/v1/mr/dcr/${dcrId}/doctor-calls`, {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

export async function submitDcr(dcrId: string) {
  return apiFetch<DcrReport>(`/api/v1/mr/dcr/${dcrId}/submit`, { method: 'POST' })
}

export async function approveDcr(dcrId: string) {
  return apiFetch<DcrReport>(`/api/v1/mr/dcr/${dcrId}/approve`, { method: 'POST' })
}

export async function rejectDcr(dcrId: string, reason: string) {
  return apiFetch<DcrReport>(`/api/v1/mr/dcr/${dcrId}/reject`, {
    method: 'POST',
    body: JSON.stringify({ reason }),
  })
}

// Detail Aids (E-Detailing)
export async function listDetailAids() {
  return apiFetch<DetailAid[]>('/api/v1/mr/detail-aids')
}

export async function createDetailAid(data: {
  name: string
  productName: string
  specialtyTarget?: string
  slideCount: number
  slides?: Array<{ slideNumber: number; title: string; imageUrl?: string; notes?: string }>
}) {
  return apiFetch<DetailAid>('/api/v1/mr/detail-aids', {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

// Samples & Inputs
export async function listMySampleBalances() {
  return apiFetch<Array<{ itemId?: string; productName: string; balance: number }>>('/api/v1/field-sales/samples/balance/me')
}

export async function issueSamples(data: {
  salespersonId: string
  itemId?: string | null
  productName: string
  quantity: number
  date?: string
  notes?: string
}) {
  return apiFetch<FieldSampleTxn>('/api/v1/field-sales/samples/issue', {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

export async function returnSamples(data: {
  salespersonId: string
  itemId?: string | null
  productName: string
  quantity: number
  date?: string
  notes?: string
}) {
  return apiFetch<FieldSampleTxn>('/api/v1/field-sales/samples/return', {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

// RCPA Endpoints
export async function listMyRcpaAudits() {
  return apiFetch<RcpaAudit[]>('/api/v1/mr/rcpa/me')
}

export async function getRcpaAudit(id: string) {
  return apiFetch<RcpaAudit>(`/api/v1/mr/rcpa/${id}`)
}

export async function recordRcpaAudit(data: {
  chemistContactId: string
  auditDate: string
  fieldVisitId?: string | null
  remarks?: string
  lines: Array<{
    productName: string
    brandType: 'OWN' | 'COMPETITOR'
    competitorName?: string
    ourItemId?: string | null
    quantity?: number
    value?: number
  }>
}) {
  return apiFetch<RcpaAudit>('/api/v1/mr/rcpa', {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

// Stockist Secondary Sales Statements
export async function listStockistStatements(stockistId?: string, month?: string) {
  const query = stockistId ? `?stockistId=${stockistId}` : month ? `?month=${month}` : ''
  return apiFetch<StockistSalesStatement[]>(`/api/v1/field-sales/secondary-sales/statements${query}`)
}

export async function getStockistStatement(id: string) {
  return apiFetch<StockistSalesStatement>(`/api/v1/field-sales/secondary-sales/statements/${id}`)
}

export async function saveStockistStatement(data: {
  stockistContactId: string
  periodMonth: string
  notes?: string
  lines: Array<{
    itemId?: string | null
    productName: string
    openingQty?: number
    purchaseQty?: number
    salesQty?: number
    returnQty?: number
    salesValue?: number
  }>
}) {
  return apiFetch<StockistSalesStatement>('/api/v1/field-sales/secondary-sales/statements', {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

export async function submitStockistStatement(id: string) {
  return apiFetch<StockistSalesStatement>(`/api/v1/field-sales/secondary-sales/statements/${id}/submit`, {
    method: 'POST',
  })
}

// ==========================================
// Field Sales KPI Dashboard
// ==========================================

export interface SecondaryDashboardData {
  totalSalespersons: number
  totalRoutes: number
  totalVisitsPlanned: number
  totalVisitsCompleted: number
  totalOrdersValue: number
  totalBookedAmount?: number
  totalOrdersBooked?: number
  totalVisitsActual?: number
  strikeRatePercent?: number
  activeSalespersons?: number
  totalCollections: number
  averageOrderValue: number
  productiveVisitPct: number
}

export async function getSecondaryDashboard(from: string, to: string) {
  return apiFetch<SecondaryDashboardData>(`/api/v1/field-sales/dashboard?from=${from}&to=${to}`)
}

// ==========================================
// Live GPS Locations & Location Trails
// ==========================================

export interface LiveLocationUser {
  userId: string
  salespersonId?: string
  fullName?: string
  salespersonName?: string
  latitude: number
  longitude: number
  accuracy?: number
  batteryLevel?: number
  updatedAt: string
  executionId?: string
  routeName?: string
}

export interface LocationTrailPoint {
  latitude: number
  longitude: number
  timestamp: string
  visitId?: string
  activity?: string
}

export interface LocationTrail {
  executionId: string
  salespersonId: string
  salespersonName?: string
  executionDate: string
  trail: LocationTrailPoint[]
}

export async function getLiveLocations() {
  return apiFetch<LiveLocationUser[]>('/api/v1/field-sales/locations/live')
}

export async function getLocationTrail(executionId: string) {
  return apiFetch<LocationTrail>(`/api/v1/field-sales/locations/trail/${executionId}`)
}

// ==========================================
// Field Attendance & Leave Management
// ==========================================

export interface AttendancePunch {
  id: string
  userId: string
  userName?: string
  date: string
  punchInTime?: string
  punchInLatitude?: number
  punchInLongitude?: number
  punchOutTime?: string
  punchOutLatitude?: number
  punchOutLongitude?: number
  status: 'PRESENT' | 'HALF_DAY' | 'ON_LEAVE' | 'PUNCHED_OUT' | string
  notes?: string
}

export interface LeaveRequest {
  id: string
  userId: string
  userName?: string
  leaveType: string
  startDate: string
  endDate: string
  reason: string
  status: 'PENDING' | 'APPROVED' | 'REJECTED' | string
  appliedAt: string
}

export async function punchIn(latitude?: number, longitude?: number, notes?: string) {
  return apiFetch<AttendancePunch>('/api/v1/attendance/punch-in', {
    method: 'POST',
    body: JSON.stringify({ latitude, longitude, notes }),
  })
}

export async function punchOut(latitude?: number, longitude?: number) {
  return apiFetch<AttendancePunch>('/api/v1/attendance/punch-out', {
    method: 'POST',
    body: JSON.stringify({ latitude, longitude }),
  })
}

export async function getTodayAttendance() {
  return apiFetch<AttendancePunch | null>('/api/v1/attendance/today')
}

export async function getMyMonthAttendance(month?: string) {
  const q = month ? `?month=${month}` : ''
  return apiFetch<AttendancePunch[]>(`/api/v1/attendance/me${q}`)
}

export async function getTeamAttendance(date?: string) {
  const q = date ? `?date=${date}` : ''
  return apiFetch<AttendancePunch[]>(`/api/v1/attendance/team${q}`)
}

export async function getPendingLeaves() {
  return apiFetch<LeaveRequest[]>('/api/v1/attendance/leave/pending')
}

export async function approveLeave(id: string) {
  return apiFetch<void>(`/api/v1/attendance/leave/${id}/approve`, {
    method: 'POST',
  })
}

export async function rejectLeave(id: string, reason: string) {
  return apiFetch<void>(`/api/v1/attendance/leave/${id}/reject`, {
    method: 'POST',
    body: JSON.stringify({ reason }),
  })
}

// ==========================================
// Field Reporting Hierarchy (Org Chart)
// ==========================================

export interface OrgChartNode {
  userId: string
  fullName: string
  role: string
  reportsToUserId?: string | null
  reportsToName?: string | null
  teamCount?: number
  children?: OrgChartNode[]
}

export interface MyTeamSummary {
  directReports: Array<{
    userId: string
    fullName: string
    role: string
  }>
  downlineCount: number
}

export async function getFieldOrgChart() {
  return apiFetch<OrgChartNode[]>('/api/v1/field-sales/hierarchy/org-chart')
}

export async function getMyFieldTeam() {
  return apiFetch<MyTeamSummary>('/api/v1/field-sales/hierarchy/my-team')
}

export async function assignReportingManager(userId: string, managerId: string | null) {
  return apiFetch<{ userId: string; reportsToUserId: string | null }>(
    `/api/v1/field-sales/hierarchy/users/${userId}/manager`,
    {
      method: 'PUT',
      body: JSON.stringify({ managerId }),
    }
  )
}

// ==========================================
// Field Coverage & Deviation Analytics
// ==========================================

export interface FrequencyComplianceReport {
  month: string
  salespersonId?: string
  salespersonName?: string
  totalPlannedVisits: number
  totalActualVisits: number
  compliancePercentage: number
  categoryBreakdown?: Array<{
    category: string
    planned: number
    completed: number
    compliance: number
  }>
}

export interface DeviationReport {
  month: string
  salespersonId: string
  salespersonName?: string
  unplannedVisits: number
  missedVisits: number
  jointVisits: number
}

export interface TeamCoverageSummary {
  salespersonId: string
  salespersonName: string
  plannedCalls: number
  actualCalls: number
  productiveCalls: number
  strikeRate: number
  orderValue: number
}

export async function getFrequencyCompliance(month: string, salespersonId?: string) {
  const spParam = salespersonId ? `&salespersonId=${salespersonId}` : ''
  return apiFetch<FrequencyComplianceReport>(`/api/v1/mr/reports/frequency-compliance?month=${month}${spParam}`)
}

export async function getDeviationReport(month: string, salespersonId: string) {
  return apiFetch<DeviationReport>(`/api/v1/mr/reports/deviation?month=${month}&salespersonId=${salespersonId}`)
}

export async function getTeamCoverageDashboard(from: string, to: string) {
  return apiFetch<TeamCoverageSummary[]>(`/api/v1/mr/reports/team-dashboard?from=${from}&to=${to}`)
}
