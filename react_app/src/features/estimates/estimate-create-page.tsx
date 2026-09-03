import { useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  ArrowLeft,
  FileCheck,
  Save,
  Trash2,
} from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { listContacts } from '@/features/contacts/contacts-api'
import {
  createEstimate,
  type CreateEstimateRequest,
  type EstimateLineRequest,
} from '@/features/estimates/estimates-api'
import { listItems } from '@/features/items/items-api'

type FormLine = EstimateLineRequest & {
  id: string
  itemName: string
  unit: string
  calculatedAmount: number
}

export function EstimateCreatePage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const todayStr = new Date().toISOString().split('T')[0] || ''

  const defaultExpiryStr = useMemo(() => {
    const d = new Date()
    d.setDate(d.getDate() + 30)
    return d.toISOString().split('T')[0] || ''
  }, [])

  // Form State
  const [contactId, setContactId] = useState('')
  const [estimateDate, setEstimateDate] = useState(todayStr)
  const [expiryDate, setExpiryDate] = useState(defaultExpiryStr)
  const [referenceNumber, setReferenceNumber] = useState('')
  const [notes, setNotes] = useState('Thank you for considering our proposal.')
  const [terms, setTerms] = useState('Payment terms: 30 days. Prices valid for 30 days from proposal date.')
  const [feedback, setFeedback] = useState<{ type: 'success' | 'error'; message: string } | null>(null)

  const [lines, setLines] = useState<FormLine[]>([])

  // Queries
  const contactsQuery = useQuery({
    queryKey: ['contacts-select-customer'],
    queryFn: () => listContacts({ filter: 'CUSTOMER', page: 0, search: '' }),
  })

  const itemsQuery = useQuery({
    queryKey: ['items-select-estimate'],
    queryFn: () => listItems({ page: 0, size: 200 }),
  })

  const contacts = contactsQuery.data?.content ?? []
  const items = itemsQuery.data?.content ?? []

  // Add Item to Lines
  const handleAddItem = (itemId: string) => {
    const found = items.find((i) => i.id === itemId)
    if (!found) return
    const rate = Number(found.rate || found.purchasePrice || 0)
    const newLine: FormLine = {
      id: Math.random().toString(36).substring(2, 9),
      itemId: found.id,
      itemName: found.name,
      unit: found.unit || 'pcs',
      description: found.name,
      quantity: 1,
      rate: rate,
      taxGroupId: found.taxGroupId || undefined,
      hsnCode: found.hsnCode || undefined,
      discountPercentage: 0,
      calculatedAmount: rate * 1,
    }
    setLines([...lines, newLine])
  }

  const handleUpdateLine = (id: string, updates: Partial<FormLine>) => {
    setLines(
      lines.map((l) => {
        if (l.id !== id) return l
        const updated = { ...l, ...updates }
        const raw = (updated.quantity || 0) * (updated.rate || 0)
        const disc = ((updated.discountPercentage || 0) / 100) * raw
        updated.calculatedAmount = Math.max(0, raw - disc)
        return updated
      })
    )
  }

  const handleRemoveLine = (id: string) => {
    setLines(lines.filter((l) => l.id !== id))
  }

  // Totals
  const subtotal = useMemo(() => {
    return lines.reduce((sum, l) => sum + l.calculatedAmount, 0)
  }, [lines])

  const taxAmount = useMemo(() => {
    // 5% standard tax estimation unless mapped
    return Math.round(subtotal * 0.05 * 100) / 100
  }, [subtotal])

  const grandTotal = subtotal + taxAmount

  // Mutations
  const createMutation = useMutation({
    mutationFn: (req: CreateEstimateRequest) => createEstimate(req),
    onSuccess: (est) => {
      queryClient.invalidateQueries({ queryKey: ['estimates-list'] })
      navigate(`/estimates/${est.id}`)
    },
    onError: (err: unknown) => {
      setFeedback({
        type: 'error',
        message: err instanceof Error ? err.message : 'Failed to create estimate proposal.',
      })
    },
  })

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (!contactId) {
      setFeedback({ type: 'error', message: 'Please select a customer.' })
      return
    }
    if (!lines.length) {
      setFeedback({ type: 'error', message: 'Please add at least one line item.' })
      return
    }

    const payload: CreateEstimateRequest = {
      contactId,
      estimateDate,
      expiryDate: expiryDate || undefined,
      referenceNumber: referenceNumber.trim() || undefined,
      notes: notes.trim() || undefined,
      terms: terms.trim() || undefined,
      lines: lines.map((l) => ({
        itemId: l.itemId,
        description: l.description,
        quantity: l.quantity,
        rate: l.rate,
        taxGroupId: l.taxGroupId,
        hsnCode: l.hsnCode,
        discountPercentage: l.discountPercentage,
        batchId: l.batchId,
      })),
    }

    createMutation.mutate(payload)
  }

  return (
    <section className="workspace-page">
      <div style={{ marginBottom: 'var(--space-sm)' }}>
        <Link className="table-row-action" to="/estimates">
          <ArrowLeft aria-hidden="true" size={14} style={{ display: 'inline', marginRight: 4 }} />
          Back to all estimates
        </Link>
      </div>

      <PageHeader
        eyebrow="Sales Proposal Builder"
        title="Create New Estimate"
        description="Draft a formal price proposal with product lines, tax calculations, discounts, and terms."
      />

      {feedback && (
        <div
          className={`banner ${feedback.type === 'success' ? 'banner--success' : 'banner--error'}`}
          role="status"
          style={{ marginBottom: 'var(--space-md)' }}
        >
          <span>{feedback.message}</span>
          <button className="banner-dismiss" onClick={() => setFeedback(null)} type="button">
            ×
          </button>
        </div>
      )}

      <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-md)' }}>
        {/* Header Information Card */}
        <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
          <h3 style={{ fontSize: '1.05rem', margin: '0 0 var(--space-sm) 0' }}>Estimate Header & Customer</h3>
          <div className="form-grid">
            <div className="form-field">
              <label htmlFor="contactId">Customer / Client *</label>
              <select
                id="contactId"
                required
                value={contactId}
                onChange={(e) => setContactId(e.target.value)}
              >
                <option value="">Select customer...</option>
                {contacts.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name} {c.phone ? '(' + c.phone + ')' : ''}
                  </option>
                ))}
              </select>
            </div>

            <div className="form-field">
              <label htmlFor="estimateDate">Estimate Date *</label>
              <input
                id="estimateDate"
                type="date"
                required
                value={estimateDate}
                onChange={(e) => setEstimateDate(e.target.value)}
              />
            </div>

            <div className="form-field">
              <label htmlFor="expiryDate">Expiry / Validity Date</label>
              <input
                id="expiryDate"
                type="date"
                value={expiryDate}
                onChange={(e) => setExpiryDate(e.target.value)}
              />
            </div>

            <div className="form-field">
              <label htmlFor="referenceNumber">Client Reference / PO Ref</label>
              <input
                id="referenceNumber"
                type="text"
                value={referenceNumber}
                onChange={(e) => setReferenceNumber(e.target.value)}
                placeholder="e.g. RFQ-2026-99"
              />
            </div>
          </div>
        </div>

        {/* Line Items Card */}
        <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 'var(--space-sm)' }}>
            <h3 style={{ fontSize: '1.05rem', margin: 0 }}>Line Items ({lines.length})</h3>
            <div style={{ display: 'flex', gap: 'var(--space-sm)', alignItems: 'center' }}>
              <select
                onChange={(e) => {
                  if (e.target.value) {
                    handleAddItem(e.target.value)
                    e.target.value = ''
                  }
                }}
                style={{ padding: '6px 12px', borderRadius: 'var(--radius-sm)', border: '1px solid var(--color-border)' }}
              >
                <option value="">+ Add Item to Proposal...</option>
                {items.map((it) => (
                  <option key={it.id} value={it.id}>
                    {it.name} (Stock: {it.stockBalance ?? it.onHandStock ?? 0} {it.unit || ''})
                  </option>
                ))}
              </select>
            </div>
          </div>

          {lines.length === 0 ? (
            <div className="directory-state" style={{ padding: 'var(--space-lg)' }}>
              <FileCheck size={24} />
              <p>No items added yet. Select products from the dropdown above to build the quotation.</p>
            </div>
          ) : (
            <DataTable caption="Estimate line items">
              <thead>
                <tr>
                  <th scope="col">Item & Description</th>
                  <th scope="col">HSN</th>
                  <th className="numeric-cell" scope="col">Rate (₹)</th>
                  <th className="numeric-cell" scope="col">Qty</th>
                  <th className="numeric-cell" scope="col">Disc %</th>
                  <th className="numeric-cell" scope="col">Amount</th>
                  <th className="numeric-cell" scope="col">Action</th>
                </tr>
              </thead>
              <tbody>
                {lines.map((l) => (
                  <tr key={l.id}>
                    <td>
                      <div className="cell-stack">
                        <strong>{l.itemName}</strong>
                        <input
                          type="text"
                          value={l.description || ''}
                          onChange={(e) => handleUpdateLine(l.id, { description: e.target.value })}
                          placeholder="Optional line notes"
                          style={{
                            fontSize: '0.8rem',
                            padding: '2px 6px',
                            borderRadius: 'var(--radius-sm)',
                            border: '1px solid var(--color-border)',
                            width: '100%',
                            marginTop: 2,
                          }}
                        />
                      </div>
                    </td>
                    <td>
                      <input
                        type="text"
                        value={l.hsnCode || ''}
                        onChange={(e) => handleUpdateLine(l.id, { hsnCode: e.target.value })}
                        placeholder="HSN"
                        style={{
                          width: 80,
                          fontSize: '0.8rem',
                          padding: '2px 6px',
                          borderRadius: 'var(--radius-sm)',
                          border: '1px solid var(--color-border)',
                        }}
                      />
                    </td>
                    <td className="numeric-cell">
                      <input
                        type="number"
                        min="0"
                        step="0.01"
                        value={l.rate}
                        onChange={(e) => handleUpdateLine(l.id, { rate: Number(e.target.value) || 0 })}
                        style={{
                          width: 90,
                          textAlign: 'right',
                          padding: '4px 6px',
                          borderRadius: 'var(--radius-sm)',
                          border: '1px solid var(--color-border)',
                        }}
                      />
                    </td>
                    <td className="numeric-cell">
                      <div style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
                        <input
                          type="number"
                          min="1"
                          step="1"
                          value={l.quantity}
                          onChange={(e) => handleUpdateLine(l.id, { quantity: Number(e.target.value) || 1 })}
                          style={{
                            width: 65,
                            textAlign: 'right',
                            padding: '4px 6px',
                            borderRadius: 'var(--radius-sm)',
                            border: '1px solid var(--color-border)',
                          }}
                        />
                        <span className="cell-muted" style={{ fontSize: '0.75rem' }}>{l.unit}</span>
                      </div>
                    </td>
                    <td className="numeric-cell">
                      <input
                        type="number"
                        min="0"
                        max="100"
                        step="0.1"
                        value={l.discountPercentage || 0}
                        onChange={(e) => handleUpdateLine(l.id, { discountPercentage: Number(e.target.value) || 0 })}
                        style={{
                          width: 60,
                          textAlign: 'right',
                          padding: '4px 6px',
                          borderRadius: 'var(--radius-sm)',
                          border: '1px solid var(--color-border)',
                        }}
                      />
                    </td>
                    <td className="numeric-cell">
                      <strong>
                        <Money amount={l.calculatedAmount} />
                      </strong>
                    </td>
                    <td className="numeric-cell">
                      <Button onClick={() => handleRemoveLine(l.id)} type="button" variant="ghost">
                        <Trash2 size={14} color="var(--color-danger)" />
                      </Button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          )}

          {/* Grand Totals */}
          {lines.length > 0 && (
            <div
              style={{
                marginTop: 'var(--space-md)',
                display: 'flex',
                justifyContent: 'flex-end',
              }}
            >
              <div
                style={{
                  width: 280,
                  display: 'flex',
                  flexDirection: 'column',
                  gap: 6,
                  padding: 'var(--space-md)',
                  background: 'var(--color-surface-subtle)',
                  borderRadius: 'var(--radius-md)',
                }}
              >
                <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                  <span className="cell-muted">Subtotal:</span>
                  <Money amount={subtotal} />
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                  <span className="cell-muted">Estimated GST:</span>
                  <Money amount={taxAmount} />
                </div>
                <div
                  style={{
                    display: 'flex',
                    justifyContent: 'space-between',
                    borderTop: '1px solid var(--color-border)',
                    paddingTop: 6,
                    marginTop: 4,
                    fontWeight: 'bold',
                    fontSize: '1.05rem',
                  }}
                >
                  <span>Grand Total:</span>
                  <Money amount={grandTotal} />
                </div>
              </div>
            </div>
          )}
        </div>

        {/* Notes & Terms */}
        <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
          <div className="form-grid">
            <div className="form-field form-field--full">
              <label htmlFor="notes">Customer Notes (Printed on Proposal)</label>
              <textarea
                id="notes"
                rows={2}
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
              />
            </div>
            <div className="form-field form-field--full">
              <label htmlFor="terms">Terms & Conditions</label>
              <textarea
                id="terms"
                rows={2}
                value={terms}
                onChange={(e) => setTerms(e.target.value)}
              />
            </div>
          </div>
        </div>

        <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 'var(--space-sm)' }}>
          <Link className="btn btn--secondary" to="/estimates">
            Cancel
          </Link>
          <Button disabled={createMutation.isPending} type="submit" variant="primary">
            <Save size={14} style={{ marginRight: 6 }} />
            {createMutation.isPending ? 'Saving...' : 'Save Estimate'}
          </Button>
        </div>
      </form>
    </section>
  )
}
