import { apiFetch } from '@/api/client/api-client'

export type SalesOrderLine = {
  id: string
  lineNumber: number
  itemId: string | null
  itemName: string | null
  description: string | null
  quantity: number | string | null
  quantityShipped: number | string | null
  quantityInvoiced: number | string | null
  quantityBackordered: number | string | null
  unit: string | null
  rate: number | string | null
  discountPct: number | string | null
  taxRate: number | string | null
  hsnCode: string | null
  amount: number | string | null
}

export type SalesOrder = {
  id: string
  salesOrderNumber: string
  contactId: string
  contactName: string | null
  orderDate: string | null
  expectedShipmentDate: string | null
  referenceNumber: string | null
  status: string
  shippedStatus: string | null
  invoicedStatus: string | null
  currency: string | null
  subtotal: number | string | null
  taxAmount: number | string | null
  shippingCharge: number | string | null
  adjustment: number | string | null
  totalAmount: number | string | null
  deliveryMethod: string | null
  placeOfSupply: string | null
  notes: string | null
  terms: string | null
  warehouseName: string | null
  lines: SalesOrderLine[]
  linkedInvoiceCount: number
  linkedChallanCount: number
  allowBackorder: boolean
}

export type SalesOrderPage = {
  content: SalesOrder[]
  page: number
  size: number
  totalElements: number
  totalPages: number
  last: boolean
}

type ListSalesOrdersOptions = {
  page: number
  status: string | null
}

export async function listSalesOrders({ page, status }: ListSalesOrdersOptions) {
  const params = new URLSearchParams({ page: String(page), size: '25', sort: 'orderDate,desc' })
  if (status) params.set('status', status)
  return apiFetch<SalesOrderPage>(`/api/v1/sales-orders?${params.toString()}`)
}

export function getSalesOrder(id: string) {
  return apiFetch<SalesOrder>(`/api/v1/sales-orders/${id}`)
}

export type CreateSalesOrderLineRequest = {
  itemId?: string
  description: string
  hsnCode?: string
  quantity: number
  rate: number
  unit?: string
  discountPct?: number
  taxGroupId?: string
}

export type CreateSalesOrderRequest = {
  contactId: string
  lines: CreateSalesOrderLineRequest[]
  orderDate?: string
  expectedShipmentDate?: string
  referenceNumber?: string
  deliveryMethod?: string
  placeOfSupply?: string
  notes?: string
  terms?: string
  warehouseId?: string
  allowBackorder?: boolean
}

export function createSalesOrder(req: CreateSalesOrderRequest) {
  return apiFetch<SalesOrder>('/api/v1/sales-orders', {
    method: 'POST',
    body: req,
  })
}

