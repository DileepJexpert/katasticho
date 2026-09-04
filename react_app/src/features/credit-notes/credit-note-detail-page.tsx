import { useQuery } from '@tanstack/react-query'
import { ArrowLeft } from 'lucide-react'
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
import { getCreditNote } from '@/features/credit-notes/credit-notes-api'
import { formatDate, formatStatusLabel } from '@/shared/format/format'

export function CreditNoteDetailPage() {
  const { creditNoteId } = useParams()
  const navigate = useNavigate()
  const creditNote = useQuery({
    queryKey: ['credit-notes', creditNoteId],
    queryFn: () => getCreditNote(creditNoteId!),
    enabled: Boolean(creditNoteId),
  })

  if (!creditNoteId) return <DocumentError onBack={() => navigate(appRoutes.creditNotes)} />
  if (creditNote.isLoading) {
    return (
      <section className="workspace-page">
        <div aria-live="polite" className="directory-state">
          Loading credit note...
        </div>
      </section>
    )
  }
  if (creditNote.isError || !creditNote.data) {
    return <DocumentError onBack={() => navigate(appRoutes.creditNotes)} />
  }

  const document = creditNote.data

  return (
    <section className="workspace-page">
      <PageHeader
        actions={<StatusChip status={formatStatusLabel(document.status)} />}
        description={`${document.contactName} · Note date ${formatDate(document.creditNoteDate)}`}
        eyebrow="Sales / Receivables / Credit note"
        title={document.creditNoteNumber}
      />

      <div className="document-actions">
        <Button onClick={() => navigate(appRoutes.creditNotes)} variant="secondary">
          <ArrowLeft aria-hidden="true" size={16} />
          Back to credit notes
        </Button>
      </div>

      <div className="document-layout">
        <DocumentCard title="Credit Adjustment Details">
          <FactList columns={2}>
            <Fact label="Customer" value={document.contactName} />
            <Fact label="Credit Note Date" value={formatDate(document.creditNoteDate)} />
            <Fact label="Linked Invoice #" mono value={document.invoiceNumber ?? 'Direct / Standalone'} />
            <Fact label="Place of Supply" value={document.placeOfSupply ?? 'Intra-state'} />
            <Fact label="Adjustment Reason" value={document.reason ?? 'Sales return or discount'} />
            <Fact label="Status" value={formatStatusLabel(document.status)} />
          </FactList>
        </DocumentCard>

        <DocumentCard title="Financial Adjustment" variant="summary">
          <SummaryRow label="Taxable Value" value={<Money amount={document.subtotal} currency={document.currency} />} />
          <SummaryRow label="GST Credit" value={<Money amount={document.taxAmount} currency={document.currency} />} />
          <SummaryRow isTotal label="Total Credit Amount" value={<Money amount={document.totalAmount} currency={document.currency} />} />
        </DocumentCard>
      </div>

      <DocumentCard title="Credited Line Items" variant="lines">
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
                  <td><strong>{line.description || '--'}</strong></td>
                  <td>{line.hsnCode ? <code>{line.hsnCode}</code> : <span className="cell-muted">--</span>}</td>
                  <td className="numeric-cell"><Quantity value={line.quantity} /></td>
                  <td className="numeric-cell"><Money amount={line.unitPrice} currency={document.currency} /></td>
                  <td className="numeric-cell">{line.gstRate ?? 0}%</td>
                  <td className="numeric-cell"><Money amount={line.taxAmount} currency={document.currency} /></td>
                  <td className="numeric-cell"><strong><Money amount={line.lineTotal} currency={document.currency} /></strong></td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        ) : (
          <div className="directory-state" style={{ minHeight: 120 }}>
            No line items recorded for this credit note.
          </div>
        )}
      </DocumentCard>
    </section>
  )
}
