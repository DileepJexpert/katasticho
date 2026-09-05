import { useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, FileCheck, Save, Trash2 } from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
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
import { listItems, type Item } from '@/features/items/items-api'
import { listSelectableSuppliers, type Supplier } from '@/features/suppliers/suppliers-api'
import {
  createStockReceipt,
  type CreateStockReceiptLineRequest,
  type CreateStockReceiptRequest,
} from '@/features/stock-receipts/stock-receipts-api'
import { listWarehouses } from '@/features/warehouses/warehouses-api'

type GrnLineItem = CreateStockReceiptLineRequest & {
  id: string
  itemName: string
  trackBatches: boolean
}

type Charges = {
  freightAmount: number
  dutyAmount: number
  insuranceAmount: number
  otherCharges: number
}

export function StockReceiptCreatePage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [supplier, setSupplier] = useState<Supplier | null>(null)
  const [warehouseId, setWarehouseId] = useState('')
  const [receiptDate, setReceiptDate] = useState(() => new Date().toISOString().split('T')[0] || '')
  const [supplierInvoiceNo, setSupplierInvoiceNo] = useState('')
  const [supplierInvoiceDate, setSupplierInvoiceDate] = useState('')
  const [notes, setNotes] = useState('')
  const [charges, setCharges] = useState<Charges>({
    freightAmount: 0,
    dutyAmount: 0,
    insuranceAmount: 0,
    otherCharges: 0,
  })
  const [lines, setLines] = useState<GrnLineItem[]>([])
  const [feedback, setFeedback] = useState<string | null>(null)

  const warehouses = useQuery({ queryKey: ['warehouses'], queryFn: listWarehouses })

  const handleAddItem = (item: Item | null | undefined) => {
    if (!item || item.itemType === 'COMPOSITE') return
    setLines((previous) => [
      ...previous,
      {
        id: crypto.randomUUID(),
        itemId: item.id,
        itemName: item.name,
        description: item.name,
        hsnCode: item.hsnCode || undefined,
        unitOfMeasure: item.unitOfMeasure || undefined,
        quantity: 1,
        unitPrice: Number(item.purchasePrice || 0),
        discountPercent: 0,
        gstRate: Number(item.gstRate || 0),
        batchNumber: '',
        manufacturingDate: '',
        expiryDate: '',
        trackBatches: item.trackBatches,
      },
    ])
  }

  const handleUpdateLine = (id: string, updates: Partial<GrnLineItem>) => {
    setLines((previous) => previous.map((line) => line.id === id ? { ...line, ...updates } : line))
  }

  const preview = useMemo(() => lines.reduce((totals, line) => {
    const gross = line.quantity * line.unitPrice
    const taxable = gross * (1 - (line.discountPercent || 0) / 100)
    const tax = taxable * (line.gstRate || 0) / 100
    return { subtotal: totals.subtotal + taxable, tax: totals.tax + tax }
  }, { subtotal: 0, tax: 0 }), [lines])
  const chargeTotal = Object.values(charges).reduce((total, amount) => total + amount, 0)

  const createMutation = useMutation({
    mutationFn: (request: CreateStockReceiptRequest) => createStockReceipt(request),
    onSuccess: (created) => {
      queryClient.invalidateQueries({ queryKey: ['stock-receipts'] })
      navigate(appRoutes.stockReceiptDetail(created.id))
    },
    onError: (error: Error) => setFeedback(error.message),
  })

  const handleSubmit = (event: React.FormEvent) => {
    event.preventDefault()
    setFeedback(null)
    if (!supplier) {
      setFeedback('Select an active supplier before creating the receipt.')
      return
    }
    if (!lines.length) {
      setFeedback('Add at least one received item before creating the receipt.')
      return
    }
    const missingBatch = lines.find((line) => line.trackBatches && !line.batchNumber?.trim())
    if (missingBatch) {
      setFeedback(`${missingBatch.itemName} is batch tracked and needs a batch number before receipt.`)
      return
    }
    createMutation.mutate({
      supplierId: supplier.id,
      warehouseId: warehouseId || undefined,
      receiptDate,
      supplierInvoiceNo: supplierInvoiceNo.trim() || undefined,
      supplierInvoiceDate: supplierInvoiceDate || undefined,
      notes: notes.trim() || undefined,
      ...charges,
      lines: lines.map((line) => ({
        itemId: line.itemId,
        quantity: line.quantity,
        unitPrice: line.unitPrice,
        hsnCode: line.hsnCode,
        discountPercent: line.discountPercent,
        gstRate: line.gstRate,
        description: line.description?.trim() || undefined,
        batchNumber: line.batchNumber?.trim() || undefined,
        manufacturingDate: line.manufacturingDate || undefined,
        expiryDate: line.expiryDate || undefined,
      })),
    })
  }

  return (
    <section className="workspace-page">
      <Link className="form-back-link" to={appRoutes.stockReceipts}><ArrowLeft size={16} /> Back to goods receipts</Link>
      <PageHeader
        eyebrow="Purchases / Inbound logistics"
        title="New Goods Receipt"
        description="Create a draft direct receipt. For a PO-backed receipt, use Receive Stock (GRN) from the purchase order so source line links stay intact."
      />
      {feedback ? <div className="banner banner--error" role="alert">{feedback}</div> : null}

      <form className="create-form-container" onSubmit={handleSubmit}>
        <FormCard description="Record the eligible supplier, warehouse, and supplier delivery reference." stepNumber={1} title="Supplier and receipt information">
          <FormGrid columns={3}>
            <FormField label="Supplier" required>
              <EntityPicker
                ariaLabel="Search active suppliers"
                getOptionDescription={(item) => [item.gstin, item.phone, item.city].filter(Boolean).join(' / ')}
                getOptionId={(item) => item.id}
                getOptionLabel={(item) => item.name}
                onChange={(_id, item) => setSupplier(item ?? null)}
                onSearch={async (search) => (await listSelectableSuppliers(search)).content}
                placeholder="Search supplier name, GSTIN, or phone"
                selectedEntity={supplier}
                value={supplier?.id ?? null}
              />
            </FormField>
            <FormField label="Receiving warehouse">
              <SelectInput
                onChange={(event) => setWarehouseId(event.target.value)}
                options={(warehouses.data ?? []).filter((warehouse) => warehouse.active).map((warehouse) => ({ value: warehouse.id, label: `${warehouse.code} / ${warehouse.name}${warehouse.isDefault ? ' (default)' : ''}` }))}
                placeholderOption="Use organisation default warehouse"
                value={warehouseId}
              />
            </FormField>
            <FormField label="Receipt date" required><TextInput onChange={(event) => setReceiptDate(event.target.value)} required type="date" value={receiptDate} /></FormField>
            <FormField label="Supplier invoice or challan number"><TextInput onChange={(event) => setSupplierInvoiceNo(event.target.value)} placeholder="e.g. DC-987" value={supplierInvoiceNo} /></FormField>
            <FormField label="Supplier invoice date"><TextInput onChange={(event) => setSupplierInvoiceDate(event.target.value)} type="date" value={supplierInvoiceDate} /></FormField>
          </FormGrid>
        </FormCard>

        <FormCard description="Capture the commercial cost, tax, discount, and batch information before the draft is received into stock." stepNumber={2} title={`Received items (${lines.length})`}>
          <FormField label="Add catalog item">
            <EntityPicker<Item>
              ariaLabel="Search items to add to goods receipt"
              getOptionDescription={(item) => [item.sku, item.hsnCode, item.unitOfMeasure, item.trackBatches ? 'Batch tracked' : 'Standard'].filter(Boolean).join(' / ')}
              getOptionId={(item) => item.id}
              getOptionLabel={(item) => item.name}
              onChange={(_id, item) => handleAddItem(item)}
              onSearch={async (search) => (await listItems({ activeOnly: true, search, size: 20 })).content.filter((item) => item.itemType === 'GOODS')}
              placeholder="Search item name, SKU, or HSN"
              value={null}
            />
          </FormField>

          {lines.length ? (
            <DataTable caption="Goods receipt lines">
              <thead>
                <tr>
                  <th scope="col">Item</th>
                  <th className="numeric-cell" scope="col">Qty</th>
                  <th className="numeric-cell" scope="col">Unit cost</th>
                  <th className="numeric-cell" scope="col">Discount</th>
                  <th className="numeric-cell" scope="col">GST</th>
                  <th scope="col">Batch</th>
                  <th scope="col">Mfg</th>
                  <th scope="col">Expiry</th>
                  <th scope="col"><span className="visually-hidden">Remove</span></th>
                </tr>
              </thead>
              <tbody>
                {lines.map((line) => (
                  <tr key={line.id}>
                    <td><div className="cell-stack"><strong>{line.itemName}</strong><span className="cell-muted">{line.hsnCode || 'No HSN'} / {line.unitOfMeasure || 'base unit'}{line.trackBatches ? ' / Batch tracked' : ''}</span></div></td>
                    <td className="numeric-cell"><NumberInput min={0.0001} onChange={(event) => handleUpdateLine(line.id, { quantity: Number(event.target.value) || 0 })} step="0.0001" value={line.quantity} /></td>
                    <td className="numeric-cell"><NumberInput currencyPrefix="INR" min={0} onChange={(event) => handleUpdateLine(line.id, { unitPrice: Number(event.target.value) || 0 })} step="0.01" value={line.unitPrice} /></td>
                    <td className="numeric-cell"><NumberInput min={0} max={100} onChange={(event) => handleUpdateLine(line.id, { discountPercent: Number(event.target.value) || 0 })} step="0.01" unitSuffix="%" value={line.discountPercent || 0} /></td>
                    <td className="numeric-cell"><NumberInput min={0} max={100} onChange={(event) => handleUpdateLine(line.id, { gstRate: Number(event.target.value) || 0 })} step="0.01" unitSuffix="%" value={line.gstRate || 0} /></td>
                    <td><TextInput aria-label={`Batch number for ${line.itemName}`} onChange={(event) => handleUpdateLine(line.id, { batchNumber: event.target.value })} placeholder={line.trackBatches ? 'Required' : 'Optional'} value={line.batchNumber || ''} /></td>
                    <td><TextInput aria-label={`Manufacturing date for ${line.itemName}`} onChange={(event) => handleUpdateLine(line.id, { manufacturingDate: event.target.value })} type="date" value={line.manufacturingDate || ''} /></td>
                    <td><TextInput aria-label={`Expiry date for ${line.itemName}`} onChange={(event) => handleUpdateLine(line.id, { expiryDate: event.target.value })} type="date" value={line.expiryDate || ''} /></td>
                    <td><Button aria-label={`Remove ${line.itemName}`} onClick={() => setLines((previous) => previous.filter((entry) => entry.id !== line.id))} type="button" variant="ghost"><Trash2 size={14} /></Button></td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          ) : <div className="directory-state"><FileCheck size={28} /><p>Search for an item to begin this direct goods receipt.</p></div>}
        </FormCard>

        <FormCard description="Additional charges are apportioned by the server and become part of landed unit cost when stock is received." stepNumber={3} title="Landed charges and notes">
          <FormGrid columns={4}>
            {(Object.entries(charges) as Array<[keyof Charges, number]>).map(([field, value]) => (
              <FormField key={field} label={field.replace('Amount', '').replace(/([A-Z])/g, ' $1')}>
                <NumberInput currencyPrefix="INR" min={0} onChange={(event) => setCharges((previous) => ({ ...previous, [field]: Number(event.target.value) || 0 }))} step="0.01" value={value} />
              </FormField>
            ))}
          </FormGrid>
          <FormField label="Receiving notes"><TextAreaInput onChange={(event) => setNotes(event.target.value)} placeholder="Gate pass, condition checks, or supplier instructions" rows={3} value={notes} /></FormField>
          <div className="form-summary-card">
            <div className="form-summary-row"><span>Material subtotal preview</span><Money amount={preview.subtotal} /></div>
            <div className="form-summary-row"><span>Input GST preview</span><Money amount={preview.tax} /></div>
            <div className="form-summary-row"><span>Additional landed charges</span><Money amount={chargeTotal} /></div>
            <div className="form-summary-row form-summary-row--total"><span>Receipt total preview</span><Money amount={preview.subtotal + preview.tax + chargeTotal} /></div>
          </div>
        </FormCard>

        <div className="form-actions-bar">
          <Button onClick={() => navigate(appRoutes.stockReceipts)} type="button" variant="secondary">Cancel</Button>
          <Button disabled={createMutation.isPending || !supplier || !lines.length} type="submit" variant="primary"><Save size={16} />{createMutation.isPending ? 'Creating...' : 'Create draft receipt'}</Button>
        </div>
      </form>
    </section>
  )
}
