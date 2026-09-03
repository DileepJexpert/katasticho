import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Link } from 'react-router-dom'
import {
  FileText,
  Plus,
  X,
} from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate } from '@/shared/format/format'
import {
  createDcr,
  listMyDcrs,
} from '@/features/field-sales/field-sales-api'

export function DcrPage() {
  const [isCreateOpen, setIsCreateOpen] = useState(false)
  const queryClient = useQueryClient()

  const { data: dcrs = [], isLoading, isError } = useQuery({
    queryKey: ['mr', 'dcr', 'my'],
    queryFn: () => listMyDcrs(),
  })

  const createMutation = useMutation({
    mutationFn: createDcr,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['mr', 'dcr'] })
      setIsCreateOpen(false)
    },
  })

  const totalCalls = dcrs.reduce((s, d) => s + (d.totalCalls || 0), 0)
  const totalPob = dcrs.reduce((s, d) => s + Number(d.totalPobValue || 0), 0)

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <Button onClick={() => setIsCreateOpen(true)} type="button" variant="primary">
            <Plus aria-hidden="true" size={16} />
            <span>Create Daily Call Report</span>
          </Button>
        }
        description="Doctor calls, chemist visits, product detailing, and Personal Order Booking (POB)."
        eyebrow="Pharma MR Reporting"
        title="Daily Call Reports (DCR)"
      />

      <div className="summary-strip">
        <div className="metric-cell">
          <span className="metric-label">DCRs Filed</span>
          <strong className="metric-value">{dcrs.length}</strong>
        </div>
        <div className="metric-cell">
          <span className="metric-label">Total Calls Logged</span>
          <strong className="metric-value">{totalCalls}</strong>
        </div>
        <div className="metric-cell">
          <span className="metric-label">Total POB Booked</span>
          <strong className="metric-value"><Money amount={totalPob} /></strong>
        </div>
      </div>

      <div className="table-card">
        {isLoading ? (
          <div className="directory-state">Loading Daily Call Reports...</div>
        ) : isError ? (
          <div className="directory-state directory-state--error">Failed to load DCRs.</div>
        ) : dcrs.length === 0 ? (
          <div className="directory-state">
            <FileText aria-hidden="true" size={32} />
            <p>No DCRs filed yet. Create a Daily Call Report for today's field activity.</p>
          </div>
        ) : (
          <DataTable caption="Daily Call Reports">
            <thead>
              <tr>
                <th scope="col">Date</th>
                <th scope="col">Work Type</th>
                <th scope="col">Beat / Area</th>
                <th scope="col" style={{ textAlign: 'right' }}>Doctor Calls</th>
                <th scope="col" style={{ textAlign: 'right' }}>Chemist Calls</th>
                <th scope="col" style={{ textAlign: 'right' }}>POB Value</th>
                <th scope="col">Status</th>
              </tr>
            </thead>
            <tbody>
              {dcrs.map((d) => (
                <tr key={d.id}>
                  <td>
                    <Link className="table-link" to={`/mr/dcr/${d.id}`}>
                      <strong>{formatDate(d.reportDate)}</strong>
                    </Link>
                  </td>
                  <td><StatusChip status={d.workType} /></td>
                  <td>{d.beatName || 'General Field'}</td>
                  <td style={{ textAlign: 'right' }}><strong>{d.totalDoctorCalls ?? 0}</strong></td>
                  <td style={{ textAlign: 'right' }}>{d.totalChemistCalls ?? 0}</td>
                  <td style={{ textAlign: 'right' }}>
                    <strong><Money amount={d.totalPobValue ?? 0} /></strong>
                  </td>
                  <td><StatusChip status={d.status} /></td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        )}
      </div>

      {isCreateOpen ? (
        <CreateDcrModal
          isPending={createMutation.isPending}
          onClose={() => setIsCreateOpen(false)}
          onSubmit={(payload) => createMutation.mutate(payload)}
        />
      ) : null}
    </section>
  )
}

function CreateDcrModal({
  onClose,
  onSubmit,
  isPending,
}: {
  onClose: () => void
  onSubmit: (payload: { reportDate: string; workType: string; beatId?: string; notes?: string }) => void
  isPending: boolean
}) {
  const [reportDate, setReportDate] = useState(new Date().toISOString().slice(0, 10))
  const [workType, setWorkType] = useState('FIELD_WORK')
  const [beatId, setBeatId] = useState('')
  const [notes, setNotes] = useState('')

  return (
    <div className="modal-backdrop">
      <div className="modal-card" style={{ maxWidth: 440 }}>
        <div className="modal-header">
          <h2 className="modal-title">Create Daily Call Report</h2>
          <button aria-label="Close" className="button button--ghost" onClick={onClose} type="button">
            <X aria-hidden="true" size={18} />
          </button>
        </div>

        <form
          onSubmit={(e) => {
            e.preventDefault()
            onSubmit({ reportDate, workType, beatId: beatId || undefined, notes: notes || undefined })
          }}
        >
          <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              <div className="form-field">
                <label className="form-label" htmlFor="dcr-date">Report Date *</label>
                <input
                  className="form-input"
                  id="dcr-date"
                  onChange={(e) => setReportDate(e.target.value)}
                  required
                  type="date"
                  value={reportDate}
                />
              </div>

              <div className="form-field">
                <label className="form-label" htmlFor="dcr-work">Work Type</label>
                <select
                  className="form-input"
                  id="dcr-work"
                  onChange={(e) => setWorkType(e.target.value)}
                  value={workType}
                >
                  <option value="FIELD_WORK">Field Work</option>
                  <option value="NON_FIELD">Non-Field Work</option>
                  <option value="MEETING">Cycle Meeting / CME</option>
                  <option value="LEAVE">Leave</option>
                </select>
              </div>
            </div>

            <div className="form-field">
              <label className="form-label" htmlFor="dcr-beat">Beat UUID (Optional)</label>
              <input
                className="form-input"
                id="dcr-beat"
                onChange={(e) => setBeatId(e.target.value)}
                placeholder="Optional Beat UUID"
                value={beatId}
              />
            </div>

            <div className="form-field">
              <label className="form-label" htmlFor="dcr-notes">Remarks</label>
              <textarea
                className="form-input"
                id="dcr-notes"
                onChange={(e) => setNotes(e.target.value)}
                placeholder="Day plan summary..."
                rows={2}
                value={notes}
              />
            </div>
          </div>

          <div className="modal-footer">
            <Button onClick={onClose} type="button" variant="secondary">Cancel</Button>
            <Button disabled={isPending} type="submit" variant="primary">
              {isPending ? 'Creating...' : 'Create DCR'}
            </Button>
          </div>
        </form>
      </div>
    </div>
  )
}
