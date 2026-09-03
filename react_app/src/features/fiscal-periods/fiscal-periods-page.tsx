import { useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  AlertTriangle,
  CheckCircle,
  CheckCircle2,
  FileCheck,
  Lock,
  ShieldCheck,
  Unlock,
  XCircle,
} from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import {
  closePeriod,
  closePeriodGuarded,
  closeYear,
  getContinuousCloseChecklist,
  listPeriods,
  lockPeriod,
  reopenPeriod,
  reopenYear,
  type ContinuousCloseChecklist,
} from '@/features/fiscal-periods/fiscal-periods-api'

const monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
]

export function FiscalPeriodsPage() {
  const queryClient = useQueryClient()
  const currentYear = new Date().getFullYear()
  const [selectedYear, setSelectedYear] = useState<number>(currentYear)
  const [activeChecklistPeriod, setActiveChecklistPeriod] = useState<{
    year: number
    month: number
  } | null>(null)
  const [isYearCloseModalOpen, setIsYearCloseModalOpen] = useState(false)
  const [closingResult, setClosingResult] = useState<{
    journalEntryId: string
    closingAmount: number
  } | null>(null)

  // Queries
  const periodsQuery = useQuery({
    queryKey: ['fiscal-periods'],
    queryFn: listPeriods,
  })

  const checklistQuery = useQuery({
    queryKey: [
      'continuous-close-checklist',
      activeChecklistPeriod?.year,
      activeChecklistPeriod?.month,
    ],
    queryFn: () =>
      getContinuousCloseChecklist(
        activeChecklistPeriod!.year,
        activeChecklistPeriod!.month
      ),
    enabled: Boolean(activeChecklistPeriod),
  })

  // Mutations
  const closePeriodMutation = useMutation({
    mutationFn: ({ year, month, force }: { year: number; month: number; force?: boolean }) =>
      force ? closePeriodGuarded(year, month, true) : closePeriod(year, month),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['fiscal-periods'] })
      queryClient.invalidateQueries({ queryKey: ['continuous-close-checklist'] })
      setActiveChecklistPeriod(null)
    },
  })

  const reopenPeriodMutation = useMutation({
    mutationFn: ({ year, month }: { year: number; month: number }) =>
      reopenPeriod(year, month),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['fiscal-periods'] }),
  })

  const lockPeriodMutation = useMutation({
    mutationFn: ({ year, month }: { year: number; month: number }) =>
      lockPeriod(year, month),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['fiscal-periods'] }),
  })

  const closeYearMutation = useMutation({
    mutationFn: (year: number) => closeYear(year),
    onSuccess: (res) => {
      queryClient.invalidateQueries({ queryKey: ['fiscal-periods'] })
      setClosingResult(res)
    },
  })

  const reopenYearMutation = useMutation({
    mutationFn: (year: number) => reopenYear(year),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['fiscal-periods'] }),
  })

  const allPeriods = periodsQuery.data ?? []

  // Generate 12 months for selected year
  const yearPeriods = useMemo(() => {
    const months = []
    for (let m = 1; m <= 12; m++) {
      const existing = allPeriods.find(
        (p) => p.periodYear === selectedYear && p.periodMonth === m
      )
      months.push({
        month: m,
        monthName: monthNames[m - 1],
        year: selectedYear,
        status: existing?.status || 'OPEN',
        closedBy: existing?.closedBy,
        closedAt: existing?.closedAt,
        lockedBy: existing?.lockedBy,
        lockedAt: existing?.lockedAt,
        id: existing?.id,
      })
    }
    return months
  }, [allPeriods, selectedYear])

  // Summary Metrics
  const openCount = yearPeriods.filter((p) => p.status === 'OPEN').length
  const softClosedCount = yearPeriods.filter((p) => p.status === 'SOFT_CLOSED' || p.status === 'CLOSED').length
  const lockedCount = yearPeriods.filter((p) => p.status === 'LOCKED').length

  const checklist: ContinuousCloseChecklist | undefined = checklistQuery.data

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Financial Governance & Auditing"
        title="Fiscal Periods & Financial Close"
        description="Accounting period boundaries, continuous close checklist, soft closures, audit locks, and statutory year-end retained earnings rollup."
        actions={
          <div style={{ display: 'flex', gap: 'var(--space-sm)', alignItems: 'center' }}>
            <select
              className="select-field"
              onChange={(e) => setSelectedYear(Number(e.target.value))}
              style={{
                padding: '6px 12px',
                borderRadius: 'var(--radius-md)',
                border: '1px solid var(--color-border)',
                fontWeight: 600,
                background: 'var(--color-surface)',
              }}
              value={selectedYear}
            >
              {[currentYear - 2, currentYear - 1, currentYear, currentYear + 1].map((yr) => (
                <option key={yr} value={yr}>
                  Calendar Year {yr}
                </option>
              ))}
            </select>

            <Button onClick={() => setIsYearCloseModalOpen(true)} variant="secondary">
              <FileCheck aria-hidden="true" size={14} style={{ marginRight: 6 }} />
              Year-End Close Console
            </Button>
          </div>
        }
      />

      {/* KPI Summary Strip */}
      <div className="summary-strip">
        <div className="summary-card">
          <span className="summary-card__label">Open Accounting Periods</span>
          <strong className="summary-card__value" style={{ color: 'var(--color-primary)' }}>
            <Quantity value={openCount} /> Months
          </strong>
          <span className="summary-card__hint">Open for voucher postings</span>
        </div>

        <div className="summary-card">
          <span className="summary-card__label">Closed Periods</span>
          <strong className="summary-card__value" style={{ color: 'var(--color-warning)' }}>
            <Quantity value={softClosedCount} /> Months
          </strong>
          <span className="summary-card__hint">Soft closed for final audit</span>
        </div>

        <div className="summary-card summary-card--accent">
          <span className="summary-card__label">Immutable Locked Periods</span>
          <strong className="summary-card__value" style={{ color: 'var(--color-success)' }}>
            <Quantity value={lockedCount} /> Months
          </strong>
          <span className="summary-card__hint">Hard locked against edits</span>
        </div>
      </div>

      {/* Monthly Periods Grid */}
      <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
        <div
          style={{
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
            marginBottom: 'var(--space-md)',
          }}
        >
          <h3 style={{ fontSize: '1.05rem', fontWeight: 600 }}>
            Period Lifecycle Matrix ({selectedYear})
          </h3>
          <span className="cell-muted" style={{ fontSize: '0.85rem' }}>
            All dates and postings in closed periods require explicit reopening overrides.
          </span>
        </div>

        <DataTable caption={`Fiscal Periods Matrix for ${selectedYear}`}>
          <thead>
            <tr>
              <th scope="col">Period</th>
              <th scope="col">Calendar Month</th>
              <th scope="col">Status</th>
              <th scope="col">Closing Metadata</th>
              <th className="numeric-cell" scope="col">Actions</th>
            </tr>
          </thead>
          <tbody>
            {yearPeriods.map((period) => {
              const isOpen = period.status === 'OPEN'
              const isClosed = period.status === 'SOFT_CLOSED' || period.status === 'CLOSED'
              const isLocked = period.status === 'LOCKED'

              return (
                <tr key={period.month}>
                  <td>
                    <span className="table-code">
                      {selectedYear}-{String(period.month).padStart(2, '0')}
                    </span>
                  </td>
                  <td>
                    <strong>{period.monthName} {selectedYear}</strong>
                  </td>
                  <td>
                    <StatusChip status={period.status} />
                  </td>
                  <td>
                    {isLocked ? (
                      <span className="cell-muted" style={{ fontSize: '0.8rem' }}>
                        Locked at {period.lockedAt ? new Date(period.lockedAt).toLocaleDateString() : 'Audited'}
                      </span>
                    ) : isClosed ? (
                      <span className="cell-muted" style={{ fontSize: '0.8rem' }}>
                        Closed at {period.closedAt ? new Date(period.closedAt).toLocaleDateString() : 'Recent'}
                      </span>
                    ) : (
                      <span className="cell-muted" style={{ fontSize: '0.8rem' }}>
                        Active for journal postings
                      </span>
                    )}
                  </td>
                  <td className="numeric-cell">
                    <div style={{ display: 'flex', gap: 6, justifyContent: 'flex-end' }}>
                      {isOpen && (
                        <Button
                          onClick={() =>
                            setActiveChecklistPeriod({ year: selectedYear, month: period.month })
                          }
                          variant="secondary"
                        >
                          <CheckCircle aria-hidden="true" size={13} style={{ marginRight: 4 }} />
                          Checklist & Close
                        </Button>
                      )}

                      {isClosed && (
                        <>
                          <Button
                            onClick={() =>
                              lockPeriodMutation.mutate({ year: selectedYear, month: period.month })
                            }
                            variant="primary"
                          >
                            <Lock aria-hidden="true" size={13} style={{ marginRight: 4 }} />
                            Hard Lock
                          </Button>
                          <Button
                            onClick={() =>
                              reopenPeriodMutation.mutate({ year: selectedYear, month: period.month })
                            }
                            variant="ghost"
                          >
                            <Unlock aria-hidden="true" size={13} style={{ marginRight: 4 }} />
                            Reopen
                          </Button>
                        </>
                      )}

                      {isLocked && (
                        <span
                          style={{
                            display: 'inline-flex',
                            alignItems: 'center',
                            gap: 4,
                            fontSize: '0.8rem',
                            fontWeight: 600,
                            color: 'var(--color-text-secondary)',
                          }}
                        >
                          <Lock size={12} /> Audit Locked
                        </span>
                      )}
                    </div>
                  </td>
                </tr>
              )
            })}
          </tbody>
        </DataTable>
      </div>

      {/* DRAWER / MODAL: CONTINUOUS CLOSE CHECKLIST */}
      {activeChecklistPeriod && (
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
              maxWidth: 600,
              backgroundColor: 'var(--color-surface)',
              borderRadius: 'var(--radius-lg)',
              padding: 'var(--space-lg)',
              border: '1px solid var(--color-border)',
            }}
          >
            <div style={{ marginBottom: 'var(--space-md)' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <ShieldCheck size={22} color="var(--color-primary)" />
                <h3 style={{ fontSize: '1.2rem', fontWeight: 600 }}>
                  Continuous Close Audit Checklist
                </h3>
              </div>
              <p className="cell-muted" style={{ fontSize: '0.85rem', marginTop: 4 }}>
                Period: {monthNames[activeChecklistPeriod.month - 1]} {activeChecklistPeriod.year}
              </p>
            </div>

            {checklistQuery.isLoading ? (
              <div className="directory-state">Running ledger integrity validations...</div>
            ) : checklist ? (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-sm)', marginBottom: 'var(--space-lg)' }}>
                {checklist.checks.map((c, i) => (
                  <div
                    key={i}
                    style={{
                      display: 'flex',
                      alignItems: 'flex-start',
                      gap: 12,
                      padding: '10px 12px',
                      borderRadius: 'var(--radius-md)',
                      background: c.passed ? 'rgba(16, 185, 129, 0.06)' : 'rgba(239, 68, 68, 0.06)',
                      border: `1px solid ${c.passed ? 'rgba(16, 185, 129, 0.2)' : 'rgba(239, 68, 68, 0.2)'}`,
                    }}
                  >
                    {c.passed ? (
                      <CheckCircle2 size={18} color="var(--color-success)" style={{ marginTop: 2 }} />
                    ) : (
                      <XCircle size={18} color="var(--color-error)" style={{ marginTop: 2 }} />
                    )}
                    <div style={{ flex: 1 }}>
                      <strong style={{ fontSize: '0.9rem', display: 'block' }}>{c.name}</strong>
                      <span className="cell-muted" style={{ fontSize: '0.8rem' }}>
                        {c.description}
                      </span>
                      {c.unresolvedCount !== undefined && c.unresolvedCount > 0 && (
                        <span
                          style={{
                            display: 'block',
                            fontSize: '0.75rem',
                            fontWeight: 600,
                            color: 'var(--color-error)',
                            marginTop: 2,
                          }}
                        >
                          {c.unresolvedCount} unresolved items requiring action
                        </span>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <div className="directory-state">Unable to load integrity checklist.</div>
            )}

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
              <Button onClick={() => setActiveChecklistPeriod(null)} variant="secondary">
                Cancel
              </Button>

              {checklist && !checklist.canClose && (
                <Button
                  disabled={closePeriodMutation.isPending}
                  onClick={() =>
                    closePeriodMutation.mutate({
                      year: activeChecklistPeriod.year,
                      month: activeChecklistPeriod.month,
                      force: true,
                    })
                  }
                  variant="destructive"
                >
                  <AlertTriangle aria-hidden="true" size={14} style={{ marginRight: 4 }} />
                  Force Close Period
                </Button>
              )}

              {checklist && checklist.canClose && (
                <Button
                  disabled={closePeriodMutation.isPending}
                  onClick={() =>
                    closePeriodMutation.mutate({
                      year: activeChecklistPeriod.year,
                      month: activeChecklistPeriod.month,
                      force: false,
                    })
                  }
                  variant="primary"
                >
                  <CheckCircle aria-hidden="true" size={14} style={{ marginRight: 4 }} />
                  Confirm & Close Period
                </Button>
              )}
            </div>
          </div>
        </div>
      )}

      {/* MODAL: YEAR END CLOSE CONSOLE */}
      {isYearCloseModalOpen && (
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
              maxWidth: 540,
              backgroundColor: 'var(--color-surface)',
              borderRadius: 'var(--radius-lg)',
              padding: 'var(--space-lg)',
              border: '1px solid var(--color-border)',
            }}
          >
            <div style={{ marginBottom: 'var(--space-md)' }}>
              <h3 style={{ fontSize: '1.2rem', fontWeight: 600 }}>
                Year-End Financial Close Console
              </h3>
              <p className="cell-muted" style={{ fontSize: '0.85rem' }}>
                Rolls all nominal income and expense balances into Retained Earnings for FY {selectedYear}.
              </p>
            </div>

            {closingResult ? (
              <div
                style={{
                  padding: 'var(--space-md)',
                  background: 'rgba(16, 185, 129, 0.08)',
                  borderRadius: 'var(--radius-md)',
                  border: '1px solid rgba(16, 185, 129, 0.2)',
                  marginBottom: 'var(--space-md)',
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 6 }}>
                  <CheckCircle2 size={18} color="var(--color-success)" />
                  <strong style={{ color: 'var(--color-success)' }}>
                    Year-End Close Completed Successfully
                  </strong>
                </div>
                <div style={{ fontSize: '0.85rem' }}>
                  <p>
                    Closing Journal Voucher ID: <code>{closingResult.journalEntryId}</code>
                  </p>
                  <p style={{ marginTop: 4 }}>
                    Net Retained Earnings Transferred:{' '}
                    <strong>
                      <Money amount={closingResult.closingAmount} />
                    </strong>
                  </p>
                </div>
              </div>
            ) : (
              <div
                style={{
                  padding: 'var(--space-md)',
                  background: 'var(--color-bg-subtle)',
                  borderRadius: 'var(--radius-md)',
                  marginBottom: 'var(--space-md)',
                  fontSize: '0.85rem',
                }}
              >
                <p>
                  Executing year-end closure will:
                </p>
                <ul style={{ paddingLeft: 20, marginTop: 6 }}>
                  <li>Lock all 12 fiscal periods in FY {selectedYear}.</li>
                  <li>Generate an automated Closing Journal Entry debiting revenue and crediting expenses.</li>
                  <li>Transfer the net profit or loss directly to the Retained Earnings balance sheet equity account.</li>
                </ul>
              </div>
            )}

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
              <Button
                onClick={() => {
                  setIsYearCloseModalOpen(false)
                  setClosingResult(null)
                }}
                variant="secondary"
              >
                Close
              </Button>

              {!closingResult && (
                <>
                  <Button
                    onClick={() => reopenYearMutation.mutate(selectedYear)}
                    variant="ghost"
                  >
                    Reopen Year
                  </Button>
                  <Button
                    disabled={closeYearMutation.isPending}
                    onClick={() => closeYearMutation.mutate(selectedYear)}
                    variant="primary"
                  >
                    {closeYearMutation.isPending ? 'Closing Year...' : 'Execute Year-End Close'}
                  </Button>
                </>
              )}
            </div>
          </div>
        </div>
      )}
    </section>
  )
}