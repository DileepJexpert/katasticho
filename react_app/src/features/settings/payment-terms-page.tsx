import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { CalendarClock } from 'lucide-react'
import { DataTable, DirectoryToolbar, EmptyState, FilterTabs, PageHeader, StatusChip } from '@/design-system'
import { listPaymentTerms, type PaymentTerm, type PaymentTermLine } from '@/features/settings/payment-terms-api'

type TermFilter = 'ALL' | 'ACTIVE' | 'INACTIVE'

export function PaymentTermsPage() {
  const [filter, setFilter] = useState<TermFilter>('ALL')
  const termsQuery = useQuery({ queryKey: ['payment-terms'], queryFn: () => listPaymentTerms() })
  const terms = termsQuery.data ?? []
  const filteredTerms = terms.filter((term) => filter === 'ALL' || (filter === 'ACTIVE' ? term.active : !term.active))

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Settings / Collections"
        title="Payment terms"
        description="Read-only instalment schedule review. Payment-term and dunning changes remain in Flutter during migration."
      />

      <section className="list-panel" aria-label="Payment term directory">
        <DirectoryToolbar ariaLabel="Filter payment terms by status">
          <FilterTabs
            activeValue={filter}
            ariaLabel="Filter payment terms"
            items={[
              { value: 'ALL', label: 'All terms', count: terms.length },
              { value: 'ACTIVE', label: 'Active', count: terms.filter((term) => term.active).length },
              { value: 'INACTIVE', label: 'Inactive', count: terms.filter((term) => !term.active).length },
            ]}
            onChange={(value) => setFilter(value as TermFilter)}
          />
        </DirectoryToolbar>

        {termsQuery.isError ? (
          <div className="directory-state directory-state--error" role="alert">
            <strong>Payment terms could not be loaded.</strong>
            <p>Check your connection and permissions, then refresh the page.</p>
          </div>
        ) : termsQuery.isLoading ? (
          <div aria-live="polite" className="directory-state">Loading payment terms...</div>
        ) : filteredTerms.length ? (
          <DataTable caption="Payment terms">
            <thead>
              <tr>
                <th scope="col">Payment term</th>
                <th scope="col">Description</th>
                <th scope="col">Instalment schedule</th>
                <th scope="col">Default</th>
                <th scope="col">Status</th>
              </tr>
            </thead>
            <tbody>{filteredTerms.map((term) => <PaymentTermRow key={term.id} term={term} />)}</tbody>
          </DataTable>
        ) : (
          <EmptyState
            description={filter === 'ALL' ? 'Payment terms will appear here when they are configured for the organisation.' : 'No payment terms match this status filter.'}
            icon={CalendarClock}
            title={filter === 'ALL' ? 'No payment terms are available.' : 'No matching payment terms.'}
          />
        )}
      </section>
    </section>
  )
}

function PaymentTermRow({ term }: { term: PaymentTerm }) {
  return (
    <tr>
      <td><strong>{term.name}</strong></td>
      <td>{term.description ?? '--'}</td>
      <td><div className="cell-stack">{[...term.lines].sort((left, right) => left.seq - right.seq).map((line) => <span key={line.id}>{formatLine(line)}</span>)}</div></td>
      <td><StatusChip status={term.isDefault ? 'Default' : 'Standard'} /></td>
      <td><StatusChip status={term.active ? 'Active' : 'Inactive'} /></td>
    </tr>
  )
}

function formatLine(line: PaymentTermLine) {
  const due = line.daysOffset === 0 ? 'due on invoice date' : `due in ${line.daysOffset} day${line.daysOffset === 1 ? '' : 's'}`
  return line.valueType === 'BALANCE'
    ? `Remaining balance ${due}`
    : `${line.value ?? 0}% ${due}`
}
