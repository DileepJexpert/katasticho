import { apiFetch } from '@/api/client/api-client'

export type CourierEvent = {
  id: string
  eventStatus: string
  eventAt: string | null
  location: string | null
  source: string | null
}

export type CourierShipment = {
  id: string
  courierShipmentNumber: string
  deliveryChallanId: string | null
  invoiceId: string | null
  contactId: string
  courierPartner: string
  courierService: string | null
  awbNumber: string | null
  status: string
  cod: boolean
  codAmount: number | string | null
  codRemittanceLineId: string | null
  freightAmount: number | string | null
  codFee: number | string | null
  transporterContactId: string | null
  weightKg: number | string | null
  declaredValue: number | string | null
  bookedAt: string | null
  deliveredAt: string | null
  rtoInitiatedAt: string | null
  rtoDeliveredAt: string | null
  notes: string | null
  events: CourierEvent[]
}

export type CreateCourierShipmentRequest = {
  deliveryChallanId?: string | null
  invoiceId?: string | null
  contactId: string
  courierPartner: string
  courierService?: string | null
  awbNumber?: string | null
  cod?: boolean
  codAmount?: number | null
  freightAmount?: number | null
  codFee?: number | null
  transporterContactId?: string | null
  weightKg?: number | null
  declaredValue?: number | null
  pickupAddress?: string | null
  deliveryAddress?: string | null
  notes?: string | null
}

export type RecordCourierEventRequest = {
  eventStatus: string
  eventAt?: string | null
  location?: string | null
  rawPayload?: string | null
  source?: string | null
}

export type CodLineResponse = {
  id: string
  awbNumber: string
  courierShipmentId: string | null
  invoiceId: string | null
  codAmount: number | string | null
  codFee: number | string | null
  netAmount: number | string | null
  matchStatus: string
  paymentId: string | null
  notes: string | null
}

export type CodLineInput = {
  awbNumber: string
  codAmount: number
  codFee?: number | null
}

export type CodRemittance = {
  id: string
  remittanceNumber: string
  courierPartner: string
  remittanceDate: string
  bankAccount: string | null
  utr: string | null
  grossCollected: number | string | null
  totalFees: number | string | null
  netRemitted: number | string | null
  expectedNet: number | string | null
  variance: number | string | null
  status: string
  notes: string | null
  lines: CodLineResponse[]
}

export type CreateCodRemittanceRequest = {
  courierPartner: string
  remittanceDate: string
  bankAccount?: string | null
  utr?: string | null
  netRemitted?: number | null
  notes?: string | null
  lines: CodLineInput[]
}

export type ReconcileResult = {
  remittanceId: string
  matched: number
  amountMismatch: number
  orphan: number
  totalSettled: number | string | null
  totalFees: number | string | null
  variance: number | string | null
}

export type LorryReceipt = {
  id: string
  lrNumber: string
  lrDate: string
  transporterContactId: string
  contactId: string | null
  deliveryChallanId: string | null
  invoiceId: string | null
  ewayBillNo: string | null
  vehicleNumber: string | null
  driverName: string | null
  driverPhone: string | null
  origin: string | null
  destination: string | null
  distanceKm: number | string | null
  mode: string | null
  numPackages: number | null
  weightKg: number | string | null
  declaredValue: number | string | null
  freightAmount: number | string | null
  freightBasis: string | null
  gstTreatment: string | null
  freightGstRate: number | string | null
  freightBillId: string | null
  status: string
  notes: string | null
}

export type CreateLorryReceiptRequest = {
  lrDate: string
  transporterContactId: string
  contactId?: string | null
  deliveryChallanId?: string | null
  invoiceId?: string | null
  ewayBillNo?: string | null
  vehicleNumber?: string | null
  driverName?: string | null
  driverPhone?: string | null
  origin?: string | null
  destination?: string | null
  distanceKm?: number | null
  mode?: string | null
  numPackages?: number | null
  weightKg?: number | null
  declaredValue?: number | null
  freightAmount?: number | null
  freightBasis?: string | null
  gstTreatment?: string | null
  freightGstRate?: number | null
  notes?: string | null
}

export type BillFreightResult = {
  lorryReceiptId: string
  billId: string
  billNumber: string
  freightAmount: number | string | null
  reverseCharge: boolean
  message: string
}

export type FreightRateCard = {
  id: string
  transporterContactId: string
  origin: string | null
  destination: string | null
  mode: string | null
  weightSlabMinKg: number | string | null
  weightSlabMaxKg: number | string | null
  rateType: string | null
  rate: number | string
  minCharge: number | string | null
  effectiveFrom: string | null
  effectiveTo: string | null
  active: boolean
  notes: string | null
}

