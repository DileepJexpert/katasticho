import { useMemo } from 'react'
import { useQuery } from '@tanstack/react-query'
import {
  ArrowLeft,
  Bookmark,
  FileText,
  Globe,
  Lock,
} from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { formatDate } from '@/shared/format/format'
import { listSavedReports } from '@/features/reports/reports-api'

export function SavedReportsPage() {
  const navigate = useNavigate()

  const query = useQuery({
    queryKey: ['saved-reports'],
    queryFn: () => listSavedReports(),
  })

  const savedList = query.data ?? []

  const publicCount = useMemo(() => {
    return savedList.filter((r) => r.isPublic).length
  }, [savedList])

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Intelligence & Custom Analytics"
        title="Saved Custom Reports"
        description="Saved report queries, customized column selections, and automated scheduled deliveries."
      />

      <div className="document-actions">
        <Button onClick={() => navigate(appRoutes.reports)} variant="secondary">
          <ArrowLeft aria-hidden="true" size={16} />
          Back to Reports Hub
        </Button>
      </div>

      <div className="summary-strip">
        <div className="summary-card">
          <span className="summary-card__label">Total Saved Reports</span>
          <strong className="summary-card__value">
            <Quantity value={savedList.length} />
          </strong>
          <span className="summary-card__hint">Configured report templates</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__label">Shared Public Reports</span>
          <strong className="summary-card__value">
            <Quantity value={publicCount} />
          </strong>
          <span className="summary-card__hint">Visible across the organization</span>
        </div>
        <div className="summary-card summary-card--accent">
          <span className="summary-card__label">Personal Views</span>
          <strong className="summary-card__value">
            <Quantity value={savedList.length - publicCount} />
          </strong>
          <span className="summary-card__hint">Private to creator</span>
        </div>
      </div>

      {query.isLoading ? (
        <div aria-live="polite" className="directory-state">
          Loading saved custom reports...
        </div>
      ) : query.isError ? (
        <div className="directory-state directory-state--error" role="alert">
          <FileText aria-hidden="true" size={24} />
          <strong>Unable to load saved reports.</strong>
          <p>Please check your connection or organizational permissions.</p>
          <Button onClick={() => query.refetch()} variant="secondary">
            Retry
          </Button>
        </div>
      ) : savedList.length === 0 ? (
        <div className="directory-state">
          <Bookmark aria-hidden="true" size={24} />
          <strong>No saved reports found.</strong>
          <p>Customize standard reports from the Reports Hub to save reusable views.</p>
        </div>
      ) : (
        <DataTable caption="Saved custom reports and automated delivery schedules">
          <thead>
            <tr>
              <th scope="col">Report Name</th>
              <th scope="col">Base Template</th>
              <th scope="col">Tags</th>
              <th scope="col">Visibility</th>
              <th scope="col">Created Date</th>
              <th className="numeric-cell" scope="col">Action</th>
            </tr>
          </thead>
          <tbody>
            {savedList.map((rep) => (
              <tr key={rep.id}>
                <td>
                  <div className="cell-stack">
                    <Link className="table-row-link" to={appRoutes.savedReportDetail(rep.id)}>
                      {rep.name}
                    </Link>
                    {rep.description ? (
                      <span className="cell-muted">{rep.description}</span>
                    ) : null}
                  </div>
                </td>
                <td>
                  <span className="table-code">{rep.baseReportKey}</span>
                </td>
                <td>
                  {rep.tags ? (
                    <span className="status-badge">{rep.tags}</span>
                  ) : (
                    <span className="cell-muted">—</span>
                  )}
                </td>
                <td>
                  {rep.isPublic ? (
                    <span className="status-badge" style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
                      <Globe aria-hidden="true" size={12} /> Public
                    </span>
                  ) : (
                    <span className="status-badge" style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
                      <Lock aria-hidden="true" size={12} /> Private
                    </span>
                  )}
                </td>
                <td>{rep.createdAt ? formatDate(rep.createdAt) : '—'}</td>
                <td className="numeric-cell">
                  <Link className="table-row-action" to={appRoutes.savedReportDetail(rep.id)}>
                    View schedules
                  </Link>
                </td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      )}
    </section>
  )
}
