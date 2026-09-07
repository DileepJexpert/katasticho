import { expect, it, vi } from 'vitest'
import { apiFetchBlob } from '@/api/client/api-client'
import { downloadBlob } from '@/shared/files/download-blob'
import { downloadBmrPdf } from './bmr-api'

vi.mock('@/api/client/api-client', () => ({ apiFetch: vi.fn(), apiFetchBlob: vi.fn() }))
vi.mock('@/shared/files/download-blob', () => ({ downloadBlob: vi.fn() }))

it('downloads BMR PDFs through the authenticated PDF client', async () => {
  const pdf = new Blob(['bmr'], { type: 'application/pdf' })
  vi.mocked(apiFetchBlob).mockResolvedValue(pdf)

  await downloadBmrPdf('work-order-1')

  expect(apiFetchBlob).toHaveBeenCalledWith('/api/v1/manufacturing/bmr/work-orders/work-order-1/pdf', 'application/pdf')
  expect(downloadBlob).toHaveBeenCalledWith(pdf, 'BMR-work-order-1.pdf')
})
