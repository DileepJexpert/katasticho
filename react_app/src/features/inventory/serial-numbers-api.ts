import { apiFetch } from '@/api/client/api-client'

export interface SerialNumberRecord {
  id: string
  itemId: string
  serial: string
  warehouseId: string | null
  batchId: string | null
  status: string
  receivedAt: string | null
  soldAt: string | null
  receiptLineId: string | null
  invoiceLineId: string | null
  notes: string | null
}

export interface SerialNumberPage {
  content: SerialNumberRecord[]
  totalElements: number
  totalPages: number
  last: boolean
}

export function listSerialNumbers(itemId: string, page: number) {
  const params = new URLSearchParams({ page: String(page), size: '25', sort: 'serial,asc' })
  return apiFetch<SerialNumberPage>(`/api/v1/serial-numbers/by-item/${encodeURIComponent(itemId)}?${params}`)
}

export function listAvailableSerials(itemId: string, warehouseId?: string) {
  const params = new URLSearchParams({ itemId })
  if (warehouseId) params.set('warehouseId', warehouseId)
  return apiFetch<SerialNumberRecord[]>(`/api/v1/serial-numbers/available?${params}`)
}

export interface ReceiveSerialsRequest {
  itemId: string
  warehouseId?: string
  batchId?: string
  receiptLineId?: string
  serials: string[]
}

export function receiveSerials(request: ReceiveSerialsRequest) {
  return apiFetch<SerialNumberRecord[]>('/api/v1/serial-numbers/receive', {
    method: 'POST',
    body: request,
  })
}

export interface AssignSaleSerialsRequest {
  itemId: string
  warehouseId?: string
  invoiceLineId?: string
  serials: string[]
}

export function assignSerialsToSale(request: AssignSaleSerialsRequest) {
  return apiFetch<SerialNumberRecord[]>('/api/v1/serial-numbers/assign-sale', {
    method: 'POST',
    body: request,
  })
}

export function markSerialDamaged(id: string, notes?: string) {
  return apiFetch<SerialNumberRecord>(`/api/v1/serial-numbers/${encodeURIComponent(id)}/damage`, {
    method: 'POST',
    body: notes ? { notes } : {},
  })
}

export function markSerialReturned(id: string) {
  return apiFetch<SerialNumberRecord>(`/api/v1/serial-numbers/${encodeURIComponent(id)}/return`, {
    method: 'POST',
  })
}
