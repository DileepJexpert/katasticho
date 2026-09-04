import { useQuery } from '@tanstack/react-query'
import { AlertTriangle, ArrowLeft, BookOpen } from 'lucide-react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button, DataTable, DocumentCard, Fact, FactList, Money, PageHeader, StatusChip } from '@/design-system'
import { getAccount, getAccountTransactions, type Account, type AccountTransaction } from '@/features/accounts/accounts-api'
import { formatDate, formatStatusLabel } from '@/shared/format/format'

export function AccountDetailPage() {
  const { accountId } = useParams()
  const navigate = useNavigate()
  const accountQuery = useQuery({
    queryKey: ['accounts', accountId],
    queryFn: () => getAccount(accountId!),
    enabled: Boolean(accountId),
  })
  const transactionsQuery = useQuery({
    queryKey: ['accounts', accountId, 'transactions'],
    queryFn: () => getAccountTransactions(accountId!),
    enabled: Boolean(accountId),
  })

  if (!accountId) return <AccountState message="No account ID was specified." />
  if (accountQuery.isLoading) return <AccountState message="Loading account details..." />
  if (accountQuery.isError || !accountQuery.data) {
    return (
      <section className="workspace-page">
        <div className="directory-state directory-state--error" role="alert">
          <AlertTriangle aria-hidden="true" size={24} />
          <strong>Account details could not be loaded.</strong>
          <Button onClick={() => navigate(appRoutes.accounts)} variant="secondary">Back to accounts</Button>
        </div>
      </section>
    )
  }

  const account = accountQuery.data

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Accounting / Account review"
        title={account.name}
        description={`${account.code} · ${formatStatusLabel(account.type)}${account.subType ? ` / ${formatStatusLabel(account.subType)}` : ''}`}
        actions={<StatusChip status={account.isActive ? 'Active' : 'Inactive'} />}
      />

      <div className="document-actions">
        <Button onClick={() => navigate(appRoutes.accounts)} variant="ghost">
          <ArrowLeft aria-hidden="true" size={16} />
          Back to accounts
        </Button>
        <span className="cell-muted">Read-only review. Account maintenance and financial postings remain in Flutter during migration.</span>
      </div>

      <AccountOverview account={account} />
      <TransactionsPanel isError={transactionsQuery.isError} isLoading={transactionsQuery.isLoading} transactions={transactionsQuery.data ?? []} />
    </section>
  )
}

function AccountState({ message }: { message: string }) {
  return <section className="workspace-page"><div aria-live="polite" className="directory-state">{message}</div></section>
}

function AccountOverview({ account }: { account: Account }) {
  return (
    <div className="document-layout">
      <DocumentCard title="Account details">
        <FactList>
          <Fact label="Account code" mono value={account.code} />
          <Fact label="Account type" value={formatStatusLabel(account.type)} />
          <Fact label="Category" value={account.subType ? formatStatusLabel(account.subType) : null} />
          <Fact label="Parent account" value={account.parentAccountName} />
          <Fact label="Description" value={account.description} />
          <Fact label="Hierarchy level" value={account.level} />
        </FactList>
      </DocumentCard>
      <DocumentCard title="Posting controls" variant="summary">
        <FactList>
          <Fact label="Opening balance" value={<Money amount={account.openingBalance} currency={account.currency ?? 'INR'} />} />
          <Fact label="System account" value={account.isSystem ? 'Yes' : 'No'} />
          <Fact label="Child accounts" value={account.childCount} />
          <Fact label="Direct posting" value={account.hasChildren ? 'Not allowed on a parent account' : 'Allowed on this leaf account'} />
          <Fact label="Transaction history" value={account.isInvolvedInTransaction ? 'Present' : 'No postings recorded'} />
        </FactList>
      </DocumentCard>
    </div>
  )
}

function TransactionsPanel({ isError, isLoading, transactions }: { isError: boolean; isLoading: boolean; transactions: AccountTransaction[] }) {
  if (isLoading) return <AccountState message="Loading ledger transactions..." />
  if (isError) return <div className="directory-state directory-state--error" role="alert">Ledger transactions could not be loaded.</div>
  if (!transactions.length) return <div className="directory-state"><BookOpen aria-hidden="true" size={24} /><span>No ledger transactions have been recorded for this account.</span></div>

  return (
    <DocumentCard title="Ledger transactions" variant="lines">
      <DataTable caption="Account ledger transactions">
        <thead>
          <tr>
            <th scope="col">Date</th>
            <th scope="col">Journal</th>
            <th scope="col">Narration</th>
            <th scope="col">Source</th>
            <th className="numeric-cell" scope="col">Debit</th>
            <th className="numeric-cell" scope="col">Credit</th>
          </tr>
        </thead>
        <tbody>{transactions.map((transaction) => (
          <tr key={transaction.lineId}>
            <td>{formatDate(transaction.effectiveDate)}</td>
            <td><Link className="table-row-link table-row-link--mono" to={`${appRoutes.journals}/${transaction.journalEntryId}`}>{transaction.entryNumber}</Link></td>
            <td>{transaction.lineDescription ?? transaction.entryDescription ?? '--'}</td>
            <td>{formatStatusLabel(transaction.sourceModule)}</td>
            <td className="numeric-cell">{Number(transaction.debit ?? 0) > 0 ? <Money amount={transaction.debit} currency={transaction.currency ?? 'INR'} /> : '--'}</td>
            <td className="numeric-cell">{Number(transaction.credit ?? 0) > 0 ? <Money amount={transaction.credit} currency={transaction.currency ?? 'INR'} /> : '--'}</td>
          </tr>
        ))}</tbody>
      </DataTable>
    </DocumentCard>
  )
}
