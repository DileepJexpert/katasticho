import { useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, Save, Trash2 } from 'lucide-react'
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
  TextInput,
} from '@/design-system'
import { listContacts } from '@/features/contacts/contacts-api'
import {
  createCreditNote,
  type CreateCreditNoteLineRequest,
  type CreateCreditNoteRequest,
} from '@/features/credit-notes/credit-notes-api'

interface CnLineItem extends CreateCreditNoteLineRequest {
  id: string
}

export function CreditNoteCreatePage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const [contactId, setContactId] = useState('')
  const [creditNoteDate, setCreditNoteDate] = useState(() => new Date().toISOString().split('T')[0] || '')
  const [reason, setReason] = useState('Product Return / Damaged Goods')
  const [lines, setLines] = useState<CnLineItem[]>([
    { id: '1', description: 'Goods returned by customer', quantity: 1, unitPrice: 0, gstRate: 18 },
  ])
  const [feedback, setFeedback] = useState<{ type: 'error' | 'success'; message: string } | null>(null)

  const contactsQuery = useQuery({
    queryKey: ['customers-for-cn'],
    queryFn: () => listContacts({ filter: 'CUSTOMER', page: 0 }),
  })

  const customers = contactsQuery.data?.content ?? []

  const handleAddLine = () => {
    setLines((prev) => [
      ...prev,
      { id: Math.random().toString(36).substring(2, 9), description: '', quantity: 1, unitPrice: 0, gstRate: 18 },
    ])
  }

  const handleUpdateLine = (id: string, updates: Partial<CnLineItem>) => {
    setLines((prev) =>
      prev.map((l) => (l.id === id ? { ...l, ...updates } : l))
    )
  }

  const handleRemoveLine = (id: string) => {
    setLines((prev) => prev.filter((l) => l.id !== id))
  }

  const { subtotal, taxAmount, grandTotal } = useMemo(() => {
    let sub = 0
    let tax = 0
    lines.forEach((l) => {
      const lineSub = (l.quantity || 0) * (l.unitPrice || 0)
      const lineTax = (lineSub * (l.gstRate || 0)) / 100
      sub += lineSub
      tax += lineTax
    })
    return {
      subtotal: sub,
      taxAmount: tax,
      grandTotal: sub + tax,
    }
  }, [lines])

  const createMutation = useMutation({
    mutationFn: (req: CreateCreditNoteRequest) => createCreditNote(req),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['credit-notes'] })
      navigate(appRoutes.creditNotes)
    },
    onError: (err: unknown) => {
      const msg = err instanceof Error ? err.message : 'Failed to create credit note.'
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

    createMutation.mutate({
      contactId,
      creditNoteDate,
      reason,
      lines: lines.map((l) => ({
        description: l.description,
        quantity: l.quantity,
        unitPrice: l.unitPrice,
        gstRate: l.gstRate,
      })),
    })
  }

  return (
    <section className="workspace-page">
      <Link className="form-back-link" to={appRoutes.creditNotes}>
        <ArrowLeft size={16} /> Back to Credit Notes
      </Link>

      <PageHeader
        eyebrow="Sales / Adjustments"
        title="New Credit Note"
        description="Issue credit notes for sales returns, rate differences, or post-invoice adjustments."
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
          description="Identify the customer and the commercial justification for this credit note."
          stepNumber={1}
          title="Customer & Adjustment Reason"
        >
          <FormGrid columns={3}>
            <FormField label="Customer" required>
              <SelectInput
                onChange={(e) => setContactId(e.target.value)}
                options={customers.map((c) => ({
                  value: c.id,
                  label: c.displayName || c.name,
                }))}
                placeholderOption="-- Select Customer --"
                required
                value={contactId}
              />
            </FormField>

            <FormField label="Credit Note Date" required>
              <TextInput
                onChange={(e) => setCreditNoteDate(e.target.value)}
                required
                type="date"
                value={creditNoteDate}
              />
            </FormField>

            <FormField label="Reason" required>
              <TextInput
                onChange={(e) => setReason(e.target.value)}
                placeholder="e.g. Sales return / Damaged goods"
                required
                value={reason}
              />
            </FormField>
          </FormGrid>
        </FormCard>

        <FormCard
          description="Specify line items, quantities returned or adjusted, unit rate, and GST rate."
          headerAction={
            <Button onClick={handleAddLine} type="button" variant="secondary">
              + Add Line
            </Button>
          }
          stepNumber={2}
          title={`Credit Note Lines (${lines.length})`}
        >
          <DataTable caption="Credit note lines">
            <thead>
              <tr>
                <th scope="col">Description</th>
                <th className="numeric-cell" scope="col">Qty</th>
                <th className="numeric-cell" scope="col">Rate (₹)</th>
                <th className="numeric-cell" scope="col">GST %</th>
                <th className="numeric-cell" scope="col">Total</th>
                <th style={{ width: '40px' }} />
              </tr>
            </thead>
            <tbody>
              {lines.map((line) => {
                const lineTotal = (line.quantity || 0) * (line.unitPrice || 0) * (1 + (line.gstRate || 0) / 100)
                return (
                  <tr key={line.id}>
                    <td>
                      <TextInput
                        onChange={(e) => handleUpdateLine(line.id, { description: e.target.value })}
                        placeholder="Item description or return reason"
                        value={line.description}
                      />
                    </td>
                    <td className="numeric-cell">
                      <NumberInput
                        min={1}
                        onChange={(e) => handleUpdateLine(line.id, { quantity: parseFloat(e.target.value) || 0 })}
                        style={{ width: 80 }}
                        value={line.quantity}
                      />
                    </td>
                    <td className="numeric-cell">
                      <NumberInput
                        currencyPrefix="₹"
                        min={0}
                        onChange={(e) => handleUpdateLine(line.id, { unitPrice: parseFloat(e.target.value) || 0 })}
                        step="0.01"
                        style={{ width: 110 }}
                        value={line.unitPrice}
                      />
                    </td>
                    <td className="numeric-cell">
                      <NumberInput
                        min={0}
                        onChange={(e) => handleUpdateLine(line.id, { gstRate: parseFloat(e.target.value) || 0 })}
                        style={{ width: 75 }}
                        unitSuffix="%"
                        value={line.gstRate}
                      />
                    </td>
                    <td className="numeric-cell">
                      <strong>
                        <Money amount={lineTotal} />
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
                )
              })}
            </tbody>
          </DataTable>

          <div className="form-summary-card">
            <div className="form-summary-row">
              <span className="cell-muted">Subtotal:</span>
              <Money amount={subtotal} />
            </div>
            <div className="form-summary-row">
              <span className="cell-muted">Tax Amount:</span>
              <Money amount={taxAmount} />
            </div>
            <div className="form-summary-row form-summary-row--total">
              <span>Credit Note Total:</span>
              <Money amount={grandTotal} />
            </div>
          </div>
        </FormCard>

        <div className="form-actions-bar">
          <Button
            onClick={() => navigate(appRoutes.creditNotes)}
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
            {createMutation.isPending ? 'Saving...' : 'Create Credit Note'}
          </Button>
        </div>
      </form>
    </section>
  )
}
