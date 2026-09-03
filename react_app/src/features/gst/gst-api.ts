import { apiFetch } from '@/api/client/api-client'

export type GstPeriod = {
  year: number
  month: number
}

export type Gstr1Summary = {
  b2bCount: number
  b2bTaxable: number
  b2bTax: number
  b2clCount: number
  b2clTaxable: number
  b2clTax: number
  b2csCount: number
  b2csTaxable: number
  b2csTax: number
  exportCount: number
  exportTaxable: number
  exportTax: number
  totalTaxable: number
  totalCgst: number
  totalSgst: number
  totalIgst: number
  totalCess: number
  totalTax: number
}

export type Gstr3bSummary = {
  outwardTaxable: number
  outwardCgst: number
  outwardSgst: number
  outwardIgst: number
  outwardCess: number
  itcAllOther: {
    cgst: number
    sgst: number
    igst: number
    cess: number
  }
  itcIneligible: {
    cgst: number
    sgst: number
    igst: number
    cess: number
  }
  netPayable: {
    cgst: number
    sgst: number
    igst: number
    cess: number
  }
}

export type Gstr2bEntry = {
  id: string
  period: string
  supplierGstin: string
  supplierTradeName?: string | null
  supplierLegalName?: string | null
  invoiceNumber: string
  invoiceType?: string | null
  invoiceDate: string
  invoiceValue: number
  taxableValue: number
  igst: number
  cgst: number
  sgst: number
  cess: number
  itcAvailable: boolean
  matchStatus: 'MATCHED' | 'MISSING_IN_BOOKS' | 'MISSING_IN_PORTAL' | 'VALUE_MISMATCH' | 'TAX_MISMATCH' | string
  imsAction?: 'ACCEPT' | 'REJECT' | 'PENDING' | null
  imsActionDate?: string | null
  imsRemarks?: string | null
  aiRecommendedAction?: string | null
  aiRecommendationReason?: string | null
}

export type ImsSummary = {
  period: string
  totalEntries: number
  totalItcExposure: number
  actionedCount: number
  actionedItc: number
  noActionCount: number
  noActionItc: number
  acceptedCount: number
  rejectedCount: number
  pendingCount: number
  deemedAcceptedWarning: boolean
}

export type ItcRiskSupplier = {
  supplierGstin: string
  supplierName: string
  invoiceCount: number
  totalItcAtRisk: number
  gstr1FilingStatus: 'FILED' | 'NOT_FILED' | 'DELAYED' | string
  riskLevel: 'HIGH' | 'MEDIUM' | 'LOW' | string
  lastFilingDate?: string | null
}

export type ItcRiskReport = {
  period: string
  totalSuppliersAtRisk: number
  totalItcAtRisk: number
  suppliers: ItcRiskSupplier[]
}

export type EwayBill = {
  id: string
  documentType: string
  documentNumber: string
  documentDate: string
  ewbNumber?: string | null
  ewbDate?: string | null
  validUntil?: string | null
  status: 'PENDING' | 'GENERATED' | 'CANCELLED' | string
  fromPincode: string
  toPincode: string
  distanceKm: number
  vehicleNumber?: string | null
  transporterId?: string | null
  transporterName?: string | null
  totalAmount: number
  cgstAmount: number
  sgstAmount: number
  igstAmount: number
  cancelReason?: string | null
}

export type EInvoice = {
  id: string
  invoiceId: string
  invoiceNumber: string
  invoiceDate: string
  customerGstin: string
  customerName: string
  irn?: string | null
  ackNumber?: string | null
  ackDate?: string | null
  signedQr?: string | null
  status: 'PENDING' | 'GENERATED' | 'CANCELLED' | string
  totalAmount: number
  taxAmount: number
  cancelReason?: string | null
}

export type MonthEndChecklistItem = {
  id: string
  title: string
  category: string
  status: 'READY' | 'WARNING' | 'BLOCKED' | 'COMPLETED' | string
  detail: string
  actionUrl?: string | null
}

export type MonthEndCloseChecklist = {
  period: string
  overallStatus: 'GREEN' | 'AMBER' | 'RED' | string
  items: MonthEndChecklistItem[]
}

export type ComplianceDeadline = {
  form: string
  period: string
  dueDate: string
  description: string
  isOverdue: boolean
  daysRemaining: number
}

// â”€â”€ GST API Calls â”€â”€

export async function getGstr1(year: number, month: number): Promise<Gstr1Summary> {
  return apiFetch<Gstr1Summary>(`/api/v1/gst/gstr1?year=${year}&month=${month}`)
}

export async function getGstr3b(year: number, month: number): Promise<Gstr3bSummary> {
  return apiFetch<Gstr3bSummary>(`/api/v1/gst/gstr3b?year=${year}&month=${month}`)
}

