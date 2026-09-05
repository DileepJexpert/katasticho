import { apiFetch } from '@/api/client/api-client'

export type FranchiseNode = {
  id: string; nodeCode: string; nodeName: string; nodeType: string; branchId?: string | null
  contactEmail?: string | null; phone?: string | null; city?: string | null; stateCode?: string | null
  royaltyRatePercent: number | string; fixedMonthlyFee: number | string; active: boolean
  lastSyncAt?: string | null; createdAt?: string
}
export type FranchiseNodeRequest = Omit<FranchiseNode, 'id' | 'lastSyncAt' | 'createdAt'>
export type FranchiseCatalogPolicy = {
  id?: string; autoSyncNewItems: boolean; allowBranchPriceOverride: boolean
  maxDiscountFromMrpPercent: number | string; minMarginPercent: number | string; syncMode: string
}
export type FranchiseRoyaltySettlement = {
  id: string; franchiseNodeId: string; nodeCode: string; nodeName: string; periodStart: string; periodEnd: string
  grossSalesAmount: number | string; royaltyPercent: number | string; royaltyAmount: number | string
  fixedFeeAmount: number | string; totalSettlementAmount: number | string; status: string; generatedInvoiceId: string | null
}
export const franchiseIntegrationNotice = 'Royalty calculation, royalty invoicing, catalog sync, and branch price overrides are unavailable in the current backend. Saved nodes and policies do not enable those integrations.'
export function listFranchiseNodes() { return apiFetch<FranchiseNode[]>('/api/v1/franchise/nodes') }
export function createFranchiseNode(body: FranchiseNodeRequest) { return apiFetch<FranchiseNode>('/api/v1/franchise/nodes', { method: 'POST', body }) }
export function updateFranchiseNode(id: string, body: Partial<FranchiseNodeRequest>) { return apiFetch<FranchiseNode>(`/api/v1/franchise/nodes/${id}`, { method: 'PUT', body }) }
export function deleteFranchiseNode(id: string) { return apiFetch<string>(`/api/v1/franchise/nodes/${id}`, { method: 'DELETE' }) }
export function getFranchisePolicy() { return apiFetch<FranchiseCatalogPolicy>('/api/v1/franchise/policy') }
export function saveFranchisePolicy(body: FranchiseCatalogPolicy) { return apiFetch<FranchiseCatalogPolicy>('/api/v1/franchise/policy', { method: 'PUT', body }) }
export function listRoyaltySettlements(nodeId?: string) { return apiFetch<FranchiseRoyaltySettlement[]>(`/api/v1/franchise/settlements${nodeId ? '?nodeId=' + encodeURIComponent(nodeId) : ''}`) }
