import { useState, type FormEvent } from 'react'
import { useMutation } from '@tanstack/react-query'
import { Button, DocumentCard, FormField, FormGrid, PageHeader, SelectInput, TextAreaInput, TextInput, NumberInput } from '@/design-system'
import type { Item } from '@/features/items/items-api'
import { generateBarcodeLabel, type BarcodeLabelRequest } from './barcode-labels-api'
import { InventoryItemPicker } from './inventory-pickers'
import { useInventoryAccess } from './inventory-access'

function downloadCode(code: string, extension: 'zpl' | 'epl') {
  const url = URL.createObjectURL(new Blob([code], { type: 'text/plain;charset=utf-8' }))
  const anchor = document.createElement('a')
  anchor.href = url
  anchor.download = 'barcode-label.' + extension
  anchor.click()
  window.setTimeout(() => URL.revokeObjectURL(url), 1000)
}

function validEan13(value: string) {
  if (!/^\d{13}$/.test(value)) return false
  const sum = [...value.slice(0, 12)].reduce((total, digit, index) => total + Number(digit) * (index % 2 === 0 ? 1 : 3), 0)
  return Number(value[12]) === (10 - sum % 10) % 10
}

export function BarcodeLabelsPage() {
  const access = useInventoryAccess()
  const [item, setItem] = useState<Item | null>(null)
  const [form, setForm] = useState({ itemName: '', sku: '', barcodeValue: '', barcodeType: 'CODE128', batchNumber: '', expiryDate: '', mrp: '', sellingPrice: '', companyName: '', fssaiLicNo: '', width: '50', height: '25', dpi: '203', copies: '1' })
  const [error, setError] = useState('')
  const mutation = useMutation({ mutationFn: generateBarcodeLabel })
  const signature = JSON.stringify(form)
  const [generatedSignature, setGeneratedSignature] = useState('')
  const output = signature === generatedSignature ? mutation.data : undefined
  function update(key: keyof typeof form, value: string) { setForm((current) => ({ ...current, [key]: value })) }
  function selectItem(selected: Item | null) {
    setItem(selected)
    if (selected) setForm((current) => ({ ...current, itemName: selected.name, sku: selected.sku ?? '', barcodeValue: selected.barcode ?? selected.sku ?? '', mrp: String(selected.mrp ?? ''), sellingPrice: String(selected.salePrice ?? ''), batchNumber: '', expiryDate: '' }))
  }
  function submit(event: FormEvent) {
    event.preventDefault()
    if (!access.operate || mutation.isPending) return
    const dimensions = [form.width, form.height, form.copies]
    if (!form.itemName.trim() || !form.barcodeValue.trim() || dimensions.some((value) => !value.trim() || !Number.isInteger(Number(value)) || Number(value) <= 0) || [form.mrp, form.sellingPrice].some((value) => value.trim() && (!Number.isFinite(Number(value)) || Number(value) < 0))) {
      setError('Enter an item name, barcode value, positive whole-number media dimensions and copies, and nonnegative prices.'); return
    }
    // eslint-disable-next-line no-control-regex
    if ([form.itemName, form.sku, form.barcodeValue, form.batchNumber, form.companyName, form.fssaiLicNo].some((value) => /[\x00-\x1f"^~]/.test(value))) {
      setError('Label text cannot contain control characters, quotes, or printer-command characters (^ and ~).'); return
    }
    if (form.barcodeType === 'EAN13' && !validEan13(form.barcodeValue.trim())) { setError('EAN13 requires 13 digits with a valid check digit.'); return }
    setError('')
    setGeneratedSignature(signature)
    mutation.mutate({ itemName: form.itemName.trim(), sku: form.sku || undefined, barcodeValue: form.barcodeValue.trim(), barcodeType: form.barcodeType as BarcodeLabelRequest['barcodeType'], batchNumber: form.batchNumber || undefined, expiryDate: form.expiryDate || undefined, mrp: form.mrp.trim() ? Number(form.mrp) : undefined, sellingPrice: form.sellingPrice.trim() ? Number(form.sellingPrice) : undefined, companyName: form.companyName || undefined, fssaiLicNo: form.fssaiLicNo || undefined, labelWidthMm: Number(form.width), labelHeightMm: Number(form.height), dpi: Number(form.dpi), copies: Number(form.copies) })
  }
  return <section className="workspace-page">
    <PageHeader eyebrow="Inventory / Barcodes" title="Barcode labels" description="Generate the existing server's ZPL/EPL printer commands. Printer calibration and scan verification remain required." />
    {!access.operate ? <p>Your role has no permission to generate labels.</p> : <div className="document-layout">
      <DocumentCard title="Label configuration"><form onSubmit={submit} className="create-form-container">
        {(error || mutation.isError) && <div role="alert" className="banner banner--error">{error || mutation.error?.message}</div>}
        <FormField label="Load from item"><InventoryItemPicker value={item} onChange={selectItem} disabled={mutation.isPending} /></FormField>
        <FormGrid columns={2}>
          {(['itemName', 'barcodeValue', 'sku', 'batchNumber', 'companyName', 'fssaiLicNo'] as const).map((key) => <FormField key={key} label={{ itemName: 'Item name', barcodeValue: 'Barcode value', sku: 'SKU', batchNumber: 'Batch number', companyName: 'Company name', fssaiLicNo: 'FSSAI licence' }[key]} required={key === 'itemName' || key === 'barcodeValue'}><TextInput value={form[key]} required={key === 'itemName' || key === 'barcodeValue'} onChange={(event) => update(key, event.target.value)} disabled={mutation.isPending} /></FormField>)}
          <FormField label="Barcode type"><SelectInput value={form.barcodeType} onChange={(event) => update('barcodeType', event.target.value)} options={['CODE128', 'EAN13', 'QR'].map((value) => ({ value, label: value }))} disabled={mutation.isPending} /></FormField>
          <FormField label="Expiry date"><TextInput type="date" value={form.expiryDate} onChange={(event) => update('expiryDate', event.target.value)} disabled={mutation.isPending} /></FormField>
          {(['mrp', 'sellingPrice', 'width', 'height', 'copies'] as const).map((key) => <FormField key={key} label={{ mrp: 'MRP', sellingPrice: 'Selling price', width: 'Width (mm)', height: 'Height (mm)', copies: 'Copies' }[key]}><NumberInput value={form[key]} min={key === 'mrp' || key === 'sellingPrice' ? 0 : 1} step={key === 'mrp' || key === 'sellingPrice' ? 'any' : 1} onChange={(event) => update(key, event.target.value)} disabled={mutation.isPending} /></FormField>)}
          <FormField label="Printer resolution"><SelectInput value={form.dpi} onChange={(event) => update('dpi', event.target.value)} options={[{ value: '203', label: '203 DPI' }, { value: '300', label: '300 DPI' }]} disabled={mutation.isPending} /></FormField>
        </FormGrid>
        <Button type="submit" loading={mutation.isPending}>Generate printer code</Button>
      </form></DocumentCard>
      <DocumentCard title="Generated printer output">
        <p>No visual barcode preview or browser print is provided by this API. Download the generated commands for a compatible printer; A4 sheet printing is not supported here.</p>
        {output ? <div className="create-form-container"><p>{output.copies} copies / {output.labelWidthDots} x {output.labelHeightDots} dots</p>
          <FormField label="ZPL code"><TextAreaInput readOnly rows={12} value={output.zplCode} /></FormField><Button variant="secondary" onClick={() => downloadCode(output.zplCode, 'zpl')}>Download ZPL</Button>
          <FormField label="EPL code"><TextAreaInput readOnly rows={8} value={output.eplCode} /></FormField><Button variant="secondary" onClick={() => downloadCode(output.eplCode, 'epl')}>Download EPL</Button>
          <p className="cell-muted">The server's EPL output uses its fixed barcode format and does not mirror every ZPL option. Check the selected format on the printer.</p>
        </div> : <p className="cell-muted">Generate code for the current label settings. Editing settings hides previous output.</p>}
      </DocumentCard>
    </div>}
  </section>
}
