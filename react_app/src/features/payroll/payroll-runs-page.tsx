import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  ArrowLeft,
  ArrowRight,
  Banknote,
  Calendar,
  FileText,
  Plus,
  X,
} from 'lucide-react'
import { Link } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import {
  createPayrollRun,
  listPayrollRuns,
} from '@/features/payroll/payroll-api'

const statusTabs = [
  { key: 'all', label: 'All runs' },
  { key: 'DRAFT', label: 'Draft' },
  { key: 'CALCULATED', label: 'Calculated' },
  { key: 'APPROVED', label: 'Approved' },
  { key: 'POSTED', label: 'Posted' },
] as const

type StatusTab = (typeof statusTabs)[number]['key']

export function PayrollRunsPage() {
  const [activeTab, setActiveTab] = useState<StatusTab>('all')
  const [page, setPage] = useState(0)
  const [isCreateOpen, setIsCreateOpen] = useState(false)

  const queryClient = useQueryClient()

  const query = useQuery({
    queryKey: ['payroll-runs', page],
    queryFn: () => listPayrollRuns(page),
  })

  const createMutation = useMutation({
    mutationFn: ({ start, end }: { start: string; end: string }) =>
      createPayrollRun(start, end),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['payroll-runs'] })
      setIsCreateOpen(false)
    },
  })

  const pageData = query.data
  const rawList = pageData?.content ?? []
  const filtered = rawList.filter((r) => {
    if (activeTab !== 'all' && r.status !== activeTab) return false
    return true
  })

  const totalPages = pageData?.totalPages ?? 0

  const totalGross = rawList.reduce((acc, r) => acc + Number(r.grossTotal || 0), 0)
  const totalNet = rawList.reduce((acc, r) => acc + Number(r.netPayTotal || 0), 0)
  const postedCount = rawList.filter((r) => r.status === 'POSTED').length

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="HR & Payroll"
        title="Payroll Runs"
        description="Monthly salary processing cycles, statutory deductions (PF, ESI, PT, TDS), and general ledger postings."
        actions={
          <div className="table-actions">
            <Button onClick={() => setIsCreateOpen(true)} variant="primary">
              <Plus aria-hidden="true" size={16} />
              New Payroll Run
            </Button>
          </div>
        }
      />

      <div className="summary-strip">
        <div className="summary-card">
          <span className="summary-card__label">Payroll Cycles</span>
          <strong className="summary-card__value">{rawList.length}</strong>
          <span className="summary-card__hint">Total processed batches</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__label">Posted to GL</span>
          <strong className="summary-card__value text-success">{postedCount}</strong>
          <span className="summary-card__hint">Completed disbursal runs</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__label">Cumulative Gross</span>
          <strong className="summary-card__value">
            <Money amount={totalGross} />
          </strong>
          <span className="summary-card__hint">Total salary obligations</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__label">Cumulative Net Paid</span>
          <strong className="summary-card__value text-primary">
            <Money amount={totalNet} />
          </strong>
          <span className="summary-card__hint">Disbursed to employee banks</span>
        </div>
      </div>

      <div className="list-toolbar">
        <div aria-label="Filter payroll runs by status" className="list-tabs" role="tablist">
          {statusTabs.map((tab) => (
            <button
              aria-selected={activeTab === tab.key}
              className={activeTab === tab.key ? 'list-tab list-tab--active' : 'list-tab'}
              key={tab.key}
              onClick={() => {
                setActiveTab(tab.key)
                setPage(0)
              }}
              role="tab"
              type="button"
            >
              {tab.label}
            </button>
          ))}
        </div>
      </div>

      {query.isLoading ? (
        <div aria-live="polite" className="directory-state">
          Loading payroll processing runs...
        </div>
      ) : query.isError ? (
        <div className="directory-state directory-state--error" role="alert">
          <FileText aria-hidden="true" size={24} />
          <strong>Unable to load payroll runs.</strong>
          <p>Please verify your connection or organizational permissions.</p>
          <Button onClick={() => query.refetch()} variant="secondary">
            Retry
          </Button>
        </div>
      ) : filtered.length === 0 ? (
        <div className="directory-state">
          <Banknote aria-hidden="true" size={24} />
          <strong>No payroll runs found.</strong>
          <p>Click "New Payroll Run" to start monthly salary computation.</p>
        </div>
      ) : (
        <DataTable caption="Monthly payroll processing and settlement runs">
          <thead>
            <tr>
              <th scope="col">Pay Period</th>
              <th className="numeric-cell" scope="col">Headcount</th>
              <th className="numeric-cell" scope="col">Gross Total</th>
              <th className="numeric-cell" scope="col">Deductions</th>
              <th className="numeric-cell" scope="col">Employer Contrib.</th>
              <th className="numeric-cell" scope="col">Net Pay Total</th>
              <th scope="col">Status</th>
              <th scope="col">Actions</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((run) => (
              <tr key={run.id}>
                <td>
                  <Link
                    className="table-code"
                    to={appRoutes.payrollRunDetail(run.id)}
                  >
                    {formatDate(run.periodStart)} â€“ {formatDate(run.periodEnd)}
                  </Link>
                </td>
                <td className="numeric-cell">
                  <Quantity unit="Staff" value={run.employeeCount} />
                </td>
                <td className="numeric-cell">
                  <Money amount={run.grossTotal} />
                </td>
                <td className="numeric-cell text-danger">
                  <Money amount={run.deductionTotal} />
                </td>
                <td className="numeric-cell">
                  <Money amount={run.employerContributionTotal} />
                </td>
                <td className="numeric-cell">
                  <strong><Money amount={run.netPayTotal} /></strong>
                </td>
                <td>
                  <StatusChip status={formatStatusLabel(run.status)} />
                </td>
                <td>
                  <Link
                    className="table-row-action"
                    to={appRoutes.payrollRunDetail(run.id)}
                  >
                    Manage Run
                  </Link>
                </td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      )}

      {totalPages > 1 ? (
        <div className="pagination-bar">
          <Button
            disabled={page === 0}
            onClick={() => setPage((p) => Math.max(0, p - 1))}
            variant="secondary"
          >
            <ArrowLeft aria-hidden="true" size={16} />
            Previous
          </Button>
          <span className="pagination-info">
            Page {page + 1} of {totalPages}
          </span>
          <Button
            disabled={page >= totalPages - 1}
            onClick={() => setPage((p) => p + 1)}
            variant="secondary"
          >
            Next
            <ArrowRight aria-hidden="true" size={16} />
          </Button>
        </div>
      ) : null}

      {/* Create Payroll Run Modal */}
      {isCreateOpen ? (
        <CreatePayrollRunModal
          isPending={createMutation.isPending}
          onClose={() => setIsCreateOpen(false)}
          onCreate={(start, end) => createMutation.mutate({ start, end })}
        />
      ) : null}
    </section>
  )
}

