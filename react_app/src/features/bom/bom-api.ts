import { apiFetch } from '@/api/client/api-client'

export type BomComponent = {
  id: string
  parentItemId: string
  componentItemId: string
  componentItemName?: string | null
  quantity: number | string
  scrapFactorPercent?: number | string | null
  version: number
  costAllocationPercent?: number | string | null
}

export type BomAlternate = {
  id: string
  bomComponentId: string
  alternateItemId: string
  alternateItemName?: string | null
  priority?: number | null
  notes?: string | null
}

export type BomCoProduct = {
  id: string
  parentItemId: string
  coProductItemId: string
  coProductItemName?: string | null
  quantityPerUnit: number | string
  costAllocationPercent?: number | string | null
}

export type BomDiff = {
  added: Array<{ itemId: string; itemName?: string; quantity: number | string }>
  removed: Array<{ itemId: string; itemName?: string; quantity: number | string }>
  changed: Array<{ itemId: string; itemName?: string; oldQuantity: number | string; newQuantity: number | string }>
}

export type BomCostRollup = {
  itemId: string
  itemName?: string
  rawMaterialCost: number | string
  laborCost: number | string
  overheadCost: number | string
  totalUnitCost: number | string
  components: Array<{
    itemId: string
    itemName: string
    qtyRequired: number | string
    unitCost: number | string
    lineCost: number | string
  }>
}

export async function getBomVersion(parentItemId: string, version: number) {
  return apiFetch<BomComponent[]>(`/api/v1/manufacturing/bom/${parentItemId}/version/${version}`)
}

export async function getLatestBomVersion(parentItemId: string) {
  return apiFetch<{ version: number }>(`/api/v1/manufacturing/bom/${parentItemId}/latest-version`)
}

export async function createBomVersion(parentItemId: string, changeNotes?: string) {
  return apiFetch<{ version: number }>(`/api/v1/manufacturing/bom/${parentItemId}/version`, {
    method: 'POST',
    body: JSON.stringify({ changeNotes }),
  })
}

export async function diffBomVersions(parentItemId: string, fromVersion: number, toVersion: number) {
  return apiFetch<BomDiff>(`/api/v1/manufacturing/bom/${parentItemId}/diff?fromVersion=${fromVersion}&toVersion=${toVersion}`)
}

export async function getBomCostRollup(itemId: string) {
  return apiFetch<BomCostRollup>(`/api/v1/manufacturing/bom/${itemId}/cost-rollup`)
}

export async function listBomAlternates(bomComponentId: string) {
  return apiFetch<BomAlternate[]>(`/api/v1/manufacturing/bom-alternates?bomComponentId=${bomComponentId}`)
}

export async function addBomAlternate(data: {
  bomComponentId: string
  alternateItemId: string
  priority?: number
  notes?: string
}) {
  return apiFetch<BomAlternate>('/api/v1/manufacturing/bom-alternates', {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

export async function deleteBomAlternate(id: string) {
  return apiFetch<void>(`/api/v1/manufacturing/bom-alternates/${id}`, {
    method: 'DELETE',
  })
}

export async function listBomCoProducts(parentItemId: string) {
  return apiFetch<BomCoProduct[]>(`/api/v1/manufacturing/bom-co-products?parentItemId=${parentItemId}`)
}

export async function addBomCoProduct(data: {
  parentItemId: string
  coProductItemId: string
  quantityPerUnit: number | string
  costAllocationPercent?: number | string
}) {
  return apiFetch<BomCoProduct>('/api/v1/manufacturing/bom-co-products', {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

export async function deleteBomCoProduct(id: string) {
  return apiFetch<void>(`/api/v1/manufacturing/bom-co-products/${id}`, {
    method: 'DELETE',
  })
}