import { apiFetch } from '@/api/client/api-client'

export type JobWorkOrderLine = {
  id: string
  jobWorkOrderId: string
  itemId: string
  itemName?: string | null
  lineType: string
  sentQty: number | string
  receivedQty: number | string
  wastageQty: number | string
  unitCost: number | string
  lineCost: number | string
  status: string
}

export type JobWorkOrder = {
  id: string
  jobWorkNumber: string
  vendorId: string
  vendorName?: string | null
  warehouseId: string
  warehouseName?: string | null
  workOrderId: string | null
  status: string
  processingCharges: number | string
  totalMaterialCost: number | string
  totalCost: number | string
  challanNumber: string | null
  plannedSendDate: string | null
  plannedReturnDate: string | null
  actualSendDate: string | null
  actualReturnDate: string | null
  gstReturnDeadline: string | null
  notes: string | null
  lines: JobWorkOrderLine[]
}

export type JobWorkOrderPage = {
  content: JobWorkOrder[]
  page: number
  size: number
  totalElements: number
  totalPages: number
  last: boolean
}

export async function listJobWorkOrders({ page, status }: { page: number; status?: string | null }) {
  const params = new URLSearchParams({
    page: String(page),
    size: '25',
  })
  if (status) params.set('status', status)

  return apiFetch<JobWorkOrderPage>(`/api/v1/manufacturing/job-work?${params.toString()}`)
}

export function getJobWorkOrder(id: string) {
  return apiFetch<JobWorkOrder>(`/api/v1/manufacturing/job-work/${id}`)
}

export function getJobWorkGstAlerts(days = 30) {
  return apiFetch<JobWorkOrder[]>(`/api/v1/manufacturing/job-work/gst-alerts?days=${days}`)
}

export async function createJobWorkOrder(data: {
  vendorId: string
  warehouseId: string
  processingCharges?: number | string | null
  plannedSendDate?: string | null
  plannedReturnDate?: string | null
  materials: Array<{ itemId: string; qty: number | string }>
  outputs: Array<{ itemId: string; qty: number | string }>
  notes?: string | null
}) {
  return apiFetch<JobWorkOrder>('/api/v1/manufacturing/job-work', {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

export async function sendJobWorkMaterials(id: string) {
  return apiFetch<JobWorkOrder>(`/api/v1/manufacturing/job-work/${id}/send`, {
    method: 'POST',
  })
}

export async function receiveJobWorkGoods(id: string, lines: Array<{
  itemId: string
  receivedQty: number | string
  wastageQty?: number | string | null
}>) {
  return apiFetch<JobWorkOrder>(`/api/v1/manufacturing/job-work/${id}/receive`, {
    method: 'POST',
    body: JSON.stringify({ lines }),
  })
}

export async function cancelJobWorkOrder(id: string) {
  return apiFetch<JobWorkOrder>(`/api/v1/manufacturing/job-work/${id}/cancel`, {
    method: 'POST',
  })
}