import { useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  History,
  Lock,
  MinusCircle,
  PlusCircle,
  Receipt,
  Trash2,
  Unlock,
} from 'lucide-react'
import { Link } from 'react-router-dom'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import {
  addRegisterExpense,
  closeRegister,
  deleteRegisterExpense,
  getRegisterHistory,
  getTodayRegister,
  openRegister,
} from '@/features/pos/pos-api'

const DENOMINATIONS = [2000, 500, 200, 100, 50, 20, 10, 5, 2, 1]

export function CashRegisterPage() {
  const queryClient = useQueryClient()
  const todayStr = new Date().toISOString().split('T')[0] || ''

  // Date filters for history
  const [fromDate, setFromDate] = useState(() => {
    const d = new Date()
    d.setDate(d.getDate() - 14)
    return d.toISOString().split('T')[0] || ''
  })
  const [toDate, setToDate] = useState(todayStr)

  // Modals state
  const [isOpenModal, setIsOpenModal] = useState(false)
  const [openingFloat, setOpeningFloat] = useState('1000')
  const [openNotes, setOpenNotes] = useState('')

  const [isExpenseModal, setIsExpenseModal] = useState(false)
  const [expenseAmount, setExpenseAmount] = useState('')
  const [expenseDesc, setExpenseDesc] = useState('')

  const [isCloseModal, setIsCloseModal] = useState(false)
  const [denomCounts, setDenomCounts] = useState<Record<number, number>>({
    2000: 0,
    500: 0,
    200: 0,
    100: 0,
    50: 0,
    20: 0,
    10: 0,
    5: 0,
    2: 0,
    1: 0,
  })
  const [coinsAmount, setCoinsAmount] = useState('0')
  const [closeNotes, setCloseNotes] = useState('')
  const [feedback, setFeedback] = useState<{ type: 'success' | 'error'; message: string } | null>(null)

  // Queries
  const todayQuery = useQuery({
    queryKey: ['pos-today-register'],
    queryFn: () => getTodayRegister(),
  })

  const historyQuery = useQuery({
    queryKey: ['pos-register-history', fromDate, toDate],
    queryFn: () => getRegisterHistory(fromDate, toDate),
  })

  const register = todayQuery.data
  const historyList = historyQuery.data ?? []
  const isOpen = register?.status === 'OPEN'

  // Calculated count from denomination breakdown
  const calculatedCountTotal = useMemo(() => {
    let sum = 0
    for (const d of DENOMINATIONS) {
      sum += d * (denomCounts[d] || 0)
    }
    sum += Number(coinsAmount) || 0
    return sum
  }, [denomCounts, coinsAmount])

  // Mutations
  const openMutation = useMutation({
    mutationFn: () => openRegister(Number(openingFloat) || 0, openNotes.trim() || undefined),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['pos-today-register'] })
      queryClient.invalidateQueries({ queryKey: ['pos-register-history'] })
      setIsOpenModal(false)
      setFeedback({ type: 'success', message: 'Cash register shift opened successfully.' })
    },
    onError: (err: unknown) => {
      setFeedback({
        type: 'error',
        message: err instanceof Error ? err.message : 'Failed to open register.',
      })
    },
  })

  const expenseMutation = useMutation({
    mutationFn: () => addRegisterExpense(Number(expenseAmount) || 0, expenseDesc.trim()),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['pos-today-register'] })
      setIsExpenseModal(false)
      setExpenseAmount('')
      setExpenseDesc('')
      setFeedback({ type: 'success', message: 'Petty cash expense recorded in shift.' })
    },
    onError: (err: unknown) => {
      setFeedback({
        type: 'error',
        message: err instanceof Error ? err.message : 'Failed to record expense.',
      })
    },
  })

  const deleteExpenseMutation = useMutation({
    mutationFn: (id: string) => deleteRegisterExpense(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['pos-today-register'] })
      setFeedback({ type: 'success', message: 'Expense entry deleted.' })
    },
  })

  const closeMutation = useMutation({
    mutationFn: () => closeRegister(calculatedCountTotal, closeNotes.trim() || undefined),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['pos-today-register'] })
      queryClient.invalidateQueries({ queryKey: ['pos-register-history'] })
      setIsCloseModal(false)
      setFeedback({ type: 'success', message: 'Cash register shift closed and reconciled.' })
    },
    onError: (err: unknown) => {
      setFeedback({
        type: 'error',
        message: err instanceof Error ? err.message : 'Failed to close register.',
      })
    },
  })

  const handleDenomChange = (val: number, countStr: string) => {
    const cnt = Math.max(0, parseInt(countStr, 10) || 0)
    setDenomCounts((prev) => ({ ...prev, [val]: cnt }))
  }

  const expectedClosing = register?.expectedClosing ?? 0
  const countVariance = calculatedCountTotal - expectedClosing

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Point of Sale"
        title="Cash Register & Shift Reconciliation"
        description="Shift drawer status, opening cash float, mid-shift petty expenses, and end-of-day denomination balancing."
        actions={
          <div style={{ display: 'flex', gap: 'var(--space-sm)' }}>
            <Link className="btn btn--secondary" to="/pos">
              <Receipt aria-hidden="true" size={14} style={{ marginRight: 6 }} />
              Open POS Billing
            </Link>
            {!isOpen ? (
              <Button onClick={() => setIsOpenModal(true)} variant="primary">
                <Unlock aria-hidden="true" size={14} style={{ marginRight: 6 }} />
                Open Today's Register
              </Button>
            ) : (
              <>
                <Button onClick={() => setIsExpenseModal(true)} variant="secondary">
                  <MinusCircle aria-hidden="true" size={14} style={{ marginRight: 6 }} />
                  Record Cash Expense / Drop
                </Button>
                <Button onClick={() => setIsCloseModal(true)} variant="primary">
                  <Lock aria-hidden="true" size={14} style={{ marginRight: 6 }} />
                  Close Shift & Count Cash
                </Button>
              </>
            )}
          </div>
        }
      />

      {feedback && (
        <div
          className={`banner ${feedback.type === 'success' ? 'banner--success' : 'banner--error'}`}
          role="status"
          style={{ marginBottom: 'var(--space-md)' }}
        >
          <span>{feedback.message}</span>
          <button className="banner-dismiss" onClick={() => setFeedback(null)} type="button">
            ×
          </button>
        </div>
      )}

      {/* Shift Status Banner */}
      <div
        className="panel-card"
        style={{
          padding: 'var(--space-md) var(--space-lg)',
          marginBottom: 'var(--space-lg)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          flexWrap: 'wrap',
          gap: 'var(--space-md)',
          background: isOpen ? 'var(--color-surface)' : 'var(--color-surface-subtle)',
          borderLeft: isOpen ? '4px solid var(--color-success)' : '4px solid var(--color-muted)',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-md)' }}>
          <div
            style={{
              width: 44,
              height: 44,
              borderRadius: 'var(--radius-full)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              background: isOpen ? 'rgba(16, 185, 129, 0.12)' : 'rgba(107, 114, 128, 0.12)',
              color: isOpen ? 'var(--color-success)' : 'var(--color-text-muted)',
            }}
          >
            {isOpen ? <Unlock size={22} /> : <Lock size={22} />}
          </div>
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-sm)' }}>
              <h3 style={{ fontSize: '1.1rem', margin: 0 }}>
                {isOpen ? "Today's Shift is Active" : "Today's Shift is Closed"}
              </h3>
              <StatusChip status={isOpen ? 'OPEN' : 'CLOSED'} />
            </div>
            <p className="cell-muted" style={{ margin: '4px 0 0 0', fontSize: '0.85rem' }}>
              Date: <strong>{register?.date || todayStr}</strong> • Transactions:{' '}
              <strong>{register?.transactionCount ?? 0}</strong> completed
            </p>
          </div>
        </div>

        <div style={{ display: 'flex', gap: 'var(--space-lg)' }}>
          <div>
            <span className="cell-muted" style={{ fontSize: '0.8rem', display: 'block' }}>
              Opening Float
            </span>
            <strong style={{ fontSize: '1.1rem' }}>
              <Money amount={register?.openingBalance ?? 0} />
            </strong>
          </div>
          <div>
            <span className="cell-muted" style={{ fontSize: '0.8rem', display: 'block' }}>
              Cash Sales
            </span>
            <strong style={{ fontSize: '1.1rem' }}>
              <Money amount={register?.cashSales ?? 0} />
            </strong>
          </div>
          <div>
            <span className="cell-muted" style={{ fontSize: '0.8rem', display: 'block' }}>
              Expected in Drawer
            </span>
            <strong style={{ fontSize: '1.1rem', color: 'var(--color-primary)' }}>
              <Money amount={register?.expectedClosing ?? 0} />
            </strong>
          </div>
        </div>
      </div>

      {/* Summary Strip */}
      <div className="summary-strip">
        <div className="summary-card">
          <span className="summary-card__label">Cash Float</span>
          <strong className="summary-card__value">
            <Money amount={register?.openingBalance ?? 0} />
          </strong>
          <span className="summary-card__hint">Start of day balance</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__label">Cash Collected</span>
          <strong className="summary-card__value">
            <Money amount={register?.cashSales ?? 0} />
          </strong>
          <span className="summary-card__hint">Cash counter billing</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__label">Digital (UPI & Card)</span>
          <strong className="summary-card__value">
            <Money amount={(register?.upiSales ?? 0) + (register?.cardSales ?? 0)} />
          </strong>
          <span className="summary-card__hint">
            UPI: <Money amount={register?.upiSales ?? 0} /> • Card: <Money amount={register?.cardSales ?? 0} />
          </span>
        </div>
        <div className="summary-card">
          <span className="summary-card__label">Petty Cash Expenses</span>
          <strong className="summary-card__value" style={{ color: 'var(--color-danger)' }}>
            <Money amount={register?.totalExpenses ?? 0} />
          </strong>
          <span className="summary-card__hint">{register?.expenses?.length ?? 0} cash drops logged</span>
        </div>
        <div className="summary-card summary-card--accent">
          <span className="summary-card__label">Expected In-Drawer</span>
          <strong className="summary-card__value">
            <Money amount={register?.expectedClosing ?? 0} />
          </strong>
          <span className="summary-card__hint">Float + Cash Sales - Drops</span>
        </div>
      </div>

      {/* Mid-Shift Expenses Section */}
      <div className="panel-card" style={{ padding: 'var(--space-md)', marginBottom: 'var(--space-lg)' }}>
        <div
          style={{
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
            marginBottom: 'var(--space-sm)',
          }}
        >
          <div>
            <h3 style={{ fontSize: '1.05rem', margin: 0 }}>Mid-Shift Petty Cash Expenses & Cash Drops</h3>
            <p className="cell-muted" style={{ margin: '2px 0 0 0', fontSize: '0.85rem' }}>
              Cash removed from the drawer during shift for petty vendor bills, tea/snacks, or bank cash drops.
            </p>
          </div>
          {isOpen && (
            <Button onClick={() => setIsExpenseModal(true)} variant="secondary">
              <PlusCircle aria-hidden="true" size={14} style={{ marginRight: 6 }} />
              Add Expense
            </Button>
          )}
        </div>

        {todayQuery.isLoading ? (
          <div className="directory-state">Loading expenses...</div>
        ) : !register?.expenses || register.expenses.length === 0 ? (
          <div className="directory-state" style={{ padding: 'var(--space-md)' }}>
            <MinusCircle aria-hidden="true" size={20} />
            <p style={{ margin: '4px 0 0 0' }}>No petty cash expenses logged for this shift.</p>
          </div>
        ) : (
          <DataTable caption="Shift petty cash expenses list">
            <thead>
              <tr>
                <th scope="col">Time</th>
                <th scope="col">Description</th>
                <th className="numeric-cell" scope="col">Amount</th>
                {isOpen && <th className="numeric-cell" scope="col">Action</th>}
              </tr>
            </thead>
            <tbody>
              {register.expenses.map((exp) => (
                <tr key={exp.id}>
                  <td>
                    <span className="cell-muted">
                      {exp.expenseTime ? new Date(exp.expenseTime).toLocaleTimeString() : 'â€”'}
                    </span>
                  </td>
                  <td>
                    <strong>{exp.description}</strong>
                  </td>
                  <td className="numeric-cell">
                    <strong style={{ color: 'var(--color-danger)' }}>
                      <Money amount={exp.amount} />
                    </strong>
                  </td>
                  {isOpen && (
                    <td className="numeric-cell">
                      <Button
                        disabled={deleteExpenseMutation.isPending}
                        onClick={() => deleteExpenseMutation.mutate(exp.id)}
                        variant="ghost"
                      >
                        <Trash2 aria-hidden="true" size={14} />
                      </Button>
                    </td>
                  )}
                </tr>
              ))}
            </tbody>
          </DataTable>
        )}
      </div>

      {/* Historical Shifts Section */}
      <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
        <div
          style={{
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
            flexWrap: 'wrap',
            gap: 'var(--space-sm)',
            marginBottom: 'var(--space-md)',
          }}
        >
          <div>
            <h3 style={{ fontSize: '1.05rem', margin: 0 }}>Shift History & Reconciliation Logs</h3>
            <p className="cell-muted" style={{ margin: '2px 0 0 0', fontSize: '0.85rem' }}>
              Historical cash drawer sessions, physical counts, and overage/shortage records.
            </p>
          </div>

          <div style={{ display: 'flex', gap: 'var(--space-sm)', alignItems: 'center' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
              <span className="cell-muted" style={{ fontSize: '0.85rem' }}>From:</span>
              <input
                type="date"
                value={fromDate}
                onChange={(e) => setFromDate(e.target.value)}
                style={{ padding: '4px 8px', borderRadius: 'var(--radius-sm)', border: '1px solid var(--color-border)' }}
              />
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
              <span className="cell-muted" style={{ fontSize: '0.85rem' }}>To:</span>
              <input
                type="date"
                value={toDate}
                onChange={(e) => setToDate(e.target.value)}
                style={{ padding: '4px 8px', borderRadius: 'var(--radius-sm)', border: '1px solid var(--color-border)' }}
              />
            </div>
          </div>
        </div>

        {historyQuery.isLoading ? (
          <div className="directory-state">Loading shift history...</div>
        ) : historyList.length === 0 ? (
          <div className="directory-state">
            <History aria-hidden="true" size={24} />
            <strong>No shift records found in this range.</strong>
          </div>
        ) : (
          <DataTable caption="Shift history logs">
            <thead>
              <tr>
                <th scope="col">Date</th>
                <th scope="col">Status</th>
                <th className="numeric-cell" scope="col">Opening Float</th>
                <th className="numeric-cell" scope="col">Cash Sales</th>
                <th className="numeric-cell" scope="col">Digital Sales</th>
                <th className="numeric-cell" scope="col">Expenses</th>
                <th className="numeric-cell" scope="col">Expected Cash</th>
                <th className="numeric-cell" scope="col">Actual Count</th>
                <th className="numeric-cell" scope="col">Variance</th>
                <th scope="col">Txns</th>
              </tr>
            </thead>
            <tbody>
              {historyList.map((item) => {
                const variance = item.variance ?? 0
                return (
                  <tr key={item.id || item.date}>
                    <td>
                      <span className="table-code">{item.date}</span>
                    </td>
                    <td>
                      <StatusChip status={item.status} />
                    </td>
                    <td className="numeric-cell">
                      <Money amount={item.openingBalance} />
                    </td>
                    <td className="numeric-cell">
                      <Money amount={item.cashSales} />
                    </td>
                    <td className="numeric-cell">
                      <Money amount={item.upiSales + item.cardSales} />
                    </td>
                    <td className="numeric-cell">
                      <Money amount={item.totalExpenses} />
                    </td>
                    <td className="numeric-cell">
                      <strong>
                        <Money amount={item.expectedClosing} />
                      </strong>
                    </td>
                    <td className="numeric-cell">
                      {item.actualClosing !== null ? (
                        <strong>
                          <Money amount={item.actualClosing} />
                        </strong>
                      ) : (
                        <span className="cell-muted">â€”</span>
                      )}
                    </td>
                    <td className="numeric-cell">
                      {item.actualClosing !== null ? (
                        <span
                          style={{
                            fontWeight: 600,
                            color:
                              variance === 0
                                ? 'var(--color-success)'
                                : variance > 0
                                ? 'var(--color-primary)'
                                : 'var(--color-danger)',
                          }}
                        >
                          {variance > 0 ? '+' : ''}
                          <Money amount={variance} />
                        </span>
                      ) : (
                        <span className="cell-muted">â€”</span>
                      )}
                    </td>
                    <td>
                      <Quantity value={item.transactionCount} />
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </DataTable>
        )}
      </div>

      {/* Modal: Open Register */}
      {isOpenModal && (
        <div className="modal-backdrop" role="dialog" aria-modal="true">
          <div className="modal-card">
            <header className="modal-header">
              <h2>Open Today's Cash Register</h2>
              <button className="modal-close" onClick={() => setIsOpenModal(false)} type="button">
                ×
              </button>
            </header>
            <form
              onSubmit={(e) => {
                e.preventDefault()
                openMutation.mutate()
              }}
            >
              <div className="modal-body form-grid">
                <div className="form-field">
                  <label htmlFor="openFloatInput">Opening Cash Float (₹) *</label>
                  <input
                    id="openFloatInput"
                    type="number"
                    min="0"
                    step="1"
                    required
                    value={openingFloat}
                    onChange={(e) => setOpeningFloat(e.target.value)}
                    placeholder="1000"
                  />
                  <span className="form-hint">Physical cash placed into the drawer at the start of shift.</span>
                </div>
                <div className="form-field">
                  <label htmlFor="openNotesInput">Cashier Notes (Optional)</label>
                  <input
                    id="openNotesInput"
                    type="text"
                    value={openNotes}
                    onChange={(e) => setOpenNotes(e.target.value)}
                    placeholder="e.g. Counter 1 - Morning shift"
                  />
                </div>
              </div>
              <footer className="modal-footer">
                <Button onClick={() => setIsOpenModal(false)} type="button" variant="secondary">
                  Cancel
                </Button>
                <Button disabled={openMutation.isPending} type="submit" variant="primary">
                  {openMutation.isPending ? 'Opening...' : 'Confirm & Open Register'}
                </Button>
              </footer>
            </form>
          </div>
        </div>
      )}

      {/* Modal: Add Petty Expense */}
      {isExpenseModal && (
        <div className="modal-backdrop" role="dialog" aria-modal="true">
          <div className="modal-card">
            <header className="modal-header">
              <h2>Record Mid-Shift Cash Expense / Drop</h2>
              <button className="modal-close" onClick={() => setIsExpenseModal(false)} type="button">
                ×
              </button>
            </header>
            <form
              onSubmit={(e) => {
                e.preventDefault()
                expenseMutation.mutate()
              }}
            >
              <div className="modal-body form-grid">
                <div className="form-field">
                  <label htmlFor="expAmountInput">Expense Amount (₹) *</label>
                  <input
                    id="expAmountInput"
                    type="number"
                    min="1"
                    step="0.01"
                    required
                    value={expenseAmount}
                    onChange={(e) => setExpenseAmount(e.target.value)}
                    placeholder="50"
                  />
                </div>
                <div className="form-field">
                  <label htmlFor="expDescInput">Reason / Description *</label>
                  <input
                    id="expDescInput"
                    type="text"
                    required
                    value={expenseDesc}
                    onChange={(e) => setExpenseDesc(e.target.value)}
                    placeholder="e.g. Cleaning supplies, tea for staff, cash drop"
                  />
                </div>
              </div>
              <footer className="modal-footer">
                <Button onClick={() => setIsExpenseModal(false)} type="button" variant="secondary">
                  Cancel
                </Button>
                <Button disabled={expenseMutation.isPending} type="submit" variant="primary">
                  {expenseMutation.isPending ? 'Saving...' : 'Record Expense'}
                </Button>
              </footer>
            </form>
          </div>
        </div>
      )}

      {/* Modal: Close Shift & Denomination Balancing */}
      {isCloseModal && (
        <div className="modal-backdrop" role="dialog" aria-modal="true">
          <div className="modal-card modal-card--wide" style={{ maxWidth: 640 }}>
            <header className="modal-header">
              <h2>Shift Reconciliation & Physical Cash Count</h2>
              <button className="modal-close" onClick={() => setIsCloseModal(false)} type="button">
                ×
              </button>
            </header>
            <form
              onSubmit={(e) => {
                e.preventDefault()
                closeMutation.mutate()
              }}
            >
              <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-md)' }}>
                <div
                  style={{
                    display: 'grid',
                    gridTemplateColumns: 'repeat(3, 1fr)',
                    gap: 'var(--space-sm)',
                    padding: 'var(--space-md)',
                    background: 'var(--color-surface-subtle)',
                    borderRadius: 'var(--radius-md)',
                  }}
                >
                  <div>
                    <span className="cell-muted" style={{ fontSize: '0.8rem', display: 'block' }}>
                      Expected Drawer Cash
                    </span>
                    <strong style={{ fontSize: '1.15rem' }}>
                      <Money amount={expectedClosing} />
                    </strong>
                  </div>
                  <div>
                    <span className="cell-muted" style={{ fontSize: '0.8rem', display: 'block' }}>
                      Physical Cash Counted
                    </span>
                    <strong style={{ fontSize: '1.15rem', color: 'var(--color-primary)' }}>
                      <Money amount={calculatedCountTotal} />
                    </strong>
                  </div>
                  <div>
                    <span className="cell-muted" style={{ fontSize: '0.8rem', display: 'block' }}>
                      Cash Variance
                    </span>
                    <strong
                      style={{
                        fontSize: '1.15rem',
                        color:
                          countVariance === 0
                            ? 'var(--color-success)'
                            : countVariance > 0
                            ? 'var(--color-primary)'
                            : 'var(--color-danger)',
                      }}
                    >
                      {countVariance > 0 ? '+' : ''}
                      <Money amount={countVariance} />
                    </strong>
                  </div>
                </div>

                <div>
                  <h4 style={{ margin: '0 0 var(--space-xs) 0', fontSize: '0.9rem' }}>
                    Denomination Breakdown (₹ Currency Notes & Coins)
                  </h4>
                  <div
                    style={{
                      display: 'grid',
                      gridTemplateColumns: 'repeat(2, 1fr)',
                      gap: 'var(--space-xs) var(--space-md)',
                    }}
                  >
                    {DENOMINATIONS.map((val) => (
                      <div
                        key={val}
                        style={{
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'space-between',
                          gap: 'var(--space-sm)',
                        }}
                      >
                        <span style={{ width: 60, fontWeight: 600 }}>₹{val} ×</span>
                        <input
                          type="number"
                          min="0"
                          step="1"
                          style={{
                            width: 80,
                            padding: '4px 8px',
                            textAlign: 'right',
                            borderRadius: 'var(--radius-sm)',
                            border: '1px solid var(--color-border)',
                          }}
                          value={denomCounts[val] || ''}
                          onChange={(e) => handleDenomChange(val, e.target.value)}
                          placeholder="0"
                        />
                        <span style={{ width: 80, textAlign: 'right', fontSize: '0.85rem' }} className="cell-muted">
                          = ₹{(val * (denomCounts[val] || 0)).toLocaleString('en-IN')}
                        </span>
                      </div>
                    ))}
                    <div
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'space-between',
                        gap: 'var(--space-sm)',
                      }}
                    >
                      <span style={{ width: 60, fontWeight: 600 }}>Coins</span>
                      <input
                        type="number"
                        min="0"
                        step="1"
                        style={{
                          width: 80,
                          padding: '4px 8px',
                          textAlign: 'right',
                          borderRadius: 'var(--radius-sm)',
                          border: '1px solid var(--color-border)',
                        }}
                        value={coinsAmount}
                        onChange={(e) => setCoinsAmount(e.target.value)}
                        placeholder="0"
                      />
                      <span style={{ width: 80, textAlign: 'right', fontSize: '0.85rem' }} className="cell-muted">
                        = ₹{(Number(coinsAmount) || 0).toLocaleString('en-IN')}
                      </span>
                    </div>
                  </div>
                </div>

                <div className="form-field">
                  <label htmlFor="closeNotesInput">Shift Closing Remarks / Variance Reason</label>
                  <input
                    id="closeNotesInput"
                    type="text"
                    value={closeNotes}
                    onChange={(e) => setCloseNotes(e.target.value)}
                    placeholder="e.g. Exact match, or ₹5 shortage due to rounding"
                  />
                </div>
              </div>

              <footer className="modal-footer">
                <Button onClick={() => setIsCloseModal(false)} type="button" variant="secondary">
                  Cancel
                </Button>
                <Button disabled={closeMutation.isPending} type="submit" variant="primary">
                  {closeMutation.isPending ? 'Closing...' : 'Close Shift & Finalize'}
                </Button>
              </footer>
            </form>
          </div>
        </div>
      )}
    </section>
  )
}
