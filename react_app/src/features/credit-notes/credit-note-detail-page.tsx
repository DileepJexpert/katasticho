import { useQuery } from '@tanstack/react-query'
import { ArrowLeft, FileText } from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatPercent, formatStatusLabel } from '@/shared/format/format'
import { getCreditNote } from '@/features/credit-notes/credit-notes-api'

export function CreditNoteDetailPage() {
  const { creditNoteId } = useParams()
  const navigate = useNavigate()
  const creditNote = useQuery({
    queryKey: ['credit-notes', creditNoteId],
    queryFn: () => getCreditNote(creditNoteId!),
    enabled: Boolean(creditNoteId),
  })

  if (!creditNoteId) return <DocumentError onBack={() => navigate('/credit-notes')} />
  if (creditNote.isLoading) return <section className="workspace-page"><div aria-live="polite" className="directory-state">Loading credit note...</div></section>
  if (creditNote.isError || !creditNote.data) return <DocumentError onBack={() => navigate('/credit-notes')} />

  const document = creditNote.data

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Sales / Receivables / Credit note"
        title={document.creditNoteNumber}
        description={`${document.contactName} · Note date ${formatDate(document.creditNoteDate)}`}
        actions={<StatusChip status={formatStatusLabel(document.status)} />}
      />

      <div className="document-actions">
        <Button onClick={() => navigate('/credit-notes')} variant="secondary">
          <ArrowLeft aria-hidden="true" size={16} />
          Back to credit notes
        </Button>
      </div>

      <div className="document-layout">
        <section className="document-card">
          <h2>Credit adjustment details</h2>
          <dl className="document-facts">
            <Fact label="Customer" value={document.contactName} />
            <Fact label="Credit note date" value={formatDate(document.creditNoteDate)} />
            <Fact label="Linked invoice #" value={document.invoiceNumber ?? 'Direct / Standalone'} />
            <Fact label="Place of supply" value={document.placeOfSupply ?? 'Intra-state'} />
            <Fact label="Adjustment reason" value={document.reason ?? 'Sales return or discount'} />
            <Fact label="Status" value={formatStatusLabel(document.status)} />
          </dl>
        </section>

        <aside className="document-card document-card--summary">
          <h2>Financial adjustment</h2>
          <div className="summary-row">
            <span>Taxable value</span>
            <Money amount={document.subtotal} currency={document.currency} />
          </div>
          <div className="summary-row">
            <span>GST credit</span>
            <Money amount={document.taxAmount} currency={document.currency} />
          </div>
          <div className="summary-row summary-row--total">
            <span>Total credit amount</span>
            <Money amount={document.totalAmount} currency={document.currency} />
          </div>
        </aside>
      </div>

      <section className="document-card document-card--lines">
        <h2>Credited line items</h2>
        {document.lines?.length ? (
          <DataTable caption="Credit note line items">
            <thead>
              <tr>
                <th scope="col">#</th>
                <th scope="col">Description</th>
                <th scope="col">HSN</th>
                <th className="numeric-cell" scope="col">Quantity</th>
                <th className="numeric-cell" scope="col">Unit price</th>
                <th className="numeric-cell" scope="col">GST rate</th>
                <th className="numeric-cell" scope="col">Tax amount</th>
                <th className="numeric-cell" scope="col">Line total</th>
              </tr>
            </thead>
            <tbody>
              {document.lines.map((line) => (
                <tr key={line.id}>
                  <td>{line.lineNumber}</td>
                  <td>
                    <strong>{line.description || '--'}</strong>
                  </td>
                  <td>{line.hsnCode ? <code>{line.hsnCode}</code> : <span className="cell-muted">--</span>}</td>
                  <td className="numeric-cell">
                    <Quantity value={line.quantity} />
                  </td>
                  <td className="numeric-cell">
                    <Money amount={line.unitPrice} currency={document.currency} />
                  </td>
                  <td className="numeric-cell">{formatPercent(line.gstRate)}</td>
                  <td className="numeric-cell">
                    <Money amount={line.taxAmount} currency={document.currency} />
                  </td>
                  <td className="numeric-cell">
                    <Money amount={line.lineTotal} currency={document.currency} />
                  </td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        ) : (
          <p className="document-loading">No line items recorded for this credit note.</p>
        )}
      </section>

      <section className="document-card document-card--notes">
        <h2>Reason & remarks</h2>
        <div className="document-notes">
          <span>Reason</span>
          <p>{document.reason ?? 'No remarks recorded.'}</p>
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
        <strong>Credit note details could not be loaded.</strong>
        <p>The credit note record may no longer be available, or you may not have permission to view it.</p>
        <Button onClick={onBack} variant="secondary">Back to credit notes</Button>
      </div>
    </section>
  )
}
