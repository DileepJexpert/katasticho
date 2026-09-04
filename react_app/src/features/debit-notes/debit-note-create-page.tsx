import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, Save, Trash2 } from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
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
        actions={
          <div style={{ display: 'flex', gap: 'var(--space-2)' }}>
            <Button
              onClick={() => navigate(appRoutes.debitNotes)}
              type="button"
              variant="secondary"
            >
              Cancel
            </Button>
            <Button
              disabled={createMutation.isPending || !supplierId || lines.length === 0}
              form="dn-form"
              type="submit"
              variant="primary"
            >
              <Save size={16} />
              {createMutation.isPending ? 'Saving...' : 'Create Debit Note'}
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

      <form className="create-form-container" id="dn-form" onSubmit={handleSubmit}>
          <div className="form-card">
          <div className="form-card-header">
            <h2 className="form-card-title">1. Supplier & Reason</h2>
          </div>
            <div className="form-grid--auto">
              <label className="field-group">
                <span>Supplier / Vendor *</span>
                <select
                  onChange={(e) => setSupplierId(e.target.value)}
                  required
                  value={supplierId}
                >
                  <option value="">-- Select Supplier --</option>
                  {suppliers.map((s) => (
                    <option key={s.id} value={s.id}>
                      {s.displayName}
                    </option>
                  ))}
                </select>
              </label>

              <label className="field-group">
                <span>Debit Note Date *</span>
                <input
                  onChange={(e) => setNoteDate(e.target.value)}
                  required
                  type="date"
                  value={noteDate}
                />
              </label>

              <label className="field-group">
                <span>Return Reason</span>
                <input
                  onChange={(e) => setReturnReason(e.target.value)}
                  placeholder="e.g. Damaged during transit / expired"
                  type="text"
                  value={returnReason}
                />
              </label>

              <label className="field-group">
                <span>Internal Notes</span>
                <input
                  onChange={(e) => setNotes(e.target.value)}
                  placeholder="Additional remarks..."
                  type="text"
                  value={notes}
                />
              </label>
            </div>
          </div>

          <div className="form-card">
            <div className="form-card-header">
              <div>
                <h2 className="form-card-title">2. Items to Return</h2>
                <p className="form-card-description">Select goods to return to supplier for credit adjustment</p>
              </div>
              <div>
                <select
                  onChange={(e) => {
                    if (e.target.value) {
                      handleAddItem(e.target.value)
                      e.target.value = ''
                    }
                  }}
                  value=""
                >
                  <option value="">+ Add Item to Return...</option>
                  {catalogItems.map((item) => (
                    <option key={item.id} value={item.id}>
                      {item.name}
                    </option>
                  ))}
                </select>
              </div>
            </div>

            {lines.length === 0 ? (
              <div className="directory-state" style={{ minHeight: '120px' }}>
                No items added yet. Select an item above to add to debit note.
              </div>
            ) : (
              <DataTable caption="Returned items">
                <thead>
                  <tr>
                    <th scope="col">Item</th>
                    <th className="numeric-cell" scope="col">Quantity</th>
                    <th className="numeric-cell" scope="col">Unit Cost (₹)</th>
                    <th scope="col">Batch #</th>
                    <th style={{ width: '40px' }} />
                  </tr>
                </thead>
                <tbody>
                  {lines.map((line) => (
                    <tr key={line.id}>
                      <td>
                        <strong>{line.itemName}</strong>
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
                            width: '80px',
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
                            width: '100px',
                          }}
                          type="number"
                          value={line.unitPrice}
                        />
                      </td>
                      <td>
                        <input
                          onChange={(e) => handleUpdateLine(line.id, { batchNumber: e.target.value })}
                          placeholder="Batch"
                          style={{
                            background: 'var(--bg-surface)',
                            border: '1px solid var(--border)',
                            borderRadius: 'var(--radius)',
                            color: 'var(--text-primary)',
                            height: '28px',
                            padding: '0 4px',
                            width: '100px',
                          }}
                          value={line.batchNumber}
                        />
                      </td>
                      <td>
                        <button
                          aria-label="Remove item"
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
          </div>

        <div className="form-actions-bar">
          <Button
            onClick={() => navigate(appRoutes.debitNotes)}
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
            {createMutation.isPending ? 'Saving...' : 'Issue Debit Note'}
          </Button>
        </div>
      </form>
    </section>
  )
}
