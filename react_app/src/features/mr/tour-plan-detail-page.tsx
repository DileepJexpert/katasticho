import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useNavigate, useParams } from 'react-router-dom'
import {
  ArrowLeft,
  CheckCircle2,
  FileText,
  Plus,
  Send,
  X,
} from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate } from '@/shared/format/format'
import {
  addTourPlanEntry,
  approveTourPlan,
  getTourPlan,
  submitTourPlan,
} from '@/features/field-sales/field-sales-api'

export function TourPlanDetailPage() {
  const { planId = '' } = useParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [isAddEntryOpen, setIsAddEntryOpen] = useState(false)

  const { data: plan, isLoading, isError } = useQuery({
    queryKey: ['mr', 'tour-plans', planId],
    queryFn: () => getTourPlan(planId),
    enabled: !!planId,
  })

  const submitMutation = useMutation({
    mutationFn: () => submitTourPlan(planId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['mr', 'tour-plans', planId] })
    },
  })

  const approveMutation = useMutation({
    mutationFn: () => approveTourPlan(planId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['mr', 'tour-plans', planId] })
    },
  })

  const addEntryMutation = useMutation({
    mutationFn: (payload: { planDate: string; activityType: string; beatId?: string; area?: string; notes?: string }) =>
      addTourPlanEntry(planId, payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['mr', 'tour-plans', planId] })
      setIsAddEntryOpen(false)
    },
  })

  if (isLoading) return <div className="directory-state">Loading tour plan...</div>
  if (isError || !plan) return <DocumentError onBack={() => navigate('/mr/tour-plans')} />

  const entries = plan.entries || []

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <div style={{ display: 'flex', gap: 8 }}>
            {plan.status === 'DRAFT' ? (
              <>
                <Button onClick={() => setIsAddEntryOpen(true)} type="button" variant="secondary">
                  <Plus aria-hidden="true" size={16} />
                  <span>Add Day Itinerary</span>
                </Button>
                <Button
                  disabled={submitMutation.isPending}
                  onClick={() => submitMutation.mutate()}
                  type="button"
                  variant="primary"
                >
                  <Send aria-hidden="true" size={16} />
                  <span>Submit Tour Plan</span>
                </Button>
              </>
            ) : null}

            {plan.status === 'SUBMITTED' ? (
              <Button
                disabled={approveMutation.isPending}
                onClick={() => approveMutation.mutate()}
                type="button"
                variant="primary"
              >
                <CheckCircle2 aria-hidden="true" size={16} />
                <span>Approve Tour Plan</span>
              </Button>
            ) : null}
          </div>
        }
        description={`Rep: ${plan.salespersonName || 'Representative'} | Month: ${plan.planMonth}`}
        eyebrow="Monthly Tour Plan"
        title={`MTP â€” ${plan.planMonth}`}
      />

      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 16 }}>
        <button className="button button--ghost" onClick={() => navigate('/mr/tour-plans')} type="button">
          <ArrowLeft aria-hidden="true" size={16} />
          <span>Back to Tour Plans</span>
        </button>
      </div>

      <div className="summary-strip">
        <div className="metric-cell">
          <span className="metric-label">Status</span>
          <strong className="metric-value"><StatusChip status={plan.status} /></strong>
        </div>
        <div className="metric-cell">
          <span className="metric-label">Days Planned</span>
          <strong className="metric-value">{entries.length}</strong>
        </div>
      </div>

      <div className="table-card">
        <div className="card-header" style={{ padding: '16px 20px', borderBottom: '1px solid var(--k-color-border)' }}>
          <h3 style={{ margin: 0, fontSize: '1rem', fontWeight: 600 }}>Daily Itinerary Schedule</h3>
        </div>

        <DataTable caption="Daily Itinerary Schedule">
          <thead>
            <tr>
              <th scope="col">Date</th>
              <th scope="col">Activity Type</th>
              <th scope="col">Beat / Area</th>
              <th scope="col">Notes</th>
            </tr>
          </thead>
          <tbody>
            {entries.length === 0 ? (
              <tr>
                <td colSpan={4} style={{ textAlign: 'center', padding: 24, color: 'var(--k-color-text-muted)' }}>
                  No day entries added yet. Use "Add Day Itinerary" to build your monthly travel schedule.
                </td>
              </tr>
            ) : (
              entries.map((e) => (
                <tr key={e.id}>
                  <td><strong>{formatDate(e.planDate)}</strong></td>
                  <td><StatusChip status={e.activityType} /></td>
                  <td>{e.beatName || e.area || 'General HQ'}</td>
                  <td>{e.notes || 'â€”'}</td>
                </tr>
              ))
            )}
          </tbody>
        </DataTable>
      </div>

      {isAddEntryOpen ? (
        <AddEntryModal
          isPending={addEntryMutation.isPending}
          onClose={() => setIsAddEntryOpen(false)}
          onSubmit={(payload) => addEntryMutation.mutate(payload)}
        />
      ) : null}
    </section>
  )
}

