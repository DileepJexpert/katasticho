import { apiFetch } from '@/api/client/api-client'

export type BarcodeLabelRequest = {
  itemName: string
  sku?: string
  barcodeValue: string
  barcodeType: 'CODE128' | 'EAN13' | 'QR'
  batchNumber?: string
  expiryDate?: string
  mrp?: number
  sellingPrice?: number
  companyName?: string
  fssaiLicNo?: string
  labelWidthMm: number
  labelHeightMm: number
  dpi: number
  copies: number
}

export type BarcodeLabelResponse = {
  zplCode: string
  eplCode: string
  labelWidthDots: number
  labelHeightDots: number
  copies: number
}

export async function generateBarcodeLabel(req: BarcodeLabelRequest) {
  return apiFetch<BarcodeLabelResponse>('/api/v1/inventory/barcode-labels/generate', {
    method: 'POST',
    body: req,
  })
}
