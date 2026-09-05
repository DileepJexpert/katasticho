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
