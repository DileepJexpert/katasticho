import { afterEach, beforeEach, expect, it, vi } from 'vitest'
import { saveBudget, listBudget, getBudgetVariance } from '@/features/budgets/budgets-api'
import { createAmortizationSchedule, postAmortizationPeriod } from '@/features/amortization/amortization-api'
import { createFixedAsset, disposeFixedAsset, runDepreciation, getFixedAssetSchedulePreview } from '@/features/fixed-assets/fixed-assets-api'
import { createFranchiseNode, saveFranchisePolicy } from '@/features/franchise/franchise-api'
import { earnLoyaltyPoints, redeemLoyaltyPoints } from '@/features/loyalty/loyalty-api'
import { exportTrainingJsonl } from '@/features/ai/ai-api'
import { savePdfTemplate } from '@/features/settings/settings-api'

const fetchMock = vi.fn<typeof fetch>()
beforeEach(() => { vi.stubGlobal('fetch', fetchMock); fetchMock.mockReset(); reply({}) })
afterEach(() => vi.unstubAllGlobals())
function reply(data: unknown) { fetchMock.mockImplementation(async () => new Response(JSON.stringify({ success: true, data }), { headers: { 'Content-Type': 'application/json' } })) }
function lastRequest() { const [path, req] = fetchMock.mock.calls.at(-1)!; return { path, method: req?.method, body: req?.body ? JSON.parse(String(req.body)) : undefined } }
it('round-trips annualAmount/accountCode instead of fictional budget fields', async () => {
  const lines = [{ accountCode: '5270', accountName: 'Depreciation', annualAmount: '1200.00', notes: 'Preserve' }]; reply(lines)
  expect(await listBudget(2026)).toEqual(lines); await saveBudget(2026, lines)
  expect(lastRequest()).toEqual({ path: '/api/v1/budgets/2026', method: 'PUT', body: lines })
})
it('loads actuals from the fiscal-year variance report', async () => { await getBudgetVariance(2026); expect(lastRequest().path).toBe('/api/v1/reports/budget-variance?startDate=2026-04-01&endDate=2027-03-31') })
it('posts amortization with whole-organisation scope and consumes the run summary', async () => {
  reply({ scheduleCount: 2, totalRecognized: 120, journalEntryId: 'journal-1' })
  expect(await postAmortizationPeriod(2026, 9)).toEqual({ count: 2, total: 120, journalEntryId: 'journal-1' })
  expect(lastRequest()).toEqual({ path: '/api/v1/amortization/run?year=2026&month=9', method: 'POST', body: undefined })
})
it('creates recognition schedules only with the supplied posting codes', async () => {
  const req = { description: 'Rent', scheduleType: 'PREPAID', totalAmount: 1200, numberOfPeriods: 12, startYear: 2026, startMonth: 9, debitAccountCode: '5270', creditAccountCode: '1510' }
  await createAmortizationSchedule(req); expect(lastRequest().body).toEqual(req)
})
it('posts depreciation with the existing bulk endpoint', async () => {
  reply({ assetCount: 3, totalDepreciation: 450, journalEntryId: 'journal-2' })
  expect(await runDepreciation(2026, 9)).toEqual({ count: 3, total: 450, journalEntryId: 'journal-2' }); expect(lastRequest().path).toBe('/api/v1/fixed-assets/depreciation/run?year=2026&month=9')
})
it('sends the WDV rate and real disposal proceeds/account fields', async () => {
  await createFixedAsset({ assetCode: 'FA-1', name: 'Machine', acquisitionDate: '2026-09-01', cost: 10000, bookMethod: 'WDV', bookRatePct: 15 }); expect(lastRequest().body.bookRatePct).toBe(15)
  await disposeFixedAsset('asset-1', { disposalDate: '2026-09-05', proceeds: 7500, proceedsAccountCode: '1010', gainLossAccountCode: '5270' }); expect(lastRequest().body).toEqual({ disposalDate: '2026-09-05', proceeds: 7500, proceedsAccountCode: '1010', gainLossAccountCode: '5270' })
})
it('reads the actual depreciation preview field names', async () => { const rows = [{ periodYear: 2026, periodMonth: 9, opening: 1000, depreciation: 100, closing: 900 }]; reply(rows); expect(await getFixedAssetSchedulePreview('asset-1')).toEqual(rows) })
it('uses the franchise DTO rather than display aliases', async () => {
  const req = { nodeCode: 'FR-01', nodeName: 'Store', nodeType: 'FOFO', royaltyRatePercent: 5, fixedMonthlyFee: 100, active: true }
  await createFranchiseNode(req); expect(lastRequest().body).toEqual(req)
  const policy = { autoSyncNewItems: false, allowBranchPriceOverride: false, maxDiscountFromMrpPercent: 15, minMarginPercent: 8, syncMode: 'ALL_ITEMS' }; await saveFranchisePolicy(policy); expect(lastRequest().body).toEqual(policy)
})
it('requires sale receipt contracts for loyalty instead of arbitrary bonus amounts', async () => {
  await earnLoyaltyPoints({ contactId: 'contact-1', saleTotal: 1000, receiptId: 'receipt-1' }); expect(lastRequest().body).toEqual({ contactId: 'contact-1', saleTotal: 1000, receiptId: 'receipt-1' })
  await redeemLoyaltyPoints({ contactId: 'contact-1', redeemAmount: 20, receiptId: 'receipt-1' }); expect(lastRequest().body).toEqual({ contactId: 'contact-1', redeemAmount: 20, receiptId: 'receipt-1' })
})
it('downloads NDJSON without trying to read an ApiResponse envelope', async () => {
  const text = '{"messages":[]}\n{"messages":[{"role":"user","content":"Rent"}]}\n'
  fetchMock.mockResolvedValue(new Response(text, { headers: { 'Content-Type': 'application/x-ndjson' } }))
  expect(await exportTrainingJsonl()).toBe(text)
})
it('propagates download errors rather than creating an error-shaped export', async () => {
  fetchMock.mockResolvedValue(new Response(JSON.stringify({ success: false, message: 'Export denied' }), { status: 403, headers: { 'Content-Type': 'application/json' } }))
  await expect(exportTrainingJsonl()).rejects.toThrow('Export denied')
})
it('persists the exact PDF configuration fields', async () => {
  const template = { documentType: 'QUOTATION', templateTheme: 'MINIMAL', primaryColor: '#0F8576', headerLayout: 'LOGO_LEFT', showGstColumns: true, showHsnColumn: false, showPaymentQr: false, showTerms: true, termsAndConditions: '', showSignature: true, signatureLabel: 'Approved by', watermarkText: '', active: true }
  await savePdfTemplate(template); expect(lastRequest()).toEqual({ path: '/api/v1/settings/pdf-templates', method: 'POST', body: template })
})
