import { beforeEach, expect, it, vi } from 'vitest'
import { apiFetchBlob } from '@/api/client/api-client'
import {
  downloadForm24qCsv,
  downloadForm26qCsv,
  downloadForm26qFvu,
  downloadForm27eqCsv,
} from './tds-tcs-api'

vi.mock('@/api/client/api-client', () => ({ apiFetch: vi.fn(), apiFetchBlob: vi.fn() }))

beforeEach(() => vi.clearAllMocks())

it('downloads TDS and TCS exports through the authenticated blob client', async () => {
  await downloadForm26qCsv(2026, 1)
  await downloadForm26qFvu(2026, 1)
  await downloadForm24qCsv(2026, 1)
  await downloadForm27eqCsv(2026, 1)

  expect(apiFetchBlob).toHaveBeenNthCalledWith(1, '/api/v1/tds/26q/csv?fy=2026&quarter=1', 'text/csv')
  expect(apiFetchBlob).toHaveBeenNthCalledWith(2, '/api/v1/tds/26q/fvu?fy=2026&quarter=1')
  expect(apiFetchBlob).toHaveBeenNthCalledWith(3, '/api/v1/tds/24q/csv?fy=2026&quarter=1', 'text/csv')
  expect(apiFetchBlob).toHaveBeenNthCalledWith(4, '/api/v1/tcs/27eq/csv?fy=2026&quarter=1', 'text/csv')
})
