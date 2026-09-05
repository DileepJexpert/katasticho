import { useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  CalendarClock,
  Plus,
  Search,
} from 'lucide-react'
import { Link } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { FormGrid, FormField, SelectInput } from '@/design-system'
import { Modal } from '@/design-system/modal'
import { TextField } from '@/design-system/text-field'
import { useSessionStore } from '@/shared/session/session-store'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { EntityPicker } from '@/design-system/entity-picker'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { listAccounts, type Account } from '@/features/accounts/accounts-api'
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
  const user = useSessionStore((s) => s.user)
  return <AmortizationPageWorkspace key={`${user?.orgId}:${user?.id}:${user?.role}`} />
}

function AmortizationPageWorkspace() {
  const orgId = useSessionStore((s) => s.user?.orgId)
  const role = useSessionStore((s) => s.user?.role)
  const canWrite = ['OWNER', 'ADMIN', 'ACCOUNTANT'].includes(role ?? '')
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
  const [debitAccount, setDebitAccount] = useState<Account | null>(null)
  const [creditAccount, setCreditAccount] = useState<Account | null>(null)

  // Queries
  const schedulesQuery = useQuery({
    queryKey: ['amortization-schedules', orgId],
    queryFn: listAmortizationSchedules,
  })

  const accountsQuery = useQuery({
    queryKey: ['amortization-accounts', orgId],
    queryFn: listAccounts,
    enabled: canWrite,
  })
  const accounts = (accountsQuery.data ?? []).filter((a) => a.isActive && !a.hasChildren)
  const valid = canWrite && description.trim() && Number.isFinite(Number(totalAmount)) && Number(totalAmount) > 0 && Number.isInteger(Number(totalPeriods)) && Number(totalPeriods) > 0 && /^\d{4}-\d{2}-\d{2}$/.test(startDate) && debitAccount && creditAccount && debitAccount.id !== creditAccount.id

  // Mutations
  const createMutation = useMutation({
    mutationFn: (req: CreateAmortizationScheduleRequest) => createAmortizationSchedule(req),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['amortization-schedules'] })
      setIsCreateModalOpen(false)
      setDescription('')
      setTotalAmount('')
      setReference('')
      setDebitAccount(null)
      setCreditAccount(null)
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
    if (!valid || !debitAccount || !creditAccount) return
    const [year, month] = startDate.split('-').map(Number)
    createMutation.mutate({
      description: description.trim(),
      scheduleType,
      totalAmount: Number(totalAmount),
      numberOfPeriods: Number(totalPeriods),
      startYear: year!,
      startMonth: month!,
      reference: reference.trim() || undefined,
      debitAccountCode: debitAccount.code,
      creditAccountCode: creditAccount.code,
    })
  }

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Financial / Accounting"
        title="Amortization & Prepaids"
        description="Recurring straight-line amortization for prepaid software/rent, deferred revenue recognition, and periodic accounting accruals."
        actions={
          <Button disabled={!canWrite} onClick={() => { createMutation.reset(); setIsCreateModalOpen(true) }} variant="primary">
            <Plus aria-hidden="true" size={14} style={{ marginRight: 6 }} />
            New Amortization Schedule
          </Button>
        }
      />

      {schedulesQuery.isError && <div role="alert" className="banner banner--error">{schedulesQuery.error.message}<Button onClick={() => schedulesQuery.refetch()}>Retry</Button></div>}
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
      {schedulesQuery.isPending ? <p role="status">Loading schedules...</p> : schedulesQuery.isError ? null : filtered.length === 0 ? (
        <div className="directory-state" role="status">
          <CalendarClock aria-hidden="true" size={24} />
          <strong>No amortization schedules found.</strong>
          <p>Create a prepaid expense schedule to distribute annual contracts or subscriptions smoothly across fiscal months.</p>
          <Button disabled={!canWrite} onClick={() => { createMutation.reset(); setIsCreateModalOpen(true) }} variant="primary">
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

      <Modal isOpen={isCreateModalOpen} onClose={() => { if (!createMutation.isPending) setIsCreateModalOpen(false) }} title="Create Amortization Schedule"
        description="Choose the accounts for each monthly recognition entry, not the original cash payment. No account defaults are silently applied."
        error={createMutation.error?.message || accountsQuery.error?.message}
        footer={<><Button variant="secondary" disabled={createMutation.isPending} onClick={() => setIsCreateModalOpen(false)}>Cancel</Button><Button disabled={!valid || createMutation.isPending} onClick={handleCreate}>Create Schedule</Button></>}>
        <FormGrid>
          <TextField label="Description" placeholder="e.g. AWS Annual Cloud Hosting Contract" value={description} onChange={(e) => setDescription(e.target.value)} required />
          <FormField label="Schedule type"><SelectInput value={scheduleType} onChange={(e) => setScheduleType(e.target.value as typeof scheduleType)}><option value="PREPAID">Prepaid expense</option><option value="DEFERRED_INCOME">Deferred income</option><option value="ACCRUAL">Accrual</option></SelectInput></FormField>
          <TextField label="Reference" placeholder="PO-9912 or INV-1002" value={reference} onChange={(e) => setReference(e.target.value)} />
          <TextField label="Total amount" type="number" min="0.01" step="0.01" placeholder="0.00" value={totalAmount} onChange={(e) => setTotalAmount(e.target.value)} required />
          <TextField label="Number of months" type="number" min="1" step="1" value={totalPeriods} onChange={(e) => setTotalPeriods(e.target.value)} required />
          <TextField label="Start date" type="date" value={startDate} onChange={(e) => setStartDate(e.target.value)} required />
          <div className="field"><span>Debit account</span><EntityPicker<Account> ariaLabel="Debit Account" options={accounts} getOptionId={(a) => a.id} getOptionLabel={(a) => a.code + ' - ' + a.name} value={debitAccount?.id ?? null} selectedEntity={debitAccount} onChange={(_id, a) => setDebitAccount(a ?? null)} /></div>
          <div className="field"><span>Credit account</span><EntityPicker<Account> ariaLabel="Credit Account" options={accounts} getOptionId={(a) => a.id} getOptionLabel={(a) => a.code + ' - ' + a.name} value={creditAccount?.id ?? null} selectedEntity={creditAccount} onChange={(_id, a) => setCreditAccount(a ?? null)} /></div>
        </FormGrid>
        {debitAccount && creditAccount && debitAccount.id === creditAccount.id && <p role="alert">Debit and credit accounts must differ.</p>}
      </Modal>
    </section>
  )
}
