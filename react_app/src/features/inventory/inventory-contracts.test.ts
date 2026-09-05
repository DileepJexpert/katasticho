import { beforeEach, describe, expect, it, vi } from 'vitest'
import { apiFetch, apiFetchRawJson } from '@/api/client/api-client'
import { getShortbook } from '@/features/items/items-api'
import { createPicklist, updatePickedQuantities } from '@/features/picklists/picklists-api'
import { generateBarcodeLabel } from './barcode-labels-api'
import { getUnsettledConsignmentSales, recordConsignmentSale, settleConsignment } from './consignment-api'
import { createTransferOrder } from './transfer-orders-api'

vi.mock('@/api/client/api-client', () => ({ apiFetch: vi.fn(), apiFetchRawJson: vi.fn() }))
beforeEach(() => vi.clearAllMocks())

describe('frozen inventory API contracts', () => {
  it('reads the raw shortbook array rather than requiring an ApiResponse wrapper', async () => {
    const data = [{ itemId: 'item-1', itemName: 'Turmeric', sku: 'TUR', hsnCode: null, currentStock: 2, reorderLevel: 10, reorderQuantity: 20, backordered: 5, suggestOrderQty: 25, reason: 'BOTH' }]
    vi.mocked(apiFetchRawJson).mockResolvedValue(data)
    expect(await getShortbook()).toEqual(data)
    expect(apiFetchRawJson).toHaveBeenCalledWith('/api/v1/stock/shortbook')
    expect(apiFetch).not.toHaveBeenCalled()
  })

  it('creates picking lines by order-line UUID and wraps picked quantities in lines', async () => {
    const request = { salesOrderId: 'so-id', warehouseId: 'wh-id', lines: [{ salesOrderLineId: 'so-line-id', requiredQuantity: 5 }] }
    await createPicklist(request)
    expect(apiFetch).toHaveBeenLastCalledWith('/api/v1/picklists', { method: 'POST', body: request })
    const update = { lines: [{ lineId: 'pick-line-id', pickedQuantity: 0, batchId: 'batch-id', notes: '' }] }
    await updatePickedQuantities('pick-id', update)
    expect(apiFetch).toHaveBeenLastCalledWith('/api/v1/picklists/pick-id/lines', { method: 'PUT', body: update })
  })

  it('sends actual label fields and exposes the generated printer commands', async () => {
    const request = { itemName: 'Turmeric 100g', barcodeValue: 'TUR-100', barcodeType: 'CODE128' as const, labelWidthMm: 50, labelHeightMm: 25, dpi: 203, copies: 2 }
    const output = { zplCode: '^XA^XZ', eplCode: 'N\nP2', labelWidthDots: 400, labelHeightDots: 200, copies: 2 }
    vi.mocked(apiFetch).mockResolvedValue(output)
    expect(await generateBarcodeLabel(request)).toEqual(output)
    expect(apiFetch).toHaveBeenCalledWith('/api/v1/inventory/barcode-labels/generate', { method: 'POST', body: request })
  })

  it('separates a consignment stock ID from a settlement ID', async () => {
    await recordConsignmentSale({ consignmentStockId: 'stock-id', quantitySold: 3 })
    expect(apiFetch).toHaveBeenLastCalledWith('/api/v1/inventory/consignment/record-sale', { method: 'POST', body: { consignmentStockId: 'stock-id', quantitySold: 3 } })
    await getUnsettledConsignmentSales('supplier-id')
    expect(apiFetch).toHaveBeenLastCalledWith('/api/v1/inventory/consignment/unsettled/supplier-id')
    await settleConsignment('settlement-id')
    expect(apiFetch).toHaveBeenLastCalledWith('/api/v1/inventory/consignment/settlement-id/settle', { method: 'POST' })
  })

  it('preserves the batch UUID when creating a warehouse transfer', async () => {
    const request = { fromWarehouseId: 'from-id', toWarehouseId: 'to-id', transferDate: '2026-09-05', lines: [{ itemId: 'item-id', batchId: 'batch-id', quantity: 2 }] }
    await createTransferOrder(request)
    expect(apiFetch).toHaveBeenLastCalledWith('/api/v1/transfer-orders', { method: 'POST', body: request })
  })
})
