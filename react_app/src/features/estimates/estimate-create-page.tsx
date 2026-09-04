import { useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, FileCheck, Save, Trash2 } from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
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
    const rate = Number(found.salePrice || found.purchasePrice || 0)
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
    setLines((prev) => [...prev, newLine])
  }

  const handleUpdateLine = (id: string, updates: Partial<FormLine>) => {
    setLines((prev) =>
      prev.map((l) => {
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
    setLines((prev) => prev.filter((l) => l.id !== id))
  }

  // Totals
  const subtotal = useMemo(() => {
    return lines.reduce((sum, l) => sum + l.calculatedAmount, 0)
  }, [lines])

  const taxAmount = useMemo(() => {
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
      <Link className="form-back-link" to={appRoutes.estimates}>
        <ArrowLeft size={16} /> Back to all estimates
      </Link>

      <PageHeader
        eyebrow="Sales Proposal Builder"
        title="Create New Estimate"
        description="Draft a formal price proposal with product lines, tax calculations, discounts, and terms."
      />

      {feedback && (
        <div
          className={`banner ${feedback.type === 'success' ? 'banner--success' : 'banner--error'}`}
          role="status"
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
          description="Specify the customer, proposal issue date, validity window, and reference identifier."
          stepNumber={1}
          title="Estimate Header & Customer"
        >
          <FormGrid columns={4}>
            <FormField label="Customer / Client" required>
              <SelectInput
                onChange={(e) => setContactId(e.target.value)}
                options={contacts.map((c) => ({
                  value: c.id,
                  label: `${c.name} ${c.phone ? '(' + c.phone + ')' : ''}`,
                }))}
                placeholderOption="Select customer..."
                required
                value={contactId}
              />
            </FormField>

            <FormField label="Estimate Date" required>
              <TextInput
                onChange={(e) => setEstimateDate(e.target.value)}
                required
                type="date"
                value={estimateDate}
              />
            </FormField>

            <FormField label="Expiry / Validity Date">
              <TextInput
                onChange={(e) => setExpiryDate(e.target.value)}
                type="date"
                value={expiryDate}
              />
            </FormField>

            <FormField label="Client Reference / PO Ref">
              <TextInput
                onChange={(e) => setReferenceNumber(e.target.value)}
                placeholder="e.g. RFQ-2026-99"
                value={referenceNumber}
              />
            </FormField>
          </FormGrid>
        </FormCard>

        <FormCard
          description="Select catalog products, customize quantities, unit rates, and customer discounts."
          headerAction={
            <div style={{ minWidth: 260 }}>
              <SelectInput
                onChange={(e) => {
                  if (e.target.value) {
                    handleAddItem(e.target.value)
                    e.target.value = ''
                  }
                }}
                options={items.map((it) => ({
                  value: it.id,
                  label: `${it.name} (Stock: ${it.stockBalance ?? it.onHandStock ?? 0} ${it.unit || ''})`,
                }))}
                placeholderOption="+ Add Item to Proposal..."
                value=""
              />
            </div>
          }
          stepNumber={2}
          title={`Proposal Line Items (${lines.length})`}
        >
          {lines.length === 0 ? (
            <div className="directory-state" style={{ padding: 'var(--space-6)' }}>
              <FileCheck size={28} />
              <p>No items added yet. Select products from the dropdown above to build the quotation.</p>
            </div>
          ) : (
            <>
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
                          <TextInput
                            onChange={(e) => handleUpdateLine(l.id, { description: e.target.value })}
                            placeholder="Optional line notes"
                            style={{ marginTop: 'var(--space-1)', width: '100%' }}
                            value={l.description || ''}
                          />
                        </div>
                      </td>
                      <td>
                        <TextInput
                          onChange={(e) => handleUpdateLine(l.id, { hsnCode: e.target.value })}
                          placeholder="HSN"
                          style={{ width: 85 }}
                          value={l.hsnCode || ''}
                        />
                      </td>
                      <td className="numeric-cell">
                        <NumberInput
                          currencyPrefix="₹"
                          min={0}
                          onChange={(e) => handleUpdateLine(l.id, { rate: Number(e.target.value) || 0 })}
                          step="0.01"
                          style={{ width: 110 }}
                          value={l.rate}
                        />
                      </td>
                      <td className="numeric-cell">
                        <NumberInput
                          min={1}
                          onChange={(e) => handleUpdateLine(l.id, { quantity: Number(e.target.value) || 1 })}
                          step="1"
                          style={{ width: 80 }}
                          unitSuffix={l.unit}
                          value={l.quantity}
                        />
                      </td>
                      <td className="numeric-cell">
                        <NumberInput
                          max={100}
                          min={0}
                          onChange={(e) => handleUpdateLine(l.id, { discountPercentage: Number(e.target.value) || 0 })}
                          step="0.1"
                          style={{ width: 75 }}
                          unitSuffix="%"
                          value={l.discountPercentage || 0}
                        />
                      </td>
                      <td className="numeric-cell">
                        <strong>
                          <Money amount={l.calculatedAmount} />
                        </strong>
                      </td>
                      <td className="numeric-cell">
                        <Button onClick={() => handleRemoveLine(l.id)} type="button" variant="ghost">
                          <Trash2 color="var(--color-danger)" size={14} />
                        </Button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </DataTable>

              <div className="form-summary-card">
                <div className="form-summary-row">
                  <span className="cell-muted">Subtotal:</span>
                  <Money amount={subtotal} />
                </div>
                <div className="form-summary-row">
                  <span className="cell-muted">Estimated GST (5%):</span>
                  <Money amount={taxAmount} />
                </div>
                <div className="form-summary-row form-summary-row--total">
                  <span>Grand Total:</span>
                  <Money amount={grandTotal} />
                </div>
              </div>
            </>
          )}
        </FormCard>

        <FormCard
          description="Terms and notes will be rendered on the printed proposal and PDF quotation."
          stepNumber={3}
          title="Proposal Terms & Conditions"
        >
          <FormGrid columns={2}>
            <FormField label="Customer Notes (Printed on Proposal)">
              <TextAreaInput
                onChange={(e) => setNotes(e.target.value)}
                rows={3}
                value={notes}
              />
            </FormField>

            <FormField label="Terms & Conditions">
              <TextAreaInput
                onChange={(e) => setTerms(e.target.value)}
                rows={3}
                value={terms}
              />
            </FormField>
          </FormGrid>
        </FormCard>

        <div className="form-actions-bar">
          <Link className="btn btn--secondary" to={appRoutes.estimates}>
            Cancel
          </Link>
          <Button disabled={createMutation.isPending || !contactId || lines.length === 0} type="submit" variant="primary">
            <Save size={16} />
            {createMutation.isPending ? 'Saving...' : 'Save Estimate'}
          </Button>
        </div>
      </form>
    </section>
  )
}
