import { apiFetch } from '@/api/client/api-client'

export type TdsRegisterEntry = {
  id?: string
  billId?: string
  billNumber?: string
  billDate?: string
  vendorId?: string
  vendorName?: string
  vendorPan?: string
  section?: string
  rate?: number
  billAmount?: number
  taxableAmount?: number
  tdsAmount?: number
  paidAt?: string | null
  challanNumber?: string | null
  status?: string
}

export type Form26qSummary = {
  fy: number
  quarter: number
  totalDeductees: number
  totalAmountPaid: number
  totalTdsDeducted: number
  totalTdsDeposited: number
  sections?: Array<{
    section: string
    count: number
    totalAmount: number
    totalTds: number
  }>
  deductees?: Array<{
    pan: string
    name: string
    section: string
    paymentDate: string
    amount: number
    tdsDeducted: number
  }>
}

export type Form24qSummary = {
  fy: number
  quarter: number
  totalEmployees: number
  totalGrossSalary: number
  totalTdsDeducted: number
  employees?: Array<{
    employeeId: string
    employeeName: string
    pan: string
    regime: string
    grossSalary: number
    taxableSalary: number
    tdsDeducted: number
  }>
}

export type TcsRegisterEntry = {
  id?: string
  invoiceId?: string
  invoiceNumber?: string
  invoiceDate?: string
  customerId?: string
  customerName?: string
  customerPan?: string
  section?: string
  rate?: number
  invoiceAmount?: number
  cumulativeFySales?: number
  tcsAmount?: number
  challanNumber?: string | null
  status?: string
}

export type Form27eqSummary = {
  fy: number
  quarter: number
  totalCollectees: number
  totalSalesValue: number
  totalTcsCollected: number
  totalTcsDeposited: number
  collectees?: Array<{
    pan: string
    name: string
    section: string
    invoiceDate: string
    amount: number
    tcsCollected: number
  }>
}

export type TaxGroup = {
  id: string
  name: string
  description?: string | null
  active: boolean
  rates: Array<{
    taxRateId: string
    rateCode: string
    name: string
    percentage: number
    taxType: string
    recoverable: boolean
  }>
}

export type TaxAccountMapping = {
  taxRateId: string
  name: string
  rateCode: string
  percentage: number
  taxType: string
  glOutputAccountId?: string | null
  glOutputAccountCode?: string | null
  glOutputAccountName?: string | null
  glInputAccountId?: string | null
  glInputAccountCode?: string | null
  glInputAccountName?: string | null
  recoverable: boolean
  customized: boolean
}

// ── TDS Calls ──

export async function getTdsRegister(from: string, to: string) {
  return apiFetch<TdsRegisterEntry[]>(`/api/v1/tds/register?from=${encodeURIComponent(from)}&to=${encodeURIComponent(to)}`)
}

export async function getForm26q(fy: number, quarter: number) {
  return apiFetch<Form26qSummary>(`/api/v1/tds/26q?fy=${fy}&quarter=${quarter}`)
}

export function getForm26qCsvUrl(fy: number, quarter: number) {
  return `/api/v1/tds/26q/csv?fy=${fy}&quarter=${quarter}`
}

export function getForm26qFvuUrl(fy: number, quarter: number) {
  return `/api/v1/tds/26q/fvu?fy=${fy}&quarter=${quarter}`
}

export async function getForm24q(fy: number, quarter: number) {
  return apiFetch<Form24qSummary>(`/api/v1/tds/24q?fy=${fy}&quarter=${quarter}`)
}

export function getForm24qCsvUrl(fy: number, quarter: number) {
  return `/api/v1/tds/24q/csv?fy=${fy}&quarter=${quarter}`
}

export function getForm16Url(employeeId: string, fy: number) {
  return `/api/v1/tds/form16/${employeeId}?fy=${fy}`
}

// ── TCS Calls ──

export async function getTcsRegister(from: string, to: string) {
  return apiFetch<TcsRegisterEntry[]>(`/api/v1/tcs/register?from=${encodeURIComponent(from)}&to=${encodeURIComponent(to)}`)
}

export async function getForm27eq(fy: number, quarter: number) {
  return apiFetch<Form27eqSummary>(`/api/v1/tcs/27eq?fy=${fy}&quarter=${quarter}`)
}

export function getForm27eqCsvUrl(fy: number, quarter: number) {
  return `/api/v1/tcs/27eq/csv?fy=${fy}&quarter=${quarter}`
}

export async function getTcsSettings() {
  return apiFetch<{ enabled: boolean; rate: number }>('/api/v1/tcs/settings')
}

export async function updateTcsSettings(data: { enabled: boolean; rate: number }) {
  return apiFetch<{ enabled: boolean; rate: number }>('/api/v1/tcs/settings', {
    method: 'PUT',
    body: JSON.stringify(data),
  })
}

// ── Tax Groups & Mappings ──

export async function listTaxGroups() {
  return apiFetch<TaxGroup[]>('/api/v1/tax-groups')
}

export async function listTaxAccountMappings() {
  return apiFetch<TaxAccountMapping[]>('/api/v1/settings/tax-accounts')
}

export async function updateTaxAccountMappings(mappings: Array<{
  taxRateId: string
  glOutputAccountId?: string | null
  glInputAccountId?: string | null
}>) {
  return apiFetch<TaxAccountMapping[]>('/api/v1/settings/tax-accounts', {
    method: 'PUT',
    body: JSON.stringify({ mappings }),
  })
}

export async function resetTaxAccountMappings() {
  return apiFetch<TaxAccountMapping[]>('/api/v1/settings/tax-accounts/reset', {
    method: 'POST',
  })
}
