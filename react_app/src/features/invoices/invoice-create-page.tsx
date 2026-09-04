import { useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, Save, Trash2 } from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { listContacts } from '@/features/contacts/contacts-api'
import {
  createInvoice,
  type CreateInvoiceLineRequest,
  type CreateInvoiceRequest,
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
    mutationFn: (req: CreateInvoiceRequest) => createInvoice(req),
    onSuccess: (created) => {
      queryClient.invalidateQueries({ queryKey: ['invoices'] })
      navigate(appRoutes.invoiceDetail(created.id))
    },
    onError: (err: unknown) => {
      const msg = err instanceof Error ? err.message : 'Failed to create invoice.'
      setFeedback({ type: 'error', message: msg })
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
      <div style={{ marginBottom: 'var(--space-3)' }}>
        <Link
          to={appRoutes.invoices}
          style={{
            alignItems: 'center',
            color: 'var(--text-secondary)',
            display: 'inline-flex',
            fontSize: 'var(--text-sm)',
            gap: 'var(--space-1)',
            textDecoration: 'none',
          }}
        >
          <ArrowLeft size={16} /> Back to Invoices
        </Link>
      </div>

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

      <form id="inv-form" onSubmit={handleSubmit}>
        <div style={{ display: 'grid', gap: 'var(--space-4)', marginBottom: 'var(--space-6)' }}>
          <div className="document-card">
            <h2 style={{ marginBottom: 'var(--space-3)' }}>1. Customer & Billing Dates</h2>
            <div style={{ display: 'grid', gap: 'var(--space-4)', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))' }}>
              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Customer *
                </label>
                <select
                  onChange={(e) => setContactId(e.target.value)}
                  required
                  style={{
                    background: 'var(--bg-surface)',
                    border: '1px solid var(--border-strong)',
                    borderRadius: 'var(--radius)',
                    color: 'var(--text-primary)',
                    height: 'var(--control-h)',
                    padding: '0 var(--space-2)',
                    width: '100%',
                  }}
                  value={contactId}
                >
                  <option value="">-- Select Customer --</option>
                  {customers.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.displayName} {c.companyName ? `(${c.companyName})` : ''}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Invoice Date *
                </label>
                <input
                  onChange={(e) => setInvoiceDate(e.target.value)}
                  required
                  style={{
                    background: 'var(--bg-surface)',
                    border: '1px solid var(--border-strong)',
                    borderRadius: 'var(--radius)',
                    color: 'var(--text-primary)',
                    height: 'var(--control-h)',
                    padding: '0 var(--space-2)',
                    width: '100%',
                  }}
                  type="date"
                  value={invoiceDate}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Due Date
                </label>
                <input
                  onChange={(e) => setDueDate(e.target.value)}
                  style={{
                    background: 'var(--bg-surface)',
                    border: '1px solid var(--border-strong)',
                    borderRadius: 'var(--radius)',
                    color: 'var(--text-primary)',
                    height: 'var(--control-h)',
                    padding: '0 var(--space-2)',
                    width: '100%',
                  }}
                  type="date"
                  value={dueDate}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Place of Supply
                </label>
                <input
                  onChange={(e) => setPlaceOfSupply(e.target.value)}
                  placeholder="e.g. 29-Karnataka"
                  style={{
                    background: 'var(--bg-surface)',
                    border: '1px solid var(--border-strong)',
                    borderRadius: 'var(--radius)',
                    color: 'var(--text-primary)',
                    height: 'var(--control-h)',
                    padding: '0 var(--space-2)',
                    width: '100%',
                  }}
                  type="text"
                  value={placeOfSupply}
                />
              </div>

              <div style={{ display: 'flex', alignItems: 'center', gap: '8px', paddingTop: '22px' }}>
                <label style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: 'var(--text-xs)', cursor: 'pointer' }}>
                  <input
                    checked={reverseCharge}
                    onChange={(e) => setReverseCharge(e.target.checked)}
                    type="checkbox"
                  />
                  <span>Reverse Charge (RCM)</span>
                </label>
              </div>
            </div>
          </div>

          <div className="document-card document-card--lines">
            <div style={{ alignItems: 'center', display: 'flex', justifyContent: 'space-between', marginBottom: 'var(--space-3)' }}>
              <h2>2. Invoice Line Items</h2>
              <div>
                <select
                  onChange={(e) => {
                    if (e.target.value) {
                      handleAddItem(e.target.value)
                      e.target.value = ''
                    }
                  }}
                  style={{
                    background: 'var(--bg-surface)',
                    border: '1px solid var(--border-strong)',
                    borderRadius: 'var(--radius)',
                    color: 'var(--text-primary)',
                    height: '32px',
                    padding: '0 var(--space-2)',
                  }}
                  value=""
                >
                  <option value="">+ Add Item to Invoice...</option>
                  {catalogItems.map((item) => (
                    <option key={item.id} value={item.id}>
                      {item.name} ({item.sku || 'No SKU'})
                    </option>
                  ))}
                </select>
              </div>
            </div>

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
                          style={{
                            background: 'transparent',
                            border: '0',
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
                <div style={{ minWidth: '260px' }}>
                  <div className="progress-row">
                    <span>Taxable Subtotal</span>
                    <Money amount={subtotal} />
                  </div>
                  <div className="progress-row">
                    <span>Total GST Amount</span>
                    <Money amount={totalGst} />
                  </div>
                  <div className="progress-row progress-row--total">
                    <span>Invoice Total</span>
                    <Money amount={grandTotal} />
                  </div>
                </div>
              </div>
            )}
          </div>

          <div className="document-card">
            <h2 style={{ marginBottom: 'var(--space-3)' }}>3. Terms & Notes</h2>
            <div style={{ display: 'grid', gap: 'var(--space-4)', gridTemplateColumns: '1fr 1fr' }}>
              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Invoice Notes (shown to customer)
                </label>
                <textarea
                  onChange={(e) => setNotes(e.target.value)}
                  rows={3}
                  style={{
                    background: 'var(--bg-surface)',
                    border: '1px solid var(--border-strong)',
                    borderRadius: 'var(--radius)',
                    color: 'var(--text-primary)',
                    padding: 'var(--space-2)',
                    width: '100%',
                  }}
                  value={notes}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Terms & Conditions
                </label>
                <textarea
                  onChange={(e) => setTermsAndConditions(e.target.value)}
                  rows={3}
                  style={{
                    background: 'var(--bg-surface)',
                    border: '1px solid var(--border-strong)',
                    borderRadius: 'var(--radius)',
                    color: 'var(--text-primary)',
                    padding: 'var(--space-2)',
                    width: '100%',
                  }}
                  value={termsAndConditions}
                />
              </div>
            </div>
          </div>
        </div>
      </form>
    </section>
  )
}
