import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { beforeEach, expect, it, vi } from 'vitest'
import { BarcodeLabelsPage } from './barcode-labels-page'
import { generateBarcodeLabel } from './barcode-labels-api'

vi.mock('./barcode-labels-api', () => ({ generateBarcodeLabel: vi.fn() }))
vi.mock('./inventory-access', () => ({ useInventoryAccess: () => ({ operate: true }) }))
vi.mock('./inventory-pickers', () => ({ InventoryItemPicker: () => <span>Item lookup</span> }))

beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(generateBarcodeLabel).mockResolvedValue({ zplCode: '^XA^FDTUR-100^FS^XZ', eplCode: 'N\nP2', labelWidthDots: 400, labelHeightDots: 200, copies: 2 })
})

function renderPage() { return render(<QueryClientProvider client={new QueryClient()}><BarcodeLabelsPage /></QueryClientProvider>) }
function fillLabel() {
  fireEvent.change(screen.getByRole('textbox', { name: /Item name/ }), { target: { value: 'Turmeric 100g' } })
  fireEvent.change(screen.getByRole('textbox', { name: /Barcode value/ }), { target: { value: 'TUR-100' } })
  fireEvent.change(screen.getByRole('spinbutton', { name: 'Copies' }), { target: { value: '2' } })
}

it('generates the exact printer request and displays server output instead of a fake barcode', async () => {
  renderPage()
  fillLabel()
  fireEvent.click(screen.getByRole('button', { name: 'Generate printer code' }))
  expect(await screen.findByRole('textbox', { name: 'ZPL code' })).toHaveValue('^XA^FDTUR-100^FS^XZ')
  expect(vi.mocked(generateBarcodeLabel).mock.calls[0]?.[0]).toEqual(expect.objectContaining({ itemName: 'Turmeric 100g', barcodeValue: 'TUR-100', barcodeType: 'CODE128', labelWidthMm: 50, labelHeightMm: 25, dpi: 203, copies: 2 }))
  expect(screen.queryByRole('button', { name: /print label/i })).not.toBeInTheDocument()
  fireEvent.change(screen.getByRole('textbox', { name: /Barcode value/ }), { target: { value: 'TUR-200' } })
  expect(screen.queryByRole('button', { name: 'Download ZPL' })).not.toBeInTheDocument()
})

it('rejects raw printer control sequences without sending them to the generator', async () => {
  renderPage()
  fillLabel()
  fireEvent.change(screen.getByRole('textbox', { name: /Barcode value/ }), { target: { value: '^XZ^XA' } })
  fireEvent.click(screen.getByRole('button', { name: 'Generate printer code' }))
  await waitFor(() => expect(screen.getByRole('alert')).toHaveTextContent('printer-command characters'))
  expect(generateBarcodeLabel).not.toHaveBeenCalled()
})

it('validates the EAN13 check digit before generating code', async () => {
  renderPage()
  fillLabel()
  fireEvent.change(screen.getByRole('combobox', { name: 'Barcode type' }), { target: { value: 'EAN13' } })
  fireEvent.change(screen.getByRole('textbox', { name: /Barcode value/ }), { target: { value: '4006381333932' } })
  fireEvent.click(screen.getByRole('button', { name: 'Generate printer code' }))
  expect(screen.getByRole('alert')).toHaveTextContent('valid check digit')
  expect(generateBarcodeLabel).not.toHaveBeenCalled()
  fireEvent.change(screen.getByRole('textbox', { name: /Barcode value/ }), { target: { value: '4006381333931' } })
  fireEvent.click(screen.getByRole('button', { name: 'Generate printer code' }))
  await waitFor(() => expect(generateBarcodeLabel).toHaveBeenCalledTimes(1))
})
