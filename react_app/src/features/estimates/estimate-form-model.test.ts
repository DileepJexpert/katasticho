import { describe, expect, it } from 'vitest'
import type { Item } from '@/features/items/items-api'
import { buildEstimateRequest, canEditEstimate, estimateFormLines, estimatePermissions, localEstimateDate, newEstimateLine, previewEstimate } from './estimate-form-model'
import { estimateFixture } from './estimate-test-fixtures'

const header = { contactId: 'customer-1', estimateDate: '2026-09-05' }
describe('frozen estimate contract', () => {
  it('sends discountPct, taxRate, HSN, and unit without invoice-only fields', () => {
    const request = buildEstimateRequest(header, estimateFormLines(estimateFixture))
    expect(request.lines).toEqual([{ itemId: 'item-1', description: 'Turmeric Masala Test 100g', quantity: 10, rate: 45, discountPct: 10, taxRate: 18, unit: 'PCS', hsnCode: '0910' }])
    expect(JSON.stringify(request)).not.toMatch(/discountPercentage|taxGroupId|batchId|calculatedAmount/)
  })
  it('supports service lines and fractional quantity with zero rates', () => {
    const line = { ...newEstimateLine(), description: 'Consultation', quantity: '0.125', rate: '0' }
    expect(buildEstimateRequest(header, [line]).lines[0]).toMatchObject({ quantity: 0.125, rate: 0, taxRate: 0 })
    expect(JSON.stringify(buildEstimateRequest(header, [line]))).not.toContain('itemId')
  })
  it('does not replace a free sale price with purchase price', () => {
    const item = { id: 'item-1', name: 'Sample', salePrice: 0, purchasePrice: 30, gstRate: 18, unitOfMeasure: 'PCS' } as Item
    expect(newEstimateLine(item)).toMatchObject({ rate: '0', taxRate: '18', unit: 'PCS' })
  })
  it('matches the discounted quotation total without subtracting discount twice', () => {
    expect(previewEstimate(estimateFormLines(estimateFixture))).toEqual({ subtotal: 405, discount: 45, tax: 72.9, total: 477.9 })
  })
  it('rounds each gross, discount, and tax HALF_UP without binary floating-point errors', () => {
    const line = { ...newEstimateLine(), quantity: '1', rate: '10.075', description: 'Rounding example' }
    expect(previewEstimate([line, line])).toEqual({ subtotal: 20.16, discount: 0, tax: 0, total: 20.16 })
    expect(previewEstimate([{ ...line, rate: '1e-2', taxRate: '50' }])?.total).toBe(0.02)
  })
  it.each(['', '-1', 'Infinity', 'NaN'])('rejects invalid quantity %s instead of silently replacing it', (quantity) => {
    const line = { ...newEstimateLine(), description: 'Item', quantity }
    expect(() => buildEstimateRequest(header, [line])).toThrow(/line 1/)
    expect(previewEstimate([line])).toBeNull()
  })
  it('rejects empty lines, missing customer, invalid discount and backwards validity', () => {
    expect(() => buildEstimateRequest(header, [])).toThrow(/at least one/)
    expect(() => buildEstimateRequest({ ...header, contactId: '' }, [])).toThrow(/customer/)
    expect(() => buildEstimateRequest({ ...header, expiryDate: '2026-09-04' }, [])).toThrow(/Expiry/)
    expect(() => buildEstimateRequest(header, [{ ...newEstimateLine(), description: 'Item', discountPct: '101' }])).toThrow(/line 1/)
  })
  it('does not pretend a null update clears an existing expiry date', () => {
    expect(() => buildEstimateRequest(header, estimateFormLines(estimateFixture), estimateFixture)).toThrow(/cannot clear/)
  })
  it('retains explicit empty notes on update', () => {
    expect(buildEstimateRequest({ ...header, expiryDate: '2026-10-05', notes: '', terms: '' }, estimateFormLines(estimateFixture), estimateFixture)).toMatchObject({ notes: '', terms: '' })
  })
  it('uses local calendar dates rather than UTC dates', () => {
    expect(localEstimateDate(new Date(2026, 8, 5, 0, 1))).toBe('2026-09-05')
  })
  it('matches roles and editable lifecycle states rather than granting all logged-in users writes', () => {
    expect(estimatePermissions('OPERATOR')).toEqual({ write: true, delete: false })
    expect(estimatePermissions('VIEWER')).toEqual({ write: false, delete: false })
    expect(estimatePermissions()).toEqual({ write: false, delete: false })
    expect(estimatePermissions('ADMIN')).toEqual({ write: true, delete: true })
    expect(canEditEstimate('SENT')).toBe(true)
    expect(canEditEstimate('ACCEPTED')).toBe(false)
    expect(canEditEstimate('INVOICED')).toBe(false)
  })
})
