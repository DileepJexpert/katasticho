import { useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  CalendarClock,
  Plus,
  Search,
} from 'lucide-react'
import { Link } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import {
  createAmortizationSchedule,
  listAmortizationSchedules,
  type CreateAmortizationScheduleRequest,
} from '@/features/amortization/amortization-api'

const typeTabs = [
  { key: 'all', label: 'All schedules' },
  { key: 'PREPAID', label: 'Prepaids' },
  { key: 'DEFERRED_INCOME', label: 'Deferred income' },
  { key: 'ACCRUAL', label: 'Accruals' },
] as const

type TypeTab = (typeof typeTabs)[number]['key']

export function AmortizationPage() {
  const queryClient = useQueryClient()
  const [activeTab, setActiveTab] = useState<TypeTab>('all')
  const [search, setSearch] = useState('')
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false)

  // Form State
  const [description, setDescription] = useState('')
  const [scheduleType, setScheduleType] = useState<'PREPAID' | 'DEFERRED_INCOME' | 'ACCRUAL'>('PREPAID')
  const [totalAmount, setTotalAmount] = useState('')
  const [totalPeriods, setTotalPeriods] = useState('12')
  const [startDate, setStartDate] = useState(new Date().toISOString().split('T')[0] || '')
  const [reference, setReference] = useState('')

  // Queries
  const schedulesQuery = useQuery({
    queryKey: ['amortization-schedules'],
    queryFn: listAmortizationSchedules,
  })

  // Mutations
  const createMutation = useMutation({
    mutationFn: (req: CreateAmortizationScheduleRequest) => createAmortizationSchedule(req),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['amortization-schedules'] })
      setIsCreateModalOpen(false)
      setDescription('')
      setTotalAmount('')
      setReference('')
    },
  })

  const rawList = schedulesQuery.data ?? []

  const filtered = useMemo(() => {
    return rawList.filter((s) => {
      if (activeTab !== 'all' && s.scheduleType !== activeTab) return false
      if (!search.trim()) return true
      const q = search.toLowerCase()
      const matchDesc = s.description.toLowerCase().includes(q)
      const matchRef = s.reference ? s.reference.toLowerCase().includes(q) : false
      const matchType = s.scheduleType.toLowerCase().includes(q)
      return matchDesc || matchRef || matchType
    })
  }, [rawList, activeTab, search])

  const totalScheduled = useMemo(
    () => rawList.reduce((sum, s) => sum + Number(s.totalAmount || 0), 0),
    [rawList]
  )
  const totalRecognized = useMemo(
    () => rawList.reduce((sum, s) => sum + Number(s.recognizedAmount || 0), 0),
    [rawList]
  )
  const totalRemaining = Math.max(0, totalScheduled - totalRecognized)

  const handleCreate = () => {
    if (!description.trim() || !totalAmount || Number(totalAmount) <= 0) return
    const parsedDate = new Date(startDate)
    createMutation.mutate({
      description: description.trim(),
      scheduleType,
      totalAmount: Number(totalAmount),
      numberOfPeriods: Number(totalPeriods) || 12,
      startYear: parsedDate.getFullYear() || new Date().getFullYear(),
      startMonth: parsedDate.getMonth() + 1 || 1,
      reference: reference.trim() || undefined,
      debitAccountCode: 'PREPAID',
      creditAccountCode: 'BANK',
    })
  }

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Financial / Accounting"
        title="Amortization & Prepaids"
        description="Recurring straight-line amortization for prepaid software/rent, deferred revenue recognition, and periodic accounting accruals."
        actions={
          <Button onClick={() => setIsCreateModalOpen(true)} variant="primary">
            <Plus aria-hidden="true" size={14} style={{ marginRight: 6 }} />
            New Amortization Schedule
          </Button>
        }
      />

      {/* KPI Summary Strip */}
      <div className="summary-strip">
        <div className="summary-card">
          <span className="summary-card__label">Total Scheduled</span>
          <strong className="summary-card__value">
            <Money amount={totalScheduled} />
          </strong>
          <span className="summary-card__hint">{rawList.length} active schedules</span>
        </div>

        <div className="summary-card">
          <span className="summary-card__label">Recognized to Date</span>
          <strong className="summary-card__value" style={{ color: 'var(--color-primary)' }}>
            <Money amount={totalRecognized} />
          </strong>
          <span className="summary-card__hint">Posted to P&L accounts</span>
        </div>

        <div className="summary-card summary-card--accent">
          <span className="summary-card__label">Remaining Unamortized</span>
          <strong className="summary-card__value" style={{ color: 'var(--color-success)' }}>
            <Money amount={totalRemaining} />
          </strong>
          <span className="summary-card__hint">Pending future periods</span>
        </div>
      </div>

      {/* Toolbar */}
      <div className="list-toolbar" style={{ justifyContent: 'space-between' }}>
        <div style={{ display: 'flex', gap: 'var(--space-sm)', alignItems: 'center' }}>
          <div className="search-field" style={{ width: 280 }}>
            <Search aria-hidden="true" size={16} />
            <input
              aria-label="Search amortization schedules"
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search description, reference..."
              type="text"
              value={search}
            />
          </div>

          <div className="filter-chips">
            {typeTabs.map((t) => (
              <button
                key={t.key}
                className={`filter-chip ${activeTab === t.key ? 'filter-chip--active' : ''}`}
                onClick={() => setActiveTab(t.key)}
                type="button"
              >
                {t.label}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Schedules Table */}
      {filtered.length === 0 ? (
        <div className="directory-state" role="status">
          <CalendarClock aria-hidden="true" size={24} />
          <strong>No amortization schedules found.</strong>
          <p>Create a prepaid expense schedule to distribute annual contracts or subscriptions smoothly across fiscal months.</p>
          <Button onClick={() => setIsCreateModalOpen(true)} variant="primary">
            New Amortization Schedule
          </Button>
        </div>
      ) : (
        <DataTable caption="Amortization Schedules Table">
          <thead>
            <tr>
              <th scope="col">Schedule Description</th>
              <th scope="col">Type</th>
              <th scope="col">Reference</th>
              <th className="numeric-cell" scope="col">Total Contract</th>
              <th className="numeric-cell" scope="col">Recognized</th>
              <th className="numeric-cell" scope="col">Remaining</th>
              <th scope="col" style={{ width: 140 }}>Progress</th>
              <th scope="col">Status</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((s) => {
              const total = Number(s.totalAmount || 0)
              const rec = Number(s.recognizedAmount || 0)
              const rem = Math.max(0, total - rec)
              const pct = total > 0 ? (rec / total) * 100 : 0
              return (
                <tr key={s.id}>
                  <td>
                    <Link
                      style={{ color: 'var(--color-primary)', fontWeight: 600 }}
                      to={appRoutes.amortizationDetail(s.id)}
                    >
                      {s.description}
                    </Link>
                  </td>
                  <td>
                    <StatusChip status={s.scheduleType} />
                  </td>
                  <td>
                    <span className="table-code">{s.reference || 'â€”'}</span>
                  </td>
                  <td className="numeric-cell">
                    <strong>
                      <Money amount={total} />
                    </strong>
                  </td>
                  <td className="numeric-cell" style={{ color: 'var(--color-primary)' }}>
                    <Money amount={rec} />
                  </td>
                  <td className="numeric-cell">
                    <strong style={{ color: 'var(--color-success)' }}>
                      <Money amount={rem} />
                    </strong>
                  </td>
                  <td>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                      <div
                        style={{
                          flex: 1,
                          height: 6,
                          background: 'var(--color-border)',
                          borderRadius: 3,
                          overflow: 'hidden',
                        }}
                      >
                        <div
                          style={{
                            width: `${Math.min(100, pct)}%`,
                            height: '100%',
                            background: 'var(--color-primary)',
                          }}
                        />
                      </div>
                      <span style={{ fontSize: '0.75rem', fontWeight: 600, minWidth: 32 }}>
                        {pct.toFixed(0)}%
                      </span>
                    </div>
                  </td>
                  <td>
                    <StatusChip status={s.status} />
                  </td>
                </tr>
              )
            })}
          </tbody>
        </DataTable>
      )}

      {/* MODAL: CREATE SCHEDULE */}
      {isCreateModalOpen && (
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
            <h3 style={{ fontSize: '1.2rem', fontWeight: 600, marginBottom: 'var(--space-xs)' }}>
              Create Amortization Schedule
            </h3>
            <p className="cell-muted" style={{ fontSize: '0.85rem', marginBottom: 'var(--space-md)' }}>
              Establish a periodic recognition plan for deferred income or prepaid expenditure.
            </p>

            <div style={{ marginBottom: 'var(--space-sm)' }}>
              <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                Description *
              </label>
              <input
                style={{
                  width: '100%',
                  padding: '8px 12px',
                  borderRadius: 'var(--radius-md)',
                  border: '1px solid var(--color-border)',
                }}
                onChange={(e) => setDescription(e.target.value)}
                placeholder="e.g. AWS Annual Cloud Hosting Contract"
                type="text"
                value={description}
              />
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 'var(--space-sm)', marginBottom: 'var(--space-sm)' }}>
              <div>
                <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                  Schedule Type
                </label>
                <select
                  className="select-field"
                  onChange={(e) =>
                    setScheduleType(e.target.value as 'PREPAID' | 'DEFERRED_INCOME' | 'ACCRUAL')
                  }
                  style={{
                    width: '100%',
                    padding: '8px 12px',
                    borderRadius: 'var(--radius-md)',
                    border: '1px solid var(--color-border)',
                  }}
                  value={scheduleType}
                >
                  <option value="PREPAID">Prepaid Expense</option>
                  <option value="DEFERRED_INCOME">Deferred Income / Revenue</option>
                  <option value="ACCRUAL">Accounting Accrual</option>
                </select>
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                  Reference Number
                </label>
                <input
                  style={{
                    width: '100%',
                    padding: '8px 12px',
                    borderRadius: 'var(--radius-md)',
                    border: '1px solid var(--color-border)',
                  }}
                  onChange={(e) => setReference(e.target.value)}
                  placeholder="PO-9912 or INV-1002"
                  type="text"
                  value={reference}
                />
              </div>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 'var(--space-sm)', marginBottom: 'var(--space-md)' }}>
              <div>
                <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                  Total Amount (â‚¹) *
                </label>
                <input
                  style={{
                    width: '100%',
                    padding: '8px 12px',
                    borderRadius: 'var(--radius-md)',
                    border: '1px solid var(--color-border)',
                  }}
                  onChange={(e) => setTotalAmount(e.target.value)}
                  placeholder="0.00"
                  type="number"
                  value={totalAmount}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                  Periods (Months)
                </label>
                <input
                  style={{
                    width: '100%',
                    padding: '8px 12px',
                    borderRadius: 'var(--radius-md)',
                    border: '1px solid var(--color-border)',
                  }}
                  onChange={(e) => setTotalPeriods(e.target.value)}
                  placeholder="12"
                  type="number"
                  value={totalPeriods}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                  Start Date
                </label>
                <input
                  style={{
                    width: '100%',
                    padding: '8px 12px',
                    borderRadius: 'var(--radius-md)',
                    border: '1px solid var(--color-border)',
                  }}
                  onChange={(e) => setStartDate(e.target.value)}
                  type="date"
                  value={startDate}
                />
              </div>
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
              <Button onClick={() => setIsCreateModalOpen(false)} variant="secondary">
                Cancel
              </Button>
              <Button
                disabled={!description.trim() || !totalAmount || createMutation.isPending}
                onClick={handleCreate}
                variant="primary"
              >
                {createMutation.isPending ? 'Creating...' : 'Create Schedule'}
              </Button>
            </div>
          </div>
        </div>
      )}
    </section>
  )
}