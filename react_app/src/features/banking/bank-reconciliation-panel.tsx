import { useRef, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { CheckCircle2, FileUp, RefreshCw, Sparkles, Upload, XCircle, EyeOff } from 'lucide-react'
import {
  Button,
  DataTable,
  DirectoryToolbar,
  EmptyState,
  FilterTabs,
  Money,
  SelectInput,
  StatusChip,
  TablePagination,
} from '@/design-system'
import {
  acceptPaymentMatch,
  getBankReconciliationSummary,
  ignoreBankTransaction,
  importBankStatementFile,
  listBankTransactions,
  rejectPaymentMatch,
  rerunBankMatches,
  runAutoMatch,
  type BankAccount,
  type BankTransaction,
} from './banking-api'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import { useSessionStore } from '@/shared/session/session-store'

const statusTabs = [
  { label: 'All', value: 'ALL' },
  { label: 'Unreconciled', value: 'UNRECONCILED' },
  { label: 'Reconciled', value: 'RECONCILED' },
  { label: 'Ignored', value: 'IGNORED' },
] as const

type StatusFilter = (typeof statusTabs)[number]['value']

export function BankReconciliationPanel({ bankAccounts }: { bankAccounts: BankAccount[] }) {
  const role = useSessionStore((state) => state.user?.role) ?? ''
  const canReconcile = ['OWNER', 'ADMIN', 'ACCOUNTANT'].includes(role)
  const queryClient = useQueryClient()
  const fileInputRef = useRef<HTMLInputElement>(null)

  const [selectedAccountId, setSelectedAccountId] = useState<string>(
    bankAccounts.find((a) => a.isDefault)?.id ?? bankAccounts[0]?.id ?? ''
  )
  const [statusFilter, setStatusFilter] = useState<StatusFilter>('UNRECONCILED')
  const [page, setPage] = useState(0)
  const [feedback, setFeedback] = useState<{ type: 'success' | 'error'; message: string } | null>(null)

  const summaryQuery = useQuery({
    queryKey: ['banking-summary'],
    queryFn: getBankReconciliationSummary,
  })

  const transactionsQuery = useQuery({
    queryKey: ['bank-transactions', statusFilter, page],
    queryFn: () => listBankTransactions(statusFilter, page, 20),
  })

  const uploadMutation = useMutation({
    mutationFn: (file: File) => importBankStatementFile(file),
    onSuccess: (data) => {
      setFeedback({
        type: 'success',
        message: `Statement imported successfully. ${data.importedCount} transactions created (${data.duplicateCount} duplicates skipped).`,
      })
      void queryClient.invalidateQueries({ queryKey: ['banking-summary'] })
      void queryClient.invalidateQueries({ queryKey: ['bank-transactions'] })
    },
    onError: (err: Error) => {
      setFeedback({ type: 'error', message: err.message || 'Failed to import bank statement.' })
    },
  })

  const autoMatchMutation = useMutation({
    mutationFn: () => runAutoMatch(selectedAccountId),
    onSuccess: (results) => {
      setFeedback({
        type: 'success',
        message: `Smart auto-match complete. ${results?.length ?? 0} matches evaluated.`,
      })
      void queryClient.invalidateQueries({ queryKey: ['bank-transactions'] })
      void queryClient.invalidateQueries({ queryKey: ['banking-summary'] })
    },
    onError: (err: Error) => {
      setFeedback({ type: 'error', message: err.message || 'Auto-match run failed.' })
    },
  })

  const acceptMutation = useMutation({
    mutationFn: ({ matchId, bankAccId }: { matchId: string; bankAccId?: string }) =>
      acceptPaymentMatch(matchId, bankAccId),
    onSuccess: () => {
      setFeedback({ type: 'success', message: 'Match accepted and posted to ledger.' })
      void queryClient.invalidateQueries({ queryKey: ['bank-transactions'] })
      void queryClient.invalidateQueries({ queryKey: ['banking-summary'] })
    },
    onError: (err: Error) => {
      setFeedback({ type: 'error', message: err.message || 'Could not accept match.' })
    },
  })

  const rejectMutation = useMutation({
    mutationFn: (matchId: string) => rejectPaymentMatch(matchId),
    onSuccess: () => {
      setFeedback({ type: 'success', message: 'Match suggestion rejected.' })
      void queryClient.invalidateQueries({ queryKey: ['bank-transactions'] })
    },
  })

  const ignoreMutation = useMutation({
    mutationFn: (txnId: string) => ignoreBankTransaction(txnId),
    onSuccess: () => {
      setFeedback({ type: 'success', message: 'Transaction ignored from reconciliation.' })
      void queryClient.invalidateQueries({ queryKey: ['bank-transactions'] })
      void queryClient.invalidateQueries({ queryKey: ['banking-summary'] })
    },
  })

  const rerunMutation = useMutation({
    mutationFn: (txnId: string) => rerunBankMatches(txnId),
    onSuccess: () => {
      setFeedback({ type: 'success', message: 'Matching rules re-evaluated.' })
      void queryClient.invalidateQueries({ queryKey: ['bank-transactions'] })
    },
  })

  const summary = summaryQuery.data ?? {}
  const pagedData = transactionsQuery.data
  const transactions = pagedData?.content ?? []
  const totalElements = pagedData?.totalElements ?? 0
  const totalPages = pagedData?.totalPages ?? 1

  function handleFileChange(event: React.ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0]
    if (!file) return
    uploadMutation.mutate(file)
    event.target.value = ''
  }

  return (
    <section className="bank-reconciliation-panel" aria-label="Bank statement reconciliation">
      {/* Summary KPI Cards */}
      <div className="document-facts form-grid--4col" style={{ marginBottom: '1.25rem' }}>
        <div className="summary-stat-card">
          <dt>Unreconciled</dt>
          <dd>
            <strong style={{ color: 'var(--color-warning)' }}>
              {summary.unreconciledCount ?? 0}
            </strong>
          </dd>
        </div>
        <div className="summary-stat-card">
          <dt>Reconciled</dt>
          <dd>
            <strong style={{ color: 'var(--color-success)' }}>
              {summary.reconciledCount ?? 0}
            </strong>
          </dd>
        </div>
        <div className="summary-stat-card">
          <dt>Ignored</dt>
          <dd>
            <strong>{summary.ignoredCount ?? 0}</strong>
          </dd>
        </div>
        <div className="summary-stat-card">
          <dt>Total transactions</dt>
          <dd>
            <strong>{summary.totalTransactions ?? 0}</strong>
          </dd>
        </div>
      </div>

      {feedback && (
        <div
          role="alert"
          className={`directory-state ${feedback.type === 'error' ? 'directory-state--error' : ''}`}
          style={{ marginBottom: '1rem' }}
        >
          {feedback.message}
        </div>
      )}

      {/* Toolbar with Account Selector, Upload, Auto-Match, and Tabs */}
      <DirectoryToolbar ariaLabel="Reconciliation controls" stacked>
        <div style={{ display: 'flex', gap: '1rem', alignItems: 'center', flexWrap: 'wrap' }}>
          {bankAccounts.length > 0 && (
            <div style={{ minWidth: '240px' }}>
              <SelectInput
                aria-label="Select bank account"
                value={selectedAccountId}
                onChange={(e) => setSelectedAccountId(typeof e === 'string' ? e : e.target.value)}
                options={bankAccounts.map((acc) => ({
                  label: `${acc.name} (${acc.accountNumber ? `•••• ${acc.accountNumber.slice(-4)}` : 'No A/c'})`,
                  value: acc.id,
                }))}
              />
            </div>
          )}

          {canReconcile && (
            <>
              <input
                type="file"
                ref={fileInputRef}
                style={{ display: 'none' }}
                accept=".csv,.xlsx,.xls"
                onChange={handleFileChange}
              />
              <Button
                variant="secondary"
                loading={uploadMutation.isPending}
                onClick={() => fileInputRef.current?.click()}
              >
                <Upload size={16} aria-hidden="true" />
                Upload Statement (.csv/.xlsx)
              </Button>

              {selectedAccountId && (
                <Button
                  variant="secondary"
                  loading={autoMatchMutation.isPending}
                  onClick={() => autoMatchMutation.mutate()}
                >
                  <Sparkles size={16} aria-hidden="true" />
                  Run Smart Match
                </Button>
              )}
            </>
          )}
        </div>

        <FilterTabs
          activeValue={statusFilter}
          ariaLabel="Filter transactions by reconciliation status"
          items={statusTabs.map((t) => ({
            label: t.label,
            value: t.value,
          }))}
          onChange={(val) => {
            setStatusFilter(val as StatusFilter)
            setPage(0)
          }}
        />
      </DirectoryToolbar>

      {/* Transactions Table */}
      {transactionsQuery.isError ? (
        <div className="directory-state directory-state--error" role="alert">
          Bank transactions could not be loaded. Check network connection or permissions.
        </div>
      ) : transactionsQuery.isLoading ? (
        <div aria-live="polite" className="directory-state">Loading transactions...</div>
      ) : transactions.length > 0 ? (
        <>
          <DataTable caption="Bank transactions and reconciliation matches">
            <thead>
              <tr>
                <th scope="col">Date</th>
                <th scope="col">Narration & UTR</th>
                <th scope="col">Payer / Beneficiary</th>
                <th scope="col" className="numeric-cell">Amount</th>
                <th scope="col">Status</th>
                <th scope="col">Suggested Match</th>
                {canReconcile && <th scope="col">Actions</th>}
              </tr>
            </thead>
            <tbody>
              {transactions.map((txn) => (
                <TransactionRow
                  key={txn.id}
                  transaction={txn}
                  canReconcile={canReconcile}
                  selectedAccountId={selectedAccountId}
                  onAccept={(matchId) => acceptMutation.mutate({ matchId, bankAccId: selectedAccountId })}
                  onReject={(matchId) => rejectMutation.mutate(matchId)}
                  onIgnore={() => ignoreMutation.mutate(txn.id)}
                  onRerun={() => rerunMutation.mutate(txn.id)}
                  isBusy={
                    acceptMutation.isPending ||
                    rejectMutation.isPending ||
                    ignoreMutation.isPending ||
                    rerunMutation.isPending
                  }
                />
              ))}
            </tbody>
          </DataTable>

          <TablePagination
            filterDescription={`with status ${statusFilter.toLowerCase()}`}
            isFiltered={statusFilter !== 'ALL'}
            itemLabel="transaction"
            onPageChange={setPage}
            page={page}
            totalElements={totalElements}
            totalPages={totalPages}
          />
        </>
      ) : (
        <EmptyState
          icon={FileUp}
          title="No bank transactions found"
          description={
            statusFilter === 'UNRECONCILED'
              ? 'All transactions have been reconciled! Upload a new statement to match fresh bank feeds.'
              : `No transactions found matching status ${statusFilter.toLowerCase()}.`
          }
        />
      )}
    </section>
  )
}

