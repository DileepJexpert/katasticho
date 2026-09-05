import { apiFetch } from '@/api/client/api-client'

export type AmortizationSchedule = {
  id: string
  orgId: string
  scheduleType: 'PREPAID' | 'DEFERRED_INCOME' | 'ACCRUAL' | string
  description: string
  reference: string | null
  totalAmount: number | string
  recognizedAmount: number | string
  startYear: number
  startMonth: number
  numberOfPeriods: number
  debitAccountCode: string
  creditAccountCode: string
  status: 'ACTIVE' | 'COMPLETED' | 'CANCELLED' | string
  notes: string | null
  createdAt?: string
  updatedAt?: string
}

export type AmortizationEntry = {
  id: string
  scheduleId: string
  periodYear: number
  periodMonth: number
  amount: number | string
  journalEntryId: string | null
  createdAt: string
}

export type AmortizationDetailResponse = {
  schedule: AmortizationSchedule
  periodAmount: number | string
  remaining: number | string
  entries: AmortizationEntry[]
}

export type CreateAmortizationScheduleRequest = {
  scheduleType: string
  description: string
  reference?: string
  totalAmount: number
  startYear: number
  startMonth: number
  numberOfPeriods: number
  debitAccountCode: string
  creditAccountCode: string
  notes?: string
}

export async function listAmortizationSchedules() {
  return apiFetch<AmortizationSchedule[]>('/api/v1/amortization')
}

export async function getAmortizationSchedule(id: string) {
  return apiFetch<AmortizationDetailResponse>(`/api/v1/amortization/${id}`)
}

export async function createAmortizationSchedule(req: CreateAmortizationScheduleRequest) {
  return apiFetch<AmortizationSchedule>('/api/v1/amortization', {
    method: 'POST',
    body: req,
  })
}

export async function postAmortizationPeriod(year: number, month: number) {
  const result = await apiFetch<{ scheduleCount: number; totalRecognized: number; journalEntryId: string | null }>(`/api/v1/amortization/run?year=${year}&month=${month}`, { method: 'POST' })
  return { count: result.scheduleCount, total: result.totalRecognized, journalEntryId: result.journalEntryId }
}
