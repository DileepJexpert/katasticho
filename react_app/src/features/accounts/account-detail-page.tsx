import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, BookOpen, Edit2 } from 'lucide-react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  CheckboxInput,
  DataTable,
  DocumentCard,
  DocumentError,
  Fact,
  FactList,
  FormField,
  Modal,
  Money,
  PageHeader,
  StatusChip,
  TextAreaInput,
  TextInput,
} from '@/design-system'
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
        <DocumentCard title="Account Specification">
          <FactList>
            <Fact label="Account Code" mono value={document.code} />
            <Fact label="Account Name" value={document.name} />
            <Fact label="Classification" value={<StatusChip status={document.type} />} />
            <Fact label="Category" value={document.subType ? formatStatusLabel(document.subType) : 'Uncategorized'} />
            <Fact label="Hierarchy Parent" value={document.parentAccountName ?? 'Top-level root'} />
            <Fact label="System Status" value={document.isSystem ? 'Standard System Account' : 'User-defined Account'} />
            <Fact label="Postings Allowed" value={document.hasChildren ? 'Parent Header (No Direct Postings)' : 'Transactional Leaf'} />
            <Fact label="Status" value={<StatusChip status={document.isActive ? 'Active' : 'Inactive'} />} />
          </FactList>
        </DocumentCard>
      </div>

      <DocumentCard className="document-card--lines" title="Ledger Transaction History">
        <div className="document-card__toolbar">
          <span className="document-card__toolbar-meta">
            Total entries: {txList.length}
          </span>
          <div className="document-card__toolbar-controls">
            <label className="filter-label">
              From: <TextInput onChange={(e) => setStartDate(e.target.value)} type="date" value={startDate} />
            </label>
            <label className="filter-label">
              To: <TextInput onChange={(e) => setEndDate(e.target.value)} type="date" value={endDate} />
            </label>
            {(startDate || endDate) && (
              <Button onClick={() => { setStartDate(''); setEndDate('') }} variant="ghost">Clear</Button>
            )}
          </div>
        </div>

        {transactions.isLoading ? (
          <div aria-live="polite" className="directory-state">Loading transaction history...</div>
        ) : transactions.isError ? (
          <div className="directory-state directory-state--error" role="alert">
            <strong>Transactions could not be loaded.</strong>
          </div>
        ) : txList.length ? (
          <DataTable caption="Account general ledger transactions">
            <thead>
              <tr>
                <th scope="col">Date</th>
                <th scope="col">Entry Number</th>
                <th scope="col">Narration / Memo</th>
                <th scope="col">Module</th>
                <th className="numeric-cell" scope="col">Debit</th>
                <th className="numeric-cell" scope="col">Credit</th>
              </tr>
            </thead>
            <tbody>
              {txList.map((tx) => {
                const debitVal = Number(tx.debit ?? 0)
                const creditVal = Number(tx.credit ?? 0)
                return (
                  <tr key={tx.lineId || tx.id || tx.journalEntryId}>
                    <td>{formatDate(tx.effectiveDate)}</td>
                    <td>
                      <Link to={`${appRoutes.journals}/${tx.journalEntryId}`}>
                        <strong>{tx.entryNumber}</strong>
                      </Link>
                    </td>
                    <td>{tx.lineDescription || tx.entryDescription || tx.description || '—'}</td>
                    <td>{formatStatusLabel(tx.sourceModule)}</td>
                    <td className="numeric-cell">
                      {debitVal > 0 ? <Money amount={debitVal} currency={document.currency ?? 'INR'} /> : '—'}
                    </td>
                    <td className="numeric-cell">
                      {creditVal > 0 ? <Money amount={creditVal} currency={document.currency ?? 'INR'} /> : '—'}
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </DataTable>
        ) : (
          <div className="directory-state">
            <BookOpen aria-hidden="true" size={24} />
            <strong>No transactions recorded in this period.</strong>
          </div>
        )}
      </DocumentCard>

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
    <Modal
      footer={
        <>
          <Button onClick={onClose} variant="secondary">Cancel</Button>
          <Button disabled={!name || mutation.isPending} onClick={() => mutation.mutate()} variant="primary">
            {mutation.isPending ? 'Saving...' : 'Save Changes'}
          </Button>
        </>
      }
      isOpen
      onClose={onClose}
      size="md"
      title={`Edit Account (${account.code})`}
    >
      <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
        <FormField label="Account Name" required>
          <TextInput onChange={(e) => setName(e.target.value)} required value={name} />
        </FormField>

        <FormField label="Sub-Type / Category">
          <TextInput onChange={(e) => setSubType(e.target.value)} value={subType} />
        </FormField>

        <FormField label="Description">
          <TextAreaInput onChange={(e) => setDescription(e.target.value)} rows={2} value={description} />
        </FormField>

        <CheckboxInput
          checked={isActive}
          label="Account is Active"
          onChange={(e) => setIsActive(e.target.checked)}
        />
      </div>
    </Modal>
  )
}