function TransactionRow({
  transaction,
  canReconcile,
  onAccept,
  onReject,
  onIgnore,
  onRerun,
  isBusy,
}: {
  transaction: BankTransaction
  canReconcile: boolean
  selectedAccountId?: string
  onAccept: (matchId: string) => void
  onReject: (matchId: string) => void
  onIgnore: () => void
  onRerun: () => void
  isBusy: boolean
}) {
  const match = transaction.suggestedMatches?.[0]
  const isInflow = transaction.direction === 'INFLOW'

  return (
    <tr>
      <td>{formatDate(transaction.transactionDate)}</td>
      <td>
        <div className="cell-stack">
          <strong>{transaction.narration || 'Bank Statement Entry'}</strong>
          {transaction.utr && <span className="cell-muted">UTR: {transaction.utr}</span>}
        </div>
      </td>
      <td>
        <div className="cell-stack">
          <span>{transaction.payerName || '--'}</span>
          {transaction.payerVpa && <span className="cell-muted">{transaction.payerVpa}</span>}
        </div>
      </td>
      <td className="numeric-cell" style={{ color: isInflow ? 'var(--color-success)' : undefined }}>
        <Money amount={transaction.amount} />
      </td>
      <td>
        <StatusChip status={formatStatusLabel(transaction.status)} />
      </td>
      <td>
        {match ? (
          <div className="cell-stack">
            <span>
              <strong>{match.matchType}</strong>: {match.documentNumber || match.contactName || 'Matched entry'}
            </span>
            <span className="cell-muted">
              Amount: <Money amount={match.matchedAmount} />
              {match.confidence && ` · ${Math.round(match.confidence * 100)}% match`}
            </span>
          </div>
        ) : (
          <span className="cell-muted">No suggested match</span>
        )}
      </td>
      {canReconcile && (
        <td>
          <div className="document-actions" style={{ gap: '0.25rem' }}>
            {match && transaction.status === 'UNRECONCILED' && (
              <>
                <Button
                  disabled={isBusy}
                  onClick={() => onAccept(match.id)}
                  aria-label="Accept match"
                >
                  <CheckCircle2 size={14} aria-hidden="true" />
                  Accept
                </Button>
                <Button
                  variant="secondary"
                  disabled={isBusy}
                  onClick={() => onReject(match.id)}
                  aria-label="Reject match"
                >
                  <XCircle size={14} aria-hidden="true" />
                </Button>
              </>
            )}
            {transaction.status === 'UNRECONCILED' && (
              <>
                <Button
                  variant="ghost"
                  disabled={isBusy}
                  onClick={onRerun}
                  aria-label="Re-run matching"
                  title="Re-run matching rules"
                >
                  <RefreshCw size={14} aria-hidden="true" />
                </Button>
                <Button
                  variant="ghost"
                  disabled={isBusy}
                  onClick={onIgnore}
                  aria-label="Ignore transaction"
                  title="Ignore transaction"
                >
                  <EyeOff size={14} aria-hidden="true" />
                </Button>
              </>
            )}
          </div>
        </td>
      )}
    </tr>
  )
}
