import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, expect, it, vi } from 'vitest'
import { useInventoryAccess } from '@/features/inventory/inventory-access'
import { listWarehouses, type Warehouse } from '@/features/warehouses/warehouses-api'
import { commitItemImport, downloadItemImportTemplate, previewItemImport, type ItemImportPreview } from './item-import-api'
import { ItemImportPage } from './item-import-page'

vi.mock('@/features/inventory/inventory-access', () => ({ useInventoryAccess: vi.fn() }))
vi.mock('@/features/warehouses/warehouses-api', () => ({ listWarehouses: vi.fn() }))
vi.mock('./item-import-api', () => ({ commitItemImport: vi.fn(), previewItemImport: vi.fn(), downloadItemImportTemplate: vi.fn() }))
vi.mock('@/shared/files/download-blob', () => ({ downloadBlob: vi.fn() }))

const preview: ItemImportPreview = { totalRows: 2, validRows: 1, errorRows: 1, rows: [
  { rowNumber: 2, sku: 'SKU-1', name: 'New item', itemType: 'GOODS', category: 'Food', hsnCode: '2106', unitOfMeasure: 'PCS', purchasePrice: 30, salePrice: 45, gstRate: 18, openingStock: 10, status: 'OK', error: null },
  { rowNumber: 3, sku: 'EXISTS', name: 'Existing item', itemType: 'GOODS', category: null, hsnCode: null, unitOfMeasure: 'PCS', purchasePrice: null, salePrice: null, gstRate: null, openingStock: null, status: 'ERROR', error: 'SKU already exists in this org' },
] }
const warehouse = { id: 'warehouse-1', name: 'Default store', active: true, isDefault: true } as Warehouse
beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(useInventoryAccess).mockReturnValue({ operate: true, manage: true, administer: true, readZones: true })
  vi.mocked(listWarehouses).mockResolvedValue([warehouse])
  vi.mocked(previewItemImport).mockResolvedValue(preview)
  vi.mocked(commitItemImport).mockResolvedValue({ totalRows: 2, created: 1, skipped: 1, successRows: [preview.rows[0]!], failedRows: [{ ...preview.rows[1]!, errorMessage: 'SKU already exists in this org' }] })
})
function setup() {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false, gcTime: 0 }, mutations: { retry: false } } })
  return render(<QueryClientProvider client={client}><MemoryRouter><ItemImportPage /></MemoryRouter></QueryClientProvider>)
}
function chooseFile(name = 'items.csv') {
  const file = new File(['sku,name\nSKU-1,New item'], name, { type: 'text/csv' })
  fireEvent.change(screen.getByLabelText('Import file', { exact: false }), { target: { files: [file] } })
  return file
}

it('requires preview and explicit confirmation, commits the same file and shows partial success', async () => {
  setup()
  const file = chooseFile()
  expect(screen.getByRole('button', { name: 'Review import' })).toBeDisabled()
  fireEvent.click(screen.getByRole('button', { name: 'Preview file' }))
  expect(await screen.findByText(/Preview only: 1 valid, 1 errors/)).toBeInTheDocument()
  expect(vi.mocked(previewItemImport).mock.calls[0]?.[0]).toBe(file)
  expect(commitItemImport).not.toHaveBeenCalled()
  await waitFor(() => expect(screen.getByRole('button', { name: 'Review import' })).toBeEnabled())
  fireEvent.click(screen.getByRole('button', { name: 'Review import' }))
  expect(screen.getByRole('dialog')).toHaveTextContent('not an all-or-nothing transaction')
  fireEvent.click(within(screen.getByRole('dialog')).getByRole('button', { name: 'Import file' }))
  expect(await screen.findByText('Import result: 1 created, 1 skipped, 2 total rows.')).toBeInTheDocument()
  expect(vi.mocked(commitItemImport).mock.calls[0]?.[0]).toBe(file)
  expect(screen.getByRole('button', { name: 'Review import' })).toBeDisabled()
})

it('invalidates the preview when another file is selected', async () => {
  setup(); chooseFile()
  fireEvent.click(screen.getByRole('button', { name: 'Preview file' }))
  await screen.findByText(/Preview only:/)
  chooseFile('replacement.csv')
  expect(screen.queryByText(/Preview only:/)).not.toBeInTheDocument()
  expect(screen.getByRole('button', { name: 'Review import' })).toBeDisabled()
  expect(commitItemImport).not.toHaveBeenCalled()
})

it('does not permit commit without a default warehouse', async () => {
  vi.mocked(listWarehouses).mockResolvedValue([{ ...warehouse, isDefault: false }])
  setup(); chooseFile()
  fireEvent.click(screen.getByRole('button', { name: 'Preview file' }))
  await screen.findByText(/Preview only:/)
  expect(screen.getByRole('button', { name: 'Review import' })).toBeDisabled()
  expect(screen.getByText(/Configure an active default warehouse/)).toBeInTheDocument()
})

it('requires a fresh preview after an unconfirmed import and never automatically retries it', async () => {
  vi.mocked(commitItemImport).mockRejectedValue(new Error('Network disconnected'))
  setup(); chooseFile()
  fireEvent.click(screen.getByRole('button', { name: 'Preview file' }))
  await screen.findByText(/Preview only:/)
  await waitFor(() => expect(screen.getByRole('button', { name: 'Review import' })).toBeEnabled())
  fireEvent.click(screen.getByRole('button', { name: 'Review import' }))
  fireEvent.click(within(screen.getByRole('dialog')).getByRole('button', { name: 'Import file' }))
  expect(await screen.findByText(/Some rows may already have committed/)).toBeInTheDocument()
  expect(commitItemImport).toHaveBeenCalledTimes(1)
  expect(screen.getByRole('button', { name: 'Review import' })).toBeDisabled()
  expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
})

it('keeps imports and template calls unavailable to viewers', () => {
  vi.mocked(useInventoryAccess).mockReturnValue({ operate: false, manage: false, administer: false, readZones: false })
  setup()
  expect(screen.getByRole('alert')).toHaveTextContent('Your role cannot import items')
  expect(listWarehouses).not.toHaveBeenCalled()
  expect(downloadItemImportTemplate).not.toHaveBeenCalled()
  expect(screen.queryByLabelText('Import file', { exact: false })).not.toBeInTheDocument()
})

it('blocks visibly invalid numeric data even when the server preview marks it OK', async () => {
  vi.mocked(previewItemImport).mockResolvedValue({ ...preview, rows: [{ ...preview.rows[0]!, openingStock: -10 }, preview.rows[1]!] })
  setup(); chooseFile()
  fireEvent.click(screen.getByRole('button', { name: 'Preview file' }))
  expect(await screen.findByRole('alert')).toHaveTextContent('openingStock must be a non-negative number')
  expect(screen.getByRole('button', { name: 'Review import' })).toBeDisabled()
  expect(commitItemImport).not.toHaveBeenCalled()
})