function AddEntryModal({
  onClose,
  onSubmit,
  isPending,
}: {
  onClose: () => void
  onSubmit: (payload: { planDate: string; activityType: string; beatId?: string; area?: string; notes?: string }) => void
  isPending: boolean
}) {
  const [planDate, setPlanDate] = useState(new Date().toISOString().slice(0, 10))
  const [activityType, setActivityType] = useState('FIELD_VISIT')
  const [area, setArea] = useState('')
  const [notes, setNotes] = useState('')

  return (
    <div className="modal-backdrop">
      <div className="modal-card" style={{ maxWidth: 440 }}>
        <div className="modal-header">
          <h2 className="modal-title">Add Day Itinerary Entry</h2>
          <button aria-label="Close" className="button button--ghost" onClick={onClose} type="button">
            <X aria-hidden="true" size={18} />
          </button>
        </div>

        <form onSubmit={(e) => { e.preventDefault(); onSubmit({ planDate, activityType, area: area || undefined, notes: notes || undefined }) }}>
          <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              <div className="form-field">
                <label className="form-label" htmlFor="ent-dt">Date *</label>
                <input
                  className="form-input"
                  id="ent-dt"
                  onChange={(e) => setPlanDate(e.target.value)}
                  required
                  type="date"
                  value={planDate}
                />
              </div>

              <div className="form-field">
                <label className="form-label" htmlFor="ent-tp">Activity</label>
                <select
                  className="form-input"
                  id="ent-tp"
                  onChange={(e) => setActivityType(e.target.value)}
                  value={activityType}
                >
                  <option value="FIELD_VISIT">Field Visit</option>
                  <option value="JOINT_FIELD_WORK">Joint Field Work</option>
                  <option value="HQ_DAY">HQ Day / Admin</option>
                  <option value="CONFERENCE">CME / Conference</option>
                  <option value="LEAVE">Leave</option>
                </select>
              </div>
            </div>

            <div className="form-field">
              <label className="form-label" htmlFor="ent-area">Area / Town</label>
              <input
                className="form-input"
                id="ent-area"
                onChange={(e) => setArea(e.target.value)}
                placeholder="South Clinic Cluster"
                value={area}
              />
            </div>

            <div className="form-field">
              <label className="form-label" htmlFor="ent-notes">Coverage Objective</label>
              <textarea
                className="form-input"
                id="ent-notes"
                onChange={(e) => setNotes(e.target.value)}
                placeholder="Detailing new cardiology portfolio..."
                rows={2}
                value={notes}
              />
            </div>
          </div>

          <div className="modal-footer">
            <Button onClick={onClose} type="button" variant="secondary">Cancel</Button>
            <Button disabled={isPending} type="submit" variant="primary">
              {isPending ? 'Adding...' : 'Add Itinerary'}
            </Button>
          </div>
        </form>
      </div>
    </div>
  )
}

function DocumentError({ onBack }: { onBack: () => void }) {
  return (
    <section className="workspace-page">
      <div className="directory-state directory-state--error" role="alert">
        <FileText aria-hidden="true" size={24} />
        <p>Tour plan could not be found or loaded.</p>
        <Button onClick={onBack} type="button" variant="secondary">Return to Tour Plans</Button>
      </div>
    </section>
  )
}
