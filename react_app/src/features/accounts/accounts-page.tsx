import { useDeferredValue, useEffect, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { BookOpen } from 'lucide-react'
import { Link } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { DataTable, DirectoryToolbar, EmptyState, FilterTabs, Money, PageHeader, SearchInput, StatusChip, TablePagination } from '@/design-system'
import { listAccounts, type Account } from '@/features/accounts/accounts-api'
import { formatStatusLabel } from '@/shared/format/format'

const typeTabs = [
  { label: 'All', value: 'ALL' },
  { label: 'Assets', value: 'ASSET' },
  { label: 'Liabilities', value: 'LIABILITY' },
  { label: 'Equity', value: 'EQUITY' },
  { label: 'Revenue', value: 'REVENUE' },
  { label: 'Expenses', value: 'EXPENSE' },
] as const

type TypeFilter = (typeof typeTabs)[number]['value']
const pageSize = 25

export function AccountsPage() {
  const [selectedType, setSelectedType] = useState<TypeFilter>('ALL')
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(0)
  const deferredSearch = useDeferredValue(search.trim().toLowerCase())
  const accountsQuery = useQuery({ queryKey: ['accounts'], queryFn: listAccounts })
  const accounts = accountsQuery.data ?? []

  useEffect(() => {
    setPage(0)
  }, [deferredSearch, selectedType])

  const filteredAccounts = accounts.filter((account) => {
    if (selectedType !== 'ALL' && account.type.toUpperCase() !== selectedType) return false
    if (!deferredSearch) return true
    return [account.code, account.name, account.subType, account.parentAccountName]
      .filter(Boolean)
      .some((value) => value!.toLowerCase().includes(deferredSearch))
  })
  const totalPages = Math.max(1, Math.ceil(filteredAccounts.length / pageSize))
  const paginatedAccounts = filteredAccounts.slice(page * pageSize, (page + 1) * pageSize)

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Accounting / General ledger"
        title="Chart of accounts"
        description="Read-only account and ledger review. Account maintenance and chart templates remain in Flutter during migration."
      />

      <section className="list-panel" aria-label="Chart of accounts directory">
        <DirectoryToolbar ariaLabel="Filter chart of accounts by type and search" stacked>
          <FilterTabs
            activeValue={selectedType}
            ariaLabel="Filter accounts by type"
            items={typeTabs.map((tab) => ({
              value: tab.value,
              label: tab.label,
              count: tab.value === 'ALL' ? accounts.length : accounts.filter((account) => account.type.toUpperCase() === tab.value).length,
            }))}
            onChange={(value) => setSelectedType(value as TypeFilter)}
          />
          <SearchInput
            ariaLabel="Search accounts"
            onChange={setSearch}
            onClear={() => setSearch('')}
            placeholder="Search account code, name, category, or parent"
            value={search}
          />
        </DirectoryToolbar>

        {accountsQuery.isError ? (
          <div className="directory-state directory-state--error" role="alert">
            <strong>Accounts could not be loaded.</strong>
            <p>Check your connection and permissions, then refresh the page.</p>
          </div>
        ) : accountsQuery.isLoading ? (
          <div aria-live="polite" className="directory-state">Loading accounts...</div>
        ) : paginatedAccounts.length ? (
          <>
            <DataTable caption="Chart of accounts">
              <thead>
                <tr>
                  <th scope="col">Code</th>
                  <th scope="col">Account</th>
                  <th scope="col">Type</th>
                  <th scope="col">Category</th>
                  <th scope="col">Parent account</th>
                  <th className="numeric-cell" scope="col">Opening balance</th>
                  <th scope="col">Status</th>
                </tr>
              </thead>
              <tbody>{paginatedAccounts.map((account) => <AccountRow account={account} key={account.id} />)}</tbody>
            </DataTable>
            <TablePagination
              filterDescription={deferredSearch ? 'matching this search' : selectedType === 'ALL' ? 'in total' : `in ${selectedType.toLowerCase()}`}
              isFiltered={Boolean(deferredSearch || selectedType !== 'ALL')}
              itemLabel="account"
              onPageChange={setPage}
              page={page}
              totalElements={filteredAccounts.length}
              totalPages={totalPages}
            />
          </>
        ) : (
          <EmptyState
            description={deferredSearch ? 'Try a different account code, name, category, or parent account.' : 'No accounts are available in this organisation.'}
            icon={BookOpen}
            title="No accounts found."
          />
        )}
      </section>
    </section>
  )
}

function AccountRow({ account }: { account: Account }) {
  return (
    <tr>
      <td><Link className="table-row-link table-row-link--mono" to={`${appRoutes.accounts}/${account.id}`}>{account.code}</Link></td>
      <td><div className="cell-stack"><Link className="table-row-link" to={`${appRoutes.accounts}/${account.id}`}>{account.name}</Link>{account.isSystem && <span className="cell-muted">System account</span>}</div></td>
      <td><StatusChip status={formatStatusLabel(account.type)} /></td>
      <td>{account.subType ? formatStatusLabel(account.subType) : '--'}</td>
      <td>{account.parentAccountName ?? '--'}</td>
      <td className="numeric-cell"><Money amount={account.openingBalance} currency={account.currency ?? 'INR'} /></td>
      <td><StatusChip status={account.isActive ? 'Active' : 'Inactive'} /></td>
    </tr>
  )
}
