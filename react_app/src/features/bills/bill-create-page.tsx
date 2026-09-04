import { useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, FileCheck, Save, Trash2 } from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  CheckboxInput,
  DataTable,
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
import {
  createBill,
  type CreatePurchaseBillRequest,
} from '@/features/bills/bills-api'
import { listContacts } from '@/features/contacts/contacts-api'
import { listItems } from '@/features/items/items-api'

interface BillLineFormItem {
  id: string
  lineType: 'GOODS' | 'SERVICE'
  itemId?: string
  itemName: string
  description: string
  hsnCode?: string
  quantity: number
  unitPrice: number
  gstRate: number
  lineTax: number
  lineTotal: number
}

export function BillCreatePage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const [contactId, setContactId] = useState('')
  const [vendorBillNumber, setVendorBillNumber] = useState('')
  const [billDate, setBillDate] = useState(() => new Date().toISOString().split('T')[0] || '')
  const [dueDate, setDueDate] = useState(() => {
    const d = new Date()
    d.setDate(d.getDate() + 30)
    return d.toISOString().split('T')[0] || ''
  })
  const [placeOfSupply, setPlaceOfSupply] = useState('')
  const [reverseCharge, setReverseCharge] = useState(false)
  const [notes, setNotes] = useState('')
  const [lines, setLines] = useState<BillLineFormItem[]>([])
  const [feedback, setFeedback] = useState<{ type: 'error' | 'success'; message: string } | null>(null)

  const vendorsQuery = useQuery({
    queryKey: ['vendors-for-bill'],
    queryFn: () => listContacts({ filter: 'VENDOR', page: 0 }),
  })

  const itemsQuery = useQuery({
    queryKey: ['items-for-bill'],
    queryFn: () => listItems({ page: 0 }),
  })

  const vendors = vendorsQuery.data?.content ?? []
  const catalogItems = itemsQuery.data?.content ?? []

  const handleAddItem = (itemId: string) => {
    const item = catalogItems.find((i) => i.id === itemId)
    if (!item) return
    const price = Number(item.purchasePrice || 0)
    const gst = Number(item.gstRate || 18)
    const tax = (price * gst) / 100
    const newLine: BillLineFormItem = {
      id: Math.random().toString(36).substring(2, 9),
      lineType: 'GOODS',
      itemId: item.id,
      itemName: item.name,
      description: item.name,
      hsnCode: item.hsnCode || '',
      quantity: 1,
      unitPrice: price,
      gstRate: gst,
      lineTax: tax,
      lineTotal: price + tax,
    }
    setLines((prev) => [...prev, newLine])
  }

  const handleUpdateLine = (id: string, updates: Partial<BillLineFormItem>) => {
    setLines((prev) =>
      prev.map((l) => {
        if (l.id !== id) return l
        const updated = { ...l, ...updates }
        const taxable = (updated.quantity || 0) * (updated.unitPrice || 0)
        const tax = ((updated.gstRate || 0) / 100) * taxable
        updated.lineTax = tax
        updated.lineTotal = taxable + tax
        return updated
      })
    )
  }

  const handleRemoveLine = (id: string) => {
    setLines((prev) => prev.filter((l) => l.id !== id))
  }

  const subtotal = useMemo(() => {
    return lines.reduce((acc, l) => acc + (l.quantity || 0) * (l.unitPrice || 0), 0)
  }, [lines])

  const totalGst = useMemo(() => {
    return lines.reduce((acc, l) => acc + (l.lineTax || 0), 0)
  }, [lines])

  const grandTotal = useMemo(() => {
    return subtotal + totalGst
  }, [subtotal, totalGst])

  const createMutation = useMutation({
    mutationFn: (req: CreatePurchaseBillRequest) => createBill(req),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['bills'] })
      navigate(appRoutes.bills)
    },
    onError: (err: unknown) => {
      const msg = err instanceof Error ? err.message : 'Failed to create vendor bill.'
      setFeedback({ type: 'error', message: msg })
    },
  })

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    setFeedback(null)

    if (!contactId) {
      setFeedback({ type: 'error', message: 'Please select a vendor.' })
      return
    }

    if (lines.length === 0) {
      setFeedback({ type: 'error', message: 'Please add at least one line item to the bill.' })
      return
    }

    createMutation.mutate({
      contactId,
      vendorBillNumber: vendorBillNumber.trim() || undefined,
      billDate,
      dueDate,
      placeOfSupply: placeOfSupply.trim() || undefined,
      reverseCharge,
      notes: notes.trim() || undefined,
      lines: lines.map((l) => ({
        lineType: l.lineType,
        description: l.description,
        hsnCode: l.hsnCode || undefined,
        itemId: l.itemId,
        quantity: l.quantity,
        unitPrice: l.unitPrice,
        gstRate: l.gstRate,
      })),
    })
  }

  return (
    <section className="workspace-page">
      <Link className="form-back-link" to={appRoutes.bills}>
        <ArrowLeft size={16} /> Back to Bills
      </Link>

      <PageHeader
        eyebrow="Purchases / Payables"
        title="New Vendor Bill"
        description="Book vendor invoices against accounts payable, input tax credits, and purchase ledgers."
      />

      {feedback && (
        <div
          className={`banner ${feedback.type === 'success' ? 'banner--success' : 'banner--error'}`}
          role="alert"
          style={{ marginBottom: 'var(--space-4)' }}
        >
          <span>{feedback.message}</span>
          <button className="banner-dismiss" onClick={() => setFeedback(null)} type="button">
            ✕
          </button>
        </div>
      )}

      <form className="create-form-container" onSubmit={handleSubmit}>
        <FormCard
          description="Identify the vendor, enter their invoice reference, and set payment timelines."
          stepNumber={1}
          title="Vendor & Invoice Reference"
        >
          <FormGrid columns={4}>
            <FormField label="Vendor / Supplier" required>
              <SelectInput
                onChange={(e) => setContactId(e.target.value)}
                options={vendors.map((v) => ({
                  value: v.id,
                  label: `${v.displayName} ${v.companyName ? '(' + v.companyName + ')' : ''}`,
                }))}
                placeholderOption="-- Select Vendor --"
                required
                value={contactId}
              />
            </FormField>

            <FormField label="Vendor Invoice #" required>
              <TextInput
                onChange={(e) => setVendorBillNumber(e.target.value)}
                placeholder="e.g. INV-2026-908"
                required
                value={vendorBillNumber}
              />
            </FormField>

            <FormField label="Bill Date" required>
              <TextInput
                onChange={(e) => setBillDate(e.target.value)}
                required
                type="date"
                value={billDate}
              />
            </FormField>

            <FormField label="Due Date" required>
              <TextInput
                onChange={(e) => setDueDate(e.target.value)}
                required
                type="date"
                value={dueDate}
              />
            </FormField>

            <FormField label="Place of Supply">
              <TextInput
                onChange={(e) => setPlaceOfSupply(e.target.value)}
                placeholder="e.g. 29-Karnataka"
                value={placeOfSupply}
              />
            </FormField>

            <div style={{ display: 'flex', alignItems: 'center', height: '100%', paddingTop: 'var(--space-4)' }}>
              <CheckboxInput
                checked={reverseCharge}
                description="Tax payable by recipient under RCM"
                onChange={(e) => setReverseCharge(e.target.checked)}
                title="Reverse Charge"
              />
            </div>
          </FormGrid>
        </FormCard>

        <FormCard
          description="Vendor products/services, received quantities, tax rates, and landed costs."
          headerAction={
            <div style={{ minWidth: 260 }}>
              <SelectInput
                onChange={(e) => {
                  if (e.target.value) {
                    handleAddItem(e.target.value)
                    e.target.value = ''
                  }
                }}
                options={catalogItems.map((item) => ({
                  value: item.id,
                  label: `${item.name} (${item.sku || 'No SKU'})`,
                }))}
                placeholderOption="+ Add Item to Bill..."
                value=""
              />
            </div>
          }
          stepNumber={2}
          title={`Bill Line Items (${lines.length})`}
        >
          {lines.length === 0 ? (
            <div className="directory-state" style={{ padding: 'var(--space-6)' }}>
              <FileCheck size={28} />
              <p>No line items added yet. Select an item above to add it to this bill.</p>
            </div>
          ) : (
            <>
              <DataTable caption="Bill Lines">
                <thead>
                  <tr>
                    <th scope="col">Description</th>
                    <th scope="col">HSN</th>
                    <th className="numeric-cell" scope="col">Qty</th>
                    <th className="numeric-cell" scope="col">Unit Cost (₹)</th>
                    <th className="numeric-cell" scope="col">GST %</th>
                    <th className="numeric-cell" scope="col">Tax</th>
                    <th className="numeric-cell" scope="col">Total</th>
                    <th style={{ width: '40px' }} />
                  </tr>
                </thead>
                <tbody>
                  {lines.map((line) => (
                    <tr key={line.id}>
                      <td>
                        <div className="cell-stack">
                          <strong>{line.itemName}</strong>
                          <TextInput
                            onChange={(e) => handleUpdateLine(line.id, { description: e.target.value })}
                            placeholder="Line description"
                            style={{ marginTop: 'var(--space-1)', width: '100%' }}
                            value={line.description}
                          />
                        </div>
                      </td>
                      <td>
                        <TextInput
                          onChange={(e) => handleUpdateLine(line.id, { hsnCode: e.target.value })}
                          placeholder="HSN"
                          style={{ width: 85 }}
                          value={line.hsnCode}
                        />
                      </td>
                      <td className="numeric-cell">
                        <NumberInput
                          min={1}
                          onChange={(e) => handleUpdateLine(line.id, { quantity: parseFloat(e.target.value) || 0 })}
                          step="1"
                          style={{ width: 75 }}
                          value={line.quantity}
                        />
                      </td>
                      <td className="numeric-cell">
                        <NumberInput
                          currencyPrefix="₹"
                          min={0}
                          onChange={(e) => handleUpdateLine(line.id, { unitPrice: parseFloat(e.target.value) || 0 })}
                          step="0.01"
                          style={{ width: 105 }}
                          value={line.unitPrice}
                        />
                      </td>
                      <td className="numeric-cell">
                        <NumberInput
                          max={28}
                          min={0}
                          onChange={(e) => handleUpdateLine(line.id, { gstRate: parseFloat(e.target.value) || 0 })}
                          step="any"
                          style={{ width: 75 }}
                          unitSuffix="%"
                          value={line.gstRate}
                        />
                      </td>
                      <td className="numeric-cell">
                        <Money amount={line.lineTax} />
                      </td>
                      <td className="numeric-cell">
                        <strong>
                          <Money amount={line.lineTotal} />
                        </strong>
                      </td>
                      <td>
                        <Button
                          aria-label="Remove item"
                          onClick={() => handleRemoveLine(line.id)}
                          type="button"
                          variant="ghost"
                        >
                          <Trash2 color="var(--color-danger)" size={14} />
                        </Button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </DataTable>

              <div className="form-summary-card">
                <div className="form-summary-row">
                  <span className="cell-muted">Taxable Subtotal:</span>
                  <Money amount={subtotal} />
                </div>
                <div className="form-summary-row">
                  <span className="cell-muted">Input GST (ITC):</span>
                  <Money amount={totalGst} />
                </div>
                <div className="form-summary-row form-summary-row--total">
                  <span>Bill Total:</span>
                  <Money amount={grandTotal} />
                </div>
              </div>
            </>
          )}
        </FormCard>

        <FormCard
          description="Internal verification notes and vendor references."
          stepNumber={3}
          title="Notes & References"
        >
          <FormField label="Internal / Vendor Notes">
            <TextAreaInput
              onChange={(e) => setNotes(e.target.value)}
              placeholder="Vendor notes, verification comments..."
              rows={3}
              value={notes}
            />
          </FormField>
        </FormCard>

        <div className="form-actions-bar">
          <Button
            onClick={() => navigate(appRoutes.bills)}
            type="button"
            variant="secondary"
          >
            Cancel
          </Button>
          <Button
            disabled={createMutation.isPending || !contactId || lines.length === 0}
            type="submit"
            variant="primary"
          >
            <Save size={16} />
            {createMutation.isPending ? 'Saving...' : 'Record Vendor Bill'}
          </Button>
        </div>
      </form>
    </section>
  )
}
