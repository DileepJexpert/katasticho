import { apiFetch } from '@/api/client/api-client'

export type Employee = {
  id: string
  orgId: string
  userId?: string | null
  employeeCode?: string | null
  biometricPin?: string | null
  fullName: string
  phone?: string | null
  email?: string | null
  designation?: string | null
  department?: string | null
  dateOfJoining?: string | null
  dateOfExit?: string | null
  paymentMode?: string | null
  bankAccountName?: string | null
  bankAccountNumber?: string | null
  bankIfsc?: string | null
  bankIfscCode?: string | null
  bankName?: string | null
  pan?: string | null
  panNumber?: string | null
  aadhaarLast4?: string | null
  uan?: string | null
  uanNumber?: string | null
  esiNumber?: string | null
  pfApplicable?: boolean
  isPfApplicable?: boolean
  esiApplicable?: boolean
  isEsiApplicable?: boolean
  ptApplicable?: boolean
  isPtApplicable?: boolean
  lwfApplicable?: boolean
  isLwfApplicable?: boolean
  dateOfBirth?: string | null
  gender?: string | null
  maritalStatus?: string | null
  bloodGroup?: string | null
  nationality?: string | null
  personalEmail?: string | null
  currentAddressLine1?: string | null
  currentAddressLine2?: string | null
  currentCity?: string | null
  currentState?: string | null
  currentPincode?: string | null
  permanentAddressLine1?: string | null
  permanentAddressLine2?: string | null
  permanentCity?: string | null
  permanentState?: string | null
  permanentPincode?: string | null
  emergencyContactName?: string | null
  emergencyContactRelationship?: string | null
  emergencyContactPhone?: string | null
  employmentType?: string | null
  workLocation?: string | null
  probationEndDate?: string | null
  confirmationDate?: string | null
  noticePeriodDays?: number | null
  photoAttachmentId?: string | null
  status: 'ACTIVE' | 'ON_NOTICE' | 'TERMINATED' | 'RESIGNED' | string
  createdAt?: string
  updatedAt?: string
}

export type CreateEmployeeRequest = {
  employeeCode?: string
  fullName: string
  phone?: string
  email?: string
  designation?: string
  department?: string
  dateOfJoining?: string
  paymentMode?: string
  bankAccountName?: string
  bankAccountNumber?: string
  bankIfsc?: string
  pan?: string
  aadhaarLast4?: string
  uan?: string
  esiNumber?: string
  isPfApplicable?: boolean
  isEsiApplicable?: boolean
  isPtApplicable?: boolean
  isLwfApplicable?: boolean
  userId?: string
  dateOfBirth?: string
  gender?: string
  maritalStatus?: string
  bloodGroup?: string
  nationality?: string
  personalEmail?: string
  currentAddressLine1?: string
  currentAddressLine2?: string
  currentCity?: string
  currentState?: string
  currentPincode?: string
  permanentAddressLine1?: string
  permanentAddressLine2?: string
  permanentCity?: string
  permanentState?: string
  permanentPincode?: string
  emergencyContactName?: string
  emergencyContactRelationship?: string
  emergencyContactPhone?: string
  employmentType?: string
  workLocation?: string
  probationEndDate?: string
  confirmationDate?: string
  noticePeriodDays?: number
}

export type SalaryComponent = {
  id: string
  code: string
  name: string
  componentType: 'EARNING' | 'DEDUCTION' | 'STATUTORY_EMPLOYER' | string
  taxability?: string | null
  statutory: boolean
}

export type EmployeeSalaryComponentLine = {
  id?: string
  componentId: string
  componentCode?: string
  componentName?: string
  componentType?: 'EARNING' | 'DEDUCTION' | 'STATUTORY_EMPLOYER' | string
  monthlyAmount: number | string
  statutory?: boolean
}

export type EmployeeSalaryStructure = {
  id?: string
  employeeId: string
  effectiveFrom: string
  ctcMonthly: number | string | null
  grossMonthly: number | string | null
  payType: 'SALARY' | 'HOURLY' | 'PIECE_RATE' | string
  hourlyRate?: number | string | null
  pieceRate?: number | string | null
  lines?: EmployeeSalaryComponentLine[]
}

export type SaveSalaryStructureRequest = {
  effectiveFrom: string
  ctcMonthly?: number | null
  grossMonthly?: number | null
  payType?: string
  hourlyRate?: number | null
  pieceRate?: number | null
  lines: Array<{
    componentId: string
    monthlyAmount: number
  }>
}

export type LaborPayPreview = {
  employeeId?: string
  totalHours?: number
  pieceCount?: number
  totalPieces?: number
  hourlyPay?: number
  piecePay?: number
  totalLaborPay?: number
  jobCardCount?: number
  amount?: number
  payType?: string
}

