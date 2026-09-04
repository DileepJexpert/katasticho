import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  ArrowLeft,
  CalendarClock,
  Play,
} from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
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
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const currentYear = new Date().getFullYear()
  const currentMonth = new Date().getMonth() + 1

  const [isPostModalOpen, setIsPostModalOpen] = useState(false)
  const [postYear, setPostYear] = useState(currentYear)
  const [postMonth, setPostMonth] = useState(currentMonth)

  const query = useQuery({
    queryKey: ['amortization-schedules', scheduleId],
    queryFn: () => getAmortizationSchedule(scheduleId!),
    enabled: Boolean(scheduleId),
  })

  const postMutation = useMutation({
    mutationFn: () => postAmortizationPeriod(scheduleId!, postYear, postMonth),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['amortization-schedules', scheduleId] })
      setIsPostModalOpen(false)
    },
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
  const isCompleted = schedule.status === 'COMPLETED'

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

            {!isCompleted && (
              <Button onClick={() => setIsPostModalOpen(true)} variant="primary">
                <Play aria-hidden="true" size={14} style={{ marginRight: 6 }} />
                Post Amortization Period
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

      {/* MODAL: POST AMORTIZATION */}
      {isPostModalOpen && (
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
              maxWidth: 440,
              backgroundColor: 'var(--color-surface)',
              borderRadius: 'var(--radius-lg)',
              padding: 'var(--space-lg)',
              border: '1px solid var(--color-border)',
            }}
          >
            <h3 style={{ fontSize: '1.2rem', fontWeight: 600, marginBottom: 'var(--space-xs)' }}>
              Post Period Recognition
            </h3>
            <p className="cell-muted" style={{ fontSize: '0.85rem', marginBottom: 'var(--space-md)' }}>
              Execute monthly straight-line journal voucher posting of <Money amount={periodAmount} />.
            </p>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 'var(--space-sm)', marginBottom: 'var(--space-md)' }}>
              <div>
                <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                  Year
                </label>
                <input
                  style={{
                    width: '100%',
                    padding: '8px 12px',
                    borderRadius: 'var(--radius-md)',
                    border: '1px solid var(--color-border)',
                  }}
                  onChange={(e) => setPostYear(Number(e.target.value))}
                  type="number"
                  value={postYear}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                  Month (1-12)
                </label>
                <input
                  style={{
                    width: '100%',
                    padding: '8px 12px',
                    borderRadius: 'var(--radius-md)',
                    border: '1px solid var(--color-border)',
                  }}
                  max={12}
                  min={1}
                  onChange={(e) => setPostMonth(Number(e.target.value))}
                  type="number"
                  value={postMonth}
                />
              </div>
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
              <Button onClick={() => setIsPostModalOpen(false)} variant="secondary">
                Cancel
              </Button>
              <Button
                disabled={postMutation.isPending}
                onClick={() => postMutation.mutate()}
                variant="primary"
              >
                {postMutation.isPending ? 'Posting...' : 'Post Recognition'}
              </Button>
            </div>
          </div>
        </div>
      )}
    </section>
  )
}