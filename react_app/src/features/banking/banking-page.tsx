import { useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  Bot,
  Building2,
  Landmark,
  Plus,
  RefreshCw,
  Search,
  Settings,
  Star,
  Trash2,
} from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import {
  acceptReconciliationMatch,
  createBankAccount,
  deleteBankAccount,
  getBankReconciliationSummary,
  ignoreBankTransaction,
  listBankAccounts,
  listBankRules,
  listBankTransactions,
  rejectReconciliationMatch,
  rerunReconciliationMatch,
  setDefaultBankAccount,
  type BankTransaction,
  type CreateBankAccountRequest,
} from '@/features/banking/banking-api'

type BankingTab = 'accounts' | 'recon' | 'rules'

export function BankingPage() {
  const queryClient = useQueryClient()
  const [activeTab, setActiveTab] = useState<BankingTab>('accounts')

  // Filters & State
  const [transactionSearchTerm, setTransactionSearchTerm] = useState('')
  const [statusFilter, setStatusFilter] = useState<string>('UNRECONCILED')
  const [isAddAccountModalOpen, setIsAddAccountModalOpen] = useState(false)

  // New account form state
  const [accountName, setAccountName] = useState('')
  const [bankName, setBankName] = useState('')
  const [accountNumber, setAccountNumber] = useState('')
  const [ifscCode, setIfscCode] = useState('')
  const [branch, setBranch] = useState('')
  const [accountType, setAccountType] = useState('CURRENT')
  const [openingBalance, setOpeningBalance] = useState('')

  // â”€â”€ Queries â”€â”€
  const accountsQuery = useQuery({
    queryKey: ['bank-accounts-list'],
    queryFn: () => listBankAccounts(),
  })

  const summaryQuery = useQuery({
    queryKey: ['bank-recon-summary'],
    queryFn: () => getBankReconciliationSummary(),
  })

  const transactionsQuery = useQuery({
    queryKey: ['bank-transactions-list', statusFilter],
    queryFn: () => listBankTransactions(statusFilter, 0, 100),
    enabled: activeTab === 'recon',
  })

  const rulesQuery = useQuery({
    queryKey: ['bank-rules-list'],
    queryFn: () => listBankRules(),
    enabled: activeTab === 'rules',
  })

  // â”€â”€ Mutations â”€â”€
  const createAccountMutation = useMutation({
    mutationFn: (req: CreateBankAccountRequest) => createBankAccount(req),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['bank-accounts-list'] })
      queryClient.invalidateQueries({ queryKey: ['bank-recon-summary'] })
      setIsAddAccountModalOpen(false)
      setAccountName('')
      setBankName('')
      setAccountNumber('')
      setIfscCode('')
      setBranch('')
      setOpeningBalance('')
    },
  })

  const setDefaultMutation = useMutation({
    mutationFn: (id: string) => setDefaultBankAccount(id),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['bank-accounts-list'] }),
  })

  const deleteAccountMutation = useMutation({
    mutationFn: (id: string) => deleteBankAccount(id),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['bank-accounts-list'] }),
  })

  const acceptMatchMutation = useMutation({
    mutationFn: ({ matchId, bankAccountId }: { matchId: string; bankAccountId?: string }) =>
      acceptReconciliationMatch(matchId, bankAccountId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['bank-transactions-list'] })
      queryClient.invalidateQueries({ queryKey: ['bank-recon-summary'] })
    },
  })

  const rejectMatchMutation = useMutation({
    mutationFn: (matchId: string) => rejectReconciliationMatch(matchId),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['bank-transactions-list'] }),
  })

  const rerunMatchMutation = useMutation({
    mutationFn: (txnId: string) => rerunReconciliationMatch(txnId),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['bank-transactions-list'] }),
  })

  const ignoreTxnMutation = useMutation({
    mutationFn: (txnId: string) => ignoreBankTransaction(txnId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['bank-transactions-list'] })
      queryClient.invalidateQueries({ queryKey: ['bank-recon-summary'] })
    },
  })

  const accounts = accountsQuery.data ?? []
  const summary = summaryQuery.data
  const transactions: BankTransaction[] = transactionsQuery.data?.content ?? []
  const rules = rulesQuery.data ?? []

  const filteredTransactions = useMemo(() => {
    const term = transactionSearchTerm.trim().toLowerCase()
    if (!term) return transactions
    return transactions.filter(
      (t) =>
        t.description.toLowerCase().includes(term) ||
        (t.referenceNumber && t.referenceNumber.toLowerCase().includes(term))
    )
  }, [transactions, transactionSearchTerm])

  const totalBankBalance = useMemo(() => {
    return accounts.reduce((sum, acc) => sum + Number(acc.currentBalance || 0), 0)
  }, [accounts])

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Banking / Cash Management"
        title="Banking & Statement Reconciliation"
        description="Bank accounts, electronic bank feeds, AI match engine, statement reconciliation, and auto-tagging rules."
        actions={
          <div style={{ display: 'flex', gap: 'var(--space-sm)' }}>
            <Button onClick={() => setIsAddAccountModalOpen(true)} variant="primary">
              <Plus aria-hidden="true" size={14} style={{ marginRight: 6 }} />
              Add Bank Account
            </Button>
          </div>
        }
      />

      {/* KPI Summary Strip */}
      <div className="summary-strip">
        <div className="summary-card">
          <span className="summary-card__label">Total Bank & Cash Balances</span>
          <strong className="summary-card__value" style={{ color: 'var(--color-primary)' }}>
            <Money amount={summary?.totalBankBalance ?? totalBankBalance} />
          </strong>
          <span className="summary-card__hint">{accounts.length} active bank accounts</span>
        </div>

        <div className="summary-card">
          <span className="summary-card__label">General Ledger Book Balance</span>
          <strong className="summary-card__value">
            <Money amount={summary?.totalBookBalance ?? totalBankBalance} />
          </strong>
          <span className="summary-card__hint">Chart of accounts cash balance</span>
        </div>

        <div className="summary-card">
          <span className="summary-card__label">Unreconciled Variance</span>
          <strong
            className="summary-card__value"
            style={{
              color: (summary?.unreconciledDifference || 0) === 0 ? 'var(--color-success)' : 'var(--color-error)',
            }}
          >
            <Money amount={summary?.unreconciledDifference || 0} />
          </strong>
          <span className="summary-card__hint">
            <Quantity value={summary?.unreconciledCount || 0} /> transactions pending match
          </span>
        </div>

        <div className="summary-card summary-card--accent">
          <span className="summary-card__label">Reconciliation Rate</span>
          <strong className="summary-card__value" style={{ color: 'var(--color-success)' }}>
            <Quantity value={summary?.matchedCount || 0} /> Reconciled
          </strong>
          <span className="summary-card__hint">Cleared against journals</span>
        </div>
      </div>

      {/* Navigation Tabs */}
      <div
        className="tab-bar"
        style={{
          display: 'flex',
          gap: 'var(--space-xs)',
          borderBottom: '1px solid var(--color-border)',
          marginBottom: 'var(--space-md)',
        }}
      >
        {[
          { key: 'accounts' as BankingTab, label: 'Bank & Cash Accounts', icon: Landmark },
          { key: 'recon' as BankingTab, label: 'Statement Reconciliation & AI Matching', icon: RefreshCw },
          { key: 'rules' as BankingTab, label: 'Auto-Match & Categorization Rules', icon: Settings },
        ].map((tab) => {
          const Icon = tab.icon
          const isActive = activeTab === tab.key
          return (
            <button
              key={tab.key}
              className={`tab-btn ${isActive ? 'tab-btn--active' : ''}`}
              onClick={() => setActiveTab(tab.key)}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: 6,
                padding: '8px 16px',
                border: 'none',
                background: isActive ? 'var(--color-surface)' : 'transparent',
                borderBottom: isActive ? '2px solid var(--color-primary)' : '2px solid transparent',
                color: isActive ? 'var(--color-primary)' : 'var(--color-text-secondary)',
                fontWeight: isActive ? 600 : 500,
                cursor: 'pointer',
                borderRadius: 'var(--radius-md) var(--radius-md) 0 0',
              }}
              type="button"
            >
              <Icon aria-hidden="true" size={15} />
              {tab.label}
            </button>
          )
        })}
      </div>

      {/* â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */}
      {/* TAB 1: BANK ACCOUNTS */}
      {/* â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */}
      {activeTab === 'accounts' && (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))', gap: 'var(--space-md)' }}>
          {accounts.map((acc) => (
            <div
              key={acc.id}
              className="panel-card"
              style={{
                padding: 'var(--space-md)',
                display: 'flex',
                flexDirection: 'column',
                justifyContent: 'space-between',
                position: 'relative',
              }}
            >
              <div>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 'var(--space-sm)' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <div
                      style={{
                        padding: 8,
                        borderRadius: 'var(--radius-md)',
                        background: 'rgba(74, 127, 224, 0.1)',
                        color: 'var(--color-primary)',
                      }}
                    >
                      <Building2 size={20} />
                    </div>
                    <div>
                      <strong style={{ fontSize: '1rem', display: 'block' }}>{acc.accountName}</strong>
                      <span className="cell-muted" style={{ fontSize: '0.8rem' }}>
                        {acc.bankName} ({acc.accountType})
                      </span>
                    </div>
                  </div>
                  {acc.isDefault && (
                    <span
                      style={{
                        display: 'inline-flex',
                        alignItems: 'center',
                        gap: 3,
                        fontSize: '0.75rem',
                        fontWeight: 600,
                        color: 'var(--color-primary)',
                        background: 'rgba(74, 127, 224, 0.1)',
                        padding: '2px 8px',
                        borderRadius: 'var(--radius-full)',
                      }}
                    >
                      <Star size={11} fill="currentColor" /> Default
                    </span>
                  )}
                </div>

                <div style={{ margin: 'var(--space-sm) 0', padding: '10px 12px', background: 'var(--color-bg-subtle)', borderRadius: 'var(--radius-md)' }}>
                  <span className="cell-muted" style={{ fontSize: '0.75rem', display: 'block' }}>Account Number & IFSC</span>
                  <strong className="table-code" style={{ fontSize: '0.9rem' }}>
                    {acc.accountNumber}
                  </strong>
                  {acc.ifscCode && (
                    <span className="cell-muted" style={{ display: 'block', fontSize: '0.75rem', marginTop: 2 }}>
                      IFSC: {acc.ifscCode}
                    </span>
                  )}
                </div>

                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginTop: 'var(--space-sm)' }}>
                  <span className="cell-muted" style={{ fontSize: '0.85rem' }}>Current Balance</span>
                  <strong style={{ fontSize: '1.2rem', color: 'var(--color-primary)' }}>
                    <Money amount={acc.currentBalance} />
                  </strong>
                </div>
              </div>

              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 6, marginTop: 'var(--space-md)', paddingTop: 'var(--space-sm)', borderTop: '1px solid var(--color-border)' }}>
                {!acc.isDefault && (
                  <Button onClick={() => setDefaultMutation.mutate(acc.id)} variant="secondary">
                    Set Default
                  </Button>
                )}
                <Button onClick={() => deleteAccountMutation.mutate(acc.id)} variant="ghost">
                  <Trash2 aria-hidden="true" size={13} color="var(--color-error)" />
                </Button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */}
      {/* TAB 2: STATEMENT RECONCILIATION & AI MATCHING */}
      {/* â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */}
      {activeTab === 'recon' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-md)' }}>
          {/* Toolbar */}
          <div className="list-toolbar" style={{ justifyContent: 'space-between' }}>
            <div style={{ display: 'flex', gap: 'var(--space-sm)', alignItems: 'center' }}>
              <div className="search-field" style={{ width: 280 }}>
                <Search aria-hidden="true" size={16} />
                <input
                  aria-label="Search bank transactions"
                  onChange={(e) => setTransactionSearchTerm(e.target.value)}
                  placeholder="Search description or reference..."
                  type="text"
                  value={transactionSearchTerm}
                />
              </div>

              <div className="filter-chips">
                {[
                  { key: 'UNRECONCILED', label: 'Unreconciled' },
                  { key: 'RECONCILED', label: 'Reconciled' },
                  { key: 'ALL', label: 'All Transactions' },
                ].map((f) => (
                  <button
                    key={f.key}
                    className={`filter-chip ${statusFilter === f.key ? 'filter-chip--active' : ''}`}
                    onClick={() => setStatusFilter(f.key)}
                    type="button"
                  >
                    {f.label}
                  </button>
                ))}
              </div>
            </div>
          </div>

          {/* Transactions & Matches Table */}
          <DataTable caption="Bank Transactions Reconciliation Table">
            <thead>
              <tr>
                <th scope="col">Date</th>
                <th scope="col">Transaction Description</th>
                <th scope="col">Reference / UTR</th>
                <th className="numeric-cell" scope="col">Debit (Outflow)</th>
                <th className="numeric-cell" scope="col">Credit (Inflow)</th>
                <th scope="col">Matched Books Entry</th>
                <th scope="col">Status</th>
                <th className="numeric-cell" scope="col">Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredTransactions.map((txn) => {
                const topMatch = txn.matches?.[0]
                return (
                  <tr key={txn.id}>
                    <td>
                      <span className="cell-muted">{txn.transactionDate}</span>
                    </td>
                    <td>
                      <strong>{txn.description}</strong>
                    </td>
                    <td>
                      <span className="table-code">{txn.referenceNumber || 'Ã¢â‚¬â€'}</span>
                    </td>
                    <td className="numeric-cell">
                      {txn.debitAmount > 0 ? (
                        <strong style={{ color: 'var(--color-error)' }}>
                          - <Money amount={txn.debitAmount} />
                        </strong>
                      ) : (
                        <span className="cell-muted">Ã¢â‚¬â€</span>
                      )}
                    </td>
                    <td className="numeric-cell">
                      {txn.creditAmount > 0 ? (
                        <strong style={{ color: 'var(--color-success)' }}>
                          + <Money amount={txn.creditAmount} />
                        </strong>
                      ) : (
                        <span className="cell-muted">Ã¢â‚¬â€</span>
                      )}
                    </td>
                    <td>
                      {topMatch ? (
                        <div style={{ padding: '4px 8px', background: 'rgba(74, 127, 224, 0.08)', borderRadius: 'var(--radius-md)', border: '1px solid rgba(74, 127, 224, 0.2)' }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                            <Bot size={13} color="var(--color-primary)" />
                            <strong style={{ fontSize: '0.8rem', color: 'var(--color-primary)' }}>
                              Journal #{topMatch.journalNumber || 'GL Entry'}
                            </strong>
                          </div>
                          <span className="cell-muted" style={{ fontSize: '0.75rem', display: 'block' }}>
                            Match: {(topMatch.confidenceScore * 100).toFixed(0)}% confidence ({topMatch.matchType})
                          </span>
                        </div>
                      ) : (
                        <span className="cell-muted">No suggested match</span>
                      )}
                    </td>
                    <td>
                      <StatusChip status={txn.reconciliationStatus} />
                    </td>
                    <td className="numeric-cell">
                      <div style={{ display: 'flex', gap: 4, justifyContent: 'flex-end' }}>
                        {txn.reconciliationStatus === 'UNRECONCILED' && topMatch && (
                          <>
                            <Button
                              onClick={() => acceptMatchMutation.mutate({ matchId: topMatch.id, bankAccountId: txn.bankAccountId })}
                              variant="primary"
                            >
                              Accept
                            </Button>
                            <Button
                              onClick={() => rejectMatchMutation.mutate(topMatch.id)}
                              variant="ghost"
                            >
                              Reject
                            </Button>
                          </>
                        )}
                        {txn.reconciliationStatus === 'UNRECONCILED' && !topMatch && (
                          <>
                            <Button
                              onClick={() => rerunMatchMutation.mutate(txn.id)}
                              variant="secondary"
                            >
                              Rerun AI
                            </Button>
                            <Button
                              onClick={() => ignoreTxnMutation.mutate(txn.id)}
                              variant="ghost"
                            >
                              Ignore
                            </Button>
                          </>
                        )}
                      </div>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </DataTable>
        </div>
      )}

      {/* â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */}
      {/* TAB 3: BANK RULES */}
      {/* â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */}
      {activeTab === 'rules' && (
        <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
          <h3 style={{ fontSize: '1.05rem', fontWeight: 600, marginBottom: 'var(--space-sm)' }}>
            Automated Categorization & Match Rules
          </h3>
          <p className="cell-muted" style={{ fontSize: '0.85rem', marginBottom: 'var(--space-md)' }}>
            Bank transactions matching description patterns or reference formats will be automatically classified into specific general ledger expense or revenue accounts.
          </p>

          <DataTable caption="Bank rules list">
            <thead>
              <tr>
                <th scope="col">Rule Name</th>
                <th scope="col">Rule Type</th>
                <th scope="col">Pattern / Conditions</th>
                <th scope="col">Target Ledger Account</th>
                <th scope="col">Status</th>
              </tr>
            </thead>
            <tbody>
              {rules.map((r) => (
                <tr key={r.id}>
                  <td>
                    <strong>{r.name}</strong>
                  </td>
                  <td>
                    <StatusChip status={r.ruleType} />
                  </td>
                  <td>
                    <span className="table-code">{r.conditions}</span>
                  </td>
                  <td>
                    <strong>{r.targetAccountName || 'Auto-classify'}</strong>
                  </td>
                  <td>
                    <StatusChip status={r.active ? 'ACTIVE' : 'DISABLED'} />
                  </td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        </div>
      )}

      {/* MODAL: ADD BANK ACCOUNT */}
      {isAddAccountModalOpen && (
        <div
          role="dialog"
          aria-modal="true"
          style={{
            position: 'fixed',
            inset: 0,
            backgroundColor: 'rgba(0,0,0,0.5)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 1000,
            padding: 'var(--space-md)',
          }}
        >
          <div
            className="panel-card"
            style={{
              width: '100%',
              maxWidth: 480,
              backgroundColor: 'var(--color-surface)',
              borderRadius: 'var(--radius-lg)',
              padding: 'var(--space-lg)',
              border: '1px solid var(--color-border)',
            }}
          >
            <h3 style={{ fontSize: '1.2rem', fontWeight: 600, marginBottom: 'var(--space-xs)' }}>
              Add Bank / Cash Account
            </h3>
            <p className="cell-muted" style={{ fontSize: '0.85rem', marginBottom: 'var(--space-md)' }}>
              Connect your commercial bank account for reconciliations and payment tracking.
            </p>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 'var(--space-sm)', marginBottom: 'var(--space-sm)' }}>
              <div>
                <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                  Account Display Name
                </label>
                <input
                  style={{
                    width: '100%',
                    padding: '8px 12px',
                    borderRadius: 'var(--radius-md)',
                    border: '1px solid var(--color-border)',
                  }}
                  onChange={(e) => setAccountName(e.target.value)}
                  placeholder="e.g. HDFC Operating Account"
                  type="text"
                  value={accountName}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                  Bank Institution
                </label>
                <input
                  style={{
                    width: '100%',
                    padding: '8px 12px',
                    borderRadius: 'var(--radius-md)',
                    border: '1px solid var(--color-border)',
                  }}
                  onChange={(e) => setBankName(e.target.value)}
                  placeholder="e.g. HDFC Bank"
                  type="text"
                  value={bankName}
                />
              </div>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1.2fr 1fr', gap: 'var(--space-sm)', marginBottom: 'var(--space-sm)' }}>
              <div>
                <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                  Account Number
                </label>
                <input
                  style={{
                    width: '100%',
                    padding: '8px 12px',
                    borderRadius: 'var(--radius-md)',
                    border: '1px solid var(--color-border)',
                    fontFamily: 'monospace',
                  }}
                  onChange={(e) => setAccountNumber(e.target.value)}
                  placeholder="e.g. 50200012345678"
                  type="text"
                  value={accountNumber}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                  IFSC Code
                </label>
                <input
                  style={{
                    width: '100%',
                    padding: '8px 12px',
                    borderRadius: 'var(--radius-md)',
                    border: '1px solid var(--color-border)',
                    textTransform: 'uppercase',
                    fontFamily: 'monospace',
                  }}
                  onChange={(e) => setIfscCode(e.target.value)}
                  placeholder="HDFC0001234"
                  type="text"
                  value={ifscCode}
                />
              </div>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 'var(--space-sm)', marginBottom: 'var(--space-md)' }}>
              <div>
                <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                  Account Type
                </label>
                <select
                  className="select-field"
                  onChange={(e) => setAccountType(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '8px 12px',
                    borderRadius: 'var(--radius-md)',
                    border: '1px solid var(--color-border)',
                  }}
                  value={accountType}
                >
                  <option value="CURRENT">Current / Checking</option>
                  <option value="SAVINGS">Savings</option>
                  <option value="OVERDRAFT">Cash Credit / Overdraft</option>
                  <option value="CREDIT_CARD">Corporate Credit Card</option>
                </select>
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                  Opening Balance (Ã¢â€šÂ¹)
                </label>
                <input
                  style={{
                    width: '100%',
                    padding: '8px 12px',
                    borderRadius: 'var(--radius-md)',
                    border: '1px solid var(--color-border)',
                  }}
                  onChange={(e) => setOpeningBalance(e.target.value)}
                  placeholder="0.00"
                  type="number"
                  value={openingBalance}
                />
              </div>
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
              <Button onClick={() => setIsAddAccountModalOpen(false)} variant="secondary">
                Cancel
              </Button>
              <Button
                disabled={!accountName.trim() || !accountNumber.trim() || createAccountMutation.isPending}
                onClick={() =>
                  createAccountMutation.mutate({
                    accountName,
                    bankName,
                    accountNumber,
                    ifscCode,
                    branch,
                    accountType,
                    openingBalance: openingBalance ? Number(openingBalance) : 0,
                  })
                }
                variant="primary"
              >
                {createAccountMutation.isPending ? 'Saving...' : 'Save Account'}
              </Button>
            </div>
          </div>
        </div>
      )}
    </section>
  )
}