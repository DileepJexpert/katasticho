import { apiFetch } from '@/api/client/api-client'

export const networkRoles = ['OWNER', 'ADMIN', 'OPERATOR'] as const
type Amount = number | string
export type TradingPartner = {
  id: string; sellerOrgId: string; buyerOrgId: string; sellerOrgName: string; buyerOrgName: string
  status: string; requestedByOrgId: string; creditLimit: Amount | null; paymentTerms: string | null
  deliveryTerms: string | null; notes: string | null; createdAt: string; approvedAt: string | null
}
export type CatalogItem = {
  id: string; sellerOrgId: string; itemId: string; drugMasterId: string | null; displayName: string
  publishedSku: string | null; hsnCode: string | null; manufacturer: string | null; packSize: string | null
  category: string | null; description: string | null; publishedMrp: Amount | null; publishedPtr: Amount | null
  minOrderQty: Amount | null; availabilityStatus: string; isActive: boolean
}
export type CatalogRequest = Omit<CatalogItem, 'id' | 'sellerOrgId' | 'isActive'>
export type NetworkLine = {
  id: string; catalogItemId: string | null; buyerItemId: string | null; sellerItemId: string | null
  displayName: string | null; hsnCode: string | null; orderedQty: Amount; confirmedQty: Amount | null
  dispatchedQty: Amount | null; unitPrice: Amount; lineTotal: Amount; status: string; sellerNotes: string | null
}
export type NetworkOrder = {
  id: string; orderNumber: string; buyerOrgId: string; sellerOrgId: string; buyerOrgName: string
  sellerOrgName: string; tradingPartnerId: string; buyerPoId: string | null; sellerSoId: string | null
  status: string; totalAmount: Amount; totalQty: Amount; requestedDeliveryDate: string | null
  buyerNotes: string | null; sellerNotes: string | null; createdAt: string; confirmedAt: string | null
  dispatchedAt: string | null; deliveredAt: string | null; lines: NetworkLine[]
}
export type NetworkEvent = { id: string; eventType: string; actorOrgId: string; createdAt: string; payload: Record<string, unknown> | null }
export type OrderAction = 'cancel' | 'reject' | 'dispatch' | 'deliver'
const root = '/api/v1/partner-network'
export const listPartners = () => apiFetch<TradingPartner[]>(`${root}/partners`)
export const listCatalog = () => apiFetch<CatalogItem[]>(`${root}/catalog`)
export const searchSupplierCatalog = (search: string) => apiFetch<CatalogItem[]>(`${root}/supplier-search?${new URLSearchParams({ search })}`)
export const publishCatalogItem = (body: CatalogRequest) => apiFetch<unknown>(`${root}/catalog`, { method: 'POST', body })
export const unpublishCatalogItem = (id: string) => apiFetch<void>(`${root}/catalog/${encodeURIComponent(id)}/unpublish`, { method: 'POST' })
export const partnerAction = (id: string, action: 'approve' | 'reject' | 'suspend') => apiFetch<unknown>(`${root}/partners/${encodeURIComponent(id)}/${action}`, { method: 'POST' })
export const listNetworkOrders = (direction: 'outgoing' | 'incoming') => apiFetch<NetworkOrder[]>(`${root}/orders/${direction}`)
export const getNetworkOrder = (id: string) => apiFetch<NetworkOrder>(`${root}/orders/${encodeURIComponent(id)}`)
export const getNetworkEvents = (id: string) => apiFetch<NetworkEvent[]>(`${root}/orders/${encodeURIComponent(id)}/events`)
export const networkOrderAction = (id: string, action: OrderAction, reason?: string) => apiFetch<NetworkOrder>(`${root}/orders/${encodeURIComponent(id)}/${action}`, { method: 'POST', ...(action === 'reject' ? { body: { reason: reason ?? '' } } : {}) })

export function allowedOrderActions(order: NetworkOrder, orgId: string): OrderAction[] {
  if (order.buyerOrgId === orgId) return order.status === 'PLACED' ? ['cancel'] : order.status === 'DISPATCHED' ? ['deliver'] : []
  if (order.sellerOrgId === orgId) return order.status === 'PLACED' ? ['reject'] : ['CONFIRMED', 'PARTIALLY_CONFIRMED'].includes(order.status) ? ['dispatch'] : []
  return []
}

export const networkWriteBlockers = {
  request: 'New partnership requests need an authorised organisation directory. The existing API requires an organisation ID but exposes no partner discovery endpoint; raw ID entry is not offered.',
  order: 'New order placement and quantity confirmation await backend validation of seller catalog ownership, item ownership and confirmed quantities. Existing orders and tracking remain available.',
  linking: 'PO/SO linking is unavailable until the backend validates the document tenant and the buyer/seller side. Existing links are shown only for your own organisation.',
}