function CreatePayrollRunModal({
  isPending,
  onClose,
  onCreate,
}: {
  isPending: boolean
  onClose: () => void
  onCreate: (start: string, end: string) => void
}) {
  const currentYear = new Date().getFullYear()
  const currentMonth = new Date().getMonth() // 0-indexed

  const [year, setYear] = useState(currentYear)
  const [month, setMonth] = useState(currentMonth)

  // Compute start & end dates of chosen month
  
  const endDate = new Date(year, month + 1, 0)
  const startStr = `${year}-${String(month + 1).padStart(2, '0')}-01`
  const endStr = `${year}-${String(month + 1).padStart(2, '0')}-${String(endDate.getDate()).padStart(2, '0')}`

  const monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ]

  return (
    <div className="modal-backdrop" role="presentation">
      <div aria-labelledby="create-run-title" aria-modal="true" className="modal-dialog" role="dialog">
        <div className="modal-header">
          <div>
            <h2 id="create-run-title">Start New Payroll Run</h2>
            <p className="cell-muted">Initialize monthly salary computation batch for active employees.</p>
          </div>
          <button className="icon-button" onClick={onClose} type="button">
            <X aria-hidden="true" size={18} />
          </button>
        </div>
        <form
          onSubmit={(e) => {
            e.preventDefault()
            onCreate(startStr, endStr)
          }}
        >
          <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              <div>
                <label className="form-label">Pay Year</label>
                <select
                  className="select-input"
                  onChange={(e) => setYear(Number(e.target.value))}
                  value={year}
                >
                  <option value={currentYear + 1}>{currentYear + 1}</option>
                  <option value={currentYear}>{currentYear}</option>
                  <option value={currentYear - 1}>{currentYear - 1}</option>
                </select>
              </div>
              <div>
                <label className="form-label">Pay Month</label>
                <select
                  className="select-input"
                  onChange={(e) => setMonth(Number(e.target.value))}
                  value={month}
                >
                  {monthNames.map((name, idx) => (
                    <option key={name} value={idx}>
                      {name}
                    </option>
                  ))}
                </select>
              </div>
            </div>

            <fieldset style={{ border: '1px solid var(--k-color-border-subtle)', borderRadius: 6, padding: 12 }}>
              <legend style={{ fontWeight: 600, padding: '0 6px', fontSize: '0.9rem' }}>
                <Calendar aria-hidden="true" size={14} style={{ display: 'inline', marginRight: 4 }} />
                Resolved Period Window
              </legend>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginTop: 6 }}>
                <div>
                  <span className="form-label">Period Start</span>
                  <code className="table-code">{startStr}</code>
                </div>
                <div>
                  <span className="form-label">Period End</span>
                  <code className="table-code">{endStr}</code>
                </div>
              </div>
            </fieldset>
          </div>

          <div className="modal-footer">
            <Button onClick={onClose} type="button" variant="secondary">Cancel</Button>
            <Button disabled={isPending} type="submit" variant="primary">
              {isPending ? 'Initializing...' : 'Initialize Run'}
            </Button>
          </div>
        </form>
      </div>
    </div>
  )
}
