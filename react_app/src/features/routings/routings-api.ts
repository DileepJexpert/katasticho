import { apiFetch } from '@/api/client/api-client'

export type Operation = {
  id: string
  code: string
  name: string
  description?: string | null
  defaultWorkstationId?: string | null
  defaultWorkstationName?: string | null
  setupTimeMinutes: number
  runTimeMinutesPerUnit: number | string | null
}

export type RoutingOperation = {
  id: string
  routingId: string
  operationId: string
  operationName?: string | null
  workstationId?: string | null
  workstationName?: string | null
  sequenceNumber: number
  setupTimeOverride?: number | null
  runTimeOverride?: number | string | null
}

export type Routing = {
  id: string
  name: string
  itemId?: string | null
  itemName?: string | null
  isDefault: boolean
  operations: RoutingOperation[]
}

export type WorkstationAlternate = {
  id: string
  routingOperationId: string
  workstationId: string
  workstationName?: string | null
  priority?: number | null
  notes?: string | null
}

export async function listRoutings() {
  return apiFetch<Routing[]>('/api/v1/manufacturing/routings')
}

export async function getRouting(id: string) {
  return apiFetch<Routing>(`/api/v1/manufacturing/routings/${id}`)
}

export async function createRouting(data: {
  name: string
  itemId?: string | null
  isDefault?: boolean
  operations?: Array<{
    operationId: string
    workstationId?: string | null
    sequenceNumber: number
    setupTimeOverride?: number | null
    runTimeOverride?: number | string | null
  }>
}) {
  return apiFetch<Routing>('/api/v1/manufacturing/routings', {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

export async function listOperations() {
  return apiFetch<Operation[]>('/api/v1/manufacturing/operations')
}

export async function createOperation(data: {
  code: string
  name: string
  description?: string
  defaultWorkstationId?: string | null
  setupTimeMinutes?: number
  runTimeMinutesPerUnit?: number | string | null
}) {
  return apiFetch<Operation>('/api/v1/manufacturing/operations', {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

export async function listWorkstationAlternates(routingOperationId: string) {
  return apiFetch<WorkstationAlternate[]>(`/api/v1/manufacturing/routing-operations/${routingOperationId}/workstation-alternates`)
}

export async function addWorkstationAlternate(data: {
  routingOperationId: string
  workstationId: string
  priority?: number
  notes?: string
}) {
  return apiFetch<WorkstationAlternate>('/api/v1/manufacturing/workstation-alternates', {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

export async function deleteWorkstationAlternate(id: string) {
  return apiFetch<void>(`/api/v1/manufacturing/workstation-alternates/${id}`, {
    method: 'DELETE',
  })
}