import { useMemo, useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, FileCheck, Plus, Save, Trash2 } from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  CheckboxInput,
  DataTable,
  EntityPicker,
  FormCard,
  FormField,
  FormGrid,
  Money,
  NumberInput,
  PageHeader,
  SelectInput,
  TextAreaInput,
  TextInput,
} from '@/design-system'
import { createBill, type CreatePurchaseBillRequest } from '@/features/bills/bills-api'
import { listContacts, type Contact } from '@/features/contacts/contacts-api'
import { listItems, type Item } from '@/features/items/items-api'

type BillLineFormItem = {
  id: string
  lineType: 'GOODS' | 'SERVICE'
  itemId?: string
  itemName: string
  description: string
  hsnCode: string
  quantity: number
  unitPrice: number
  discountPercent: number
  gstRate: number
}

export function BillCreatePage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [vendor, setVendor] = useState<Contact | null>(null)
  const [vendorBillNumber, setVendorBillNumber] = useState('')
  const [billDate, setBillDate] = useState(() => new Date().toISOString().split('T')[0] || '')
  const [dueDate, setDueDate] = useState(() => {
    const date = new Date()
    date.setDate(date.getDate() + 30)
    return date.toISOString().split('T')[0] || ''
  })
  const [placeOfSupply, setPlaceOfSupply] = useState('')
  const [reverseCharge, setReverseCharge] = useState(false)
  const [notes, setNotes] = useState('')
  const [lines, setLines] = useState<BillLineFormItem[]>([])
  const [feedback, setFeedback] = useState<string | null>(null)

  const addCatalogItem = (item: Item | null | undefined) => {
    if (!item) return
    setLines((previous) => [
      ...previous,
      {
        id: crypto.randomUUID(),
        lineType: 'GOODS',
        itemId: item.id,
        itemName: item.name,
        description: item.name,
        hsnCode: item.hsnCode || '',
        quantity: 1,
        unitPrice: Number(item.purchasePrice || 0),
        discountPercent: 0,
        gstRate: Number(item.gstRate || 0),
      },
    ])
  }

  const addServiceLine = () => {
    setLines((previous) => [
      ...previous,
      {
        id: crypto.randomUUID(),
        lineType: 'SERVICE',
        itemName: 'Service',
        description: '',
        hsnCode: '',
        quantity: 1,
        unitPrice: 0,
        discountPercent: 0,
        gstRate: 0,
      },
    ])
  }

  const updateLine = (id: string, updates: Partial<BillLineFormItem>) => {
    setLines((previous) => previous.map((line) => line.id === id ? { ...line, ...updates } : line))
  }

  const summary = useMemo(() => lines.reduce((totals, line) => {
    const gross = line.quantity * line.unitPrice
    const taxable = gross * (1 - line.discountPercent / 100)
    const tax = taxable * line.gstRate / 100
    return { subtotal: totals.subtotal + taxable, tax: totals.tax + tax }
  }, { subtotal: 0, tax: 0 }), [lines])

  const createMutation = useMutation({
    mutationFn: (request: CreatePurchaseBillRequest) => createBill(request),
    onSuccess: (bill) => {
      queryClient.invalidateQueries({ queryKey: ['bills'] })
      navigate(appRoutes.billDetail(bill.id))
    },
    onError: (error: Error) => setFeedback(error.message),
  })

  const handleSubmit = (event: React.FormEvent) => {
    event.preventDefault()
    setFeedback(null)
    if (!vendor) {
      setFeedback('Select a vendor contact before recording the bill.')
      return
    }
    if (!lines.length || lines.some((line) => !line.description.trim())) {
      setFeedback('Add at least one line and enter a description for every line.')
      return
    }
    createMutation.mutate({
      contactId: vendor.id,
      vendorBillNumber: vendorBillNumber.trim() || undefined,
      billDate,
      dueDate: dueDate || undefined,
      placeOfSupply: placeOfSupply.trim() || undefined,
      reverseCharge,
      notes: notes.trim() || undefined,
      lines: lines.map((line) => ({
        lineType: line.lineType,
        itemId: line.lineType === 'GOODS' ? line.itemId : undefined,
        description: line.description.trim(),
        hsnCode: line.hsnCode.trim() || undefined,
        quantity: line.quantity,
        unitPrice: line.unitPrice,
        discountPercent: line.discountPercent,
        gstRate: line.gstRate,
      })),
    })
  }

  return (
    <section className="workspace-page">
      <Link className="form-back-link" to={appRoutes.bills}><ArrowLeft size={16} /> Back to bills</Link>
      <PageHeader eyebrow="Purchases / Payables" title="New Vendor Bill" description="Record a vendor invoice. The server calculates tax, accounts payable, journals, and any stock impact when you post it." />
      {feedback ? <div className="banner banner--error" role="alert">{feedback}</div> : null}

      <form className="create-form-container" onSubmit={handleSubmit}>
        <FormCard description="Use the vendor contact that owns the AP balance and capture the vendor's document reference." stepNumber={1} title="Vendor and invoice reference">
          <FormGrid columns={4}>
            <FormField label="Vendor contact" required>
              <EntityPicker
                ariaLabel="Search vendor contacts"
                getOptionBadge={(item) => item.contactType}
                getOptionDescription={(item) => [item.companyName, item.gstin, item.phone].filter(Boolean).join(' / ')}
                getOptionId={(item) => item.id}
                getOptionLabel={(item) => item.displayName}
                onChange={(_id, item) => setVendor(item ?? null)}
                onSearch={async (search) => (await listContacts({ filter: 'VENDOR', page: 0, search, size: 20 })).content}
                placeholder="Search vendor name, company, GSTIN, or phone"
                selectedEntity={vendor}
                value={vendor?.id ?? null}
              />
            </FormField>
            <FormField label="Vendor invoice number"><TextInput onChange={(event) => setVendorBillNumber(event.target.value)} placeholder="e.g. INV-2026-908" value={vendorBillNumber} /></FormField>
            <FormField label="Bill date" required><TextInput onChange={(event) => setBillDate(event.target.value)} required type="date" value={billDate} /></FormField>
            <FormField label="Due date"><TextInput onChange={(event) => setDueDate(event.target.value)} type="date" value={dueDate} /></FormField>
            <FormField label="Place of supply"><TextInput onChange={(event) => setPlaceOfSupply(event.target.value)} placeholder="e.g. 09-Uttar Pradesh" value={placeOfSupply} /></FormField>
            <FormField label="Reverse charge"><CheckboxInput checked={reverseCharge} description="Tax is payable by the recipient under RCM" onChange={(event) => setReverseCharge(event.target.checked)} title="RCM applies" /></FormField>
          </FormGrid>
        </FormCard>

        <FormCard description="Select catalog goods or add a service line. The preview is informational; the server remains the source of truth for tax and totals." stepNumber={2} title={`Bill lines (${lines.length})`}>
          <FormGrid columns={2}>
            <FormField label="Add catalog good">
              <EntityPicker<Item>
                ariaLabel="Search items to add to vendor bill"
                getOptionDescription={(item) => [item.sku, item.hsnCode, item.unitOfMeasure].filter(Boolean).join(' / ')}
                getOptionId={(item) => item.id}
                getOptionLabel={(item) => item.name}
                onChange={(_id, item) => addCatalogItem(item)}
                onSearch={async (search) => (await listItems({ activeOnly: true, search, size: 20 })).content}
                placeholder="Search item name, SKU, or HSN"
                value={null}
              />
            </FormField>
            <FormField label="Non-stock service"><Button onClick={addServiceLine} type="button" variant="secondary"><Plus size={16} /> Add service line</Button></FormField>
          </FormGrid>

          {lines.length ? (
            <DataTable caption="Vendor bill lines">
              <thead>
                <tr>
                  <th scope="col">Description</th>
                  <th scope="col">Type</th>
                  <th scope="col">HSN</th>
                  <th className="numeric-cell" scope="col">Qty</th>
                  <th className="numeric-cell" scope="col">Unit cost</th>
                  <th className="numeric-cell" scope="col">Discount</th>
                  <th className="numeric-cell" scope="col">GST</th>
                  <th className="numeric-cell" scope="col">Total preview</th>
                  <th scope="col"><span className="visually-hidden">Remove</span></th>
                </tr>
              </thead>
              <tbody>
                {lines.map((line) => {
                  const taxable = line.quantity * line.unitPrice * (1 - line.discountPercent / 100)
                  const total = taxable * (1 + line.gstRate / 100)
                  return (
                    <tr key={line.id}>
                      <td><div className="cell-stack"><strong>{line.itemName}</strong><TextInput aria-label={`Description for ${line.itemName}`} onChange={(event) => updateLine(line.id, { description: event.target.value })} placeholder="Line description" value={line.description} /></div></td>
                      <td><SelectInput aria-label={`Line type for ${line.itemName}`} disabled={line.lineType === 'SERVICE'} onChange={(event) => updateLine(line.id, { lineType: event.target.value as BillLineFormItem['lineType'] })} options={[{ value: 'GOODS', label: 'Goods' }, { value: 'SERVICE', label: 'Service' }]} value={line.lineType} /></td>
                      <td><TextInput aria-label={`HSN for ${line.itemName}`} onChange={(event) => updateLine(line.id, { hsnCode: event.target.value })} placeholder="HSN" value={line.hsnCode} /></td>
                      <td className="numeric-cell"><NumberInput min={0.0001} onChange={(event) => updateLine(line.id, { quantity: Number(event.target.value) || 0 })} step="0.0001" value={line.quantity} /></td>
                      <td className="numeric-cell"><NumberInput currencyPrefix="INR" min={0} onChange={(event) => updateLine(line.id, { unitPrice: Number(event.target.value) || 0 })} step="0.01" value={line.unitPrice} /></td>
                      <td className="numeric-cell"><NumberInput max={100} min={0} onChange={(event) => updateLine(line.id, { discountPercent: Number(event.target.value) || 0 })} step="0.01" unitSuffix="%" value={line.discountPercent} /></td>
                      <td className="numeric-cell"><NumberInput max={100} min={0} onChange={(event) => updateLine(line.id, { gstRate: Number(event.target.value) || 0 })} step="0.01" unitSuffix="%" value={line.gstRate} /></td>
                      <td className="numeric-cell"><Money amount={total} /></td>
                      <td><Button aria-label={`Remove ${line.itemName}`} onClick={() => setLines((previous) => previous.filter((entry) => entry.id !== line.id))} type="button" variant="ghost"><Trash2 size={14} /></Button></td>
                    </tr>
                  )
                })}
              </tbody>
            </DataTable>
          ) : <div className="directory-state"><FileCheck size={28} /><p>Add a catalog good or service line to begin this bill.</p></div>}
          <div className="form-summary-card">
            <div className="form-summary-row"><span>Taxable subtotal preview</span><Money amount={summary.subtotal} /></div>
            <div className="form-summary-row"><span>Input GST preview</span><Money amount={summary.tax} /></div>
            <div className="form-summary-row form-summary-row--total"><span>Bill total preview</span><Money amount={summary.subtotal + summary.tax} /></div>
          </div>
        </FormCard>

        <FormCard description="These notes are retained with the vendor bill after it is posted." stepNumber={3} title="Notes">
          <FormField label="Internal and vendor notes"><TextAreaInput onChange={(event) => setNotes(event.target.value)} placeholder="Verification comments or supplier notes" rows={3} value={notes} /></FormField>
        </FormCard>

        <div className="form-actions-bar">
          <Button onClick={() => navigate(appRoutes.bills)} type="button" variant="secondary">Cancel</Button>
          <Button disabled={createMutation.isPending || !vendor || !lines.length} type="submit" variant="primary"><Save size={16} />{createMutation.isPending ? 'Creating...' : 'Record vendor bill'}</Button>
        </div>
      </form>
    </section>
  )
}
