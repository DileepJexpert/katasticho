import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  CheckCircle2,
  RefreshCw,
} from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import {
  generateComplianceDeadlines,
  listComplianceDeadlines,
  markComplianceFiled,
  type CaComplianceDeadline,
} from '@/features/ca/ca-api'

export function CaCompliancePage() {
  const queryClient = useQueryClient()
  const [selectedStatus, setSelectedStatus] = useState<string>('')
  const [selectedType, setSelectedType] = useState<string>('')
  const [activeFilingModal, setActiveFilingModal] = useState<CaComplianceDeadline | null>(null)
  const [filingReference, setFilingReference] = useState('')
  const [filingNotes, setFilingNotes] = useState('')

  // Queries
  const deadlinesQuery = useQuery({
    queryKey: ['ca-compliance-deadlines', selectedStatus, selectedType],
    queryFn: () => listComplianceDeadlines(selectedType || undefined, selectedStatus || undefined),
  })

  // Mutations
  const markFiledMutation = useMutation({
    mutationFn: ({ id, ref, notes }: { id: string; ref: string; notes: string }) =>
      markComplianceFiled(id, { filingReference: ref, notes }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['ca-compliance-deadlines'] })
      setActiveFilingModal(null)
      setFilingReference('')
      setFilingNotes('')
    },
  })

  const generateMutation = useMutation({
    mutationFn: () => generateComplianceDeadlines(),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['ca-compliance-deadlines'] })
    },
  })

  const deadlines = deadlinesQuery.data ?? []
  const pendingCount = deadlines.filter((d) => d.status === 'PENDING').length
  const overdueCount = deadlines.filter((d) => d.status === 'OVERDUE').length
  const filedCount = deadlines.filter((d) => d.status === 'FILED').length

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Practice Compliance & Due Date Tracker"
        title="Cross-Client Statutory Compliance Calendar"
        description="Unified tracking across all client organizations for GSTR-1, GSTR-3B, TDS Form 26Q/24Q, Advance Tax, Annual Filings, and Professional Tax."
        actions={
          <Button
            disabled={generateMutation.isPending}
            onClick={() => generateMutation.mutate()}
            variant="secondary"
          >
            <RefreshCw aria-hidden="true" size={14} style={{ marginRight: 6 }} />
            Auto-Generate Due Dates
          </Button>
        }
      />

      {/* KPI Strip */}
      <div className="summary-strip">
        <div className="summary-card">
          <span className="summary-card__label">Pending Statutory Filings</span>
          <strong className="summary-card__value" style={{ color: 'var(--color-primary)' }}>
            <Quantity value={pendingCount} /> Filings
          </strong>
          <span className="summary-card__hint">Upcoming due dates</span>
        </div>

        <div className="summary-card">
          <span className="summary-card__label">Overdue Compliance</span>
          <strong className="summary-card__value" style={{ color: 'var(--color-error)' }}>
            <Quantity value={overdueCount} /> Overdue
          </strong>
          <span className="summary-card__hint">Late fee / penalty risk</span>
        </div>

        <div className="summary-card summary-card--accent">
          <span className="summary-card__label">Filed & Certified</span>
          <strong className="summary-card__value" style={{ color: 'var(--color-success)' }}>
            <Quantity value={filedCount} /> Filed
          </strong>
          <span className="summary-card__hint">ARN & challans archived</span>
        </div>
      </div>

      {/* Deadlines Table */}
      <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 'var(--space-md)' }}>
          <h3 style={{ fontSize: '1.05rem', fontWeight: 600 }}>Statutory Obligations Ledger</h3>
          <div style={{ display: 'flex', gap: 'var(--space-sm)' }}>
            <select
              className="select-field"
              onChange={(e) => setSelectedType(e.target.value)}
              style={{ padding: '6px 12px', borderRadius: 'var(--radius-md)', border: '1px solid var(--color-border)', fontSize: '0.85rem' }}
              value={selectedType}
            >
              <option value="">All Return Types</option>
              <option value="GSTR-1">GSTR-1 Monthly</option>
              <option value="GSTR-3B">GSTR-3B Monthly</option>
              <option value="TDS_26Q">TDS 26Q Quarterly</option>
              <option value="ADVANCE_TAX">Advance Tax Installment</option>
              <option value="IT_RETURN">Income Tax Return</option>
            </select>

            <select
              className="select-field"
              onChange={(e) => setSelectedStatus(e.target.value)}
              style={{ padding: '6px 12px', borderRadius: 'var(--radius-md)', border: '1px solid var(--color-border)', fontSize: '0.85rem' }}
              value={selectedStatus}
            >
              <option value="">All Statuses</option>
              <option value="PENDING">Pending</option>
              <option value="OVERDUE">Overdue</option>
              <option value="FILED">Filed</option>
            </select>
          </div>
        </div>

        <DataTable caption="Statutory Compliance Deadlines Matrix">
          <thead>
            <tr>
              <th scope="col">Client Organization</th>
              <th scope="col">Filing & Period</th>
              <th scope="col">Statutory Due Date</th>
              <th scope="col">Status</th>
              <th scope="col">Filing Acknowledgement (ARN)</th>
              <th className="numeric-cell" scope="col">Action</th>
            </tr>
          </thead>
          <tbody>
            {deadlines.map((d) => (
              <tr key={d.id}>
                <td>
                  <strong>{d.clientOrgName}</strong>
                </td>
                <td>
                  <strong>{d.deadlineType}</strong>
                  <div className="cell-muted" style={{ fontSize: '0.75rem' }}>
                    {d.periodLabel}
                  </div>
                </td>
                <td>
                  <span style={{ fontWeight: 600, fontSize: '0.85rem' }}>{d.dueDate}</span>
                </td>
                <td>
                  <StatusChip status={d.status} />
                </td>
                <td>
                  {d.filingReference ? (
                    <div>
                      <code>{d.filingReference}</code>
                      {d.filedAt && (
                        <span className="cell-muted" style={{ display: 'block', fontSize: '0.75rem' }}>
                          Filed: {new Date(d.filedAt).toLocaleDateString()}
                        </span>
                      )}
                    </div>
                  ) : (
                    <span className="cell-muted" style={{ fontSize: '0.8rem' }}>Unfiled</span>
                  )}
                </td>
                <td className="numeric-cell">
                  {d.status !== 'FILED' && (
                    <Button
                      onClick={() => setActiveFilingModal(d)}
                      variant="primary"
                    >
                      <CheckCircle2 size={13} style={{ marginRight: 4 }} />
                      Mark Filed
                    </Button>
                  )}
                </td>
              </tr>
            ))}
            {deadlines.length === 0 && (
              <tr>
                <td colSpan={6} style={{ textAlign: 'center', padding: 'var(--space-lg)', color: 'var(--color-text-secondary)' }}>
                  No statutory deadlines found for current filter.
                </td>
              </tr>
            )}
          </tbody>
        </DataTable>
      </div>

      {/* MARK FILED MODAL */}
      {activeFilingModal && (
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
              maxWidth: 480,
              backgroundColor: 'var(--color-surface)',
              borderRadius: 'var(--radius-lg)',
              padding: 'var(--space-lg)',
              border: '1px solid var(--color-border)',
            }}
          >
            <h3 style={{ fontSize: '1.2rem', fontWeight: 600, marginBottom: 'var(--space-md)' }}>
              Record Statutory Filing Completion
            </h3>
            <p className="cell-muted" style={{ fontSize: '0.85rem', marginBottom: 'var(--space-md)' }}>
              Client: <strong>{activeFilingModal.clientOrgName}</strong> &bull; {activeFilingModal.deadlineType} ({activeFilingModal.periodLabel})
            </p>

            <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-md)', marginBottom: 'var(--space-lg)' }}>
              <div>
                <label style={{ fontSize: '0.85rem', fontWeight: 600, display: 'block', marginBottom: 4 }}>
                  ARN / Challan Identification Number (CIN)
                </label>
                <input
                  className="input-field"
                  onChange={(e) => setFilingReference(e.target.value)}
                  placeholder="e.g. AA2705260019283"
                  style={{ width: '100%', padding: '8px 12px', borderRadius: 'var(--radius-md)', border: '1px solid var(--color-border)' }}
                  type="text"
                  value={filingReference}
                />
              </div>

              <div>
                <label style={{ fontSize: '0.85rem', fontWeight: 600, display: 'block', marginBottom: 4 }}>
                  Auditor Notes & Summary
                </label>
                <textarea
                  className="input-field"
                  onChange={(e) => setFilingNotes(e.target.value)}
                  placeholder="e.g. Filed on GST portal, tax liability ₹1,24,000 paid via net banking."
                  rows={3}
                  style={{ width: '100%', padding: '8px 12px', borderRadius: 'var(--radius-md)', border: '1px solid var(--color-border)', fontFamily: 'inherit' }}
                  value={filingNotes}
                />
              </div>
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
              <Button onClick={() => setActiveFilingModal(null)} variant="secondary">
                Cancel
              </Button>
              <Button
                disabled={markFiledMutation.isPending || !filingReference}
                onClick={() =>
                  markFiledMutation.mutate({
                    id: activeFilingModal.id,
                    ref: filingReference,
                    notes: filingNotes,
                  })
                }
                variant="primary"
              >
                Confirm & Archive Filing
              </Button>
            </div>
          </div>
        </div>
      )}
    </section>
  )
}
