import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, FileBadge, FileText, Send, Trash2 } from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import { deleteDebitNote, getDebitNote, submitDebitNote } from './debit-notes-api'

export function DebitNoteDetailPage() {
  const { noteId } = useParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [feedback, setFeedback] = useState<string | null>(null)

  const note = useQuery({
    queryKey: ['debit-notes', noteId],
    queryFn: () => getDebitNote(noteId!),
    enabled: Boolean(noteId),
  })

  const submitMutation = useMutation({
    mutationFn: () => submitDebitNote(noteId!),
    onSuccess: () => {
      setFeedback('Debit note submitted and supplier chargeback posted.')
      queryClient.invalidateQueries({ queryKey: ['debit-notes', noteId] })
    },
    onError: (err: Error) => setFeedback(`Submission failed: ${err.message}`),
  })

  const deleteMutation = useMutation({
    mutationFn: () => deleteDebitNote(noteId!),
    onSuccess: () => {
      navigate('/debit-notes')
    },
  })

  if (!noteId) return <DocumentError onBack={() => navigate('/debit-notes')} />
  if (note.isLoading) return <section className="workspace-page"><div aria-live="polite" className="directory-state">Loading debit note...</div></section>
  if (note.isError || !note.data) return <DocumentError onBack={() => navigate('/debit-notes')} />

  const document = note.data

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Purchases / Payables / Debit note"
        title={document.debitNoteNumber}
        description={`${document.supplierName} · Issued ${formatDate(document.noteDate)}`}
        actions={
          <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
            <StatusChip status={formatStatusLabel(document.status)} />
            <Button onClick={() => navigate('/debit-notes')} variant="secondary">
              <ArrowLeft aria-hidden="true" size={16} />
              Back to debit notes
            </Button>
          </div>
        }
      />

      {feedback ? (
        <div className="alert-banner" style={{ background: '#0F857615', border: '1px solid #0F8576', padding: '12px 16px', borderRadius: '6px', color: '#0F8576', marginBottom: '16px' }}>
          {feedback}
        </div>
      ) : null}

      <div className="document-layout">
        <section className="document-card">
          <h2>Debit note facts</h2>
          <dl className="document-facts">
            <Fact label="Supplier" value={document.supplierName} />
            <Fact label="Date" value={formatDate(document.noteDate)} />
            <Fact label="Return reason" value={document.returnReason ?? 'Purchase return'} />
            <Fact label="Reference Bill" value={document.referenceBillId ?? 'Not specified'} />
            <Fact label="Status" value={formatStatusLabel(document.status)} />
          </dl>
        </section>

        <aside className="document-card document-card--summary">
          <h2>Financial summary</h2>
          <div className="progress-row">
            <span>Material subtotal</span>
            <Money amount={document.subtotal} />
          </div>
          <div className="progress-row">
            <span>Tax return</span>
            <Money amount={document.taxAmount} />
          </div>
          <div className="summary-row summary-row--total">
            <span>Total debit amount</span>
            <Money amount={document.totalAmount} />
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', marginTop: '16px' }}>
            {document.status === 'DRAFT' ? (
              <Button
                disabled={submitMutation.isPending}
                onClick={() => submitMutation.mutate()}
                variant="primary"
              >
                <Send size={16} />
                {submitMutation.isPending ? 'Submitting...' : 'Submit Debit Note'}
              </Button>
            ) : (
              <Button
                onClick={() => navigate('/vendor-credits')}
                variant="secondary"
              >
                <FileBadge size={16} />
                Apply as Vendor Credit
              </Button>
            )}

            {document.status === 'DRAFT' ? (
              <Button
                disabled={deleteMutation.isPending}
                onClick={() => deleteMutation.mutate()}
                variant="destructive"
              >
                <Trash2 size={16} />
                Delete Draft
              </Button>
            ) : null}
          </div>
        </aside>
      </div>

      <section className="document-card document-card--lines">
        <h2>Returned line items</h2>
        {document.lines?.length ? (
          <DataTable caption="Debit note lines">
            <thead>
              <tr>
                <th scope="col">Description</th>
                <th scope="col">Batch #</th>
                <th className="numeric-cell" scope="col">Quantity</th>
                <th className="numeric-cell" scope="col">Unit price</th>
                <th className="numeric-cell" scope="col">Tax</th>
                <th className="numeric-cell" scope="col">Line total</th>
              </tr>
            </thead>
            <tbody>
              {document.lines.map((line) => (
                <tr key={line.id}>
                  <td>
                    <strong>{line.description}</strong>
                  </td>
                  <td>{line.batchNumber ?? '--'}</td>
                  <td className="numeric-cell">
                    <Quantity value={line.quantity} />
                  </td>
                  <td className="numeric-cell">
                    <Money amount={line.unitPrice} />
                  </td>
                  <td className="numeric-cell">
                    <Money amount={line.taxAmount} />
                  </td>
                  <td className="numeric-cell">
                    <Money amount={line.lineTotal} />
                  </td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        ) : (
          <p className="document-loading">No items recorded for this debit note.</p>
        )}
      </section>

      <section className="document-card document-card--notes">
        <h2>Commercial remarks</h2>
        <div className="document-notes">
          <span>Notes</span>
          <p>{document.notes ?? 'No notes recorded.'}</p>
        </div>
      </section>
    </section>
  )
}

function Fact({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt>{label}</dt>
      <dd>{value}</dd>
    </div>
  )
}

function DocumentError({ onBack }: { onBack: () => void }) {
  return (
    <section className="workspace-page">
      <div className="directory-state directory-state--error" role="alert">
        <FileText aria-hidden="true" size={24} />
        <strong>Debit note details could not be loaded.</strong>
        <p>The debit note record may no longer be available, or you may not have permission to view it.</p>
        <Button onClick={onBack} variant="secondary">Back to debit notes</Button>
      </div>
    </section>
  )
}
