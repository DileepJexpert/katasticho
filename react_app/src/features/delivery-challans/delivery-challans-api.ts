import { apiFetch } from '@/api/client/api-client'

export type DeliveryChallanLine = {
  id: string
  salesOrderLineId: string | null
  lineNumber: number
  itemId: string | null
  itemName: string | null
  description: string | null
  quantity: number | string | null
  unit: string | null
  batchId: string | null
  batchNumber: string | null
}

export type DeliveryChallan = {
  id: string
  challanNumber: string
  salesOrderId: string | null
  salesOrderNumber: string | null
  contactId: string | null
  contactName: string | null
  challanDate: string | null
  status: string
  dispatchDate: string | null
  warehouseId: string | null
  warehouseName: string | null
  deliveryMethod: string | null
  vehicleNumber: string | null
  trackingNumber: string | null
  notes: string | null
  shippingAddress: string | null
  lines: DeliveryChallanLine[]
  createdAt: string | null
  salesOrderInvoicedStatus: string | null
}

export type DeliveryChallanPage = {
  content: DeliveryChallan[]
  page: number
  size: number
  totalElements: number
  totalPages: number
  last: boolean
}

type ListDeliveryChallansOptions = {
  page: number
  status: string | null
  salesOrderId?: string | null
}

export async function listDeliveryChallans({ page, status, salesOrderId }: ListDeliveryChallansOptions) {
  const params = new URLSearchParams({ page: String(page), size: '25', sort: 'challanDate,desc' })
  if (status) params.set('status', status)
  if (salesOrderId) params.set('salesOrderId', salesOrderId)
  return apiFetch<DeliveryChallanPage>(`/api/v1/delivery-challans?${params.toString()}`)
}

export function getDeliveryChallan(id: string) {
  return apiFetch<DeliveryChallan>(`/api/v1/delivery-challans/${id}`)
}

export type CreateDeliveryChallanLineRequest = {
  soLineId: string
  quantity: number
  batchId?: string
}

export type CreateDeliveryChallanRequest = {
  salesOrderId: string
  lines: CreateDeliveryChallanLineRequest[]
  challanDate?: string
  deliveryMethod?: string
  vehicleNumber?: string
  trackingNumber?: string
  notes?: string
  shippingAddress?: string
}

export function createDeliveryChallan(req: CreateDeliveryChallanRequest) {
  return apiFetch<DeliveryChallan>('/api/v1/delivery-challans', {
    method: 'POST',
    body: req,
  })
}

export function dispatchDeliveryChallan(id: string) {
  return apiFetch<DeliveryChallan>(`/api/v1/delivery-challans/${id}/dispatch`, {
    method: 'POST',
  })
}

