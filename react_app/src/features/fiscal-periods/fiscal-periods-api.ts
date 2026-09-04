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
