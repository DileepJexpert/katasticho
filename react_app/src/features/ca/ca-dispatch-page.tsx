import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  CheckCircle2,
  Send,
  Sparkles,
} from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import {
  dispatchReports,
  getDispatchHistory,
  getCaDashboard,
} from '@/features/ca/ca-api'

export function CaDispatchPage() {
  const queryClient = useQueryClient()
  const [periodLabel, setPeriodLabel] = useState('May 2026')
  const [selectedReportTypes, setSelectedReportTypes] = useState<string[]>(['PL', 'BS', 'GST'])
  const [includeAiCommentary, setIncludeAiCommentary] = useState(true)
  const [customMsg, setCustomMsg] = useState('Enclosed please find your monthly financial reports and statutory compliance review.')

  const dashboardQuery = useQuery({
    queryKey: ['ca-dashboard'],
    queryFn: getCaDashboard,
  })

  const historyQuery = useQuery({
    queryKey: ['ca-dispatch-history'],
    queryFn: getDispatchHistory,
  })

  const dispatchMutation = useMutation({
    mutationFn: () =>
      dispatchReports({
        allClients: true,
        periodLabel,
        reportTypes: selectedReportTypes,
        sendVia: 'EMAIL',
        includeAiCommentary,
        customMessage: customMsg,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['ca-dispatch-history'] })
    },
  })

  const toggleReportType = (type: string) => {
    setSelectedReportTypes((prev) =>
      prev.includes(type) ? prev.filter((t) => t !== type) : [...prev, type]
    )
  }

  const clients = dashboardQuery.data?.clients ?? []
  const history = historyQuery.data ?? []

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Mass Document Dispatch & Client Communications"
        title="Batch Financial Statements & Tax Pack Dispatcher"
        description="One-click generation and email dispatch of Monthly P&L, Balance Sheet, GST Summaries, and AI executive commentary to all client directors."
      />

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 'var(--space-md)', marginBottom: 'var(--space-md)' }}>
        {/* Dispatch Configuration */}
        <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
          <h3 style={{ fontSize: '1.05rem', fontWeight: 600, marginBottom: 'var(--space-sm)' }}>
            Batch Pack Configuration
          </h3>
          <p className="cell-muted" style={{ fontSize: '0.8rem', marginBottom: 'var(--space-md)' }}>
            Target: All {clients.length} active client organizations.
          </p>

          <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-md)' }}>
            <div>
              <label style={{ fontSize: '0.85rem', fontWeight: 600, display: 'block', marginBottom: 4 }}>
                Reporting Period Label
              </label>
              <input
                className="input-field"
                onChange={(e) => setPeriodLabel(e.target.value)}
                placeholder="e.g. May 2026 or Q1 FY26-27"
                style={{ width: '100%', padding: '8px 12px', borderRadius: 'var(--radius-md)', border: '1px solid var(--color-border)' }}
                type="text"
                value={periodLabel}
              />
            </div>

            <div>
              <label style={{ fontSize: '0.85rem', fontWeight: 600, display: 'block', marginBottom: 6 }}>
                Include Financial Reports in Pack:
              </label>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
                {[
                  { id: 'PL', label: 'Profit & Loss Statement' },
                  { id: 'BS', label: 'Balance Sheet' },
                  { id: 'GST', label: 'GST Input/Output Summary' },
                  { id: 'AR_AGING', label: 'Debtors Aging' },
                ].map((rep) => (
                  <label
                    key={rep.id}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: 6,
                      padding: '6px 12px',
                      borderRadius: 'var(--radius-md)',
                      border: '1px solid var(--color-border)',
                      background: selectedReportTypes.includes(rep.id) ? 'rgba(15, 133, 118, 0.08)' : 'inherit',
                      cursor: 'pointer',
                      fontSize: '0.85rem',
                    }}
                  >
                    <input
                      checked={selectedReportTypes.includes(rep.id)}
                      onChange={() => toggleReportType(rep.id)}
                      type="checkbox"
                    />
                    <span>{rep.label}</span>
                  </label>
                ))}
              </div>
            </div>

            <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer', fontSize: '0.85rem' }}>
              <input
                checked={includeAiCommentary}
                onChange={(e) => setIncludeAiCommentary(e.target.checked)}
                type="checkbox"
              />
              <Sparkles size={16} color="var(--color-primary)" />
              <strong>Include AI Executive Variance Commentary in client emails</strong>
            </label>

            <div>
              <label style={{ fontSize: '0.85rem', fontWeight: 600, display: 'block', marginBottom: 4 }}>
                Cover Message to Client Directors
              </label>
              <textarea
                className="input-field"
                onChange={(e) => setCustomMsg(e.target.value)}
                rows={3}
                style={{ width: '100%', padding: '8px 12px', borderRadius: 'var(--radius-md)', border: '1px solid var(--color-border)', fontFamily: 'inherit' }}
                value={customMsg}
              />
            </div>

            <Button
              disabled={dispatchMutation.isPending || selectedReportTypes.length === 0}
              onClick={() => dispatchMutation.mutate()}
              variant="primary"
            >
              <Send size={14} style={{ marginRight: 6 }} />
              {dispatchMutation.isPending ? 'Queuing Batch Dispatch...' : `Queue & Send Reports to ${clients.length} Clients`}
            </Button>
          </div>
        </div>

        {/* Dispatch History */}
        <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
          <h3 style={{ fontSize: '1.05rem', fontWeight: 600, marginBottom: 'var(--space-sm)' }}>
            Recent Dispatch Deliveries
          </h3>
          <DataTable caption="Report Dispatch Log">
            <thead>
              <tr>
                <th scope="col">Period</th>
                <th scope="col">Included Reports</th>
                <th scope="col">AI Commentary</th>
                <th scope="col">Status</th>
                <th scope="col">Dispatched At</th>
              </tr>
            </thead>
            <tbody>
              {history.map((h) => (
                <tr key={h.id}>
                  <td><strong>{h.periodLabel}</strong></td>
                  <td>{h.reportTypes?.join(', ')}</td>
                  <td>{h.aiCommentary ? <CheckCircle2 color="var(--color-success)" size={16} /> : '-'}</td>
                  <td><StatusChip status={h.status} /></td>
                  <td className="cell-muted" style={{ fontSize: '0.8rem' }}>
                    {h.sentAt ? new Date(h.sentAt).toLocaleString() : 'Queued'}
                  </td>
                </tr>
              ))}
              {history.length === 0 && (
                <tr>
                  <td colSpan={5} style={{ textAlign: 'center', padding: 'var(--space-lg)', color: 'var(--color-text-secondary)' }}>
                    No recent report dispatches.
                  </td>
                </tr>
              )}
            </tbody>
          </DataTable>
        </div>
      </div>
    </section>
  )
}
