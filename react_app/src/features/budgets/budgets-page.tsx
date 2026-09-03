import { useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  AlertCircle,
  Calendar,
  CheckCircle2,
  Edit3,
  Search,
  TrendingDown,
} from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { listAccounts } from '@/features/accounts/accounts-api'
import { listBudget, saveBudget, type BudgetLine } from '@/features/budgets/budgets-api'

export function BudgetsPage() {
  const queryClient = useQueryClient()
  const currentYear = new Date().getFullYear()
  const [selectedFy, setSelectedFy] = useState<number>(currentYear)
  const [searchTerm, setSearchTerm] = useState('')
  const [accountTypeFilter, setAccountTypeFilter] = useState<string>('ALL')
  const [isEditModalOpen, setIsEditModalOpen] = useState(false)
  const [draftLines, setDraftLines] = useState<Record<string, number>>({})

  // Queries
  const budgetQuery = useQuery({
    queryKey: ['budgets', selectedFy],
    queryFn: () => listBudget(selectedFy),
  })

  const accountsQuery = useQuery({
    queryKey: ['accounts-for-budget'],
    queryFn: () => listAccounts(),
  })

  const saveMutation = useMutation({
    mutationFn: (lines: BudgetLine[]) => saveBudget(selectedFy, lines),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['budgets', selectedFy] })
      setIsEditModalOpen(false)
    },
  })

  const rawBudgetLines = budgetQuery.data ?? []
  const accounts = accountsQuery.data ?? []

  // Expense & Revenue accounts from Chart of Accounts
  const budgetEligibleAccounts = useMemo(() => {
    return accounts.filter((a) => a.type === 'EXPENSE' || a.type === 'REVENUE')
  }, [accounts])

  // Merge budget data with account details
  const mergedLines = useMemo(() => {
    return rawBudgetLines.map((line) => {
      const acc = accounts.find((a) => a.id === line.accountId)
      const budgeted = Number(line.amount || 0)
      const actual = Number(line.actualAmount || 0)
      const variance = budgeted - actual
      const pct = budgeted > 0 ? (actual / budgeted) * 100 : 0
      return {
        ...line,
        accountCode: line.accountCode || acc?.code || 'â€”',
        accountName: line.accountName || acc?.name || 'Unknown Account',
        accountType: line.accountType || acc?.type || 'EXPENSE',
        budgeted,
        actual,
        variance,
        consumptionPct: pct,
      }
    })
  }, [rawBudgetLines, accounts])

  const filteredLines = useMemo(() => {
    return mergedLines.filter((line) => {
      if (accountTypeFilter !== 'ALL' && line.accountType !== accountTypeFilter) return false
      if (!searchTerm.trim()) return true
      const term = searchTerm.toLowerCase().trim()
      return (
        line.accountName.toLowerCase().includes(term) ||
        line.accountCode.toLowerCase().includes(term)
      )
    })
  }, [mergedLines, accountTypeFilter, searchTerm])

  // Summary Metrics
  const totalBudgeted = useMemo(() => {
    return mergedLines.reduce((sum, l) => sum + l.budgeted, 0)
  }, [mergedLines])

  const totalActual = useMemo(() => {
    return mergedLines.reduce((sum, l) => sum + l.actual, 0)
  }, [mergedLines])

  const netVariance = totalBudgeted - totalActual
  const overallConsumptionPct = totalBudgeted > 0 ? (totalActual / totalBudgeted) * 100 : 0

  const handleOpenEditModal = () => {
    const initialMap: Record<string, number> = {}
    budgetEligibleAccounts.forEach((acc) => {
      const existing = mergedLines.find((l) => l.accountId === acc.id)
      initialMap[acc.id] = existing ? existing.budgeted : 0
    })
    setDraftLines(initialMap)
    setIsEditModalOpen(true)
  }

  const handleSaveBudget = () => {
    const payload: BudgetLine[] = Object.entries(draftLines)
      .filter(([, amount]) => amount > 0)
      .map(([accountId, amount]) => {
        const acc = accounts.find((a) => a.id === accountId)
        return {
          accountId,
          accountCode: acc?.code,
          accountName: acc?.name,
          accountType: acc?.type,
          amount,
        }
      })
    saveMutation.mutate(payload)
  }

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Financial / Management Accounting"
        title="Budgets & Variance Analysis"
        description="Annual financial operating budgets, department limits, and real-time general ledger actuals comparison."
        actions={
          <div style={{ display: 'flex', gap: 'var(--space-sm)', alignItems: 'center' }}>
            <select
              className="select-field"
              onChange={(e) => setSelectedFy(Number(e.target.value))}
              style={{
                padding: '6px 12px',
                borderRadius: 'var(--radius-md)',
                border: '1px solid var(--color-border)',
                fontWeight: 600,
                background: 'var(--color-surface)',
              }}
              value={selectedFy}
            >
              {[currentYear - 1, currentYear, currentYear + 1, currentYear + 2].map((yr) => (
                <option key={yr} value={yr}>
                  FY {yr} - {yr + 1}
                </option>
              ))}
            </select>

            <Button onClick={handleOpenEditModal} variant="primary">
              <Edit3 aria-hidden="true" size={14} style={{ marginRight: 6 }} />
              Configure Budget
            </Button>
          </div>
        }
      />

      {/* KPI Summary Strip */}
      <div className="summary-strip">
        <div className="summary-card">
          <span className="summary-card__label">Total Budgeted Limit</span>
          <strong className="summary-card__value" style={{ color: 'var(--color-primary)' }}>
            <Money amount={totalBudgeted} />
          </strong>
          <span className="summary-card__hint">FY {selectedFy} approved ceiling</span>
        </div>

        <div className="summary-card">
          <span className="summary-card__label">Actual Spend / Incurred</span>
          <strong className="summary-card__value">
            <Money amount={totalActual} />
          </strong>
          <span className="summary-card__hint">Posted general ledger actuals</span>
        </div>

        <div className="summary-card">
          <span className="summary-card__label">Net Budget Variance</span>
          <strong
            className="summary-card__value"
            style={{ color: netVariance >= 0 ? 'var(--color-success)' : 'var(--color-error)' }}
          >
            <Money amount={Math.abs(netVariance)} />
            <span style={{ fontSize: '0.8rem', marginLeft: 4, fontWeight: 500 }}>
              {netVariance >= 0 ? '(Under)' : '(Overspend)'}
            </span>
          </strong>
          <span className="summary-card__hint">
            {netVariance >= 0 ? 'Within budget bounds' : 'Exceeded allocated budget'}
          </span>
        </div>

        <div className="summary-card summary-card--accent">
          <span className="summary-card__label">Budget Consumed</span>
          <strong
            className="summary-card__value"
            style={{
              color:
                overallConsumptionPct > 100
                  ? 'var(--color-error)'
                  : overallConsumptionPct > 80
                  ? 'var(--color-warning)'
                  : 'var(--color-success)',
            }}
          >
            {overallConsumptionPct.toFixed(1)}%
          </strong>
          <div
            style={{
              width: '100%',
              height: 6,
              background: 'var(--color-border)',
              borderRadius: 3,
              marginTop: 6,
              overflow: 'hidden',
            }}
          >
            <div
              style={{
                width: `${Math.min(100, overallConsumptionPct)}%`,
                height: '100%',
                background:
                  overallConsumptionPct > 100
                    ? 'var(--color-error)'
                    : overallConsumptionPct > 80
                    ? 'var(--color-warning)'
                    : 'var(--color-success)',
              }}
            />
          </div>
        </div>
      </div>

      {/* Toolbar & Filter Bar */}
      <div className="list-toolbar" style={{ justifyContent: 'space-between' }}>
        <div style={{ display: 'flex', gap: 'var(--space-sm)', alignItems: 'center' }}>
          <div className="search-field" style={{ width: 280 }}>
            <Search aria-hidden="true" size={16} />
            <input
              aria-label="Search budget accounts"
              onChange={(e) => setSearchTerm(e.target.value)}
              placeholder="Search account code or name..."
              type="text"
              value={searchTerm}
            />
          </div>

          <div className="filter-chips">
            {[
              { key: 'ALL', label: 'All Accounts' },
              { key: 'EXPENSE', label: 'Expenses' },
              { key: 'REVENUE', label: 'Revenue' },
            ].map((f) => (
              <button
                key={f.key}
                className={`filter-chip ${accountTypeFilter === f.key ? 'filter-chip--active' : ''}`}
                onClick={() => setAccountTypeFilter(f.key)}
                type="button"
              >
                {f.label}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Budget vs Actuals Matrix Table */}
      {filteredLines.length === 0 ? (
        <div className="directory-state" role="status">
          <Calendar aria-hidden="true" size={24} />
          <strong>No budget entries found for FY {selectedFy}.</strong>
          <p>Click "Configure Budget" to establish expense and revenue targets for this fiscal year.</p>
          <Button onClick={handleOpenEditModal} variant="primary">
            Configure Budget
          </Button>
        </div>
      ) : (
        <DataTable caption={`Budget vs Actuals for FY ${selectedFy}`}>
          <thead>
            <tr>
              <th scope="col">Account Code</th>
              <th scope="col">GL Account Name</th>
              <th scope="col">Type</th>
              <th className="numeric-cell" scope="col">Budget Limit</th>
              <th className="numeric-cell" scope="col">Actual Posted</th>
              <th className="numeric-cell" scope="col">Variance (Remaining)</th>
              <th scope="col" style={{ width: 180 }}>Consumption Progress</th>
              <th scope="col">Status</th>
            </tr>
          </thead>
          <tbody>
            {filteredLines.map((line) => {
              const isOver = line.actual > line.budgeted && line.budgeted > 0
              const isNearLimit = line.consumptionPct >= 80 && line.consumptionPct <= 100
              return (
                <tr key={line.accountId}>
                  <td>
                    <span className="table-code">{line.accountCode}</span>
                  </td>
                  <td>
                    <strong>{line.accountName}</strong>
                  </td>
                  <td>
                    <StatusChip status={line.accountType} />
                  </td>
                  <td className="numeric-cell">
                    <strong>
                      <Money amount={line.budgeted} />
                    </strong>
                  </td>
                  <td className="numeric-cell">
                    <Money amount={line.actual} />
                  </td>
                  <td className="numeric-cell">
                    <strong
                      style={{
                        color: isOver ? 'var(--color-error)' : 'var(--color-success)',
                      }}
                    >
                      <Money amount={Math.abs(line.variance)} />
                    </strong>
                    <span className="cell-muted" style={{ display: 'block', fontSize: '0.75rem' }}>
                      {isOver ? 'Deficit' : 'Available'}
                    </span>
                  </td>
                  <td>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                      <div
                        style={{
                          flex: 1,
                          height: 8,
                          background: 'var(--color-border)',
                          borderRadius: 4,
                          overflow: 'hidden',
                        }}
                      >
                        <div
                          style={{
                            width: `${Math.min(100, line.consumptionPct)}%`,
                            height: '100%',
                            background: isOver
                              ? 'var(--color-error)'
                              : isNearLimit
                              ? 'var(--color-warning)'
                              : 'var(--color-success)',
                          }}
                        />
                      </div>
                      <span
                        style={{
                          fontSize: '0.8rem',
                          fontWeight: 600,
                          minWidth: 42,
                          textAlign: 'right',
                          color: isOver ? 'var(--color-error)' : 'inherit',
                        }}
                      >
                        {line.consumptionPct.toFixed(0)}%
                      </span>
                    </div>
                  </td>
                  <td>
                    {isOver ? (
                      <span
                        style={{
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: 4,
                          fontSize: '0.75rem',
                          fontWeight: 600,
                          color: 'var(--color-error)',
                          background: 'rgba(239, 68, 68, 0.1)',
                          padding: '2px 8px',
                          borderRadius: 'var(--radius-full)',
                        }}
                      >
                        <TrendingDown size={12} /> Over Budget
                      </span>
                    ) : isNearLimit ? (
                      <span
                        style={{
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: 4,
                          fontSize: '0.75rem',
                          fontWeight: 600,
                          color: 'var(--color-warning)',
                          background: 'rgba(245, 158, 11, 0.1)',
                          padding: '2px 8px',
                          borderRadius: 'var(--radius-full)',
                        }}
                      >
                        <AlertCircle size={12} /> Near Limit
                      </span>
                    ) : (
                      <span
                        style={{
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: 4,
                          fontSize: '0.75rem',
                          fontWeight: 600,
                          color: 'var(--color-success)',
                          background: 'rgba(16, 185, 129, 0.1)',
                          padding: '2px 8px',
                          borderRadius: 'var(--radius-full)',
                        }}
                      >
                        <CheckCircle2 size={12} /> On Target
                      </span>
                    )}
                  </td>
                </tr>
              )
            })}
          </tbody>
        </DataTable>
      )}

      {/* MODAL: CONFIGURE BUDGET */}
      {isEditModalOpen && (
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
              maxWidth: 720,
              maxHeight: '90vh',
              display: 'flex',
              flexDirection: 'column',
              backgroundColor: 'var(--color-surface)',
              borderRadius: 'var(--radius-lg)',
              padding: 'var(--space-lg)',
              border: '1px solid var(--color-border)',
            }}
          >
            <div style={{ marginBottom: 'var(--space-md)' }}>
              <h3 style={{ fontSize: '1.2rem', fontWeight: 600 }}>
                Configure Operating Budget (FY {selectedFy})
              </h3>
              <p className="cell-muted" style={{ fontSize: '0.85rem' }}>
                Specify annual expenditure limits and revenue targets for General Ledger accounts.
              </p>
            </div>

            <div
              style={{
                flex: 1,
                overflowY: 'auto',
                border: '1px solid var(--color-border)',
                borderRadius: 'var(--radius-md)',
                padding: 'var(--space-sm)',
                marginBottom: 'var(--space-md)',
              }}
            >
              <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '0.9rem' }}>
                <thead>
                  <tr style={{ borderBottom: '1px solid var(--color-border)', textAlign: 'left' }}>
                    <th style={{ padding: '8px' }}>Code</th>
                    <th style={{ padding: '8px' }}>Account Name</th>
                    <th style={{ padding: '8px' }}>Type</th>
                    <th style={{ padding: '8px', textAlign: 'right', width: 200 }}>
                      Annual Budget (â‚¹)
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {budgetEligibleAccounts.map((acc) => (
                    <tr key={acc.id} style={{ borderBottom: '1px solid var(--color-border)' }}>
                      <td style={{ padding: '8px' }}>
                        <span className="table-code">{acc.code}</span>
                      </td>
                      <td style={{ padding: '8px' }}>
                        <strong>{acc.name}</strong>
                      </td>
                      <td style={{ padding: '8px' }}>
                        <StatusChip status={acc.type} />
                      </td>
                      <td style={{ padding: '8px', textAlign: 'right' }}>
                        <input
                          style={{
                            width: 160,
                            padding: '6px 8px',
                            textAlign: 'right',
                            borderRadius: 'var(--radius-sm)',
                            border: '1px solid var(--color-border)',
                            fontFamily: 'monospace',
                            fontWeight: 600,
                          }}
                          onChange={(e) =>
                            setDraftLines((prev) => ({
                              ...prev,
                              [acc.id]: Number(e.target.value) || 0,
                            }))
                          }
                          placeholder="0.00"
                          type="number"
                          value={draftLines[acc.id] || ''}
                        />
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
              <Button onClick={() => setIsEditModalOpen(false)} variant="secondary">
                Cancel
              </Button>
              <Button
                disabled={saveMutation.isPending}
                onClick={handleSaveBudget}
                variant="primary"
              >
                {saveMutation.isPending ? 'Saving Targets...' : 'Save Budget Targets'}
              </Button>
            </div>
          </div>
        </div>
      )}
    </section>
  )
}