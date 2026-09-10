import { useMemo, useState } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { Calendar } from 'lucide-react'
import {
  Button,
  DataTable,
  DirectoryToolbar,
  EmptyState,
  Fact,
  FactList,
  FilterTabs,
  Modal,
  PageHeader,
  SearchInput,
  StatusChip,
} from '@/design-system'
import {
  closePeriod,
  closeYear,
  listPeriods,
  lockPeriod,
  reopenPeriod,
  reopenYear,
  type FiscalPeriod,
} from '@/features/fiscal-periods/fiscal-periods-api'

const MONTH_NAMES = [
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

function getMonthName(month: number): string {
  if (month >= 1 && month <= 12) {
    return MONTH_NAMES[month - 1]!
  }
  return `Month ${month}`
}

function getQuarter(month: number): string {
  if (month >= 1 && month <= 3) return 'Q4 (Jan - Mar)'
  if (month >= 4 && month <= 6) return 'Q1 (Apr - Jun)'
  if (month >= 7 && month <= 9) return 'Q2 (Jul - Sep)'
  return 'Q3 (Oct - Dec)'
}

function formatDate(isoString?: string | null): string {
  if (!isoString) return '--'
  try {
    const d = new Date(isoString)
    return d.toLocaleDateString('en-IN', {
      day: 'numeric',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    })
  } catch {
    return isoString
  }
}

type PeriodActionType = 'close' | 'reopen' | 'lock' | 'year-close' | 'year-reopen'

interface ConfirmActionState {
  type: PeriodActionType
  period?: FiscalPeriod
  year?: number
}

export function FiscalPeriodsPage() {
  const queryClient = useQueryClient()
  const currentYear = new Date().getFullYear()
  const [selectedYear, setSelectedYear] = useState<number>(currentYear)
  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState<'ALL' | 'OPEN' | 'CLOSED' | 'LOCKED'>('ALL')
  const [selectedPeriod, setSelectedPeriod] = useState<FiscalPeriod | null>(null)
  const [confirmAction, setConfirmAction] = useState<ConfirmActionState | null>(null)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [actionError, setActionError] = useState<string | null>(null)
  const [actionSuccess, setActionSuccess] = useState<string | null>(null)

  const periodsQuery = useQuery({
    queryKey: ['fiscal-periods'],
    queryFn: listPeriods,
  })

  const periods = periodsQuery.data ?? []

  // Extract distinct financial years present in data
  const availableYears = useMemo(() => {
    const set = new Set<number>()
    periods.forEach((p) => set.add(p.periodYear))
    if (!set.has(currentYear)) set.add(currentYear)
    return Array.from(set).sort((a, b) => b - a)
  }, [periods, currentYear])

  // If selectedYear is not in availableYears, pick first
  const activeYear = availableYears.includes(selectedYear)
    ? selectedYear
    : availableYears[0] ?? currentYear

  // Filter by year
  const yearPeriods = useMemo(
    () => periods.filter((p) => p.periodYear === activeYear),
    [periods, activeYear]
  )

  // Metrics for active year
  const openCount = useMemo(
    () => yearPeriods.filter((p) => (p.status ?? '').toUpperCase() === 'OPEN').length,
    [yearPeriods]
  )

  const closedCount = useMemo(
    () =>
      yearPeriods.filter((p) => {
        const s = (p.status ?? '').toUpperCase()
        return s === 'CLOSED' || s === 'SOFT_CLOSED'
      }).length,
    [yearPeriods]
  )

  const lockedCount = useMemo(
    () => yearPeriods.filter((p) => (p.status ?? '').toUpperCase() === 'LOCKED').length,
    [yearPeriods]
  )

  // Table filtering by status and search
  const filteredPeriods = useMemo(() => {
    const query = search.trim().toLowerCase()
    return yearPeriods.filter((p) => {
      const s = (p.status ?? '').toUpperCase()
      const matchesStatus =
        statusFilter === 'ALL' ||
        (statusFilter === 'OPEN' && s === 'OPEN') ||
        (statusFilter === 'CLOSED' && (s === 'CLOSED' || s === 'SOFT_CLOSED')) ||
        (statusFilter === 'LOCKED' && s === 'LOCKED')

      if (!matchesStatus) return false

      if (!query) return true

      const mName = getMonthName(p.periodMonth).toLowerCase()
      const quarter = getQuarter(p.periodMonth).toLowerCase()
      const statusText = s.toLowerCase()

      return (
        mName.includes(query) ||
        quarter.includes(query) ||
        statusText.includes(query) ||
        String(p.periodMonth).includes(query)
      )
    })
  }, [yearPeriods, statusFilter, search])

  async function handleExecuteAction() {
    if (!confirmAction) return
    setIsSubmitting(true)
    setActionError(null)
    setActionSuccess(null)
    try {
      if (confirmAction.type === 'close' && confirmAction.period) {
        await closePeriod(confirmAction.period.periodYear, confirmAction.period.periodMonth)
        setActionSuccess(
          `Period ${confirmAction.period.periodMonth} (${getMonthName(
            confirmAction.period.periodMonth
          )} ${confirmAction.period.periodYear}) has been closed.`
        )
      } else if (confirmAction.type === 'reopen' && confirmAction.period) {
        await reopenPeriod(confirmAction.period.periodYear, confirmAction.period.periodMonth)
        setActionSuccess(
          `Period ${confirmAction.period.periodMonth} (${getMonthName(
            confirmAction.period.periodMonth
          )} ${confirmAction.period.periodYear}) has been reopened.`
        )
      } else if (confirmAction.type === 'lock' && confirmAction.period) {
        await lockPeriod(confirmAction.period.periodYear, confirmAction.period.periodMonth)
        setActionSuccess(
          `Period ${confirmAction.period.periodMonth} (${getMonthName(
            confirmAction.period.periodMonth
          )} ${confirmAction.period.periodYear}) has been locked.`
        )
      } else if (confirmAction.type === 'year-close') {
        await closeYear(activeYear)
        setActionSuccess(`Financial Year ${activeYear} has been closed and closing entries posted.`)
      } else if (confirmAction.type === 'year-reopen') {
        const res = await reopenYear(activeYear)
        setActionSuccess(
          `Financial Year ${activeYear} has been reopened${
            res?.reversalEntryNumber ? ` (Reversal Entry: ${res.reversalEntryNumber})` : ''
          }.`
        )
      }
      await queryClient.invalidateQueries({ queryKey: ['fiscal-periods'] })
      setConfirmAction(null)
    } catch (err: unknown) {
      const errorMsg =
        err instanceof Error
          ? err.message
          : typeof err === 'object' && err !== null && 'message' in err
          ? String((err as { message: unknown }).message)
          : 'The action could not be completed. Please try again.'
      setActionError(errorMsg)
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Accounting Governance / Governance"
        title="Fiscal periods & financial years"
        description="Review accounting periods, period closure governance (OPEN, LOCKED, CLOSED), and financial year boundaries."
        actions={
          <div className="button-group" style={{ display: 'flex', gap: '8px' }}>
            <Button
              variant="secondary"
              onClick={() => {
                setActionError(null)
                setActionSuccess(null)
                setConfirmAction({ type: 'year-close', year: activeYear })
              }}
            >
              Year-End Close (FY {activeYear})
            </Button>
            <Button
              variant="ghost"
              onClick={() => {
                setActionError(null)
                setActionSuccess(null)
                setConfirmAction({ type: 'year-reopen', year: activeYear })
              }}
            >
              Reopen FY {activeYear}
            </Button>
          </div>
        }
      />

      {actionError && (
        <div className="directory-state directory-state--error" role="alert">
          <strong>Action failed.</strong>
          <p>{actionError}</p>
        </div>
      )}

      {actionSuccess && (
        <div
          className="directory-state"
          role="status"
          style={{ color: 'var(--color-primary)', fontWeight: 500 }}
        >
          {actionSuccess}
        </div>
      )}

      <section aria-label="Fiscal year selector" className="list-panel">
        <DirectoryToolbar ariaLabel="Select financial year">
          <span className="list-toolbar-note">Financial year</span>
          <FilterTabs
            activeValue={String(activeYear)}
            ariaLabel="Select financial year"
            items={availableYears.map((yr) => ({
              value: String(yr),
              label: `FY ${yr}`,
              count: periods.filter((p) => p.periodYear === yr).length,
            }))}
            onChange={(val) => setSelectedYear(Number(val))}
          />
        </DirectoryToolbar>
      </section>

      {/* Year Summary KPI Cards */}
      <section
        aria-label="Fiscal period governance summary"
        className="document-facts form-grid--4col"
      >
        <div className="summary-stat-card">
          <dt>Financial year</dt>
          <dd>
            <strong>FY {activeYear}</strong>
          </dd>
        </div>
        <div className="summary-stat-card">
          <dt>Open periods</dt>
          <dd>
            <strong className="text-pos">{openCount}</strong>
          </dd>
        </div>
        <div className="summary-stat-card">
          <dt>Closed periods</dt>
          <dd>
            <strong>{closedCount}</strong>
          </dd>
        </div>
        <div className="summary-stat-card">
          <dt>Locked periods</dt>
          <dd>
            <strong className="text-warn">{lockedCount}</strong>
          </dd>
        </div>
      </section>

      {/* Periods Table Panel */}
      <section aria-label="Fiscal periods timeline" className="list-panel">
        <DirectoryToolbar ariaLabel="Filter fiscal periods by status and search">
          <SearchInput
            onChange={setSearch}
            onClear={() => setSearch('')}
            placeholder="Search period month or quarter..."
            value={search}
          />
          <FilterTabs
            activeValue={statusFilter}
            ariaLabel="Filter period status"
            items={[
              { value: 'ALL', label: 'All periods', count: yearPeriods.length },
              { value: 'OPEN', label: 'Open', count: openCount },
              { value: 'CLOSED', label: 'Closed', count: closedCount },
              { value: 'LOCKED', label: 'Locked', count: lockedCount },
            ]}
            onChange={(val) =>
              setStatusFilter(val as 'ALL' | 'OPEN' | 'CLOSED' | 'LOCKED')
            }
          />
        </DirectoryToolbar>

        {periodsQuery.isError ? (
          <div className="directory-state directory-state--error" role="alert">
            <strong>Fiscal periods could not be loaded.</strong>
            <p>Check your connection and permissions, then refresh the page.</p>
          </div>
        ) : periodsQuery.isLoading ? (
          <div aria-live="polite" className="directory-state">
            Loading fiscal periods...
          </div>
        ) : filteredPeriods.length ? (
          <DataTable caption={`Fiscal periods for FY ${activeYear}`}>
            <thead>
              <tr>
                <th scope="col">Period / Month</th>
                <th scope="col">Quarter</th>
                <th scope="col">Period number</th>
                <th scope="col">Status</th>
                <th scope="col">Closed at</th>
                <th scope="col">Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredPeriods.map((period) => {
                const s = (period.status ?? '').toUpperCase()
                return (
                  <tr key={period.id || `${period.periodYear}-${period.periodMonth}`}>
                    <td>
                      <div className="cell-stack">
                        <strong>
                          {getMonthName(period.periodMonth)} {period.periodYear}
                        </strong>
                        <small className="table-secondary-text">
                          Month {String(period.periodMonth).padStart(2, '0')}
                        </small>
                      </div>
                    </td>
                    <td>
                      <span className="text-secondary font-medium">
                        {getQuarter(period.periodMonth)}
                      </span>
                    </td>
                    <td>
                      <span className="font-mono">
                        Period {period.periodMonth}
                      </span>
                    </td>
                    <td>
                      <StatusChip status={period.status} />
                    </td>
                    <td>
                      <span className="table-secondary-text">
                        {formatDate(period.closedAt)}
                      </span>
                    </td>
                    <td>
                      <div style={{ display: 'flex', gap: '6px', alignItems: 'center' }}>
                        <Button
                          onClick={() => setSelectedPeriod(period)}
                          variant="ghost"
                        >
                          Details
                        </Button>
                        {s === 'OPEN' && (
                          <Button
                            onClick={() => {
                              setActionError(null)
                              setActionSuccess(null)
                              setConfirmAction({ type: 'close', period })
                            }}
                            variant="secondary"
                          >
                            Close Period
                          </Button>
                        )}
                        {(s === 'CLOSED' || s === 'SOFT_CLOSED') && (
                          <>
                            <Button
                              onClick={() => {
                                setActionError(null)
                                setActionSuccess(null)
                                setConfirmAction({ type: 'reopen', period })
                              }}
                              variant="secondary"
                            >
                              Reopen
                            </Button>
                            <Button
                              onClick={() => {
                                setActionError(null)
                                setActionSuccess(null)
                                setConfirmAction({ type: 'lock', period })
                              }}
                              variant="secondary"
                            >
                              Lock
                            </Button>
                          </>
                        )}
                        {s === 'LOCKED' && (
                          <Button
                            onClick={() => {
                              setActionError(null)
                              setActionSuccess(null)
                              setConfirmAction({ type: 'reopen', period })
                            }}
                            variant="secondary"
                          >
                            Reopen
                          </Button>
                        )}
                      </div>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </DataTable>
        ) : (
          <EmptyState
            description="No fiscal periods match the active filter criteria for this financial year."
            icon={Calendar}
            title="No periods found"
          />
        )}
      </section>

      {/* Period Details Modal */}
      {selectedPeriod && (
        <Modal
          description="Governance properties and closure audit history for this period."
          footer={
            <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end', width: '100%' }}>
              {selectedPeriod.status === 'OPEN' && (
                <Button
                  onClick={() => {
                    const p = selectedPeriod
                    setSelectedPeriod(null)
                    setActionError(null)
                    setActionSuccess(null)
                    setConfirmAction({ type: 'close', period: p })
                  }}
                  variant="secondary"
                >
                  Close Period
                </Button>
              )}
              {(selectedPeriod.status === 'CLOSED' || selectedPeriod.status === 'SOFT_CLOSED') && (
                <>
                  <Button
                    onClick={() => {
                      const p = selectedPeriod
                      setSelectedPeriod(null)
                      setActionError(null)
                      setActionSuccess(null)
                      setConfirmAction({ type: 'reopen', period: p })
                    }}
                    variant="secondary"
                  >
                    Reopen Period
                  </Button>
                  <Button
                    onClick={() => {
                      const p = selectedPeriod
                      setSelectedPeriod(null)
                      setActionError(null)
                      setActionSuccess(null)
                      setConfirmAction({ type: 'lock', period: p })
                    }}
                    variant="secondary"
                  >
                    Lock Period
                  </Button>
                </>
              )}
              {selectedPeriod.status === 'LOCKED' && (
                <Button
                  onClick={() => {
                    const p = selectedPeriod
                    setSelectedPeriod(null)
                    setActionError(null)
                    setActionSuccess(null)
                    setConfirmAction({ type: 'reopen', period: p })
                  }}
                  variant="secondary"
                >
                  Reopen / Unlock Period
                </Button>
              )}
              <Button
                onClick={() => setSelectedPeriod(null)}
                variant="ghost"
              >
                Close
              </Button>
            </div>
          }
          isOpen={Boolean(selectedPeriod)}
          onClose={() => setSelectedPeriod(null)}
          size="md"
          title={`${getMonthName(selectedPeriod.periodMonth)} ${selectedPeriod.periodYear} (Period ${selectedPeriod.periodMonth})`}
        >
          <FactList columns={2}>
            <Fact
              label="Financial year"
              value={`FY ${selectedPeriod.periodYear}`}
            />
            <Fact
              label="Calendar month"
              value={`${getMonthName(selectedPeriod.periodMonth)} (M${selectedPeriod.periodMonth})`}
            />
            <Fact
              label="Accounting quarter"
              value={getQuarter(selectedPeriod.periodMonth)}
            />
            <Fact
              label="Governance status"
              value={<StatusChip status={selectedPeriod.status} />}
            />
            <Fact
              label="Closed at"
              value={formatDate(selectedPeriod.closedAt)}
            />
            <Fact
              label="Closed by"
              mono
              value={selectedPeriod.closedBy ?? '--'}
            />
            <Fact
              label="Created at"
              value={formatDate(selectedPeriod.createdAt)}
            />
            <Fact
              label="Last updated"
              value={formatDate(selectedPeriod.updatedAt)}
            />
          </FactList>
        </Modal>
      )}

      {/* Action Confirmation Modal */}
      {confirmAction && (
        <Modal
          description="Confirm accounting governance action"
          footer={
            <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end', width: '100%' }}>
              <Button
                disabled={isSubmitting}
                onClick={() => setConfirmAction(null)}
                variant="ghost"
              >
                Cancel
              </Button>
              <Button
                loading={isSubmitting}
                onClick={handleExecuteAction}
                variant={confirmAction.type === 'lock' ? 'destructive' : 'primary'}
              >
                {confirmAction.type === 'close' && 'Confirm Close'}
                {confirmAction.type === 'reopen' && 'Confirm Reopen'}
                {confirmAction.type === 'lock' && 'Confirm Lock'}
                {confirmAction.type === 'year-close' && 'Post Year-End Close'}
                {confirmAction.type === 'year-reopen' && 'Confirm Reopen FY'}
              </Button>
            </div>
          }
          isOpen={Boolean(confirmAction)}
          onClose={() => !isSubmitting && setConfirmAction(null)}
          size="sm"
          title={
            confirmAction.type === 'close'
              ? `Close Period ${confirmAction.period?.periodMonth}`
              : confirmAction.type === 'reopen'
              ? `Reopen Period ${confirmAction.period?.periodMonth}`
              : confirmAction.type === 'lock'
              ? `Lock Period ${confirmAction.period?.periodMonth}`
              : confirmAction.type === 'year-close'
              ? `Year-End Close for FY ${activeYear}`
              : `Reopen Financial Year FY ${activeYear}`
          }
        >
          <div style={{ padding: '8px 0', fontSize: '14px', lineHeight: 1.5 }}>
            {confirmAction.type === 'close' && (
              <p>
                Are you sure you want to close Period {confirmAction.period?.periodMonth} (
                {getMonthName(confirmAction.period?.periodMonth ?? 1)}{' '}
                {confirmAction.period?.periodYear})? Closing prevents posting new transactions
                within this period.
              </p>
            )}
            {confirmAction.type === 'reopen' && (
              <p>
                Are you sure you want to reopen Period {confirmAction.period?.periodMonth} (
                {getMonthName(confirmAction.period?.periodMonth ?? 1)}{' '}
                {confirmAction.period?.periodYear})? Transactions may once again be posted to this
                period.
              </p>
            )}
            {confirmAction.type === 'lock' && (
              <p>
                Are you sure you want to lock Period {confirmAction.period?.periodMonth} (
                {getMonthName(confirmAction.period?.periodMonth ?? 1)}{' '}
                {confirmAction.period?.periodYear})? Locked periods are permanently secured for
                audit and require OWNER or ADMIN privileges to reopen.
              </p>
            )}
            {confirmAction.type === 'year-close' && (
              <p>
                Are you sure you want to execute Year-End Close for FY {activeYear}? This will
                post a closing journal entry zeroing all revenue and expense accounts into
                Retained Earnings.
              </p>
            )}
            {confirmAction.type === 'year-reopen' && (
              <p>
                Are you sure you want to reopen FY {activeYear}? This will post an in-period
                reversal of the closing entry, allowing adjustments before re-closing.
              </p>
            )}
          </div>
        </Modal>
      )}
    </section>
  )
}
