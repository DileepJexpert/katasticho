import { apiFetch } from '@/api/client/api-client'

export type FiscalPeriod = {
  id: string
  orgId: string
  periodYear: number
  periodMonth: number
  status: 'OPEN' | 'SOFT_CLOSED' | 'CLOSED' | 'LOCKED' | string
  closedBy?: string | null
  closedAt?: string | null
  lockedBy?: string | null
  lockedAt?: string | null
}

export type ContinuousCloseChecklist = {
  year: number
  month: number
  canClose: boolean
  checks: {
    name: string
    passed: boolean
    description: string
    unresolvedCount?: number
  }[]
}

export async function listPeriods() {
  return apiFetch<FiscalPeriod[]>('/api/v1/accounting/periods')
}

export async function closePeriod(year: number, month: number) {
  return apiFetch<FiscalPeriod>(`/api/v1/accounting/periods/${year}/${month}/close`, {
    method: 'POST',
  })
}

export async function reopenPeriod(year: number, month: number) {
  return apiFetch<FiscalPeriod>(`/api/v1/accounting/periods/${year}/${month}/reopen`, {
    method: 'POST',
  })
}

export async function lockPeriod(year: number, month: number) {
  return apiFetch<FiscalPeriod>(`/api/v1/accounting/periods/${year}/${month}/lock`, {
    method: 'POST',
  })
}

export async function closeYear(fiscalYear: number) {
  return apiFetch<{ journalEntryId: string; closingAmount: number }>(`/api/v1/accounting/periods/year-end-close/${fiscalYear}`, {
    method: 'POST',
  })
}

export async function reopenYear(fiscalYear: number) {
  return apiFetch<void>(`/api/v1/accounting/periods/year-end-close/${fiscalYear}/reopen`, {
    method: 'POST',
  })
}

export async function getContinuousCloseChecklist(year: number, month: number) {
  return apiFetch<ContinuousCloseChecklist>(`/api/v1/accounting/continuous-close/${year}/${month}/checklist`)
}

export async function closePeriodGuarded(year: number, month: number, force = false) {
  return apiFetch<Record<string, unknown>>(`/api/v1/accounting/continuous-close/${year}/${month}/close?force=${force}`, {
    method: 'POST',
  })
}
