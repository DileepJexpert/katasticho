import { apiFetch } from '@/api/client/api-client'

export type WorkOrderLine = {
  id: string
  workOrderId: string
  itemId: string
  itemName: string | null
  requiredQty: number | string
  requiredQuantity?: number | string
  issuedQty: number | string
  issuedQuantity?: number | string
  unitCost: number | string
  lineCost: number | string
  totalCost?: number | string
  uom?: string | null
  status: string
  batchId: string | null
  batchNumber: string | null
}

export type WorkOrder = {
  id: string
  workOrderNumber: string
  finishedGoodId: string
  finishedGoodName: string | null
  warehouseId: string
  warehouseName?: string | null
  quantityToProduce: number | string
  quantityProduced: number | string
  status: string
  plannedStartDate: string | null
  plannedEndDate: string | null
  actualStartDate: string | null
  actualEndDate: string | null
  rawMaterialCost: number | string
  directLaborCost: number | string
  overheadCost: number | string
  totalCost: number | string
  unitCost: number | string
  salesOrderId: string | null
  parentWorkOrderId: string | null
  routingId: string | null
  priority: string
  scrapQty: number | string
  scrapCost: number | string
  notes: string | null
  journalEntryId: string | null
  wipJournalEntryId: string | null
  backflushMode: boolean
  bomVersion: number | null
  approvalStatus: string
  approvedBy: string | null
  approvedAt: string | null
  disassembly: boolean
  lines: WorkOrderLine[]
}

export type JobCard = {
  id: string
  workOrderId: string
  jobCardNumber?: string
  operationId: string
  workstationId: string | null
  sequenceNumber: number
  sequence?: number
  assignedTo: string | null
  operationName: string | null
  workstationName: string | null
  assigneeName: string | null
  status: string
  plannedStart: string | null
  plannedEnd: string | null
  actualStart: string | null
  actualEnd: string | null
  plannedQty: number | string
  completedQty: number | string
  scrapQty: number | string
  timeLoggedMinutes: number
  notes: string | null
}

export type ProductionScrap = {
  id: string
  workOrderId: string
  itemId: string
  itemName?: string | null
  scrapQty: number | string
  scrapCost?: number | string | null
  reasonCodeId?: string | null
  reasonCode?: string | null
  jobCardId?: string | null
  notes?: string | null
  createdAt: string
}

export type WorkOrderPage = {
  content: WorkOrder[]
  page: number
  size: number
  totalElements: number
  totalPages: number
  last: boolean
}

export async function listWorkOrders({ page, status, priority }: { page: number; status?: string | null; priority?: string | null }) {
  const params = new URLSearchParams({
    page: String(page),
    size: '25',
  })
  if (status) params.set('status', status)
  if (priority) params.set('priority', priority)

  return apiFetch<WorkOrderPage>(`/api/v1/manufacturing/work-orders?${params.toString()}`)
}

export function getWorkOrder(id: string) {
  return apiFetch<WorkOrder>(`/api/v1/manufacturing/work-orders/${id}`)
}

export function getJobCardsForWorkOrder(workOrderId: string) {
  return apiFetch<JobCard[]>(`/api/v1/manufacturing/work-orders/${workOrderId}/job-cards`)
}

export function listChildWorkOrders(workOrderId: string) {
  return apiFetch<WorkOrder[]>(`/api/v1/manufacturing/work-orders/${workOrderId}/children`)
}

export function getScrapForWorkOrder(workOrderId: string) {
  return apiFetch<ProductionScrap[]>(`/api/v1/manufacturing/work-orders/${workOrderId}/scrap`)
}

export async function createWorkOrder(data: {
  finishedGoodId: string
  warehouseId: string
  quantityToProduce: number | string
  plannedStartDate?: string | null
  plannedEndDate?: string | null
  directLaborCost?: number | string | null
  overheadCost?: number | string | null
  notes?: string | null
  backflushMode?: boolean
  bomVersion?: number | null
  priority?: string
}) {
  return apiFetch<WorkOrder>('/api/v1/manufacturing/work-orders', {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

export async function issueToProduction(id: string) {
  return apiFetch<WorkOrder>(`/api/v1/manufacturing/work-orders/${id}/issue`, {
    method: 'POST',
  })
}

export async function receiveFinishedGoods(id: string, data: {
  quantityReceived: number | string
  batchNumber?: string | null
  expiryDate?: string | null
}) {
  return apiFetch<WorkOrder>(`/api/v1/manufacturing/work-orders/${id}/receive`, {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

export async function updateWorkOrderCosts(id: string, data: {
  directLaborCost?: number | string | null
  overheadCost?: number | string | null
}) {
  return apiFetch<WorkOrder>(`/api/v1/manufacturing/work-orders/${id}/costs`, {
    method: 'PUT',
    body: JSON.stringify(data),
  })
}

export async function cancelWorkOrder(id: string) {
  return apiFetch<WorkOrder>(`/api/v1/manufacturing/work-orders/${id}/cancel`, {
    method: 'POST',
  })
}

export async function cloneWorkOrder(id: string) {
  return apiFetch<WorkOrder>(`/api/v1/manufacturing/work-orders/${id}/clone`, {
    method: 'POST',
  })
}

export async function splitWorkOrder(id: string, firstQty: number | string) {
  return apiFetch<WorkOrder[]>(`/api/v1/manufacturing/work-orders/${id}/split`, {
    method: 'POST',
    body: JSON.stringify({ firstQty }),
  })
}

export async function createSubAssemblyWos(id: string) {
  return apiFetch<WorkOrder[]>(`/api/v1/manufacturing/work-orders/${id}/create-sub-assembly-wos`, {
    method: 'POST',
  })
}

export async function autoCreateFromReorder() {
  return apiFetch<WorkOrder[]>('/api/v1/manufacturing/work-orders/from-reorder', {
    method: 'POST',
  })
}

export async function startJobCard(id: string) {
  return apiFetch<JobCard>(`/api/v1/manufacturing/job-cards/${id}/start`, {
    method: 'POST',
  })
}

export async function completeJobCard(id: string, data: {
  completedQty?: number | string | null
  scrapQty?: number | string | null
  timeLoggedMinutes?: number
  notes?: string | null
}) {
  return apiFetch<JobCard>(`/api/v1/manufacturing/job-cards/${id}/complete`, {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

export async function recordProductionScrap(workOrderId: string, data: {
  itemId: string
  scrapQty: number | string
  reasonCodeId?: string | null
  jobCardId?: string | null
  notes?: string | null
}) {
  return apiFetch<ProductionScrap>(`/api/v1/manufacturing/work-orders/${workOrderId}/scrap`, {
    method: 'POST',
    body: JSON.stringify(data),
  })
}