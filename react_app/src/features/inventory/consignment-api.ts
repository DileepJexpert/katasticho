import { apiFetch } from '@/api/client/api-client'

export type ConsignmentStock = {
  id: string
  itemId: string
  itemName: string
  itemSku?: string | null
  warehouseId: string
  warehouseName: string
  supplierId: string
  supplierName?: string
  receivedQuantity: number | string
  remainingQuantity: number | string
  unitCost: number | string
  consignmentDate: string
  agreementRef?: string | null
  status: 'ACTIVE' | 'SETTLED' | string
}

export type ConsignmentSettlement = {
  id: string
  consignmentStockId: string
  quantitySettled: number | string
  settlementAmount: number | string
  settledAt: string
  billId?: string | null
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