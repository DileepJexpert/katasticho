import { useMemo, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
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
import { listPeriods, type FiscalPeriod } from '@/features/fiscal-periods/fiscal-periods-api'

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

export function FiscalPeriodsPage() {
  const currentYear = new Date().getFullYear()
  const [selectedYear, setSelectedYear] = useState<number>(currentYear)
  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState<'ALL' | 'OPEN' | 'CLOSED' | 'LOCKED'>('ALL')
  const [selectedPeriod, setSelectedPeriod] = useState<FiscalPeriod | null>(null)

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

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Accounting Governance / Governance"
        title="Fiscal periods & financial years"
        description="Review accounting periods, period closure governance (OPEN, LOCKED, CLOSED), and financial year boundaries. Mutations remain in Flutter during migration."
      />

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
                <th scope="col">Action</th>
              </tr>
            </thead>
            <tbody>
              {filteredPeriods.map((period) => (
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
                    <Button
                      onClick={() => setSelectedPeriod(period)}
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
            description="No fiscal periods match the active filter criteria for this financial year."
            icon={Calendar}
            title="No periods found"
          />
        )}
      </section>

      {/* Period Details Modal */}
      {selectedPeriod && (
        <Modal
          description="Read-only governance properties and closure history. Period close and year-end close remain in Flutter."
          footer={
            <Button
              onClick={() => setSelectedPeriod(null)}
              variant="secondary"
            >
              Close
            </Button>
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
    </section>
  )
}
