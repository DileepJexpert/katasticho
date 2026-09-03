import { apiFetch } from '@/api/client/api-client'

export type QcInspectionResult = {
  id: string
  inspectionId: string
  parameterId: string
  parameterName?: string | null
  measuredValue: string | null
  numericValue: number | string | null
  isPassed: boolean | null
  notes: string | null
}

export type QcInspection = {
  id: string
  inspectionNumber: string
  templateId: string | null
  inspectionType: string
  referenceType: string | null
  referenceId: string | null
  itemId: string
  batchId: string | null
  inspectedQty: number | string
  acceptedQty: number | string
  rejectedQty: number | string
  status: string
  inspectorId: string | null
  itemName?: string | null
  inspectorName?: string | null
  batchNumber?: string | null
  referenceLabel?: string | null
  inspectedAt: string | null
  notes: string | null
  disposition: string | null
  holdQty: number | string | null
  quarantineZoneId: string | null
  dispositionNotes: string | null
  dispositionAt: string | null
  dispositionBy: string | null
  results: QcInspectionResult[]
}

export type QcTemplateParameter = {
  id?: string
  name: string
  description?: string
  parameterType: string
  unit?: string
  minValue?: number | string | null
  maxValue?: number | string | null
  acceptableValues?: string
  isMandatory?: boolean
}

export type QcTemplate = {
  id: string
  name: string
  itemId?: string | null
  itemName?: string | null
  inspectionType: string
  parameters: QcTemplateParameter[]
}

export type QcInspectionPage = {
  content: QcInspection[]
  page: number
  size: number
  totalElements: number
  totalPages: number
  last: boolean
}

export async function listQcInspections({ page }: { page: number }) {
  const params = new URLSearchParams({
    page: String(page),
    size: '25',
  })

  return apiFetch<QcInspectionPage>(`/api/v1/manufacturing/qc/inspections?${params.toString()}`)
}

export function getQcInspection(id: string) {
  return apiFetch<QcInspection>(`/api/v1/manufacturing/qc/inspections/${id}`)
}

export async function createQcInspection(data: {
  templateId?: string | null
  inspectionType: string
  referenceType?: string | null
  referenceId?: string | null
  itemId: string
  batchId?: string | null
  inspectedQty?: number | string | null
}) {
  return apiFetch<QcInspection>('/api/v1/manufacturing/qc/inspections', {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

export async function recordInspectionResults(id: string, results: Array<{
  parameterId: string
  measuredValue?: string | null
  numericValue?: number | string | null
  isPassed?: boolean | null
  notes?: string | null
}>) {
  return apiFetch<QcInspection>(`/api/v1/manufacturing/qc/inspections/${id}/results`, {
    method: 'POST',
    body: JSON.stringify({ results }),
  })
}

export async function finalizeInspection(id: string, data: {
  acceptedQty?: number | string | null
  rejectedQty?: number | string | null
  notes?: string | null
}) {
  return apiFetch<QcInspection>(`/api/v1/manufacturing/qc/inspections/${id}/finalize`, {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

export async function recordInspectionDisposition(id: string, data: {
  decision: string
  acceptedQty?: number | string | null
  rejectedQty?: number | string | null
  holdQty?: number | string | null
  quarantineZoneId?: string | null
  notes?: string | null
}) {
  return apiFetch<QcInspection>(`/api/v1/manufacturing/qc-inspections/${id}/disposition`, {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

export async function getCertificateOfAnalysis(id: string) {
  return apiFetch<Record<string, unknown>>(`/api/v1/manufacturing/qc-inspections/${id}/coa`)
}

export async function listQcTemplates() {
  return apiFetch<QcTemplate[]>('/api/v1/manufacturing/qc/templates')
}

export async function getQcTemplate(id: string) {
  return apiFetch<QcTemplate>(`/api/v1/manufacturing/qc/templates/${id}`)
}

export async function createQcTemplate(data: {
  name: string
  itemId?: string | null
  inspectionType: string
  parameters?: QcTemplateParameter[]
}) {
  return apiFetch<QcTemplate>('/api/v1/manufacturing/qc/templates', {
    method: 'POST',
    body: JSON.stringify(data),
  })
}