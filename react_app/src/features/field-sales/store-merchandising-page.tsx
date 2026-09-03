import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  Plus,
  ShoppingBag,
  X,
} from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate } from '@/shared/format/format'
import {
  listRecentMerchandisingAudits,
  recordMerchandisingAudit,
  type StoreMerchandisingAudit,
} from '@/features/field-sales/field-sales-api'

export function StoreMerchandisingPage() {
  const [isAuditOpen, setIsAuditOpen] = useState(false)
  const queryClient = useQueryClient()

  const { data: audits = [], isLoading, isError } = useQuery({
    queryKey: ['field-sales', 'merchandising'],
    queryFn: listRecentMerchandisingAudits,
  })

  const auditMutation = useMutation({
    mutationFn: recordMerchandisingAudit,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['field-sales', 'merchandising'] })
      setIsAuditOpen(false)
    },
  })

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <Button onClick={() => setIsAuditOpen(true)} type="button" variant="primary">
            <Plus aria-hidden="true" size={16} />
            <span>Record Shelf Audit</span>
          </Button>
        }
        description="Retail shelf audits, planogram compliance, share of shelf, and display branding checks."
        eyebrow="Merchandising & Visibility"
        title="Store Merchandising & Shelf Audits"
      />

      <div className="summary-strip">
        <div className="metric-cell">
          <span className="metric-label">Audits Logged</span>
          <strong className="metric-value">{audits.length}</strong>
        </div>
      </div>

      <div className="table-card">
        {isLoading ? (
          <div className="directory-state">Loading shelf audits...</div>
        ) : isError ? (
          <div className="directory-state directory-state--error">Failed to load shelf audits.</div>
        ) : audits.length === 0 ? (
          <div className="directory-state">
            <ShoppingBag aria-hidden="true" size={32} />
            <p>No merchandising audits recorded yet. Conduct an in-store shelf audit.</p>
          </div>
        ) : (
          <DataTable caption="Store Shelf Audits">
            <thead>
              <tr>
                <th scope="col">Audit Date</th>
                <th scope="col">Store / Retailer</th>
                <th scope="col">Audit Type</th>
                <th scope="col" style={{ textAlign: 'right' }}>Planogram Compliance</th>
                <th scope="col" style={{ textAlign: 'right' }}>Share of Shelf</th>
                <th scope="col">Remarks</th>
              </tr>
            </thead>
            <tbody>
              {audits.map((a: StoreMerchandisingAudit) => (
                <tr key={a.id}>
                  <td><strong>{formatDate(a.auditDate)}</strong></td>
                  <td><strong>{a.contactName || 'Retail Outlet'}</strong></td>
                  <td><StatusChip status={a.auditType} /></td>
                  <td style={{ textAlign: 'right' }}>
                    <strong>{a.planogramCompliancePercent != null ? `${a.planogramCompliancePercent}%` : 'â€”'}</strong>
                  </td>
                  <td style={{ textAlign: 'right' }}>
                    <strong>{a.shareOfShelfPercent != null ? `${a.shareOfShelfPercent}%` : 'â€”'}</strong>
                  </td>
                  <td>{a.remarks || 'â€”'}</td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        )}
      </div>

      {isAuditOpen ? (
        <CreateAuditModal
          isPending={auditMutation.isPending}
          onClose={() => setIsAuditOpen(false)}
          onSubmit={(payload) => auditMutation.mutate(payload)}
        />
      ) : null}
    </section>
  )
}

function CreateAuditModal({
  onClose,
  onSubmit,
  isPending,
}: {
  onClose: () => void
  onSubmit: (payload: { contactId: string; auditDate: string; auditType: string; planogramCompliancePercent?: number; shareOfShelfPercent?: number; remarks?: string }) => void
  isPending: boolean
}) {
  const [contactId, setContactId] = useState('')
  const [auditDate, setAuditDate] = useState(new Date().toISOString().slice(0, 10))
  const [auditType, setAuditType] = useState('PLANOGRAM')
  const [planogramCompliancePercent, setPlanogramCompliancePercent] = useState(90)
  const [shareOfShelfPercent, setShareOfShelfPercent] = useState(40)
  const [remarks, setRemarks] = useState('')

  return (
    <div className="modal-backdrop">
      <div className="modal-card" style={{ maxWidth: 440 }}>
        <div className="modal-header">
          <h2 className="modal-title">Record Shelf Merchandising Audit</h2>
          <button aria-label="Close" className="button button--ghost" onClick={onClose} type="button">
            <X aria-hidden="true" size={18} />
          </button>
        </div>

        <form
          onSubmit={(e) => {
            e.preventDefault()
            onSubmit({
              contactId,
              auditDate,
              auditType,
              planogramCompliancePercent,
              shareOfShelfPercent,
              remarks: remarks || undefined,
            })
          }}
        >
          <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <div className="form-field">
              <label className="form-label" htmlFor="audit-cid">Retailer Contact UUID *</label>
              <input
                className="form-input"
                id="audit-cid"
                onChange={(e) => setContactId(e.target.value)}
                placeholder="Customer UUID"
                required
                value={contactId}
              />
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              <div className="form-field">
                <label className="form-label" htmlFor="audit-dt">Date</label>
                <input
                  className="form-input"
                  id="audit-dt"
                  onChange={(e) => setAuditDate(e.target.value)}
                  type="date"
                  value={auditDate}
                />
              </div>

              <div className="form-field">
                <label className="form-label" htmlFor="audit-tp">Audit Type</label>
                <select
                  className="form-input"
                  id="audit-tp"
                  onChange={(e) => setAuditType(e.target.value)}
                  value={auditType}
                >
                  <option value="PLANOGRAM">Planogram Audit</option>
                  <option value="SHELF_SPACE">Shelf Space %</option>
                  <option value="COMPETITOR_PRICING">Competitor Pricing</option>
                  <option value="DISPLAY_STAND">FSDU / Standee</option>
                </select>
              </div>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              <div className="form-field">
                <label className="form-label" htmlFor="audit-plan">Planogram %</label>
                <input
                  className="form-input"
                  id="audit-plan"
                  max={100}
                  min={0}
                  onChange={(e) => setPlanogramCompliancePercent(parseFloat(e.target.value) || 0)}
                  type="number"
                  value={planogramCompliancePercent}
                />
              </div>

              <div className="form-field">
                <label className="form-label" htmlFor="audit-share">Share of Shelf %</label>
                <input
                  className="form-input"
                  id="audit-share"
                  max={100}
                  min={0}
                  onChange={(e) => setShareOfShelfPercent(parseFloat(e.target.value) || 0)}
                  type="number"
                  value={shareOfShelfPercent}
                />
              </div>
            </div>

            <div className="form-field">
              <label className="form-label" htmlFor="audit-rem">Remarks / Competitor Insights</label>
              <textarea
                className="form-input"
                id="audit-rem"
                onChange={(e) => setRemarks(e.target.value)}
                placeholder="Prominent eye-level placement..."
                rows={2}
                value={remarks}
              />
            </div>
          </div>

          <div className="modal-footer">
            <Button onClick={onClose} type="button" variant="secondary">Cancel</Button>
            <Button disabled={isPending || !contactId} type="submit" variant="primary">
              {isPending ? 'Saving...' : 'Save Audit'}
            </Button>
          </div>
        </form>
      </div>
    </div>
  )
}
