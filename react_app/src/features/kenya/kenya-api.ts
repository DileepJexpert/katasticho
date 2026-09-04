import { apiFetch } from '@/api/client/api-client'

export type KraEtimsInvoice = {
  id: string
  invoiceId: string
  invoiceNumber: string
  customerPin?: string | null
  customerName?: string | null
  taxableAmount: number
  vatAmount: number
  totalAmount: number
  controlNumber?: string | null
  qrCodeUrl?: string | null
  status: 'SUBMITTED' | 'ACCEPTED' | 'REJECTED' | 'FAILED' | string
  rejectionReason?: string | null
  submittedAt?: string
}

export type MpesaTransaction = {
  id: string
  checkoutRequestId: string
  merchantRequestId?: string
  phoneNumber: string
  amount: number
  mpesaReceiptNumber?: string | null
  transactionDate?: string | null
  status: 'PENDING' | 'SUCCESS' | 'FAILED' | string
  resultDesc?: string | null
  referenceId?: string | null
  referenceType?: string | null
  createdAt?: string
}

export type KenyaPayeResult = {
  grossSalary: number
  nssfTier1: number
  nssfTier2: number
  totalNssf: number
  taxablePay: number
  payeBeforeRelief: number
  personalRelief: number
  insuranceRelief: number
  netPaye: number
  nhifShif: number
  housingLevy: number
  netTakeHome: number
}

// ── KRA eTIMS Calls ──

export async function listKraEtimsInvoices() {
  return apiFetch<KraEtimsInvoice[]>('/api/v1/kenya/etims/invoices')
}

export async function submitToKraEtims(invoiceId: string) {
  return apiFetch<KraEtimsInvoice>(`/api/v1/kenya/etims/submit/${invoiceId}`, {
    method: 'POST',
  })
}

// ── M-Pesa Calls ──

export async function listMpesaTransactions() {
  return apiFetch<MpesaTransaction[]>('/api/v1/kenya/mpesa/transactions')
}

export async function initiateMpesaStkPush(data: {
  phoneNumber: string
  amount: number
  accountReference: string
  transactionDesc?: string
  invoiceId?: string
}) {
  return apiFetch<MpesaTransaction>('/api/v1/kenya/mpesa/stk-push', {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

// ── Kenya Statutory Payroll Calls ──

export async function calculateKenyaPaye(grossSalary: number, hasInsuranceRelief = false) {
  return apiFetch<KenyaPayeResult>('/api/v1/kenya/payroll/calculate-paye', {
    method: 'POST',
    body: JSON.stringify({ grossSalary, hasInsuranceRelief }),
  })
}