export type FreightRateCardRequest = {
  transporterContactId: string
  origin?: string | null
  destination?: string | null
  mode?: string | null
  weightSlabMinKg?: number | null
  weightSlabMaxKg?: number | null
  rateType?: string | null
  rate: number
  minCharge?: number | null
  effectiveFrom?: string | null
  effectiveTo?: string | null
  notes?: string | null
}

export type RateQuoteResponse = {
  found: boolean
  rateCardId: string | null
  freightAmount: number | string | null
  basis: string | null
  message: string | null
}

export type VehicleLog = {
  id: string
  vehicleNumber: string
  vanId: string | null
  logType: string
  logDate: string
  odometerKm: number | string | null
  quantity: number | string | null
  amount: number | string
  vendorContactId: string | null
  referenceNo: string | null
  notes: string | null
}

export type VehicleLogRequest = {
  vehicleNumber: string
  vanId?: string | null
  logType: string
  logDate: string
  odometerKm?: number | null
  quantity?: number | null
  amount: number
  vendorContactId?: string | null
  referenceNo?: string | null
  notes?: string | null
}

export type VehicleTcoSummary = {
  vehicleNumber: string
  totalSpend: number | string
  spendByType: Record<string, number | string>
  distanceKm: number | string
  costPerKm: number | string
  fuelLitres: number | string
  mileageKmPerLitre: number | string
  entryCount: number
}

// --- Courier Shipments API ---

export function listCourierShipments(status?: string | null) {
  const url = status ? `/api/v1/courier/shipments?status=${encodeURIComponent(status)}` : '/api/v1/courier/shipments'
  return apiFetch<CourierShipment[]>(url)
}

export function getCourierShipment(id: string) {
  return apiFetch<CourierShipment>(`/api/v1/courier/shipments/${id}`)
}

export function createCourierShipment(payload: CreateCourierShipmentRequest) {
  return apiFetch<CourierShipment>('/api/v1/courier/shipments', {
    method: 'POST',
    body: payload,
  })
}

export function bookCourierShipment(id: string, awbNumber?: string) {
  return apiFetch<CourierShipment>(`/api/v1/courier/shipments/${id}/book`, {
    method: 'POST',
    body: awbNumber ? { awbNumber } : {},
  })
}

export function cancelCourierShipment(id: string, reason?: string) {
  return apiFetch<CourierShipment>(`/api/v1/courier/shipments/${id}/cancel`, {
    method: 'POST',
    body: reason ? { reason } : {},
  })
}

export function recordCourierEvent(id: string, payload: RecordCourierEventRequest) {
  return apiFetch<CourierShipment>(`/api/v1/courier/shipments/${id}/events`, {
    method: 'POST',
    body: payload,
  })
}

export function listPendingRtoShipments() {
  return apiFetch<CourierShipment[]>('/api/v1/courier/shipments/pending-rto')
}

export function syncCourierShipment(id: string) {
  return apiFetch<CourierShipment>(`/api/v1/courier/tracking/shipments/${id}/sync`, {
    method: 'POST',
  })
}

export function syncAllCourierShipments() {
  return apiFetch<{ updated: number }>('/api/v1/courier/tracking/sync-all', {
    method: 'POST',
  })
}

export function pullCodRemittance(partner: string, from?: string, to?: string) {
  const params = new URLSearchParams({ partner })
  if (from) params.set('from', from)
  if (to) params.set('to', to)
  return apiFetch<CodRemittance>(`/api/v1/courier/tracking/cod-remittances/pull?${params.toString()}`, {
    method: 'POST',
  })
}

export function getCourierWebhookUrl(partner: string) {
  return apiFetch<{ partner: string; path: string; token: string }>(
    `/api/v1/courier/tracking/webhook-url?partner=${encodeURIComponent(partner)}`,
  )
}

export function getCourierSettings() {
  return apiFetch<Record<string, Record<string, string>>>('/api/v1/courier/settings')
}

export function updateCourierSettings(partner: string, body: Record<string, string>) {
  return apiFetch<Record<string, Record<string, string>>>(`/api/v1/courier/settings/${partner}`, {
    method: 'PUT',
    body,
  })
}

export function testCourierConnection(partner: string) {
  return apiFetch<{ success: boolean; message?: string }>(`/api/v1/courier/settings/${partner}/test`, {
    method: 'POST',
  })
}

