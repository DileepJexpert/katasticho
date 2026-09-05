import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import {
  BookOpen,
  Plus,
} from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  DataTable,
  FilterTabs,
  Money,
  PageHeader,
  SearchInput,
  StatusChip,
  TablePagination,
  TextInput,
} from '@/design-system'
import { formatDate } from '@/shared/format/format'
import { listJournals } from '@/features/journals/journals-api'

const moduleFilters = [
  { label: 'All Modules', value: 'ALL' },
  { label: 'Manual', value: 'MANUAL' },
  { label: 'Sales', value: 'SALES' },
  { label: 'Purchases', value: 'PURCHASE' },
  { label: 'Payroll', value: 'PAYROLL' },
  { label: 'Banking', value: 'BANKING' },
  { label: 'Inventory', value: 'INVENTORY' },
] as const
type JournalModuleFilter = (typeof moduleFilters)[number]['value']

export function JournalsPage() {
  const [selectedModule, setSelectedModule] = useState<JournalModuleFilter>('ALL')
  const [search, setSearch] = useState('')
  const [dateFrom, setDateFrom] = useState('')
  const [dateTo, setDateTo] = useState('')
  const [page, setPage] = useState(0)

  const navigate = useNavigate()

  const journalsQuery = useQuery({
    queryKey: ['journals', { sourceModule: selectedModule, search, page, dateFrom, dateTo }],
    queryFn: () => listJournals({ sourceModule: selectedModule, search, page, dateFrom, dateTo }),
  })

  const journalPage = journalsQuery.data
  const entries = journalPage?.content ?? []

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <Button onClick={() => navigate(appRoutes.journalCreate)} variant="primary">
            <Plus className="icon" /> New Journal Entry
          </Button>
        }
        description="Double-entry general ledger journal vouchers, automated domain postings, and reversing entries."
        eyebrow="Accounting / General Ledger"
        title="Journal Entries"
      />

      <section className="list-panel" aria-label="Journals directory">
        <div className="list-toolbar list-toolbar--stacked">
          <FilterTabs
            activeValue={selectedModule}
            ariaLabel="Filter by source module"
            items={moduleFilters}
            onChange={(value) => {
              setSelectedModule(value)
              setPage(0)
            }}
          />

          <div className="journals-toolbar">
            <SearchInput
              ariaLabel="Search journal entries"
              onChange={(value) => {
                setSearch(value)
                setPage(0)
              }}
              onClear={() => {
                setSearch('')
                setPage(0)
              }}
              placeholder="Search entry number or narration"
              value={search}
            />
            <label className="journals-date-filter">
              <span>From</span>
              <TextInput onChange={(event) => { setDateFrom(event.target.value); setPage(0) }} type="date" value={dateFrom} />
            </label>
            <label className="journals-date-filter">
              <span>To</span>
              <TextInput onChange={(event) => { setDateTo(event.target.value); setPage(0) }} type="date" value={dateTo} />
            </label>
          </div>
        </div>

        {journalsQuery.isError ? (
          <div className="directory-state directory-state--error" role="alert">
            <strong>Journals could not be loaded.</strong>
            <p>Check your connection and permissions, then refresh the page.</p>
          </div>
        ) : journalsQuery.isLoading ? (
          <div aria-live="polite" className="directory-state">Loading journals...</div>
        ) : entries.length ? (
          <>
            <DataTable caption="Journal entries">
              <thead>
                <tr>
                  <th scope="col">Entry #</th>
                  <th scope="col">Effective Date</th>
                  <th scope="col">Narration / Description</th>
                  <th scope="col">Module</th>
                  <th scope="col">Status</th>
                  <th className="numeric-cell" scope="col">Total Debit</th>
                  <th scope="col">Actions</th>
                </tr>
              </thead>
              <tbody>
                {entries.map((entry) => (
                  <tr key={entry.id}>
                    <td>
                      <Link to={`${appRoutes.journals}/${entry.id}`}>
                        <strong>{entry.entryNumber}</strong>
                      </Link>
                    </td>
                    <td>{formatDate(entry.effectiveDate)}</td>
                    <td>
                      <div>
                        <span>{entry.description || '—'}</span>
                        {entry.isReversal && (
                          <span className="journal-reversal-marker">
                            [Reversal]
                          </span>
                        )}
                      </div>
                    </td>
                    <td>
                      <StatusChip status={entry.sourceModule ?? 'MANUAL'} />
                    </td>
                    <td>
                      <StatusChip status={entry.status} />
                    </td>
                    <td className="numeric-cell">
                      <Money amount={entry.totalDebit} />
                    </td>
                    <td>
                      <Button onClick={() => navigate(`${appRoutes.journals}/${entry.id}`)} variant="secondary">
                        View Detail
                      </Button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>

            <TablePagination
              itemLabel="journal entry"
              onPageChange={setPage}
              page={page}
              totalElements={journalPage?.totalElements ?? entries.length}
              totalPages={journalPage?.totalPages ?? 1}
            />
          </>
        ) : (
          <div className="directory-state">
            <BookOpen aria-hidden="true" size={24} />
            <strong>No journal entries found.</strong>
            <p>Post a manual journal voucher or initiate domain transactions to record ledger postings.</p>
          </div>
        )}
      </section>

    </section>
  )
}
