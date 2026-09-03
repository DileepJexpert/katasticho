import { useState } from 'react'
import type { ReactNode } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, BookOpen, Edit2 } from 'lucide-react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import {
  getAccount,
  getAccountTransactions,
  updateAccount,
  type Account,
} from '@/features/accounts/accounts-api'

export function AccountDetailPage() {
  const { accountId } = useParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [showEditModal, setShowEditModal] = useState(false)
  const [startDate, setStartDate] = useState('')
  const [endDate, setEndDate] = useState('')

  const account = useQuery({
    queryKey: ['accounts', accountId],
    queryFn: () => getAccount(accountId!),
    enabled: Boolean(accountId),
  })

  const transactions = useQuery({
    queryKey: ['accounts', accountId, 'transactions', startDate, endDate],
    queryFn: () => getAccountTransactions(accountId!, startDate || undefined, endDate || undefined),
    enabled: Boolean(accountId),
  })

  if (!accountId) return <DocumentError onBack={() => navigate(appRoutes.accounts)} />
  if (account.isLoading) return <section className="workspace-page"><div aria-live="polite" className="directory-state">Loading account details...</div></section>
  if (account.isError || !account.data) return <DocumentError onBack={() => navigate(appRoutes.accounts)} />

  const document = account.data
  const txList = transactions.data ?? []

  const totalDebit = txList.reduce((acc, curr) => acc + Number(curr.debit || 0), 0)
  const totalCredit = txList.reduce((acc, curr) => acc + Number(curr.credit || 0), 0)
  const opening = Number(document.openingBalance || 0)
  const isAssetOrExpense = ['ASSET', 'EXPENSE'].includes(document.type?.toUpperCase())
  const netEndingBalance = isAssetOrExpense
    ? opening + totalDebit - totalCredit
    : opening + totalCredit - totalDebit

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
            <Button onClick={() => navigate(appRoutes.accounts)} variant="secondary">
              <ArrowLeft className="icon" /> Back to Accounts
            </Button>
            <Button onClick={() => setShowEditModal(true)} variant="primary">
              <Edit2 className="icon" /> Edit Account
            </Button>
          </div>
        }
        description={`Code: ${document.code} · ${formatStatusLabel(document.type)}${document.subType ? ` / ${formatStatusLabel(document.subType)}` : ''}`}
        eyebrow="Accounting / General Ledger / Account"
        title={document.name}
      />

      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
          gap: '1rem',
          marginBottom: '1.5rem',
        }}
      >
        <div className="card" style={{ padding: '1rem' }}>
          <div style={{ fontSize: '0.75rem', color: 'var(--color-text-muted)' }}>Opening Balance</div>
          <div style={{ fontSize: '1.25rem', fontWeight: 'bold' }}>
            <Money amount={opening} currency={document.currency ?? 'INR'} />
          </div>
        </div>
        <div className="card" style={{ padding: '1rem' }}>
          <div style={{ fontSize: '0.75rem', color: 'var(--color-text-muted)' }}>Period Debits</div>
          <div style={{ fontSize: '1.25rem', fontWeight: 'bold', color: 'var(--color-primary)' }}>
            <Money amount={totalDebit} currency={document.currency ?? 'INR'} />
          </div>
        </div>
        <div className="card" style={{ padding: '1rem' }}>
          <div style={{ fontSize: '0.75rem', color: 'var(--color-text-muted)' }}>Period Credits</div>
          <div style={{ fontSize: '1.25rem', fontWeight: 'bold' }}>
            <Money amount={totalCredit} currency={document.currency ?? 'INR'} />
          </div>
        </div>
        <div className="card" style={{ padding: '1rem' }}>
          <div style={{ fontSize: '0.75rem', color: 'var(--color-text-muted)' }}>Net Ending Balance</div>
          <div style={{ fontSize: '1.25rem', fontWeight: 'bold' }}>
            <Money amount={netEndingBalance} currency={document.currency ?? 'INR'} />
          </div>
        </div>
      </div>

      <div className="document-layout" style={{ marginBottom: '1.5rem' }}>
        <section className="document-card">
          <h2>Account Specification</h2>
          <dl className="document-facts">
            <Fact label="Account Code" value={document.code} />
            <Fact label="Account Name" value={document.name} />
            <Fact label="Classification" value={<StatusChip status={document.type} />} />
            <Fact label="Category" value={document.subType ? formatStatusLabel(document.subType) : 'Uncategorized'} />
            <Fact label="Hierarchy Parent" value={document.parentAccountName ?? 'Top-level root'} />
            <Fact label="System Status" value={document.isSystem ? 'Standard System Account' : 'User-defined Account'} />
            <Fact label="Postings Allowed" value={document.hasChildren ? 'Parent Header (No Direct Postings)' : 'Transactional Leaf'} />
            <Fact label="Status" value={<StatusChip status={document.isActive ? 'Active' : 'Inactive'} />} />
          </dl>
        </section>
      </div>

      <section className="document-card document-card--lines">
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem', flexWrap: 'wrap', gap: '0.5rem' }}>
          <h2>Ledger Transaction History ({txList.length})</h2>
          <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
            <label style={{ fontSize: '0.875rem' }}>
              From: <input onChange={(e) => setStartDate(e.target.value)} type="date" value={startDate} />
            </label>
            <label style={{ fontSize: '0.875rem' }}>
              To: <input onChange={(e) => setEndDate(e.target.value)} type="date" value={endDate} />
            </label>
            {(startDate || endDate) && (
              <Button onClick={() => { setStartDate(''); setEndDate('') }} variant="ghost">Clear</Button>
            )}
          </div>
        </div>

        {transactions.isLoading ? (
          <div aria-live="polite" className="directory-state">Loading transaction history...</div>
        ) : txList.length ? (
          <DataTable caption="Account transactions">
            <thead>
              <tr>
                <th scope="col">Date</th>
                <th scope="col">Entry #</th>
                <th scope="col">Module</th>
                <th scope="col">Description</th>
                <th className="numeric-cell" scope="col">Debit</th>
                <th className="numeric-cell" scope="col">Credit</th>
              </tr>
            </thead>
            <tbody>
              {txList.map((tx) => (
                <tr key={tx.lineId}>
                  <td>{formatDate(tx.effectiveDate)}</td>
                  <td>
                    <Link to={`${appRoutes.journals}/${tx.journalEntryId}`}>
                      <code>{tx.entryNumber}</code>
                    </Link>
                  </td>
                  <td>
                    <StatusChip status={tx.sourceModule ?? 'MANUAL'} />
                  </td>
                  <td>{tx.lineDescription || tx.entryDescription || '—'}</td>
                  <td className="numeric-cell">
                    {tx.debit != null && Number(tx.debit) > 0 ? (
                      <Money amount={tx.debit} currency={tx.currency ?? 'INR'} />
                    ) : '—'}
                  </td>
                  <td className="numeric-cell">
                    {tx.credit != null && Number(tx.credit) > 0 ? (
                      <Money amount={tx.credit} currency={tx.currency ?? 'INR'} />
                    ) : '—'}
                  </td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        ) : (
          <div className="directory-state">
            <BookOpen aria-hidden="true" size={24} />
            <strong>No ledger transactions recorded.</strong>
            <p>Transactions will appear here when journals, bills, or invoices post to this account.</p>
          </div>
        )}
      </section>

      {showEditModal && (
        <EditAccountModal
          account={document}
          onClose={() => setShowEditModal(false)}
          onSuccess={() => {
            setShowEditModal(false)
            queryClient.invalidateQueries({ queryKey: ['accounts', accountId] })
          }}
        />
      )}
    </section>
  )
}

function EditAccountModal({
  account,
  onClose,
  onSuccess,
}: {
  account: Account
  onClose: () => void
  onSuccess: () => void
}) {
  const [name, setName] = useState(account.name)
  const [subType, setSubType] = useState(account.subType ?? '')
  const [description, setDescription] = useState(account.description ?? '')
  const [isActive, setIsActive] = useState(account.isActive)

  const mutation = useMutation({
    mutationFn: () =>
      updateAccount(account.id, {
        name,
        subType: subType || undefined,
        description: description || undefined,
        isActive,
      }),
    onSuccess: () => onSuccess(),
  })

  return (
    <div className="modal-backdrop" role="dialog">
      <div className="modal-dialog">
        <header className="modal-header">
          <h3>Edit Account ({account.code})</h3>
          <Button onClick={onClose} variant="ghost">✕</Button>
        </header>
        <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <label className="field-group">
            <span>Account Name *</span>
            <input onChange={(e) => setName(e.target.value)} required value={name} />
          </label>

          <label className="field-group">
            <span>Sub-Type / Category</span>
            <input onChange={(e) => setSubType(e.target.value)} value={subType} />
          </label>

          <label className="field-group">
            <span>Description</span>
            <textarea onChange={(e) => setDescription(e.target.value)} rows={2} value={description} />
          </label>

          <label style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', cursor: 'pointer' }}>
            <input checked={isActive} onChange={(e) => setIsActive(e.target.checked)} type="checkbox" />
            <span>Account is Active</span>
          </label>
        </div>
        <footer className="modal-footer">
          <Button onClick={onClose} variant="secondary">Cancel</Button>
          <Button disabled={!name || mutation.isPending} onClick={() => mutation.mutate()} variant="primary">
            {mutation.isPending ? 'Saving...' : 'Save Changes'}
          </Button>
        </footer>
      </div>
    </div>
  )
}

function Fact({ label, value }: { label: string; value: ReactNode }) {
  return (
    <div className="document-fact">
      <dt>{label}</dt>
      <dd>{value}</dd>
    </div>
  )
}

function DocumentError({ onBack }: { onBack: () => void }) {
  return (
    <section className="workspace-page">
      <div className="directory-state">
        <p>Account not found or failed to load.</p>
        <Button onClick={onBack} variant="secondary">
          <ArrowLeft className="icon" /> Back to Accounts
        </Button>
      </div>
    </section>
  )
}
