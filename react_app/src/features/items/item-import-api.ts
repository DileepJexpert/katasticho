import { apiFetch, apiFetchBlob } from '@/api/client/api-client'

type NumberLike = number | string | null

export type ItemImportRow = {
  rowNumber: number
  sku: string | null
  name: string | null
  itemType: string | null
  category: string | null
  hsnCode: string | null
  unitOfMeasure: string | null
  purchasePrice: NumberLike
  salePrice: NumberLike
  gstRate: NumberLike
  openingStock: NumberLike
}
export type ItemImportPreview = {
  totalRows: number
  validRows: number
  errorRows: number
  rows: (ItemImportRow & { status: string; error: string | null })[]
}
export type ItemImportResult = {
  totalRows: number
  created: number
  skipped: number
  successRows: Pick<ItemImportRow, 'rowNumber' | 'sku' | 'name' | 'itemType' | 'purchasePrice' | 'salePrice' | 'openingStock'>[]
  failedRows: (ItemImportRow & { errorMessage: string })[]
}
function upload(file: File) {
  const form = new FormData()
  form.append('file', file)
  return form
}
export function previewItemImport(file: File) {
  return apiFetch<ItemImportPreview>('/api/v1/items/import/preview', { method: 'POST', body: upload(file) })
}
export function commitItemImport(file: File) {
  return apiFetch<ItemImportResult>('/api/v1/items/import', { method: 'POST', body: upload(file) })
}
export function downloadItemImportTemplate() {
  return apiFetchBlob('/api/v1/items/import/template', 'text/csv')
}
