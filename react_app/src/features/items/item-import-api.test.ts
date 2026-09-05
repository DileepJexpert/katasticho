import { beforeEach, expect, it, vi } from 'vitest'
import { apiFetch, apiFetchBlob } from '@/api/client/api-client'
import { commitItemImport, downloadItemImportTemplate, previewItemImport } from './item-import-api'

vi.mock('@/api/client/api-client', () => ({ apiFetch: vi.fn(), apiFetchBlob: vi.fn() }))
beforeEach(() => vi.clearAllMocks())

it('uploads the unchanged file as multipart field file to preview and commit', async () => {
  const file = new File(['sku,name,batch_number\nSKU-1,Example,B-001'], 'items.csv', { type: 'text/csv' })
  await previewItemImport(file)
  let [path, request] = vi.mocked(apiFetch).mock.calls[0]!
  expect(path).toBe('/api/v1/items/import/preview')
  expect(request?.method).toBe('POST')
  expect(request?.body).toBeInstanceOf(FormData)
  expect((request?.body as FormData).get('file')).toBe(file)
  expect(request?.headers).toBeUndefined()
  await commitItemImport(file)
  ;[path, request] = vi.mocked(apiFetch).mock.calls[1]!
  expect(path).toBe('/api/v1/items/import')
  expect((request?.body as FormData).get('file')).toBe(file)
})

it('downloads the template from the existing CSV endpoint', async () => {
  await downloadItemImportTemplate()
  expect(apiFetchBlob).toHaveBeenCalledWith('/api/v1/items/import/template', 'text/csv')
})
