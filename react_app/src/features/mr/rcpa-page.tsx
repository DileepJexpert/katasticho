import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  Activity,
  Plus,
  X,
} from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { formatDate } from '@/shared/format/format'
import {
  listMyRcpaAudits,
  recordRcpaAudit,
  type RcpaAudit,
} from '@/features/field-sales/field-sales-api'

export function RcpaPage() {
  const [isRecordOpen, setIsRecordOpen] = useState(false)
  const queryClient = useQueryClient()

  const { data: audits = [], isLoading, isError } = useQuery({
    queryKey: ['mr', 'rcpa'],
    queryFn: () => listMyRcpaAudits(),
  })

  const createMutation = useMutation({
    mutationFn: recordRcpaAudit,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['mr', 'rcpa'] })
      setIsRecordOpen(false)
    },
  })

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <Button onClick={() => setIsRecordOpen(true)} type="button" variant="primary">
            <Plus aria-hidden="true" size={16} />
            <span>Record RCPA Audit</span>
          </Button>
        }
        description="Retail Chemist Prescription Audit (RCPA), doctor prescription tracking, and competitor share."
        eyebrow="Market Intelligence"
        title="Prescription Audits (RCPA)"
      />

      <div className="summary-strip">
        <div className="metric-cell">
          <span className="metric-label">Audits Logged</span>
          <strong className="metric-value">{audits.length}</strong>
        </div>
      </div>

      <div className="table-card">
        {isLoading ? (
          <div className="directory-state">Loading RCPA audits...</div>
        ) : isError ? (
          <div className="directory-state directory-state--error">Failed to load prescription audits.</div>
        ) : audits.length === 0 ? (
          <div className="directory-state">
            <Activity aria-hidden="true" size={32} />
            <p>No RCPA audits recorded. Conduct a prescription audit at target pharmacies.</p>
          </div>
        ) : (
          <DataTable caption="Prescription Audit Ledger">
            <thead>
              <tr>
                <th scope="col">Audit Date</th>
                <th scope="col">Chemist / Pharmacy</th>
                <th scope="col">Auditor Rep</th>
                <th scope="col" style={{ textAlign: 'right' }}>Products Logged</th>
                <th scope="col">Remarks</th>
              </tr>
            </thead>
            <tbody>
              {audits.map((a: RcpaAudit) => (
                <tr key={a.id}>
                  <td><strong>{formatDate(a.auditDate)}</strong></td>
                  <td><strong>{a.chemistName || a.chemistContactId}</strong></td>
                  <td>{a.salespersonName || 'Representative'}</td>
                  <td style={{ textAlign: 'right' }}>{a.lines?.length || 0}</td>
                  <td>{a.remarks || 'â€”'}</td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        )}
      </div>

      {isRecordOpen ? (
        <CreateRcpaModal
          isPending={createMutation.isPending}
          onClose={() => setIsRecordOpen(false)}
          onSubmit={(payload) => createMutation.mutate(payload)}
        />
      ) : null}
    </section>
  )
}

function CreateRcpaModal({
  onClose,
  onSubmit,
  isPending,
}: {
  onClose: () => void
  onSubmit: (payload: {
    chemistContactId: string
    auditDate: string
    remarks?: string
    lines: Array<{
      productName: string
      brandType: 'OWN' | 'COMPETITOR'
      competitorName?: string
      quantity?: number
    }>
  }) => void
  isPending: boolean
}) {
  const [chemistContactId, setChemistContactId] = useState('')
  const [auditDate, setAuditDate] = useState(new Date().toISOString().slice(0, 10))
  const [ownBrandName, setOwnBrandName] = useState('')
  const [ownBrandQty, setOwnBrandQty] = useState(10)
  const [competitorBrandName, setCompetitorBrandName] = useState('')
  const [competitorQty, setCompetitorQty] = useState(15)
  const [remarks, setRemarks] = useState('')

  return (
    <div className="modal-backdrop">
      <div className="modal-card" style={{ maxWidth: 460 }}>
        <div className="modal-header">
          <h2 className="modal-title">Record Prescription Audit (RCPA)</h2>
          <button aria-label="Close" className="button button--ghost" onClick={onClose} type="button">
            <X aria-hidden="true" size={18} />
          </button>
        </div>

        <form
          onSubmit={(e) => {
            e.preventDefault()
            onSubmit({
              chemistContactId,
              auditDate,
              remarks: remarks || undefined,
              lines: [
                { productName: ownBrandName, brandType: 'OWN', quantity: ownBrandQty },
                { productName: competitorBrandName || 'Competitor', brandType: 'COMPETITOR', competitorName: competitorBrandName, quantity: competitorQty },
              ],
            })
          }}
        >
          <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              <div className="form-field">
                <label className="form-label" htmlFor="rcpa-chem">Chemist Contact UUID *</label>
                <input
                  className="form-input"
                  id="rcpa-chem"
                  onChange={(e) => setChemistContactId(e.target.value)}
                  placeholder="Chemist UUID"
                  required
                  value={chemistContactId}
                />
              </div>

              <div className="form-field">
                <label className="form-label" htmlFor="rcpa-dt">Audit Date *</label>
                <input
                  className="form-input"
                  id="rcpa-dt"
                  onChange={(e) => setAuditDate(e.target.value)}
                  required
                  type="date"
                  value={auditDate}
                />
              </div>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: 12 }}>
              <div className="form-field">
                <label className="form-label" htmlFor="rcpa-own">Our Brand *</label>
                <input
                  className="form-input"
                  id="rcpa-own"
                  onChange={(e) => setOwnBrandName(e.target.value)}
                  placeholder="Telmi-40"
                  required
                  value={ownBrandName}
                />
              </div>

              <div className="form-field">
                <label className="form-label" htmlFor="rcpa-own-qty">Rx Qty *</label>
                <input
                  className="form-input"
                  id="rcpa-own-qty"
                  min={0}
                  onChange={(e) => setOwnBrandQty(parseInt(e.target.value, 10) || 0)}
                  type="number"
                  value={ownBrandQty}
                />
              </div>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: 12 }}>
              <div className="form-field">
                <label className="form-label" htmlFor="rcpa-comp">Competitor Brand</label>
                <input
                  className="form-input"
                  id="rcpa-comp"
                  onChange={(e) => setCompetitorBrandName(e.target.value)}
                  placeholder="Telma-40"
                  value={competitorBrandName}
                />
              </div>

              <div className="form-field">
                <label className="form-label" htmlFor="rcpa-comp-qty">Rx Qty</label>
                <input
                  className="form-input"
                  id="rcpa-comp-qty"
                  min={0}
                  onChange={(e) => setCompetitorQty(parseInt(e.target.value, 10) || 0)}
                  type="number"
                  value={competitorQty}
                />
              </div>
            </div>

            <div className="form-field">
              <label className="form-label" htmlFor="rcpa-rem">Audit Remarks</label>
              <textarea
                className="form-input"
                id="rcpa-rem"
                onChange={(e) => setRemarks(e.target.value)}
                placeholder="Doctor preferring competitor due to scheme offer..."
                rows={2}
                value={remarks}
              />
            </div>
          </div>

          <div className="modal-footer">
            <Button onClick={onClose} type="button" variant="secondary">Cancel</Button>
            <Button disabled={isPending || !chemistContactId || !ownBrandName} type="submit" variant="primary">
              {isPending ? 'Saving...' : 'Save RCPA Audit'}
            </Button>
          </div>
        </form>
      </div>
    </div>
  )
}
