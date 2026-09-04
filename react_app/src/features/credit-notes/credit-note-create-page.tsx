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
        actions={
          <div style={{ display: 'flex', gap: 'var(--space-2)' }}>
            <Button
              onClick={() => navigate(appRoutes.creditNotes)}
              type="button"
              variant="secondary"
            >
              Cancel
            </Button>
            <Button
              disabled={createMutation.isPending || !contactId}
              form="cn-form"
              type="submit"
              variant="primary"
            >
              <Save size={16} />
              {createMutation.isPending ? 'Saving...' : 'Create Credit Note'}
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

      <form className="create-form-container" id="cn-form" onSubmit={handleSubmit}>
          <div className="form-card">
          <div className="form-card-header">
            <h2 className="form-card-title">1. Customer & Adjustment Reason</h2>
          </div>
            <div className="form-grid--auto">
              <label className="field-group">
                <span>Customer *</span>
                <select
                  onChange={(e) => setContactId(e.target.value)}
                  required
                  value={contactId}
                >
                  <option value="">-- Select Customer --</option>
                  {customers.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.displayName}
                    </option>
                  ))}
                </select>
              </label>

              <label className="field-group">
                <span>Credit Note Date *</span>
                <input
                  onChange={(e) => setCreditNoteDate(e.target.value)}
                  required
                  type="date"
                  value={creditNoteDate}
                />
              </label>

              <label className="field-group">
                <span>Reason *</span>
                <input
                  onChange={(e) => setReason(e.target.value)}
                  placeholder="e.g. Sales return / Damaged goods"
                  required
                  type="text"
                  value={reason}
                />
              </label>
            </div>
          </div>

          <div className="document-card document-card--lines">
            <div style={{ alignItems: 'center', display: 'flex', justifyContent: 'space-between', marginBottom: 'var(--space-3)' }}>
              <h2>2. Credit Note Lines</h2>
              <Button onClick={handleAddLine} type="button" variant="secondary">
                + Add Line
              </Button>
            </div>

            <DataTable caption="Credit note lines">
              <thead>
                <tr>
                  <th scope="col">Description</th>
                  <th className="numeric-cell" scope="col">Qty</th>
                  <th className="numeric-cell" scope="col">Rate (₹)</th>
                  <th className="numeric-cell" scope="col">GST %</th>
                  <th style={{ width: '40px' }} />
                </tr>
              </thead>
              <tbody>
                {lines.map((line) => (
                  <tr key={line.id}>
                    <td>
                      <input
                        onChange={(e) => handleUpdateLine(line.id, { description: e.target.value })}
                        placeholder="Item description or return reason"
                        style={{
                          background: 'var(--bg-surface)',
                          border: '1px solid var(--border)',
                          borderRadius: 'var(--radius)',
                          color: 'var(--text-primary)',
                          height: '28px',
                          padding: '0 var(--space-2)',
                          width: '100%',
                        }}
                        value={line.description}
                      />
                    </td>
                    <td className="numeric-cell">
                      <input
                        min="1"
                        onChange={(e) => handleUpdateLine(line.id, { quantity: parseFloat(e.target.value) || 0 })}
                        style={{
                          background: 'var(--bg-surface)',
                          border: '1px solid var(--border)',
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
                          border: '1px solid var(--border)',
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
                    <td className="numeric-cell">
                      <input
                        min="0"
                        onChange={(e) => handleUpdateLine(line.id, { gstRate: parseFloat(e.target.value) || 0 })}
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
          </div>
      </form>
    </section>
  )
}
