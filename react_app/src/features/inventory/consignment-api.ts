import { apiFetch } from '@/api/client/api-client'

export type ConsignmentStock = {
  id: string
  itemId: string
  warehouseId: string
  supplierId: string
  quantity: number | string
  unitCost: number | string
  consignmentDate: string | null
  agreementRef?: string | null
  status: 'ACTIVE' | 'CLOSED' | string
  settlementMethod: string
}

export type ConsignmentSettlement = {
  id: string
  consignmentStockId: string
  settlementNumber: string
  quantitySold: number | string
  unitCost: number | string
  totalAmount: number | string
  settlementDate: string | null
  status: 'DRAFT' | 'SETTLED' | string
}

export async function getConsignmentStock() {
  return apiFetch<ConsignmentStock[]>('/api/v1/inventory/consignment/stock')
}

export async function receiveConsignment(req: {
  itemId: string
  warehouseId: string
  supplierId: string
  quantity: number
  unitCost: number
  consignmentDate?: string
  agreementRef?: string
}) {
  return apiFetch<ConsignmentStock>('/api/v1/inventory/consignment/receive', {
    method: 'POST',
    body: req,
  })
}

export async function recordConsignmentSale(req: { consignmentStockId: string; quantitySold: number }) {
  return apiFetch<ConsignmentSettlement>('/api/v1/inventory/consignment/record-sale', {
    method: 'POST',
    body: req,
  })
}

export async function settleConsignment(id: string) {
  return apiFetch<ConsignmentSettlement>(`/api/v1/inventory/consignment/${id}/settle`, {
    method: 'POST',
  })
}

export function getUnsettledConsignmentSales(supplierId: string) {
  return apiFetch<ConsignmentSettlement[]>(`/api/v1/inventory/consignment/unsettled/${supplierId}`)
}
