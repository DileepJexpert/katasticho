import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, FileBadge, Send, Trash2 } from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  DataTable,
  DocumentCard,
  DocumentError,
  Fact,
  FactList,
  Money,
  PageHeader,
  Quantity,
  StatusChip,
  SummaryRow,
} from '@/design-system'
import { deleteDebitNote, getDebitNote, submitDebitNote } from './debit-notes-api'
import { formatDate, formatStatusLabel } from '@/shared/format/format'

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
      navigate(appRoutes.debitNotes)
    },
  })

  if (!noteId) return <DocumentError onBack={() => navigate(appRoutes.debitNotes)} />
  if (note.isLoading) {
    return (
      <section className="workspace-page">
        <div aria-live="polite" className="directory-state">
          Loading debit note...
        </div>
      </section>
    )
  }
  if (note.isError || !note.data) {
    return <DocumentError onBack={() => navigate(appRoutes.debitNotes)} />
  }

  const document = note.data

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <div style={{ display: 'flex', gap: 'var(--space-2)', alignItems: 'center' }}>
            <StatusChip status={formatStatusLabel(document.status)} />
            <Button onClick={() => navigate(appRoutes.debitNotes)} variant="secondary">
              <ArrowLeft aria-hidden="true" size={16} />
              Back to debit notes
            </Button>
          </div>
        }
        description={`${document.supplierName} · Issued ${formatDate(document.noteDate)}`}
        eyebrow="Purchases / Payables / Debit note"
        title={document.debitNoteNumber}
      />

      {feedback && (
        <div
          className="banner banner--success"
          role="status"
          style={{ marginBottom: 'var(--space-4)' }}
        >
          <span>{feedback}</span>
          <button className="banner-dismiss" onClick={() => setFeedback(null)} type="button">✕</button>
        </div>
      )}

      <div className="document-layout">
        <DocumentCard title="Debit Note Facts">
          <FactList columns={2}>
            <Fact label="Supplier" value={document.supplierName} />
            <Fact label="Note Date" value={formatDate(document.noteDate)} />
            <Fact label="Return Reason" value={document.returnReason ?? 'Purchase return'} />
            <Fact label="Reference Bill" mono value={document.referenceBillId ?? 'Not specified'} />
            <Fact label="Status" value={formatStatusLabel(document.status)} />
          </FactList>
        </DocumentCard>

        <DocumentCard title="Financial Summary" variant="summary">
          <SummaryRow label="Material Subtotal" value={<Money amount={document.subtotal} />} />
          <SummaryRow label="Tax Return" value={<Money amount={document.taxAmount} />} />
          <SummaryRow isTotal label="Total Debit Amount" value={<Money amount={document.totalAmount} />} />

          <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-2)', marginTop: 'var(--space-3)' }}>
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
                onClick={() => navigate(appRoutes.vendorCredits)}
                variant="secondary"
              >
                <FileBadge size={16} />
                Apply as Vendor Credit
              </Button>
            )}

            {document.status === 'DRAFT' && (
              <Button
                disabled={deleteMutation.isPending}
                onClick={() => deleteMutation.mutate()}
                variant="destructive"
              >
                <Trash2 size={16} />
                Delete Draft
              </Button>
            )}
          </div>
        </DocumentCard>
      </div>

      <DocumentCard title="Returned Line Items" variant="lines">
        {document.lines?.length ? (
          <DataTable caption="Debit note lines">
            <thead>
              <tr>
                <th scope="col">Description</th>
                <th scope="col">Batch #</th>
                <th className="numeric-cell" scope="col">Quantity</th>
                <th className="numeric-cell" scope="col">Unit Cost</th>
                <th className="numeric-cell" scope="col">Line Total</th>
              </tr>
            </thead>
            <tbody>
              {document.lines.map((line) => (
                <tr key={line.id}>
                  <td><strong>{line.description}</strong></td>
                  <td>{line.batchNumber ? <code>{line.batchNumber}</code> : '--'}</td>
                  <td className="numeric-cell"><Quantity value={line.quantity} /></td>
                  <td className="numeric-cell"><Money amount={line.unitPrice} /></td>
                  <td className="numeric-cell"><strong><Money amount={(Number(line.quantity) || 0) * (Number(line.unitPrice) || 0)} /></strong></td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        ) : (
          <div className="directory-state" style={{ minHeight: 120 }}>
            No line items returned.
          </div>
        )}
      </DocumentCard>
    </section>
  )
}