export async function getComplianceCalendar(): Promise<ComplianceDeadline[]> {
  return apiFetch<ComplianceDeadline[]>('/api/v1/gst/compliance-calendar')
}

export async function getImsSummary(period: string): Promise<ImsSummary> {
  return apiFetch<ImsSummary>(`/api/v1/gst/ims/summary?period=${encodeURIComponent(period)}`)
}

export async function listGstr2bEntries(period: string): Promise<Gstr2bEntry[]> {
  return apiFetch<Gstr2bEntry[]>(`/api/v1/gst/gstr2b?period=${encodeURIComponent(period)}`)
}

export async function actionImsEntry(id: string, action: 'ACCEPT' | 'REJECT' | 'PENDING', remarks?: string): Promise<Gstr2bEntry> {
  return apiFetch<Gstr2bEntry>(`/api/v1/gst/ims/${id}/action`, {
    method: 'POST',
    body: JSON.stringify({ action, remarks }),
  })
}

export async function bulkActionIms(entryIds: string[], action: 'ACCEPT' | 'REJECT' | 'PENDING', remarks?: string): Promise<{ updatedCount: number }> {
  return apiFetch<{ updatedCount: number }>('/api/v1/gst/ims/bulk-action', {
    method: 'POST',
    body: JSON.stringify({ entryIds, action, remarks }),
  })
}

export async function applyAiRecommendations(period: string): Promise<{ appliedCount: number }> {
  return apiFetch<{ appliedCount: number }>(`/api/v1/gst/ims/apply-recommendations?period=${encodeURIComponent(period)}`, {
    method: 'POST',
  })
}

export async function resetImsAction(id: string): Promise<Gstr2bEntry> {
  return apiFetch<Gstr2bEntry>(`/api/v1/gst/ims/${id}/reset`, {
    method: 'POST',
  })
}

export async function getItcRiskReport(period: string): Promise<ItcRiskReport> {
  return apiFetch<ItcRiskReport>(`/api/v1/gst/itc-risk?period=${encodeURIComponent(period)}`)
}

export async function refreshItcRiskAlerts(period: string): Promise<{ period: string; alertsRaised: number }> {
  return apiFetch<{ period: string; alertsRaised: number }>(`/api/v1/gst/itc-risk/alert?period=${encodeURIComponent(period)}`, {
    method: 'POST',
  })
}

export async function listEwayBills(status?: string): Promise<EwayBill[]> {
  const params = new URLSearchParams()
  if (status) params.set('status', status)
  return apiFetch<EwayBill[]>(`/api/v1/gst/eway-bills?${params.toString()}`)
}

export async function generateEwayBillViaGsp(id: string): Promise<EwayBill> {
  return apiFetch<EwayBill>(`/api/v1/gst/eway-bills/${id}/generate-gsp`, {
    method: 'POST',
  })
}

export async function recordEwayBill(id: string, ewbNumber: string, ewbDate?: string, validUntil?: string): Promise<EwayBill> {
  return apiFetch<EwayBill>(`/api/v1/gst/eway-bills/${id}/record`, {
    method: 'POST',
    body: JSON.stringify({ ewbNumber, ewbDate, validUntil }),
  })
}

export async function cancelEwayBill(id: string, reason?: string): Promise<EwayBill> {
  return apiFetch<EwayBill>(`/api/v1/gst/eway-bills/${id}/cancel`, {
    method: 'POST',
    body: JSON.stringify({ reason }),
  })
}

export async function listEInvoices(status?: string): Promise<EInvoice[]> {
  const params = new URLSearchParams()
  if (status) params.set('status', status)
  return apiFetch<EInvoice[]>(`/api/v1/gst/einvoices?${params.toString()}`)
}

export async function generateEInvoiceViaGsp(id: string): Promise<EInvoice> {
  return apiFetch<EInvoice>(`/api/v1/gst/einvoices/${id}/generate-gsp`, {
    method: 'POST',
  })
}

export async function recordEInvoice(id: string, irn: string, ackNumber?: string, ackDate?: string, signedQr?: string): Promise<EInvoice> {
  return apiFetch<EInvoice>(`/api/v1/gst/einvoices/${id}/record`, {
    method: 'POST',
    body: JSON.stringify({ irn, ackNumber, ackDate, signedQr }),
  })
}

export async function cancelEInvoice(id: string, reason?: string): Promise<EInvoice> {
  return apiFetch<EInvoice>(`/api/v1/gst/einvoices/${id}/cancel`, {
    method: 'POST',
    body: JSON.stringify({ reason }),
  })
}

export async function getMonthEndCloseChecklist(year: number, month: number): Promise<MonthEndCloseChecklist> {
  return apiFetch<MonthEndCloseChecklist>(`/api/v1/gst/close/checklist?year=${year}&month=${month}`)
}