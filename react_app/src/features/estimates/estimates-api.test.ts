import { beforeEach, expect, it, vi } from 'vitest'
import { apiFetch, apiFetchBlob } from '@/api/client/api-client'
import { createEstimate, getEstimatePdf, listEstimates, updateEstimate } from './estimates-api'
import { buildEstimateRequest, estimateFormLines } from './estimate-form-model'
import { estimateFixture } from './estimate-test-fixtures'

vi.mock('@/api/client/api-client', () => ({ apiFetch: vi.fn(), apiFetchBlob: vi.fn() }))
beforeEach(() => vi.clearAllMocks())

it('paginates the existing endpoint without an unsupported keyword filter', async () => {
  await listEstimates('SENT', undefined, 2, 25)
  const [url] = vi.mocked(apiFetch).mock.calls[0]!
  const params = new URL(url, 'http://test').searchParams
  expect(params.get('status')).toBe('SENT')
  expect(params.get('page')).toBe('2')
  expect(params.has('search')).toBe(false)
})
it('rejects combined customer and status filters rather than showing misleading results', async () => {
  await expect(listEstimates('SENT', 'customer-1')).rejects.toThrow(/not both/)
  expect(apiFetch).not.toHaveBeenCalled()
  await listEstimates('all', 'customer-1')
  expect(vi.mocked(apiFetch).mock.calls[0]?.[0]).not.toContain('status=')
})
it('serializes create and update to the declared estimate fields', async () => {
  const request = buildEstimateRequest({ contactId: 'customer-1', estimateDate: '2026-09-05' }, estimateFormLines(estimateFixture))
  await createEstimate(request)
  expect(apiFetch).toHaveBeenCalledWith('/api/v1/estimates', { method: 'POST', body: JSON.stringify(request) })
  await updateEstimate('estimate-1', { notes: '' })
  expect(apiFetch).toHaveBeenLastCalledWith('/api/v1/estimates/estimate-1', { method: 'PUT', body: '{"notes":""}' })
})
it('downloads through the shared authenticated tenant-aware binary client', async () => {
  await getEstimatePdf('estimate-1')
  expect(apiFetchBlob).toHaveBeenCalledWith('/api/v1/estimates/estimate-1/pdf', 'application/pdf')
})