// --- COD Remittances API ---

export function listCodRemittances() {
  return apiFetch<CodRemittance[]>('/api/v1/courier/cod-remittances')
}

export function getCodRemittance(id: string) {
  return apiFetch<CodRemittance>(`/api/v1/courier/cod-remittances/${id}`)
}

export function createCodRemittance(payload: CreateCodRemittanceRequest) {
  return apiFetch<CodRemittance>('/api/v1/courier/cod-remittances', {
    method: 'POST',
    body: payload,
  })
}

export function reconcileCodRemittance(id: string) {
  return apiFetch<ReconcileResult>(`/api/v1/courier/cod-remittances/${id}/reconcile`, {
    method: 'POST',
  })
}

// --- Lorry Receipts API ---

export function listLorryReceipts(status?: string | null) {
  const url = status ? `/api/v1/transport/lorry-receipts?status=${encodeURIComponent(status)}` : '/api/v1/transport/lorry-receipts'
  return apiFetch<LorryReceipt[]>(url)
}

export function getLorryReceipt(id: string) {
  return apiFetch<LorryReceipt>(`/api/v1/transport/lorry-receipts/${id}`)
}

export function createLorryReceipt(payload: CreateLorryReceiptRequest) {
  return apiFetch<LorryReceipt>('/api/v1/transport/lorry-receipts', {
    method: 'POST',
    body: payload,
  })
}

export function issueLorryReceipt(id: string) {
  return apiFetch<LorryReceipt>(`/api/v1/transport/lorry-receipts/${id}/issue`, {
    method: 'POST',
  })
}

export function deliverLorryReceipt(id: string) {
  return apiFetch<LorryReceipt>(`/api/v1/transport/lorry-receipts/${id}/deliver`, {
    method: 'POST',
  })
}

export function cancelLorryReceipt(id: string, reason?: string) {
  return apiFetch<LorryReceipt>(`/api/v1/transport/lorry-receipts/${id}/cancel`, {
    method: 'POST',
    body: reason ? { reason } : {},
  })
}

export function billLorryReceiptFreight(id: string) {
  return apiFetch<BillFreightResult>(`/api/v1/transport/lorry-receipts/${id}/bill-freight`, {
    method: 'POST',
  })
}

// --- Freight Rate Cards API ---

export function listFreightRateCards(transporterContactId?: string) {
  const url = transporterContactId
    ? `/api/v1/transport/rate-cards?transporterContactId=${transporterContactId}`
    : '/api/v1/transport/rate-cards'
  return apiFetch<FreightRateCard[]>(url)
}

export function createFreightRateCard(payload: FreightRateCardRequest) {
  return apiFetch<FreightRateCard>('/api/v1/transport/rate-cards', {
    method: 'POST',
    body: payload,
  })
}

export function deleteFreightRateCard(id: string) {
  return apiFetch<void>(`/api/v1/transport/rate-cards/${id}`, {
    method: 'DELETE',
  })
}

export function quoteFreightRate(params: {
  transporterContactId: string
  origin?: string
  destination?: string
  mode?: string
  weightKg?: number
}) {
  const q = new URLSearchParams({ transporterContactId: params.transporterContactId })
  if (params.origin) q.set('origin', params.origin)
  if (params.destination) q.set('destination', params.destination)
  if (params.mode) q.set('mode', params.mode)
  if (params.weightKg !== undefined) q.set('weightKg', String(params.weightKg))
  return apiFetch<RateQuoteResponse>(`/api/v1/transport/rate-cards/quote?${q.toString()}`)
}

// --- Vehicle Logs & TCO API ---

export function listVehicleLogs(vehicleNumber?: string) {
  const url = vehicleNumber ? `/api/v1/transport/vehicle-logs?vehicleNumber=${encodeURIComponent(vehicleNumber)}` : '/api/v1/transport/vehicle-logs'
  return apiFetch<VehicleLog[]>(url)
}

export function createVehicleLog(payload: VehicleLogRequest) {
  return apiFetch<VehicleLog>('/api/v1/transport/vehicle-logs', {
    method: 'POST',
    body: payload,
  })
}

export function deleteVehicleLog(id: string) {
  return apiFetch<void>(`/api/v1/transport/vehicle-logs/${id}`, {
    method: 'DELETE',
  })
}

export function getVehicleTcoSummary(vehicleNumber: string) {
  return apiFetch<VehicleTcoSummary>(`/api/v1/transport/vehicle-logs/summary?vehicleNumber=${encodeURIComponent(vehicleNumber)}`)
}