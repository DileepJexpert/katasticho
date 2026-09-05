import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import {
  ArrowLeft,
  CalendarClock,
  Play,
} from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { MonthlyPostingDialog } from '@/features/accounting/monthly-posting-dialog'
import { useSessionStore } from '@/shared/session/session-store'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import {
  getAmortizationSchedule,
  postAmortizationPeriod,
} from '@/features/amortization/amortization-api'

export function AmortizationDetailPage() {
  const { scheduleId } = useParams<{ scheduleId: string }>()
  const user = useSessionStore((s) => s.user)
  return <AmortizationDetailPageWorkspace key={`${user?.orgId}:${user?.role}:${scheduleId}`} />
}

function AmortizationDetailPageWorkspace() {
  const orgId = useSessionStore((s) => s.user?.orgId)
  const { scheduleId } = useParams<{ scheduleId: string }>()
  const navigate = useNavigate()
  const role = useSessionStore((s) => s.user?.role)
  const canPost = ['OWNER', 'ADMIN', 'ACCOUNTANT'].includes(role ?? '')
  const [isPostModalOpen, setIsPostModalOpen] = useState(false)

  const query = useQuery({
    queryKey: ['amortization-schedules', orgId, scheduleId],
    queryFn: () => getAmortizationSchedule(scheduleId!),
    enabled: Boolean(scheduleId),
  })

  if (!scheduleId || query.isLoading) {
    return (
      <section className="workspace-page">
        <div className="directory-state">Loading amortization schedule...</div>
      </section>
    )
  }

  if (query.isError || !query.data) {
    return (
      <section className="workspace-page">
        <div className="directory-state directory-state--error" role="alert">
          <CalendarClock aria-hidden="true" size={24} />
          <strong>Amortization schedule not found.</strong>
          <Button onClick={() => navigate(appRoutes.amortization)} variant="secondary">
            <ArrowLeft aria-hidden="true" size={14} style={{ marginRight: 6 }} />
            Back to Amortization
          </Button>
        </div>
      </section>
    )
  }

  const { entries, periodAmount, remaining, schedule } = query.data
  const total = Number(schedule.totalAmount || 0)
  const recognized = Number(schedule.recognizedAmount || 0)
  const rem = remaining !== undefined ? Number(remaining) : Math.max(0, total - recognized)
  const isCompleted = schedule.status !== 'ACTIVE'

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Financial / Amortization"
        title={schedule.description}
        description={`Type: ${schedule.scheduleType} · Ref: ${schedule.reference || 'Direct schedule'} · Periods: ${schedule.numberOfPeriods || 12} Months`}
        actions={
          <div style={{ display: 'flex', gap: 'var(--space-sm)' }}>
            <Button onClick={() => navigate(appRoutes.amortization)} variant="secondary">
              <ArrowLeft aria-hidden="true" size={14} style={{ marginRight: 6 }} />
              Back
            </Button>

            {canPost && !isCompleted && (
              <Button onClick={() => setIsPostModalOpen(true)} variant="primary">
                <Play aria-hidden="true" size={14} style={{ marginRight: 6 }} />
                Run organisation amortization
              </Button>
            )}

            <StatusChip status={schedule.status} />
          </div>
        }
      />

      {/* KPI Summary Strip */}
      <div className="summary-strip">
        <div className="summary-card">
          <span className="summary-card__label">Total Contract Value</span>
          <strong className="summary-card__value">
            <Money amount={total} />
          </strong>
          <span className="summary-card__hint">Start: {schedule.startYear}-{String(schedule.startMonth).padStart(2, '0')}</span>
        </div>

        <div className="summary-card">
          <span className="summary-card__label">Recognized to Date</span>
          <strong className="summary-card__value" style={{ color: 'var(--color-primary)' }}>
            <Money amount={recognized} />
          </strong>
          <span className="summary-card__hint">Posted to P&L accounts</span>
        </div>

        <div className="summary-card summary-card--accent">
          <span className="summary-card__label">Remaining Balance</span>
          <strong className="summary-card__value" style={{ color: 'var(--color-success)' }}>
            <Money amount={rem} />
          </strong>
          <span className="summary-card__hint">Carrying balance sheet amount</span>
        </div>

        <div className="summary-card">
          <span className="summary-card__label">Per Period Installment</span>
          <strong className="summary-card__value">
            <Money amount={periodAmount} />
          </strong>
          <span className="summary-card__hint">Monthly recognition rate</span>
        </div>
      </div>

      {/* Entries Schedule Table */}
      <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
        <h3 style={{ fontSize: '1.05rem', fontWeight: 600, marginBottom: 'var(--space-sm)' }}>
          Recognition Schedule Entries ({entries.length} Months)
        </h3>

        <DataTable caption="Amortization Schedule Entries">
          <thead>
            <tr>
              <th scope="col">Period</th>
              <th className="numeric-cell" scope="col">Period Amount</th>
              <th scope="col">Journal Voucher</th>
            </tr>
          </thead>
          <tbody>
            {entries.map((entry) => (
              <tr key={entry.id}>
                <td>
                  <span className="table-code">
                    {entry.periodYear}-{String(entry.periodMonth).padStart(2, '0')}
                  </span>
                </td>
                <td className="numeric-cell">
                  <strong>
                    <Money amount={entry.amount} />
                  </strong>
                </td>
                <td>
                  {entry.journalEntryId ? (
                    <span className="table-code" style={{ color: 'var(--color-primary)' }}>
                      GL-{entry.journalEntryId.substring(0, 8)}
                    </span>
                  ) : (
                    <span className="cell-muted">Pending posting</span>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      </div>

      {isPostModalOpen && <MonthlyPostingDialog title="Run organisation amortization" scope="amortization schedules" run={postAmortizationPeriod} onClose={() => setIsPostModalOpen(false)} />}
    </section>
  )
}
