import { apiFetch } from '@/api/client/api-client'

export type FranchiseNode = {
  id: string
  nodeCode: string
  name: string
  nodeType: 'COMPANY_OWNED' | 'FRANCHISE_FOFO' | 'FRANCHISE_COCO' | string
  contactPerson?: string | null
  phone?: string | null
  email?: string | null
  address?: string | null
  city?: string | null
  state?: string | null
  pincode?: string | null
  royaltyPercentage?: number
  active: boolean
  createdAt?: string
}

export type FranchiseCatalogPolicy = {
  id?: string
  allowLocalItemAdditions: boolean
  allowPriceOverrides: boolean
  defaultRoyaltyPercentage: number
  priceOverrideMaxDiscountPct: number
  priceOverrideMaxMarkupPct: number
  autoSyncCatalogOnItemCreate: boolean
}

export type CatalogSyncResult = {
  syncedNodesCount: number
  syncedItemsCount: number
  failedNodesCount: number
  details?: string
}

export type BranchPriceOverride = {
  id: string
  branchId: string
  branchName?: string
  itemId: string
  itemName?: string
  itemSku?: string
  standardSellingPrice: number
  overrideSellingPrice: number
  reason?: string | null
  createdAt?: string
}

export type FranchiseRoyaltySettlement = {
  id: string
  nodeId: string
  nodeName?: string
  settlementPeriod: string
  grossSalesAmount: number
  royaltyPercentage: number
  royaltyAmount: number
  journalEntryId?: string | null
  status: 'DRAFT' | 'CALCULATED' | 'POSTED' | 'PAID' | string
  calculatedAt?: string
  notes?: string | null
}

export async function listFranchiseNodes() {
  return apiFetch<FranchiseNode[]>('/api/v1/franchise/nodes')
}

export async function createFranchiseNode(data: Partial<FranchiseNode>) {
  return apiFetch<FranchiseNode>('/api/v1/franchise/nodes', {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

export async function updateFranchiseNode(id: string, data: Partial<FranchiseNode>) {
  return apiFetch<FranchiseNode>(`/api/v1/franchise/nodes/${id}`, {
    method: 'PUT',
    body: JSON.stringify(data),
  })
}

export async function deleteFranchiseNode(id: string) {
  return apiFetch<string>(`/api/v1/franchise/nodes/${id}`, {
    method: 'DELETE',
  })
}

export async function getFranchisePolicy() {
  return apiFetch<FranchiseCatalogPolicy>('/api/v1/franchise/policy')
}

export async function saveFranchisePolicy(data: FranchiseCatalogPolicy) {
  return apiFetch<FranchiseCatalogPolicy>('/api/v1/franchise/policy', {
    method: 'PUT',
    body: JSON.stringify(data),
  })
}

export async function pushCatalogToBranches(data: { itemIds?: string[]; nodeIds?: string[] }) {
  return apiFetch<CatalogSyncResult>('/api/v1/franchise/catalog-sync', {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

export async function listBranchPriceOverrides(branchId: string) {
  return apiFetch<BranchPriceOverride[]>(`/api/v1/franchise/branches/${branchId}/price-overrides`)
}

export async function saveBranchPriceOverride(data: Partial<BranchPriceOverride>) {
  return apiFetch<BranchPriceOverride>('/api/v1/franchise/price-overrides', {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

export async function deleteBranchPriceOverride(id: string) {
  return apiFetch<string>(`/api/v1/franchise/price-overrides/${id}`, {
    method: 'DELETE',
  })
}

export async function listRoyaltySettlements(nodeId?: string) {
  const params = new URLSearchParams()
  if (nodeId) params.set('nodeId', nodeId)
  return apiFetch<FranchiseRoyaltySettlement[]>(`/api/v1/franchise/settlements?${params.toString()}`)
}

export async function calculateRoyaltySettlement(data: { nodeId: string; period: string; grossSalesAmount: number }) {
  return apiFetch<FranchiseRoyaltySettlement>('/api/v1/franchise/settlements', {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

export async function postSettlementJournal(id: string) {
  return apiFetch<FranchiseRoyaltySettlement>(`/api/v1/franchise/settlements/${id}/post-journal`, {
    method: 'POST',
  })
}
