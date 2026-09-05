import { apiFetch } from '@/api/client/api-client'

export type ExpenseLine = {
  id: string
  amount: number
  description: string
  expenseTime: string
}

export type CashRegisterSummary = {
  id: string | null
  date: string
  status: 'OPEN' | 'CLOSED' | string
  openingBalance: number
  cashSales: number
  upiSales: number
  cardSales: number
  totalSales: number
  totalExpenses: number
  expectedClosing: number
  actualClosing: number | null
  variance: number | null
  transactionCount: number
  expenses: ExpenseLine[]
}

export type DiscountThresholds = {
  maxItemDiscountPct?: number
  maxBillDiscountPct?: number
}

export type PosSearchResult = {
  id: string
  name: string
  sku: string | null
  barcode: string | null
  rate: number
  mrp: number | null
  purchasePrice: number | null
  taxGroupId: string | null
  taxGroupName: string | null
  hsnCode: string | null
  unit: string | null
  currentStock: number | null
  weightBasedBilling: boolean
  batchId: string | null
  batchExpiryDate: string | null
  trackBatches: boolean
  batchNumber: string | null
  prescriptionRequired: boolean
  drugSchedule: string | null
  composition: string | null
  manufacturer: string | null
  rackLocationCode: string | null
  discountThresholds?: DiscountThresholds | null
}

export type SalesReceiptLine = {
  id: string
  lineNumber: number
  itemId: string
  itemName: string
  itemSku: string | null
  description: string | null
  quantity: number
  unit: string | null
  mrp: number | null
  rate: number
  discountPerUnit: number | null
  discountAmount: number | null
  taxGroupId: string | null
  hsnCode: string | null
  amount: number
  batchId: string | null
  batchNumber: string | null
  batchExpiry: string | null
}

export type SalesReceipt = {
  id: string
  receiptNumber: string
  offlineReceiptNumber: string | null
  receiptDate: string
  branchId: string | null
  contactId: string | null
  contactName: string | null
  subtotal: number
  taxAmount: number
  cgst: number | null
  sgst: number | null
  igst: number | null
  total: number
  gstInvoice: boolean
  paymentMode: 'CASH' | 'UPI' | 'CARD' | 'CREDIT' | string
  amountReceived: number
  changeReturned: number
  upiReference: string | null
  notes: string | null
  journalEntryId: string | null
  status: string
  createdAt: string | null
  lines: SalesReceiptLine[]
}

export type CreateSalesReceiptLine = {
  itemId: string
  description?: string
  quantity: number
  unit?: string
  rate: number
  taxGroupId?: string
  hsnCode?: string
  batchId?: string
  /** POS shelf prices are GST-inclusive, matching the established Flutter flow. */
  taxInclusive?: boolean
}

export type CreateSalesReceiptRequest = {
  branchId?: string
  contactId?: string
  receiptDate: string
  paymentMode: 'CASH' | 'UPI' | 'CARD' | 'CREDIT' | string
  paidThroughId?: string
  amountReceived: number
  upiReference?: string
  notes?: string
  gstInvoice?: boolean
  offlineReceiptNumber?: string
  lines: CreateSalesReceiptLine[]
}

export type BatchOfflineSyncResponse = {
  syncedCount: number
  duplicateCount: number
  failedCount: number
  syncedReceipts: SalesReceipt[]
  errors: string[]
}

export type CustomerHistoryReceipt = {
  id: string
  receiptNumber: string
  receiptDate: string
  total: number
  paymentMode: string
  lines: SalesReceiptLine[]
}

export type CustomerHistoryResponse = {
  contactId: string
  contactName: string
  totalReceiptsCount: number
  totalSpend: number
  lastVisitDate: string | null
  recentReceipts: CustomerHistoryReceipt[]
}

export type PosReceiptSettings = {
  storeName: string
  tagline: string
  addressLine1: string
  addressLine2: string
  phone: string
  email: string
  gstin: string
  drugLicenseNo: string
  paperWidth: '58mm' | '80mm'
  showHsn: boolean
  showBatches: boolean
  showSavings: boolean
  showLoyalty: boolean
  showCashier: boolean
  showQr: boolean
  headerNote: string
  footerNote: string
  autoPrint: boolean
  openDrawerPulse: boolean
}

// ── Cash Register APIs ──

export async function getTodayRegister(): Promise<CashRegisterSummary> {
  return apiFetch<CashRegisterSummary>('/api/v1/pos/cash-register/today')
}

export async function openRegister(openingBalance: number, notes?: string): Promise<CashRegisterSummary> {
  return apiFetch<CashRegisterSummary>('/api/v1/pos/cash-register/open', {
    method: 'POST',
    body: JSON.stringify({ openingBalance, notes }),
  })
}

export async function closeRegister(actualClosing: number, notes?: string): Promise<CashRegisterSummary> {
  return apiFetch<CashRegisterSummary>('/api/v1/pos/cash-register/close', {
    method: 'POST',
    body: JSON.stringify({ actualClosing, notes }),
  })
}

export async function addRegisterExpense(amount: number, description: string): Promise<CashRegisterSummary> {
  return apiFetch<CashRegisterSummary>('/api/v1/pos/cash-register/expense', {
    method: 'POST',
    body: JSON.stringify({ amount, description }),
  })
}

export async function deleteRegisterExpense(expenseId: string): Promise<void> {
  await apiFetch<void>(`/api/v1/pos/cash-register/expense/${expenseId}`, {
    method: 'DELETE',
  })
}

export async function getRegisterHistory(from: string, to: string): Promise<CashRegisterSummary[]> {
  return apiFetch<CashRegisterSummary[]>(`/api/v1/pos/cash-register/history?from=${from}&to=${to}`)
}

