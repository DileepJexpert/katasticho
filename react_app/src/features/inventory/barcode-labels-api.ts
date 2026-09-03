import { apiFetch } from '@/api/client/api-client'

export type BarcodeLabelRequest = {
  itemId: string
  batchId?: string
  labelFormat: 'THERMAL_50X25' | 'THERMAL_100X50' | 'A4_24UP' | string
  quantity: number
  includeMrp?: boolean
  includeExpiry?: boolean
  includeQrCode?: boolean
}

export type BarcodeLabelResponse = {
  zplPayload: string
  previewSvgUrl?: string
  totalLabels: number
}

export async function generateBarcodeLabel(req: BarcodeLabelRequest) {
  return apiFetch<BarcodeLabelResponse>('/api/v1/inventory/barcode-labels/generate', {
    method: 'POST',
    body: req,
  })
}