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
  createDebitNote,
  type CreateDebitNoteLineRequest,
  type CreateDebitNoteRequest,
} from '@/features/debit-notes/debit-notes-api'
import { listItems } from '@/features/items/items-api'

interface DnLineItem extends CreateDebitNoteLineRequest {
  id: string
  itemName: string
}

export function DebitNoteCreatePage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const [supplierId, setSupplierId] = useState('')
  const [noteDate, setNoteDate] = useState(() => new Date().toISOString().split('T')[0] || '')
  const [returnReason, setReturnReason] = useState('Rejection / Quality Defect')
  const [notes, setNotes] = useState('')
  const [lines, setLines] = useState<DnLineItem[]>([])
  const [feedback, setFeedback] = useState<{ type: 'error' | 'success'; message: string } | null>(null)

  const suppliersQuery = useQuery({
    queryKey: ['vendors-for-dn'],
    queryFn: () => listContacts({ filter: 'VENDOR', page: 0 }),
  })

  const itemsQuery = useQuery({
    queryKey: ['items-for-dn'],
    queryFn: () => listItems({ page: 0 }),
  })

  const suppliers = suppliersQuery.data?.content ?? []
  const catalogItems = itemsQuery.data?.content ?? []

  const handleAddItem = (itemId: string) => {
    const item = catalogItems.find((i) => i.id === itemId)
    if (!item) return
    const newLine: DnLineItem = {
      id: Math.random().toString(36).substring(2, 9),
      itemId: item.id,
      itemName: item.name,
      description: item.name,
      quantity: 1,
      unitPrice: Number(item.purchasePrice || 0),
      batchNumber: '',
      taxRate: Number(item.gstRate || 18),
    }
    setLines((prev) => [...prev, newLine])
  }

  const handleUpdateLine = (id: string, updates: Partial<DnLineItem>) => {
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
      const lineTax = (lineSub * (l.taxRate || 0)) / 100
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
    mutationFn: (req: CreateDebitNoteRequest) => createDebitNote(req),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['debit-notes'] })
      navigate(appRoutes.debitNotes)
    },
    onError: (err: unknown) => {
      const msg = err instanceof Error ? err.message : 'Failed to create debit note.'
      setFeedback({ type: 'error', message: msg })
    },
  })

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    setFeedback(null)

    if (!supplierId) {
      setFeedback({ type: 'error', message: 'Please select a supplier.' })
      return
    }

    if (lines.length === 0) {
      setFeedback({ type: 'error', message: 'Please add at least one line item to return.' })
      return
    }

    createMutation.mutate({
      supplierId,
      noteDate,
      returnReason: returnReason.trim() || undefined,
      notes: notes.trim() || undefined,
      lines: lines.map((l) => ({
        itemId: l.itemId,
        description: l.description,
        quantity: l.quantity,
        unitPrice: l.unitPrice,
        batchNumber: l.batchNumber || undefined,
        taxRate: l.taxRate,
      })),
    })
  }

  return (
    <section className="workspace-page">
      <Link className="form-back-link" to={appRoutes.debitNotes}>
        <ArrowLeft size={16} /> Back to Debit Notes
      </Link>

      <PageHeader
        eyebrow="Purchases / Returns"
        title="New Debit Note"
        description="Draft debit notes for vendor purchase returns, price differences, or damaged goods deductions."
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
          description="Identify the supplier and commercial reason for returning inventory or adjusting payables."
          stepNumber={1}
          title="Supplier & Reason"
        >
          <FormGrid columns={3}>
            <FormField label="Supplier / Vendor" required>
              <SelectInput
                onChange={(e) => setSupplierId(e.target.value)}
                options={suppliers.map((s) => ({
                  value: s.id,
                  label: s.displayName,
                }))}
                placeholderOption="-- Select Supplier --"
                required
                value={supplierId}
              />
            </FormField>

            <FormField label="Debit Note Date" required>
              <TextInput
                onChange={(e) => setNoteDate(e.target.value)}
                required
                type="date"
                value={noteDate}
              />
            </FormField>

            <FormField label="Return Reason" required>
              <TextInput
                onChange={(e) => setReturnReason(e.target.value)}
                placeholder="e.g. Damaged during transit / expired"
                required
                value={returnReason}
              />
            </FormField>
          </FormGrid>
        </FormCard>

        <FormCard
          description="Select catalog items, quantities to return, agreed debit rates, and lot batches."
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
                  label: item.name,
                }))}
                placeholderOption="+ Add Item to Return..."
                value=""
              />
            </div>
          }
          stepNumber={2}
          title={`Items to Return (${lines.length})`}
        >
          {lines.length === 0 ? (
            <div className="directory-state" style={{ padding: 'var(--space-6)' }}>
              <FileCheck size={28} />
              <p>No items added yet. Select an item above to add to debit note.</p>
            </div>
          ) : (
            <>
              <DataTable caption="Returned items">
                <thead>
                  <tr>
                    <th scope="col">Item</th>
                    <th className="numeric-cell" scope="col">Quantity</th>
                    <th className="numeric-cell" scope="col">Unit Cost (₹)</th>
                    <th scope="col">Batch #</th>
                    <th className="numeric-cell" scope="col">Total</th>
                    <th style={{ width: '40px' }} />
                  </tr>
                </thead>
                <tbody>
                  {lines.map((line) => {
                    const lineTotal = (line.quantity || 0) * (line.unitPrice || 0) * (1 + (line.taxRate || 0) / 100)
                    return (
                      <tr key={line.id}>
                        <td>
                          <strong>{line.itemName}</strong>
                        </td>
                        <td className="numeric-cell">
                          <NumberInput
                            min={1}
                            onChange={(e) => handleUpdateLine(line.id, { quantity: parseFloat(e.target.value) || 0 })}
                            step="1"
                            style={{ width: 85 }}
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
                        <td>
                          <TextInput
                            onChange={(e) => handleUpdateLine(line.id, { batchNumber: e.target.value })}
                            placeholder="Batch"
                            style={{ width: 110 }}
                            value={line.batchNumber}
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
                  <span className="cell-muted">Taxable Subtotal:</span>
                  <Money amount={subtotal} />
                </div>
                <div className="form-summary-row">
                  <span className="cell-muted">Adjusted Tax:</span>
                  <Money amount={taxAmount} />
                </div>
                <div className="form-summary-row form-summary-row--total">
                  <span>Debit Note Total:</span>
                  <Money amount={grandTotal} />
                </div>
              </div>
            </>
          )}
        </FormCard>

        <FormCard
          description="Internal documentation and audit details."
          stepNumber={3}
          title="Internal Remarks"
        >
          <FormField label="Internal Notes">
            <TextAreaInput
              onChange={(e) => setNotes(e.target.value)}
              placeholder="Additional remarks..."
              rows={2}
              value={notes}
            />
          </FormField>
        </FormCard>

        <div className="form-actions-bar">
          <Button
            onClick={() => navigate(appRoutes.debitNotes)}
            type="button"
            variant="secondary"
          >
            Cancel
          </Button>
          <Button
            disabled={createMutation.isPending || !supplierId || lines.length === 0}
            type="submit"
            variant="primary"
          >
            <Save size={16} />
            {createMutation.isPending ? 'Saving...' : 'Issue Debit Note'}
          </Button>
        </div>
      </form>
    </section>
  )
}
