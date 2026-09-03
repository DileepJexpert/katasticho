import { apiFetch } from '@/api/client/api-client'

export type BmrStepRecord = {
  id: string
  workOrderId: string
  jobCardId?: string | null
  stepNumber?: number
  operationName?: string
  parameterKey: string
  parameterName?: string
  parameterValue: string
  targetValue?: string
  minValue?: string
  maxValue?: string
  measuredValue?: string
  unit?: string | null
  notes?: string | null
  recordedBy?: string | null
  recordedAt?: string
  createdAt?: string
}

export type BmrSignoff = {
  id: string
  workOrderId: string
  jobCardId?: string | null
  stageName?: string
  role: 'OPERATOR' | 'SUPERVISOR' | 'QA_LEAD' | 'QA_HEAD' | 'QA_MANAGER' | string
  notes?: string | null
  remarks?: string | null
  signedBy?: string | null
  signedAt?: string
  createdAt?: string
}

export type BmrDeviation = {
  id: string
  workOrderId: string
  jobCardId?: string | null
  deviationNumber?: string
  severity: 'CRITICAL' | 'MAJOR' | 'MINOR' | string
  title: string
  description: string
  immediateActionTaken?: string
  status: 'OPEN' | 'LOGGED' | 'UNDER_INVESTIGATION' | 'RESOLVED' | 'CLOSED' | string
  resolution?: string | null
  resolvedBy?: string | null
  resolvedAt?: string | null
  loggedBy?: string | null
  createdAt?: string
}

export type BmrYieldReconciliation = {
  workOrderId: string
  theoreticalYield?: number
  actualYield?: number
  yieldPercentage?: number
  minAcceptableYieldPercentage?: number
  maxAcceptableYieldPercentage?: number
  scrapQty?: number
  scrapPercentage?: number
  status?: string
}

export type BmrSnapshot = {
  workOrder: Record<string, unknown>
  stepRecords: BmrStepRecord[]
  signoffs: BmrSignoff[]
  deviations: BmrDeviation[]
  yieldReconciliation: BmrYieldReconciliation
}

export async function listBmrStepRecords(workOrderId: string) {
  return apiFetch<BmrStepRecord[]>(`/api/v1/manufacturing/bmr/work-orders/${workOrderId}/step-records`)
}

export async function recordBmrStep(data: {
  workOrderId: string
  jobCardId?: string | null
  stepNumber?: number
  operationName?: string
  parameterName?: string
  parameterKey?: string
  targetValue?: string
  minValue?: string
  maxValue?: string
  measuredValue?: string
  parameterValue?: string
  unit?: string | null
  notes?: string | null
}) {
  return apiFetch<BmrStepRecord>('/api/v1/manufacturing/bmr/step-records', {
    method: 'POST',
    body: JSON.stringify({
      workOrderId: data.workOrderId,
      jobCardId: data.jobCardId ?? null,
      parameterKey: data.parameterKey || data.parameterName || 'parameter',
      parameterValue: data.parameterValue || data.measuredValue || '',
      unit: data.unit ?? null,
      notes: data.notes ?? null,
    }),
  })
}

export const recordBmrStepParameter = recordBmrStep

export async function listBmrSignoffs(workOrderId: string) {
  return apiFetch<BmrSignoff[]>(`/api/v1/manufacturing/bmr/work-orders/${workOrderId}/signoffs`)
}

export async function signoffBmr(data: {
  workOrderId: string
  jobCardId?: string | null
  stageName?: string
  role: string
  remarks?: string | null
  notes?: string | null
}) {
  return apiFetch<BmrSignoff>('/api/v1/manufacturing/bmr/signoffs', {
    method: 'POST',
    body: JSON.stringify({
      workOrderId: data.workOrderId,
      jobCardId: data.jobCardId ?? null,
      role: data.role,
      notes: data.remarks || data.notes || null,
    }),
  })
}

export const recordBmrSignoff = signoffBmr

export async function listBmrDeviations(workOrderId: string) {
  return apiFetch<BmrDeviation[]>(`/api/v1/manufacturing/bmr/work-orders/${workOrderId}/deviations`)
}

export async function raiseBmrDeviation(data: {
  workOrderId: string
  jobCardId?: string | null
  severity: string
  title: string
  description: string
  immediateActionTaken?: string
}) {
  return apiFetch<BmrDeviation>('/api/v1/manufacturing/bmr/deviations', {
    method: 'POST',
    body: JSON.stringify({
      workOrderId: data.workOrderId,
      jobCardId: data.jobCardId ?? null,
      severity: data.severity,
      title: data.title,
      description: data.immediateActionTaken
        ? `${data.description} [Immediate Action: ${data.immediateActionTaken}]`
        : data.description,
    }),
  })
}

export const logBmrDeviation = raiseBmrDeviation

export async function resolveBmrDeviation(deviationId: string, data: {
  status?: string
  rootCause?: string
  correctiveActionPlan?: string
  resolutionNotes?: string
  resolution?: string
}) {
  const resolutionText = data.resolution || [
    data.rootCause ? `Root Cause: ${data.rootCause}` : '',
    data.correctiveActionPlan ? `CAPA: ${data.correctiveActionPlan}` : '',
    data.resolutionNotes ? `Notes: ${data.resolutionNotes}` : '',
  ].filter(Boolean).join(' | ')

  return apiFetch<BmrDeviation>(`/api/v1/manufacturing/bmr/deviations/${deviationId}`, {
    method: 'PUT',
    body: JSON.stringify({
      status: data.status || 'RESOLVED',
      resolution: resolutionText,
    }),
  })
}

export async function getYieldReconciliation(workOrderId: string) {
  return apiFetch<BmrYieldReconciliation>(`/api/v1/manufacturing/bmr/work-orders/${workOrderId}/yield-reconciliation`)
}

export const getBmrYieldReconciliation = getYieldReconciliation

export async function getBmrSnapshot(workOrderId: string) {
  return apiFetch<BmrSnapshot>(`/api/v1/manufacturing/bmr/work-orders/${workOrderId}/snapshot`)
}

export function getBmrPdfDownloadUrl(workOrderId: string) {
  return `/api/v1/manufacturing/bmr/work-orders/${workOrderId}/pdf`
}

export async function downloadBmrPdf(workOrderId: string) {
  const url = getBmrPdfDownloadUrl(workOrderId)
  const link = document.createElement('a')
  link.href = url
  link.download = `BMR-${workOrderId}.pdf`
  link.target = '_blank'
  document.body.appendChild(link)
  link.click()
  document.body.removeChild(link)
}
