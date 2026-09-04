import { useMemo, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Landmark } from 'lucide-react'
import {
  Button,
  DataTable,
  DirectoryToolbar,
  EmptyState,
  Fact,
  FactList,
  FilterTabs,
  Modal,
  Money,
  PageHeader,
  SearchInput,
  StatusChip,
} from '@/design-system'
import { listBankAccounts, type BankAccount } from '@/features/banking/banking-api'

type AccountFilter = 'ALL' | 'CURRENT' | 'SAVINGS' | 'OVERDRAFT'

function maskAccountNumber(accNo: string): string {
  if (!accNo) return '--'
  if (accNo.length <= 4) return accNo
  const last4 = accNo.slice(-4)
  return `•••• •••• ${last4}`
}

export function BankingPage() {
  const [filter, setFilter] = useState<AccountFilter>('ALL')
  const [search, setSearch] = useState('')
  const [selectedAccount, setSelectedAccount] = useState<BankAccount | null>(null)

  const accountsQuery = useQuery({
    queryKey: ['bank-accounts'],
    queryFn: () => listBankAccounts(),
  })

  const accounts = accountsQuery.data ?? []

  const activeAccountsCount = useMemo(
    () => accounts.filter((acc) => acc.isActive).length,
    [accounts]
  )

  const defaultAccount = useMemo(
    () => accounts.find((acc) => acc.isDefault),
    [accounts]
  )

  const totalOpeningBalance = useMemo(
    () =>
      accounts.reduce((sum, acc) => sum + (Number(acc.openingBalance) || 0), 0),
    [accounts]
  )

  const filteredAccounts = useMemo(() => {
    const query = search.trim().toLowerCase()
    return accounts.filter((acc) => {
      const type = (acc.accountType ?? '').toUpperCase()
      const matchesFilter =
        filter === 'ALL' ||
        (filter === 'CURRENT' && type === 'CURRENT') ||
        (filter === 'SAVINGS' && type === 'SAVINGS') ||
        (filter === 'OVERDRAFT' && (type === 'OVERDRAFT' || type === 'CREDIT_CARD'))

      if (!matchesFilter) return false

      if (!query) return true

      const name = (acc.name ?? '').toLowerCase()
      const bank = (acc.bankName ?? '').toLowerCase()
      const accNo = (acc.accountNumber ?? '').toLowerCase()
      const ifsc = (acc.ifsc ?? '').toLowerCase()
      const glCode = (acc.glAccountCode ?? '').toLowerCase()

      return (
        name.includes(query) ||
        bank.includes(query) ||
        accNo.includes(query) ||
        ifsc.includes(query) ||
        glCode.includes(query)
      )
    })
  }, [accounts, filter, search])

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Accounting & Treasury / Accounts"
        title="Bank accounts"
        description="Review active treasury accounts, GL account bindings, IFSC routing codes, and ledger balances. Modifications remain in Flutter during migration."
      />

      {/* Summary KPI Cards */}
      <section aria-label="Treasury overview summary" className="document-facts form-grid--4col">
        <div className="summary-stat-card">
          <dt>Total accounts</dt>
          <dd><strong>{accounts.length}</strong></dd>
        </div>
        <div className="summary-stat-card">
          <dt>Active accounts</dt>
          <dd><strong>{activeAccountsCount}</strong></dd>
        </div>
        <div className="summary-stat-card">
          <dt>Default account</dt>
          <dd className="fact-value--mono">
            {defaultAccount ? defaultAccount.bankName : 'None configured'}
          </dd>
        </div>
        <div className="summary-stat-card">
          <dt>Total opening balance</dt>
          <dd>
            <Money amount={totalOpeningBalance} />
          </dd>
        </div>
      </section>

      {/* Directory Table Panel */}
      <section aria-label="Bank accounts directory" className="list-panel">
        <DirectoryToolbar ariaLabel="Filter bank accounts by type and search">
          <SearchInput
            onChange={setSearch}
            onClear={() => setSearch('')}
            placeholder="Search by bank, account, number, or IFSC..."
            value={search}
          />
          <FilterTabs
            activeValue={filter}
            ariaLabel="Filter bank accounts"
            items={[
              { value: 'ALL', label: 'All accounts', count: accounts.length },
              {
                value: 'CURRENT',
                label: 'Current',
                count: accounts.filter((a) => (a.accountType ?? '').toUpperCase() === 'CURRENT').length,
              },
              {
                value: 'SAVINGS',
                label: 'Savings',
                count: accounts.filter((a) => (a.accountType ?? '').toUpperCase() === 'SAVINGS').length,
              },
              {
                value: 'OVERDRAFT',
                label: 'Overdraft / CC',
                count: accounts.filter((a) => {
                  const t = (a.accountType ?? '').toUpperCase()
                  return t === 'OVERDRAFT' || t === 'CREDIT_CARD'
                }).length,
              },
            ]}
            onChange={(value) => setFilter(value as AccountFilter)}
          />
        </DirectoryToolbar>

        {accountsQuery.isError ? (
          <div className="directory-state directory-state--error" role="alert">
            <strong>Bank accounts could not be loaded.</strong>
            <p>Check your connection and permissions, then refresh the page.</p>
          </div>
        ) : accountsQuery.isLoading ? (
          <div aria-live="polite" className="directory-state">
            Loading bank accounts...
          </div>
        ) : filteredAccounts.length ? (
          <DataTable caption="Bank accounts register">
            <thead>
              <tr>
                <th scope="col">Account & Bank</th>
                <th scope="col">Account number</th>
                <th scope="col">IFSC / Code</th>
                <th scope="col">Type</th>
                <th scope="col">GL binding</th>
                <th className="numeric-cell" scope="col">
                  Opening balance
                </th>
                <th scope="col">Status</th>
                <th scope="col">Action</th>
              </tr>
            </thead>
            <tbody>
              {filteredAccounts.map((acc) => (
                <tr key={acc.id}>
                  <td>
                    <div className="cell-stack">
                      <strong>{acc.name}</strong>
                      <small className="table-secondary-text">
                        {acc.bankName}
                        {acc.branch ? ` • ${acc.branch}` : ''}
                      </small>
                    </div>
                  </td>
                  <td>
                    <span className="font-mono" title={acc.accountNumber}>
                      {maskAccountNumber(acc.accountNumber)}
                    </span>
                  </td>
                  <td>
                    {acc.ifsc ? (
                      <span className="code-pill font-mono">{acc.ifsc}</span>
                    ) : (
                      '--'
                    )}
                  </td>
                  <td>
                    <span className="text-secondary">{acc.accountType}</span>
                  </td>
                  <td>
                    {acc.glAccountCode ? (
                      <span className="code-pill font-mono">
                        GL: {acc.glAccountCode}
                      </span>
                    ) : (
                      <span className="text-muted">Unassigned</span>
                    )}
                  </td>
                  <td className="numeric-cell">
                    <Money amount={acc.openingBalance ?? 0} />
                  </td>
                  <td>
                    <div className="status-chip-group">
                      <StatusChip status={acc.isActive ? 'Active' : 'Inactive'} />
                      {acc.isDefault && (
                        <StatusChip status="Default" />
                      )}
                    </div>
                  </td>
                  <td>
                    <Button
                      onClick={() => setSelectedAccount(acc)}
                      variant="ghost"
                    >
                      View details
                    </Button>
                  </td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        ) : (
          <EmptyState
            description="No bank accounts match the active filter criteria."
            icon={Landmark}
            title="No bank accounts found"
          />
        )}
      </section>

      {/* Account Details Modal */}
      {selectedAccount && (
        <Modal
          description="Read-only account properties and general ledger linkage. Modifications remain in Flutter."
          footer={
            <Button
              onClick={() => setSelectedAccount(null)}
              variant="secondary"
            >
              Close
            </Button>
          }
          isOpen={Boolean(selectedAccount)}
          onClose={() => setSelectedAccount(null)}
          size="md"
          title={selectedAccount.name || 'Bank account details'}
        >
          <FactList columns={2}>
            <Fact label="Bank name" value={selectedAccount.bankName} />
            <Fact label="Account name" value={selectedAccount.name} />
            <Fact
              label="Account number"
              mono
              value={selectedAccount.accountNumber}
            />
            <Fact label="IFSC / Routing" mono value={selectedAccount.ifsc} />
            <Fact label="Branch" value={selectedAccount.branch} />
            <Fact label="Account type" value={selectedAccount.accountType} />
            <Fact
              label="GL Account code"
              mono
              value={selectedAccount.glAccountCode ?? selectedAccount.glAccountId}
            />
            <Fact
              label="Opening balance"
              value={<Money amount={selectedAccount.openingBalance ?? 0} />}
            />
            <Fact
              label="Default account"
              value={selectedAccount.isDefault ? 'Yes (Primary)' : 'No'}
            />
            <Fact
              label="Status"
              value={
                <StatusChip
                  status={selectedAccount.isActive ? 'Active' : 'Inactive'}
                />
              }
            />
            {selectedAccount.notes && (
              <Fact
                className="full-span"
                label="Notes"
                value={selectedAccount.notes}
              />
            )}
          </FactList>
        </Modal>
      )}
    </section>
  )
}
