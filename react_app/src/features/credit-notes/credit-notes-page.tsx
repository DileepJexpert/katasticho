import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { FileBadge, Plus } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import { listCreditNotes, type CreditNote } from '@/features/credit-notes/credit-notes-api'

const statusTabs = [
  { label: 'All', value: 'ALL' },
  { label: 'Draft', value: 'DRAFT' },
  { label: 'Issued', value: 'ISSUED' },
  { label: 'Void', value: 'VOID' },
] as const

type StatusFilter = (typeof statusTabs)[number]['value']

export function CreditNotesPage() {
  const [selectedTab, setSelectedTab] = useState<StatusFilter>('ALL')
  const [page, setPage] = useState(0)
  const navigate = useNavigate()

  const creditNotes = useQuery({
    queryKey: ['credit-notes', { page }],
    queryFn: () => listCreditNotes({ page }),
  })
  const notePage = creditNotes.data

  const filteredNotes = (notePage?.content ?? []).filter((note) => {
    if (selectedTab === 'ALL') return true
    return note.status?.toUpperCase() === selectedTab
  })

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Sales / Receivables"
        title="Credit Notes"
        description="Sales returns, price corrections, and accounts receivable credit adjustments."
        actions={
          <Button onClick={() => navigate(appRoutes.creditNoteCreate)} variant="primary">
            <Plus aria-hidden="true" size={16} />
            <span>New Credit Note</span>
          </Button>
        }
      />

      <section className="list-panel" aria-label="Credit note directory">
        <DirectoryToolbar ariaLabel="Filter credit notes by status" stacked>
          <FilterTabs
            activeValue={selectedTab}
            ariaLabel="Filter by credit note status"
            items={statusTabs.map((t) => ({
              value: t.value,
              label: t.label,
              count: t.value === 'ALL'
                ? notePage?.content.length ?? 0
                : (notePage?.content ?? []).filter((n) => n.status?.toUpperCase() === t.value).length,
            }))}
            onChange={setSelectedTab}
          />
          <p className="list-toolbar-note">
            Credit notes reduce customer receivable balances and post adjusting output GST and sales return journals upon issuance.
          </p>
        </DirectoryToolbar>

        {creditNotes.isError ? (
          <div className="directory-state directory-state--error" role="alert">
            <strong>Credit notes could not be loaded.</strong>
            <p>Check your connection and permissions, then refresh the page.</p>
          </div>
        ) : creditNotes.isLoading ? (
          <div aria-live="polite" className="directory-state">Loading credit notes...</div>
        ) : filteredNotes.length ? (
          <>
            <DataTable caption="Credit notes">
              <thead>
                <tr>
                  <th scope="col">Credit note #</th>
                  <th scope="col">Customer</th>
                  <th scope="col">Note date</th>
                  <th scope="col">Linked invoice</th>
                  <th className="numeric-cell" scope="col">Total amount</th>
                  <th scope="col">Status</th>
                </tr>
              </thead>
              <tbody>
                {filteredNotes.map((note) => (
                  <CreditNoteRow
                    key={note.id}
                    note={note}
                    onOpen={() => navigate(appRoutes.creditNoteDetail(note.id))}
                  />
                ))}
              </tbody>
            </DataTable>
            <TablePagination
              filterDescription={selectedTab !== 'ALL' ? `with ${selectedTab.toLowerCase()} status` : 'in this organisation'}
              isFiltered={selectedTab !== 'ALL'}
              itemLabel="credit note"
              onPageChange={(p) => setPage(p)}
              page={notePage?.page ?? 0}
              totalElements={notePage?.totalElements ?? 0}
              totalPages={notePage?.totalPages ?? 1}
            />
          </>
        ) : (
          <EmptyState
            action={
              <Button onClick={() => navigate(appRoutes.creditNoteCreate)} variant="primary">
                <Plus aria-hidden="true" size={16} />
                <span>New Credit Note</span>
              </Button>
            }
            description="Customer credit adjustments and sales return notes will appear here."
            icon={FileBadge}
            title="No credit notes found"
          />
        )}
      </section>
    </section>
  )
}

function CreditNoteRow({ note, onOpen }: { note: CreditNote; onOpen: () => void }) {
  return (
    <tr>
      <td>
        <Button className="document-link" onClick={onOpen} variant="ghost">
          <code>{note.creditNoteNumber}</code>
        </Button>
      </td>
      <td>
        <strong>{note.contactName}</strong>
      </td>
      <td>{formatDate(note.creditNoteDate)}</td>
      <td>
        {note.invoiceNumber ? (
          <code>{note.invoiceNumber}</code>
        ) : (
          <span className="cell-muted">Unlinked</span>
        )}
      </td>
      <td className="numeric-cell">
        <Money amount={note.totalAmount} currency={note.currency} />
      </td>
      <td>
        <StatusChip status={formatStatusLabel(note.status)} />
      </td>
    </tr>
  )
}
