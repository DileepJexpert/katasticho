import { useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, Save, Trash2 } from 'lucide-react'
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
  PageHeader,
  SelectInput,
  TextAreaInput,
  TextInput,
} from '@/design-system'
import { listContacts } from '@/features/contacts/contacts-api'
import {
  createInvoice,
  type CreateInvoiceLineRequest,
} from '@/features/invoices/invoices-api'
import { listItems } from '@/features/items/items-api'

interface InvoiceLineFormItem extends CreateInvoiceLineRequest {
  id: string
  itemName: string
  lineTaxAmount: number
  lineTotal: number
}

export function InvoiceCreatePage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const [contactId, setContactId] = useState('')
  const [invoiceDate, setInvoiceDate] = useState(() => new Date().toISOString().split('T')[0] || '')
  const [dueDate, setDueDate] = useState(() => {
    const d = new Date()
    d.setDate(d.getDate() + 30)
    return d.toISOString().split('T')[0] || ''
  })
  const [placeOfSupply, setPlaceOfSupply] = useState('')
  const [reverseCharge, setReverseCharge] = useState(false)
  const [notes, setNotes] = useState('Payment is due within 30 days of invoice date.')
  const [termsAndConditions, setTermsAndConditions] = useState('Standard terms apply.')
  const [lines, setLines] = useState<InvoiceLineFormItem[]>([])
  const [feedback, setFeedback] = useState<{ type: 'error' | 'success'; message: string } | null>(null)

  const contactsQuery = useQuery({
    queryKey: ['contacts-for-inv'],
    queryFn: () => listContacts({ filter: 'CUSTOMER', page: 0 }),
  })

  const itemsQuery = useQuery({
    queryKey: ['items-for-inv'],
    queryFn: () => listItems({ page: 0 }),
  })

  const customers = contactsQuery.data?.content ?? []
  const catalogItems = itemsQuery.data?.content ?? []

  const handleAddItem = (itemId: string) => {
    const item = catalogItems.find((i) => i.id === itemId)
    if (!item) return
    const price = Number(item.salePrice || item.purchasePrice || 0)
    const gst = Number(item.gstRate || 18)
    const tax = (price * gst) / 100
    const newLine: InvoiceLineFormItem = {
      id: Math.random().toString(36).substring(2, 9),
      itemId: item.id,
      itemName: item.name,
      description: item.name,
      hsnCode: item.hsnCode || '',
      quantity: 1,
      unitPrice: price,
      gstRate: gst,
      lineTaxAmount: tax,
      lineTotal: price + tax,
    }
    setLines((prev) => [...prev, newLine])
  }

  const handleUpdateLine = (id: string, updates: Partial<InvoiceLineFormItem>) => {
    setLines((prev) =>
      prev.map((l) => {
        if (l.id !== id) return l
        const updated = { ...l, ...updates }
        const taxable = (updated.quantity || 0) * (updated.unitPrice || 0)
        const tax = ((updated.gstRate || 0) / 100) * taxable
        updated.lineTaxAmount = tax
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
    return lines.reduce((acc, l) => acc + (l.lineTaxAmount || 0), 0)
  }, [lines])

  const grandTotal = useMemo(() => {
    return subtotal + totalGst
  }, [subtotal, totalGst])

  const createMutation = useMutation({
    mutationFn: createInvoice,
    onSuccess: (created) => {
      queryClient.invalidateQueries({ queryKey: ['invoices'] })
      navigate(appRoutes.invoiceDetail(created.id))
    },
    onError: (err) => {
      setFeedback({
        type: 'error',
        message: err instanceof Error ? err.message : 'Failed to create sales invoice',
      })
    },
  })

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    setFeedback(null)

    if (!contactId) {
      setFeedback({ type: 'error', message: 'Please select a customer.' })
      return
    }

    if (lines.length === 0) {
      setFeedback({ type: 'error', message: 'Please add at least one line item to the invoice.' })
      return
    }

    createMutation.mutate({
      contactId,
      invoiceDate,
      dueDate,
      placeOfSupply: placeOfSupply.trim() || undefined,
      reverseCharge,
      notes: notes.trim() || undefined,
      termsAndConditions: termsAndConditions.trim() || undefined,
      lines: lines.map((l) => ({
        itemId: l.itemId,
        description: l.description,
        hsnCode: l.hsnCode || undefined,
        quantity: l.quantity,
        unitPrice: l.unitPrice,
        gstRate: l.gstRate,
      })),
    })
  }

  return (
    <section className="workspace-page">
      <Link className="form-back-link" to={appRoutes.invoices}>
        <ArrowLeft size={16} /> Back to Invoices
      </Link>

      <PageHeader
        eyebrow="Sales / Receivables"
        title="New Sales Invoice"
        description="Issue tax-compliant sales invoices with HSN classifications, item-level GST breakdowns, and receivable tracking."
        actions={
          <div style={{ display: 'flex', gap: 'var(--space-2)' }}>
            <Button
              onClick={() => navigate(appRoutes.invoices)}
              type="button"
              variant="secondary"
            >
              Cancel
            </Button>
            <Button
              disabled={createMutation.isPending || !contactId || lines.length === 0}
              form="inv-form"
              type="submit"
              variant="primary"
            >
              <Save size={16} />
              {createMutation.isPending ? 'Saving...' : 'Create Invoice'}
            </Button>
          </div>
        }
      />

      {feedback && (
        <div
          className={`directory-state ${feedback.type === 'error' ? 'directory-state--error' : ''}`}
          role="alert"
          style={{ marginBottom: 'var(--space-4)', minHeight: 'auto', padding: 'var(--space-3)' }}
        >
          <strong>{feedback.message}</strong>
        </div>
      )}

      <form className="create-form-container" id="inv-form" onSubmit={handleSubmit}>
        <FormCard
          description="Specify client party and invoice timeline"
          stepNumber={1}
          title="Customer & Billing Dates"
        >
          <FormGrid columns={4}>
            <FormField label="Customer" required>
              <SelectInput
                onChange={(e) => setContactId(e.target.value)}
                placeholderOption="-- Select Customer --"
                required
                value={contactId}
              >
                {customers.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.displayName} {c.companyName ? `(${c.companyName})` : ''}
                  </option>
                ))}
              </SelectInput>
            </FormField>

            <FormField label="Invoice Date" required>
              <TextInput
                onChange={(e) => setInvoiceDate(e.target.value)}
                required
                type="date"
                value={invoiceDate}
              />
            </FormField>

            <FormField label="Due Date">
              <TextInput
                onChange={(e) => setDueDate(e.target.value)}
                type="date"
                value={dueDate}
              />
            </FormField>

            <FormField label="Place of Supply">
              <TextInput
                onChange={(e) => setPlaceOfSupply(e.target.value)}
                placeholder="e.g. 29-Karnataka"
                type="text"
                value={placeOfSupply}
              />
            </FormField>
          </FormGrid>

          <div style={{ marginTop: 'var(--space-2)' }}>
            <CheckboxInput
              checked={reverseCharge}
              description="Check if tax on this supply is payable by recipient under Section 9(3) / 9(4)"
              label="Reverse Charge Mechanism (RCM)"
              onChange={(e) => setReverseCharge(e.target.checked)}
            />
          </div>
        </FormCard>

        <FormCard
          description="Product lines, quantities, rates, and tax calculations"
          headerAction={
            <SelectInput
              onChange={(e) => {
                if (e.target.value) {
                  handleAddItem(e.target.value)
                  e.target.value = ''
                }
              }}
              placeholderOption="+ Add Item to Invoice..."
              style={{ minWidth: '240px' }}
              value=""
            >
              {catalogItems.map((item) => (
                <option key={item.id} value={item.id}>
                  {item.name} ({item.sku || 'No SKU'})
                </option>
              ))}
            </SelectInput>
          }
          stepNumber={2}
          title="Invoice Line Items"
        >
          {lines.length === 0 ? (
            <div className="directory-state" style={{ minHeight: '120px' }}>
              No line items added yet. Select an item above to add it to this invoice.
            </div>
          ) : (
            <DataTable caption="Invoice Lines">
              <thead>
                <tr>
                  <th scope="col">Item / Description</th>
                  <th scope="col">HSN</th>
                  <th className="numeric-cell" scope="col">Qty</th>
                  <th className="numeric-cell" scope="col">Unit Price (₹)</th>
                  <th className="numeric-cell" scope="col">GST %</th>
                  <th className="numeric-cell" scope="col">Tax (₹)</th>
                  <th className="numeric-cell" scope="col">Line Total</th>
                  <th style={{ width: '40px' }} />
                </tr>
              </thead>
              <tbody>
                {lines.map((line) => (
                  <tr key={line.id}>
                    <td>
                      <strong>{line.itemName}</strong>
                      <input
                        onChange={(e) => handleUpdateLine(line.id, { description: e.target.value })}
                        placeholder="Item description"
                        style={{
                          background: 'transparent',
                          border: 0,
                          borderBottom: '1px solid var(--border)',
                          color: 'var(--text-secondary)',
                          display: 'block',
                          fontSize: '12px',
                          marginTop: '2px',
                          width: '100%',
                        }}
                        value={line.description}
                      />
                    </td>
                    <td>
                      <input
                        onChange={(e) => handleUpdateLine(line.id, { hsnCode: e.target.value })}
                        placeholder="HSN"
                        style={{
                          background: 'var(--bg-surface)',
                          border: '1px solid var(--border)',
                          borderRadius: 'var(--radius)',
                          color: 'var(--text-primary)',
                          height: '28px',
                          padding: '0 4px',
                          width: '80px',
                        }}
                        value={line.hsnCode}
                      />
                    </td>
                    <td className="numeric-cell">
                      <input
                        min="1"
                        onChange={(e) => handleUpdateLine(line.id, { quantity: parseFloat(e.target.value) || 0 })}
                        step="any"
                        style={{
                          background: 'var(--bg-surface)',
                          border: '1px solid var(--border-strong)',
                          borderRadius: 'var(--radius)',
                          color: 'var(--text-primary)',
                          height: '28px',
                          padding: '0 var(--space-2)',
                          textAlign: 'right',
                          width: '70px',
                        }}
                        type="number"
                        value={line.quantity}
                      />
                    </td>
                    <td className="numeric-cell">
                      <input
                        min="0"
                        onChange={(e) => handleUpdateLine(line.id, { unitPrice: parseFloat(e.target.value) || 0 })}
                        step="0.01"
                        style={{
                          background: 'var(--bg-surface)',
                          border: '1px solid var(--border-strong)',
                          borderRadius: 'var(--radius)',
                          color: 'var(--text-primary)',
                          height: '28px',
                          padding: '0 var(--space-2)',
                          textAlign: 'right',
                          width: '90px',
                        }}
                        type="number"
                        value={line.unitPrice}
                      />
                    </td>
                    <td className="numeric-cell">
                      <input
                        max="28"
                        min="0"
                        onChange={(e) => handleUpdateLine(line.id, { gstRate: parseFloat(e.target.value) || 0 })}
                        step="any"
                        style={{
                          background: 'var(--bg-surface)',
                          border: '1px solid var(--border)',
                          borderRadius: 'var(--radius)',
                          color: 'var(--text-primary)',
                          height: '28px',
                          padding: '0 var(--space-2)',
                          textAlign: 'right',
                          width: '60px',
                        }}
                        type="number"
                        value={line.gstRate}
                      />
                    </td>
                    <td className="numeric-cell">
                      <Money amount={line.lineTaxAmount} />
                    </td>
                    <td className="numeric-cell">
                      <Money amount={line.lineTotal} />
                    </td>
                    <td>
                      <button
                        aria-label="Remove line"
                        onClick={() => handleRemoveLine(line.id)}
                        style={{
                          background: 'transparent',
                          border: 0,
                          color: 'var(--neg-text)',
                          cursor: 'pointer',
                          padding: '4px',
                        }}
                        type="button"
                      >
                        <Trash2 size={16} />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          )}

          {lines.length > 0 && (
            <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: 'var(--space-4)' }}>
              <div className="form-summary-card">
                <div className="form-summary-row">
                  <span>Taxable Subtotal</span>
                  <strong><Money amount={subtotal} /></strong>
                </div>
                <div className="form-summary-row">
                  <span>Total GST Amount</span>
                  <strong><Money amount={totalGst} /></strong>
                </div>
                <div className="form-summary-row form-summary-row--total">
                  <span>Invoice Total</span>
                  <span className="amount"><Money amount={grandTotal} /></span>
                </div>
              </div>
            </div>
          )}
        </FormCard>

        <FormCard
          description="Custom notes and terms displayed on customer PDF invoice"
          stepNumber={3}
          title="Terms & Notes"
        >
          <FormGrid columns={2}>
            <FormField label="Invoice Notes (shown to customer)">
              <TextAreaInput
                onChange={(e) => setNotes(e.target.value)}
                rows={3}
                value={notes}
              />
            </FormField>

            <FormField label="Terms & Conditions">
              <TextAreaInput
                onChange={(e) => setTermsAndConditions(e.target.value)}
                rows={3}
                value={termsAndConditions}
              />
            </FormField>
          </FormGrid>
        </FormCard>

        <div className="form-actions-bar">
          <Button
            onClick={() => navigate(appRoutes.invoices)}
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
            {createMutation.isPending ? 'Saving...' : 'Create Invoice'}
          </Button>
        </div>
      </form>
    </section>
  )
}
