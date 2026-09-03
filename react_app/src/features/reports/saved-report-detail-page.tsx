import { useQuery } from '@tanstack/react-query'
import {
  ArrowLeft,
  CalendarClock,
  FileText,
  Globe,
  Lock,
  Mail,
  Play,
} from 'lucide-react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate } from '@/shared/format/format'
import {
  getSavedReport,
  listReportSchedules,
} from '@/features/reports/reports-api'

export function SavedReportDetailPage() {
  const { reportId } = useParams<{ reportId: string }>()
  const navigate = useNavigate()

  const reportQuery = useQuery({
    queryKey: ['saved-reports', reportId],
    queryFn: () => getSavedReport(reportId!),
    enabled: Boolean(reportId),
  })

  const schedulesQuery = useQuery({
    queryKey: ['saved-reports', reportId, 'schedules'],
    queryFn: () => listReportSchedules(reportId!),
    enabled: Boolean(reportId),
  })

  if (!reportId) return <DocumentError onBack={() => navigate(appRoutes.savedReports)} />
  if (reportQuery.isLoading) {
    return (
      <section className="workspace-page">
        <div aria-live="polite" className="directory-state">
          Loading saved report configuration...
        </div>
      </section>
    )
  }
  if (reportQuery.isError || !reportQuery.data) {
    return <DocumentError onBack={() => navigate(appRoutes.savedReports)} />
  }

  const report = reportQuery.data
  const schedules = schedulesQuery.data ?? []

  const parsedColumns = parseJsonArray(report.columnKeys)

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Intelligence / Saved Report"
        title={report.name}
        description={report.description || `Custom view based on ${report.baseReportKey} ledger.`}
        actions={
          <div className="table-actions">
            <span className="table-code">{report.baseReportKey}</span>
            <span className="status-badge" style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
              {report.isPublic ? (
                <>
                  <Globe aria-hidden="true" size={12} /> Public
                </>
              ) : (
                <>
                  <Lock aria-hidden="true" size={12} /> Private
                </>
              )}
            </span>
            <StatusChip status="Read-only pilot" />
          </div>
        }
      />

      <div className="document-actions">
        <Button onClick={() => navigate(appRoutes.savedReports)} variant="secondary">
          <ArrowLeft aria-hidden="true" size={16} />
          Back to Saved Reports
        </Button>
        <Link
          className="table-row-action"
          style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}
          to={appRoutes.reportViewer(report.baseReportKey)}
        >
          <Play aria-hidden="true" size={14} />
          Execute Base Report
        </Link>
      </div>

      <div className="document-layout">
        <section className="document-card">
          <h2>
            <FileText aria-hidden="true" size={18} style={{ display: 'inline', marginRight: 6 }} />
            Report configuration & schema
          </h2>
          <dl className="document-facts">
            <Fact label="Report name" value={report.name} />
            <Fact label="Base template" value={report.baseReportKey} />
            <Fact label="Classification tags" value={report.tags || 'None assigned'} />
            <Fact
              label="Selected columns"
              value={
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: 4 }}>
                  {parsedColumns.map((col) => (
                    <span className="status-badge" key={col}>
                      {col}
                    </span>
                  ))}
                </div>
              }
            />
            <Fact
              label="Active filters"
              value={
                report.filters ? (
                  <code style={{ fontSize: '0.8rem', background: 'var(--k-color-surface-sunken)', padding: '2px 4px', borderRadius: 4 }}>
                    {typeof report.filters === 'string' ? report.filters : JSON.stringify(report.filters)}
                  </code>
                ) : (
                  'Default parameters'
                )
              }
            />
          </dl>
        </section>

        <section className="document-card">
          <h2>
            <CalendarClock aria-hidden="true" size={18} style={{ display: 'inline', marginRight: 6 }} />
            Delivery schedules summary
          </h2>
          <dl className="document-facts">
            <Fact
              label="Configured schedules"
              value={`${schedules.length} delivery rule(s)`}
            />
            <Fact
              label="Active automated jobs"
              value={`${schedules.filter((s) => s.active).length} active`}
            />
            <Fact
              label="Last updated"
              value={report.updatedAt ? formatDate(report.updatedAt) : '—'}
            />
          </dl>
        </section>
      </div>

      <div className="document-section">
        <h2>
          <Mail aria-hidden="true" size={18} style={{ display: 'inline', marginRight: 6 }} />
          Automated email delivery schedules ({schedules.length})
        </h2>
        {schedules.length === 0 ? (
          <div className="directory-state">
            <CalendarClock aria-hidden="true" size={24} />
            <strong>No delivery schedules configured.</strong>
            <p>Schedule recurring daily, weekly, or monthly report emails to stakeholder inboxes.</p>
          </div>
        ) : (
          <DataTable caption="Automated recurring email dispatches for this report">
            <thead>
              <tr>
                <th scope="col">Frequency</th>
                <th scope="col">Dispatch Time</th>
                <th scope="col">Recipient Emails</th>
                <th scope="col">Email Subject</th>
                <th scope="col">Last Sent</th>
                <th scope="col">Next Run</th>
                <th scope="col">Status</th>
              </tr>
            </thead>
            <tbody>
              {schedules.map((sch) => {
                const recipients = parseJsonArray(sch.recipientEmails)

                return (
                  <tr key={sch.id}>
                    <td>
                      <strong>{sch.frequency}</strong>
                      {sch.dayOfWeek !== null && sch.dayOfWeek !== undefined ? (
                        <span className="cell-muted"> (Day {sch.dayOfWeek})</span>
                      ) : null}
                      {sch.dayOfMonth !== null && sch.dayOfMonth !== undefined ? (
                        <span className="cell-muted"> (Day {sch.dayOfMonth})</span>
                      ) : null}
                    </td>
                    <td>{sch.sendTime} UTC</td>
                    <td>
                      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 4 }}>
                        {recipients.map((email) => (
                          <span className="status-badge" key={email}>
                            {email}
                          </span>
                        ))}
                      </div>
                    </td>
                    <td>{sch.subjectTemplate || `Report: ${report.name}`}</td>
                    <td>{sch.lastSentAt ? formatDate(sch.lastSentAt) : 'Never'}</td>
                    <td>{sch.nextRunAt ? formatDate(sch.nextRunAt) : 'Pending'}</td>
                    <td>
                      <StatusChip status={sch.active ? 'Active' : 'Inactive'} />
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </DataTable>
        )}
      </div>
    </section>
  )
}

function parseJsonArray(raw: string | string[] | undefined | null): string[] {
  if (!raw) return []
  if (Array.isArray(raw)) return raw
  try {
    const parsed: unknown = JSON.parse(raw)
    if (Array.isArray(parsed)) return parsed.map((item) => String(item))
    return [String(parsed)]
  } catch {
    return [raw]
  }
}

function Fact({
  hint,
  label,
  value,
}: {
  label: string
  value: React.ReactNode
  hint?: string
}) {
  return (
    <div>
      <dt className="document-fact-label">{label}</dt>
      <dd className="document-fact-value">{value}</dd>
      {hint ? <p className="cell-muted">{hint}</p> : null}
    </div>
  )
}

function DocumentError({ onBack }: { onBack: () => void }) {
  return (
    <section className="workspace-page">
      <div className="directory-state directory-state--error" role="alert">
        <FileText aria-hidden="true" size={24} />
        <strong>Unable to load saved report.</strong>
        <p>The record was not found or your session cannot access this workspace.</p>
        <Button onClick={onBack} variant="secondary">
          <ArrowLeft aria-hidden="true" size={16} />
          Back to Saved Reports
        </Button>
      </div>
    </section>
  )
}