export type EmployeeTaxDeclaration = {
  id: string
  orgId?: string
  employeeId: string
  fiscalYear: string
  regime?: 'NEW' | 'OLD' | string
  taxRegime?: 'OLD' | 'NEW' | string
  section80cTotal?: number | string
  section80dMediclaim?: number | string
  hraRentPaidAnnual?: number | string
  homeLoanInterest80ee?: number | string
  otherDeductions?: number | string
  hraRentPaid?: number | null
  hraMetroCity?: boolean
  landlordPan?: string | null
  deduction80c?: number | null
  deduction80ccd1b?: number | null
  deduction80dSelf?: number | null
  deduction80dParents?: number | null
  deduction80e?: number | null
  deduction80g?: number | null
  deduction80tta?: number | null
  deduction80ttb?: number | null
  homeLoanInterest?: number | null
  ltaClaim?: number | null
  otherIncome?: number | null
  status: 'DRAFT' | 'SUBMITTED' | 'VERIFIED' | 'REJECTED' | string
  submittedAt?: string | null
  verifiedAt?: string | null
  verifiedBy?: string | null
  remarks?: string | null
  notes?: string | null
  createdAt?: string
  updatedAt?: string
}

export type PayrollRun = {
  id: string
  orgId: string
  periodStart: string
  periodEnd: string
  status: 'DRAFT' | 'CALCULATED' | 'APPROVED' | 'POSTED' | 'CANCELLED' | string
  employeeCount: number
  grossTotal: number | string
  deductionTotal: number | string
  employerContributionTotal: number | string
  netPayTotal: number | string
  calculatedAt?: string | null
  approvedAt?: string | null
  postedAt?: string | null
  journalEntryId?: string | null
  createdAt?: string
}

export type PayslipLine = {
  id: string
  componentId?: string
  componentCode?: string
  componentName?: string
  componentType?: string
  amount: number | string
}

export type Payslip = {
  id: string
  payrollRunId: string
  employeeId: string
  employee?: Employee | null
  employeeName?: string | null
  employeeCode?: string | null
  designation?: string | null
  department?: string | null
  lopDays: number | string
  grossPay: number | string
  totalDeductions: number | string
  employerContributions: number | string
  netPay: number | string
  status?: string
  lines?: PayslipLine[]
}

export type PayrollSettings = {
  payrollStartMonth?: number
  payFrequency?: string
  defaultSalaryExpenseAccountId?: string | null
  defaultSalaryPayableAccountId?: string | null
  defaultPfPayableAccountId?: string | null
  defaultEsiPayableAccountId?: string | null
  defaultPtPayableAccountId?: string | null
  defaultLwfPayableAccountId?: string | null
  defaultTdsPayableAccountId?: string | null
  pfEnabled?: boolean
  esiEnabled?: boolean
  ptEnabled?: boolean
  lwfEnabled?: boolean
  tdsEnabled?: boolean
}

export type PageResponse<T> = {
  content: T[]
  page: number
  size: number
  totalElements: number
  totalPages: number
  last: boolean
}

// â”€â”€ Employee APIs â”€â”€

export async function listEmployees(page = 0, size = 50) {
  return apiFetch<PageResponse<Employee>>(`/api/v1/payroll/employees?pageNo=${page}&pageSize=${size}`)
}

export async function getEmployee(id: string) {
  return apiFetch<Employee>(`/api/v1/payroll/employees/${id}`)
}

export async function createEmployee(req: CreateEmployeeRequest) {
  return apiFetch<Employee>('/api/v1/payroll/employees', {
    method: 'POST',
    body: JSON.stringify(req),
  })
}

export async function updateEmployee(id: string, req: CreateEmployeeRequest) {
  return apiFetch<Employee>(`/api/v1/payroll/employees/${id}`, {
    method: 'PUT',
    body: JSON.stringify(req),
  })
}

export async function deleteEmployee(id: string) {
  return apiFetch<void>(`/api/v1/payroll/employees/${id}`, {
    method: 'DELETE',
  })
}

// â”€â”€ Salary Structure APIs â”€â”€

export async function getEmployeeSalaryStructure(employeeId: string) {
  return apiFetch<EmployeeSalaryStructure>(`/api/v1/payroll/employees/${employeeId}/salary-structure`)
}

export async function saveEmployeeSalaryStructure(employeeId: string, req: SaveSalaryStructureRequest) {
  return apiFetch<EmployeeSalaryStructure>(`/api/v1/payroll/employees/${employeeId}/salary-structure`, {
    method: 'POST',
    body: JSON.stringify(req),
  })
}

export async function listSalaryComponents() {
  return apiFetch<SalaryComponent[]>('/api/v1/payroll/salary-components')
}

export async function previewLaborPay(employeeId: string, start: string, end: string) {
  return apiFetch<LaborPayPreview>(`/api/v1/payroll/employees/${employeeId}/labor-pay-preview?periodStart=${start}&periodEnd=${end}`)
}

export const getLaborPayPreview = previewLaborPay

// ── Tax Declaration (Form 12BB) APIs ──

export async function getMyTaxDeclaration(fy: string) {
  return apiFetch<EmployeeTaxDeclaration | null>(`/api/v1/payroll/tax-declarations/me?fy=${encodeURIComponent(fy)}`)
}

