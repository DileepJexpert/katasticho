import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { FileMinus, Plus } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import { listDebitNotes, type DebitNote } from '@/features/debit-notes/debit-notes-api'

const statusTabs = [
  { label: 'All', value: 'ALL' },
  { label: 'Draft', value: 'DRAFT' },
  { label: 'Submitted', value: 'SUBMITTED' },
  { label: 'Approved', value: 'APPROVED' },
  { label: 'Cancelled', value: 'CANCELLED' },
] as const

type StatusFilter = (typeof statusTabs)[number]['value']

export function DebitNotesPage() {
  const [selectedTab, setSelectedTab] = useState<StatusFilter>('ALL')
  const [page, setPage] = useState(0)
  const navigate = useNavigate()

  const debitNotes = useQuery({
    queryKey: ['debit-notes', { page, status: selectedTab }],
    queryFn: () => listDebitNotes({ page, status: selectedTab }),
  })
  const notePage = debitNotes.data

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Purchases / Payables"
        title="Debit Notes"
        description="Purchase returns, vendor chargebacks, and accounts payable credit claims."
        actions={
          <Button onClick={() => navigate(appRoutes.debitNoteCreate)} variant="primary">
            <Plus aria-hidden="true" size={16} />
            <span>New Debit Note</span>
          </Button>
        }
      />

      <section className="list-panel" aria-label="Debit note directory">
        <DirectoryToolbar ariaLabel="Filter debit notes by status" stacked>
          <FilterTabs
            activeValue={selectedTab}
            ariaLabel="Filter by debit note status"
            items={statusTabs}
            onChange={(val) => {
              setSelectedTab(val);
              setPage(0);
            }}
          />
          <p className="list-toolbar-note">
            Debit notes claim credit against vendor bills for returned goods, damaged inventory, or pricing discrepancies.
          </p>
        </DirectoryToolbar>

        {debitNotes.isError ? (
          <div className="directory-state directory-state--error" role="alert">
            <strong>Debit notes could not be loaded.</strong>
            <p>Check your connection and permissions, then refresh the page.</p>
          </div>
        ) : debitNotes.isLoading ? (
          <div aria-live="polite" className="directory-state">Loading debit notes...</div>
        ) : notePage?.content.length ? (
          <>
            <DataTable caption="Debit notes">
              <thead>
                <tr>
                  <th scope="col">Debit note #</th>
                  <th scope="col">Supplier</th>
                  <th scope="col">Note date</th>
                  <th scope="col">Reason</th>
                  <th scope="col">Lines</th>
                  <th className="numeric-cell" scope="col">Total amount</th>
                  <th scope="col">Status</th>
                </tr>
              </thead>
              <tbody>
                {notePage.content.map((note) => (
                  <DebitNoteRow
                    key={note.id}
                    note={note}
                    onOpen={() => navigate(appRoutes.debitNoteDetail(note.id))}
                  />
                ))}
              </tbody>
            </DataTable>
            <TablePagination
              filterDescription={selectedTab !== 'ALL' ? `with ${selectedTab.toLowerCase()} status` : 'in this organisation'}
              isFiltered={selectedTab !== 'ALL'}
              itemLabel="debit note"
              onPageChange={(p) => setPage(p)}
              page={notePage?.number ?? 0}
              totalElements={notePage?.totalElements ?? 0}
              totalPages={notePage?.totalPages ?? 1}
            />
          </>
        ) : (
          <EmptyState
            action={
              <Button onClick={() => navigate(appRoutes.debitNoteCreate)} variant="primary">
                <Plus aria-hidden="true" size={16} />
                <span>New Debit Note</span>
              </Button>
            }
            description="Vendor debit claims and purchase return notes will appear here."
            icon={FileMinus}
            title="No debit notes found"
          />
        )}
      </section>
    </section>
  )
}

function DebitNoteRow({ note, onOpen }: { note: DebitNote; onOpen: () => void }) {
  return (
    <tr>
      <td>
        <Button className="document-link" onClick={onOpen} variant="ghost">
          <code>{note.debitNoteNumber}</code>
        </Button>
      </td>
      <td>
        <strong>{note.supplierName}</strong>
      </td>
      <td>{formatDate(note.noteDate)}</td>
      <td>{note.returnReason ?? <span className="cell-muted">Purchase return</span>}</td>
      <td>{note.lines?.length ?? 0} items</td>
      <td className="numeric-cell">
        <Money amount={note.totalAmount} />
      </td>
      <td>
        <StatusChip status={formatStatusLabel(note.status)} />
      </td>
    </tr>
  )
}
