import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  BookOpen,
  ChevronLeft,
  ChevronRight,
  Plus,
  Search,
} from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate } from '@/shared/format/format'
import {
  createJournal,
  listJournals,
  type CreateJournalLineRequest,
} from '@/features/journals/journals-api'
import { listAccounts } from '@/features/accounts/accounts-api'

const moduleFilters = [
  { label: 'All Modules', value: 'ALL' },
  { label: 'Manual', value: 'MANUAL' },
  { label: 'Sales', value: 'SALES' },
  { label: 'Purchases', value: 'PURCHASE' },
  { label: 'Payroll', value: 'PAYROLL' },
  { label: 'Banking', value: 'BANKING' },
  { label: 'Inventory', value: 'INVENTORY' },
] as const

export function JournalsPage() {
  const [selectedModule, setSelectedModule] = useState<string>('ALL')
  const [search, setSearch] = useState('')
  const [dateFrom, setDateFrom] = useState('')
  const [dateTo, setDateTo] = useState('')
  const [page, setPage] = useState(0)
  const [showCreateModal, setShowCreateModal] = useState(false)

  const navigate = useNavigate()
  const queryClient = useQueryClient()

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
          <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
            <Button onClick={() => setShowCreateModal(true)} variant="primary">
              <Plus className="icon" /> New Journal Entry
            </Button>
          </div>
        }
        description="Double-entry general ledger journal vouchers, automated domain postings, and reversing entries."
        eyebrow="Accounting / General Ledger"
        title="Journal Entries"
      />

      <section className="list-panel" aria-label="Journals directory">
        <div className="list-toolbar list-toolbar--stacked">
          <div aria-label="Filter by source module" className="filter-chips" role="tablist">
            {moduleFilters.map((mod) => (
              <button
                aria-selected={selectedModule === mod.value}
                className={`filter-chip ${selectedModule === mod.value ? 'filter-chip--active' : ''}`}
                key={mod.value}
                onClick={() => {
                  setSelectedModule(mod.value)
                  setPage(0)
                }}
                role="tab"
                type="button"
              >
                <span>{mod.label}</span>
              </button>
            ))}
          </div>

          <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap', alignItems: 'center' }}>
            <label className="directory-search" style={{ flex: 1, minWidth: '220px' }}>
              <Search aria-hidden="true" size={18} />
              <input
                onChange={(e) => {
                  setSearch(e.target.value)
                  setPage(0)
                }}
                placeholder="Search by entry number, narration..."
                type="search"
                value={search}
              />
            </label>
            <label style={{ fontSize: '0.875rem' }}>
              From: <input onChange={(e) => { setDateFrom(e.target.value); setPage(0) }} type="date" value={dateFrom} />
            </label>
            <label style={{ fontSize: '0.875rem' }}>
              To: <input onChange={(e) => { setDateTo(e.target.value); setPage(0) }} type="date" value={dateTo} />
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
                          <span style={{ marginLeft: '6px', fontSize: '0.75rem', color: 'var(--color-primary)' }}>
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

            <footer className="table-footer">
              <span>{journalPage?.totalElements ?? entries.length} journal entries found</span>
              <div className="pagination-actions">
                <button
                  aria-label="Previous page"
                  disabled={page === 0}
                  onClick={() => setPage((p) => p - 1)}
                  type="button"
                >
                  <ChevronLeft aria-hidden="true" size={16} />
                </button>
                <span>
                  Page {page + 1} of {Math.max(journalPage?.totalPages ?? 1, 1)}
                </span>
                <button
                  aria-label="Next page"
                  disabled={journalPage?.last ?? true}
                  onClick={() => setPage((p) => p + 1)}
                  type="button"
                >
                  <ChevronRight aria-hidden="true" size={16} />
                </button>
              </div>
            </footer>
          </>
        ) : (
          <div className="directory-state">
            <BookOpen aria-hidden="true" size={24} />
            <strong>No journal entries found.</strong>
            <p>Post a manual journal voucher or initiate domain transactions to record ledger postings.</p>
          </div>
        )}
      </section>

      {showCreateModal && (
        <CreateJournalModal
          onClose={() => setShowCreateModal(false)}
          onSuccess={(newId) => {
            setShowCreateModal(false)
            queryClient.invalidateQueries({ queryKey: ['journals'] })
            navigate(`${appRoutes.journals}/${newId}`)
          }}
        />
      )}
    </section>
  )
}