export async function saveMyTaxDeclaration(fy: string, data: Partial<EmployeeTaxDeclaration>) {
  return apiFetch<EmployeeTaxDeclaration>(`/api/v1/payroll/tax-declarations/me?fy=${encodeURIComponent(fy)}`, {
    method: 'PUT',
    body: JSON.stringify(data),
  })
}

export async function submitTaxDeclaration(id: string) {
  return apiFetch<EmployeeTaxDeclaration>(`/api/v1/payroll/tax-declarations/${id}/submit`, {
    method: 'POST',
  })
}

export async function deleteTaxDeclarationDraft(id: string) {
  return apiFetch<void>(`/api/v1/payroll/tax-declarations/${id}`, { method: 'DELETE' })
}

export async function listTaxDeclarations(fy: string) {
  return apiFetch<EmployeeTaxDeclaration[]>(`/api/v1/payroll/tax-declarations?fy=${encodeURIComponent(fy)}`)
}

export async function verifyTaxDeclaration(id: string, status?: string, remarks?: string) {
  return apiFetch<EmployeeTaxDeclaration>(`/api/v1/payroll/tax-declarations/${id}/verify`, {
    method: 'POST',
    body: status ? JSON.stringify({ status, remarks }) : undefined,
  })
}

export async function saveTaxDeclaration(employeeId: string, fy: string, data: Partial<EmployeeTaxDeclaration>) {
  return apiFetch<EmployeeTaxDeclaration>(`/api/v1/payroll/tax-declarations/employees/${employeeId}?fy=${encodeURIComponent(fy)}`, {
    method: 'PUT',
    body: JSON.stringify(data),
  })
}

export async function getTaxDeclaration(employeeId: string, fy: string) {
  return apiFetch<EmployeeTaxDeclaration>(`/api/v1/payroll/tax-declarations/employees/${employeeId}?fy=${encodeURIComponent(fy)}`)
}

export function getForm12BbPdfUrl(id: string): string {
  return `/api/v1/payroll/tax-declarations/${id}/pdf`
}

// ── Kenya PAYE & Statutory Salary Calculator APIs ──

export type KenyaPayeCalculationRequest = {
  grossSalary: number
  nonCashBenefits?: number
  pensionContribution?: number
}

export type KenyaPayeCalculationResponse = {
  grossSalary: number
  nssfTier1: number
  nssfTier2: number
  totalNssf: number
  taxablePay: number
  grossPaye: number
  personalRelief: number
  insuranceRelief: number
  netPaye: number
  shifAmount: number
  housingLevyAmount: number
  totalDeductions: number
  netPay: number
}

export async function calculateKenyaPaye(req: KenyaPayeCalculationRequest) {
  return apiFetch<KenyaPayeCalculationResponse>('/api/v1/kenya/paye/calculate', {
    method: 'POST',
    body: JSON.stringify(req),
  })
}

// ── Payroll Runs APIs ──

export async function listPayrollRuns(page = 0, size = 20) {
  return apiFetch<PageResponse<PayrollRun>>(`/api/v1/payroll/runs?pageNo=${page}&pageSize=${size}`)
}

export async function getPayrollRun(id: string) {
  return apiFetch<PayrollRun>(`/api/v1/payroll/runs/${id}`)
}

export async function createPayrollRun(periodStart: string, periodEnd: string) {
  return apiFetch<PayrollRun>('/api/v1/payroll/runs', {
    method: 'POST',
    body: JSON.stringify({ periodStart, periodEnd }),
  })
}

export async function calculatePayrollRun(id: string) {
  return apiFetch<PayrollRun>(`/api/v1/payroll/runs/${id}/calculate`, {
    method: 'POST',
  })
}

export async function approvePayrollRun(id: string) {
  return apiFetch<PayrollRun>(`/api/v1/payroll/runs/${id}/approve`, {
    method: 'POST',
  })
}

export async function postPayrollRun(id: string) {
  return apiFetch<PayrollRun>(`/api/v1/payroll/runs/${id}/post`, {
    method: 'POST',
  })
}

export async function cancelPayrollRun(id: string) {
  return apiFetch<PayrollRun>(`/api/v1/payroll/runs/${id}/cancel`, {
    method: 'POST',
  })
}

export async function listPayslips(runId: string) {
  return apiFetch<Payslip[]>(`/api/v1/payroll/runs/${runId}/payslips`)
}

export async function getPayslip(id: string) {
  return apiFetch<Payslip>(`/api/v1/payroll/payslips/${id}`)
}

// â”€â”€ Settings APIs â”€â”€

export async function getPayrollSettings() {
  return apiFetch<PayrollSettings>('/api/v1/payroll/settings')
}

export async function updatePayrollSettings(req: PayrollSettings) {
  return apiFetch<PayrollSettings>('/api/v1/payroll/settings', {
    method: 'PUT',
    body: JSON.stringify(req),
  })
}