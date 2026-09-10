import { apiFetch } from '@/api/client/api-client'

export type FiscalPeriodStatus = 'OPEN' | 'SOFT_CLOSED' | 'CLOSED' | 'LOCKED' | string

export interface FiscalPeriod {
  id: string
  periodYear: number
  periodMonth: number
  status: FiscalPeriodStatus
  closedAt?: string | null
  closedBy?: string | null
  createdAt?: string | null
  updatedAt?: string | null
  orgId?: string
}

/**
 * Lists all fiscal periods for the active organization.
 * GET /api/v1/accounting/periods
 */
export async function listPeriods(): Promise<FiscalPeriod[]> {
  return apiFetch<FiscalPeriod[]>('/api/v1/accounting/periods')
}

export function closePeriod(year: number, month: number) {
  return apiFetch<FiscalPeriod>(`/api/v1/accounting/periods/${year}/${month}/close`, {
    method: 'POST',
  })
}

export function reopenPeriod(year: number, month: number) {
  return apiFetch<FiscalPeriod>(`/api/v1/accounting/periods/${year}/${month}/reopen`, {
    method: 'POST',
  })
}

export function lockPeriod(year: number, month: number) {
  return apiFetch<FiscalPeriod>(`/api/v1/accounting/periods/${year}/${month}/lock`, {
    method: 'POST',
  })
}

export function closeYear(fiscalYear: number) {
  return apiFetch<unknown>(`/api/v1/accounting/periods/year-end-close/${fiscalYear}`, {
    method: 'POST',
  })
}

export function reopenYear(fiscalYear: number) {
  return apiFetch<{ reversalEntryId: string; reversalEntryNumber: string }>(
    `/api/v1/accounting/periods/year-end-close/${fiscalYear}/reopen`,
    {
      method: 'POST',
    }
  )
}