export async function getRegisterByDate(date: string): Promise<CashRegisterSummary> {
  return apiFetch<CashRegisterSummary>(`/api/v1/pos/cash-register/${date}`)
}

// ── Fast Item Search & Catalog APIs ──

export async function searchPosItems(q: string, limit = 20, branchId?: string): Promise<PosSearchResult[]> {
  const params = new URLSearchParams()
  params.set('q', q)
  params.set('limit', String(limit))
  if (branchId) params.set('branch_id', branchId)
  return apiFetch<PosSearchResult[]>(`/api/v1/items/pos-search?${params.toString()}`)
}

export async function createItemFromDrug(
  drugId: string,
  branchId?: string,
  openingStock?: number
): Promise<PosSearchResult> {
  const params = new URLSearchParams()
  if (branchId) params.set('branch_id', branchId)
  if (openingStock !== undefined) params.set('opening_stock', String(openingStock))
  return apiFetch<PosSearchResult>(`/api/v1/items/from-drug/${drugId}?${params.toString()}`, {
    method: 'POST',
  })
}

export async function syncPosCatalog(
  since?: string,
  sinceId?: string,
  branchId?: string,
  pageSize = 500
): Promise<{ items: PosSearchResult[]; nextSince?: string; hasMore: boolean }> {
  const params = new URLSearchParams()
  if (since) params.set('since', since)
  if (sinceId) params.set('since_id', sinceId)
  if (branchId) params.set('branch_id', branchId)
  params.set('page_size', String(pageSize))
  return apiFetch<{ items: PosSearchResult[]; nextSince?: string; hasMore: boolean }>(
    `/api/v1/items/pos-sync?${params.toString()}`
  )
}

// ── Sales Receipt APIs ──

export type SalesReceiptPage = {
  content: SalesReceipt[]
  page: number
  size: number
  totalElements: number
  totalPages: number
  last: boolean
}

export async function listSalesReceipts(
  page = 0,
  size = 50,
  paymentMode?: string,
  dateFrom?: string,
  dateTo?: string,
  branchId?: string
): Promise<SalesReceiptPage> {
  const params = new URLSearchParams()
  params.set('page', String(page))
  params.set('size', String(size))
  if (paymentMode && paymentMode !== 'all') params.set('paymentMode', paymentMode)
  if (dateFrom) params.set('dateFrom', dateFrom)
  if (dateTo) params.set('dateTo', dateTo)
  if (branchId) params.set('branchId', branchId)
  return apiFetch<SalesReceiptPage>(`/api/v1/sales-receipts?${params.toString()}`)
}

export async function getSalesReceipt(id: string): Promise<SalesReceipt> {
  return apiFetch<SalesReceipt>(`/api/v1/sales-receipts/${id}`)
}

export async function createSalesReceipt(req: CreateSalesReceiptRequest): Promise<SalesReceipt> {
  return apiFetch<SalesReceipt>('/api/v1/sales-receipts', {
    method: 'POST',
    body: JSON.stringify(req),
  })
}

export async function returnSalesReceipt(id: string, reason?: string): Promise<SalesReceipt> {
  return apiFetch<SalesReceipt>(`/api/v1/sales-receipts/${id}/return`, {
    method: 'POST',
    body: JSON.stringify({ reason }),
  })
}

export async function batchOfflineSync(requests: CreateSalesReceiptRequest[]): Promise<BatchOfflineSyncResponse> {
  return apiFetch<BatchOfflineSyncResponse>('/api/v1/sales-receipts/offline-sync', {
    method: 'POST',
    body: JSON.stringify(requests),
  })
}

export async function getReceiptWhatsAppLink(id: string): Promise<{ shareUrl?: string; message?: string }> {
  return apiFetch<{ shareUrl?: string; message?: string }>(`/api/v1/sales-receipts/${id}/whatsapp-link`, {
    method: 'POST',
  })
}

export async function getCustomerHistory(contactId: string, days = 180): Promise<CustomerHistoryResponse> {
  return apiFetch<CustomerHistoryResponse>(`/api/v1/sales-receipts/customer/${contactId}/history?days=${days}`)
}

// Local receipt settings persistence
const RECEIPT_SETTINGS_KEY = 'katasticho_pos_receipt_settings'

export const defaultReceiptSettings: PosReceiptSettings = {
  storeName: 'Katasticho Pharmacy & General Store',
  tagline: 'Quality Medicines & Daily Essentials',
  addressLine1: 'Main Market Road, Sector 4',
  addressLine2: 'Bengaluru, Karnataka - 560001',
  phone: '+91 98765 43210',
  email: 'store@katasticho.com',
  gstin: '29ABCDE1234F1Z5',
  drugLicenseNo: 'KA-B1-234567 / 234568',
  paperWidth: '80mm',
  showHsn: true,
  showBatches: true,
  showSavings: true,
  showLoyalty: true,
  showCashier: true,
  showQr: true,
  headerNote: 'GST INVOICE / CASH MEMO',
  footerNote: 'Thank you for shopping with us! Medicines cannot be returned without bill within 7 days.',
  autoPrint: false,
  openDrawerPulse: true,
}

export function loadPosReceiptSettings(): PosReceiptSettings {
  try {
    const raw = localStorage.getItem(RECEIPT_SETTINGS_KEY)
    if (!raw) return defaultReceiptSettings
    return { ...defaultReceiptSettings, ...JSON.parse(raw) }
  } catch {
    return defaultReceiptSettings
  }
}

export function savePosReceiptSettings(settings: PosReceiptSettings): void {
  localStorage.setItem(RECEIPT_SETTINGS_KEY, JSON.stringify(settings))
}
