import { expect, it, vi } from 'vitest'
import { apiFetchBlob } from '@/api/client/api-client'
import { downloadForm12BbPdf } from './payroll-api'

vi.mock('@/api/client/api-client', () => ({ apiFetch: vi.fn(), apiFetchBlob: vi.fn() }))

it('downloads Form 12BB through the authenticated PDF client', async () => {
  await downloadForm12BbPdf('declaration-1')

  expect(apiFetchBlob).toHaveBeenCalledWith(
    '/api/v1/payroll/tax-declarations/declaration-1/pdf',
    'application/pdf',
  )
})