function CreateJournalModal({
  onClose,
  onSuccess,
}: {
  onClose: () => void
  onSuccess: (newId: string) => void
}) {
  const [effectiveDate, setEffectiveDate] = useState(new Date().toISOString().slice(0, 10))
  const [description, setDescription] = useState('')
  const [reference, setReference] = useState('')
  const [lines, setLines] = useState<CreateJournalLineRequest[]>([
    { accountId: '', debit: 0, credit: 0, description: '' },
    { accountId: '', debit: 0, credit: 0, description: '' },
  ])

  const accountsQuery = useQuery({
    queryKey: ['accounts-dropdown'],
    queryFn: listAccounts,
  })

  const accounts = accountsQuery.data ?? []

  const totalDebit = lines.reduce((acc, curr) => acc + Number(curr.debit || 0), 0)
  const totalCredit = lines.reduce((acc, curr) => acc + Number(curr.credit || 0), 0)
  const isBalanced = Math.abs(totalDebit - totalCredit) < 0.001 && totalDebit > 0

  const mutation = useMutation({
    mutationFn: () =>
      createJournal({
        effectiveDate,
        description,
        reference: reference || undefined,
        sourceModule: 'MANUAL',
        lines: lines.map((l) => ({
          accountId: l.accountId,
          debit: Number(l.debit || 0),
          credit: Number(l.credit || 0),
          description: l.description || undefined,
        })),
      }),
    onSuccess: (res) => onSuccess(res.id),
  })

  function addLine() {
    setLines([...lines, { accountId: '', debit: 0, credit: 0, description: '' }])
  }

  function updateLine(idx: number, patch: Partial<CreateJournalLineRequest>) {
    setLines((prev) =>
      prev.map((l, i) => (i === idx ? { ...l, ...patch } : l))
    )
  }

  function removeLine(idx: number) {
    setLines(lines.filter((_, i) => i !== idx))
  }

  return (
    <div className="modal-backdrop" role="dialog">
      <div className="modal-dialog" style={{ maxWidth: '750px' }}>
        <header className="modal-header">
          <h3>Create Double-Entry Journal Voucher</h3>
          <Button onClick={onClose} variant="ghost">✕</Button>
        </header>
        <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
            <label className="field-group">
              <span>Effective Date *</span>
              <input onChange={(e) => setEffectiveDate(e.target.value)} required type="date" value={effectiveDate} />
            </label>
            <label className="field-group">
              <span>Reference Number</span>
              <input onChange={(e) => setReference(e.target.value)} placeholder="e.g. JV-2026-001" value={reference} />
            </label>
          </div>

          <label className="field-group">
            <span>Narration / Notes *</span>
            <input
              onChange={(e) => setDescription(e.target.value)}
              placeholder="e.g. Adjustment for prepaid rent / monthly accrual"
              required
              value={description}
            />
          </label>

          <div>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.5rem' }}>
              <h4>Journal Lines ({lines.length})</h4>
              <Button onClick={addLine} variant="secondary">
                <Plus className="icon" /> Add Line
              </Button>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
              {lines.map((line, idx) => (
                <div key={idx} style={{ display: 'grid', gridTemplateColumns: '2fr 1fr 1fr 1.5fr auto', gap: '0.5rem', alignItems: 'center' }}>
                  <select onChange={(e) => updateLine(idx, { accountId: e.target.value })} value={line.accountId}>
                    <option value="">-- Choose Account --</option>
                    {accounts.map((a) => (
                      <option key={a.id} value={a.id}>
                        {a.code} - {a.name} ({a.type})
                      </option>
                    ))}
                  </select>
                  <input
                    min={0}
                    onChange={(e) => updateLine(idx, { debit: Number(e.target.value), credit: 0 })}
                    placeholder="Debit"
                    type="number"
                    value={line.debit === 0 ? '' : line.debit}
                  />
                  <input
                    min={0}
                    onChange={(e) => updateLine(idx, { credit: Number(e.target.value), debit: 0 })}
                    placeholder="Credit"
                    type="number"
                    value={line.credit === 0 ? '' : line.credit}
                  />
                  <input
                    onChange={(e) => updateLine(idx, { description: e.target.value })}
                    placeholder="Line memo"
                    value={line.description ?? ''}
                  />
                  <Button disabled={lines.length <= 2} onClick={() => removeLine(idx)} variant="ghost">✕</Button>
                </div>
              ))}
            </div>
          </div>

          <div
            style={{
              padding: '0.75rem',
              borderRadius: '6px',
              backgroundColor: isBalanced ? 'rgba(15, 133, 118, 0.08)' : 'rgba(190, 58, 52, 0.08)',
              border: `1px solid ${isBalanced ? 'var(--color-primary)' : 'var(--color-danger, #BE3A34)'}`,
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
            }}
          >
            <div>
              <strong>Total Debits:</strong> <Money amount={totalDebit} /> | <strong>Total Credits:</strong> <Money amount={totalCredit} />
            </div>
            <div>
              {isBalanced ? (
                <span style={{ color: 'var(--color-primary)', fontWeight: 'bold' }}>✓ Balanced</span>
              ) : (
                <span style={{ color: 'var(--color-danger, #BE3A34)', fontWeight: 'bold' }}>
                  Difference: <Money amount={Math.abs(totalDebit - totalCredit)} />
                </span>
              )}
            </div>
          </div>
        </div>
        <footer className="modal-footer">
          <Button onClick={onClose} variant="secondary">Cancel</Button>
          <Button
            disabled={!description || !isBalanced || lines.some((l) => !l.accountId) || mutation.isPending}
            onClick={() => mutation.mutate()}
            variant="primary"
          >
            {mutation.isPending ? 'Posting...' : 'Post Journal Voucher'}
          </Button>
        </footer>
      </div>
    </div>
  )
}
