import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Link } from 'react-router-dom'
import {
  Compass,
  Plus,
  X,
} from 'lucide-react'
import {
  Button,
  DataTable,
  PageHeader,
  StatusChip,
} from '@/design-system'
import {
  createTourPlan,
  listMyTourPlans,
} from '@/features/field-sales/field-sales-api'

export function TourPlansPage() {
  const [isCreateOpen, setIsCreateOpen] = useState(false)
  const queryClient = useQueryClient()

  const { data: plans = [], isLoading, isError } = useQuery({
    queryKey: ['mr', 'tour-plans', 'my'],
    queryFn: () => listMyTourPlans(),
  })

  const createMutation = useMutation({
    mutationFn: ({ planMonth, notes }: { planMonth: string; notes?: string }) =>
      createTourPlan(planMonth, notes),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['mr', 'tour-plans'] })
      setIsCreateOpen(false)
    },
  })

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <Button onClick={() => setIsCreateOpen(true)} type="button" variant="primary">
            <Plus aria-hidden="true" size={16} />
            <span>Create Monthly Tour Plan</span>
          </Button>
        }
        description="Monthly itinerary planning, territory coverage schedules, and manager approvals."
        eyebrow="Pharma MR Itinerary"
        title="Monthly Tour Plans (MTP)"
      />

      <div className="summary-strip">
        <div className="metric-cell">
          <span className="metric-label">Total Plans</span>
          <strong className="metric-value">{plans.length}</strong>
        </div>
      </div>

      <div className="table-card">
        {isLoading ? (
          <div className="directory-state">Loading tour plans...</div>
        ) : isError ? (
          <div className="directory-state directory-state--error">Failed to load tour plans.</div>
        ) : plans.length === 0 ? (
          <div className="directory-state">
            <Compass aria-hidden="true" size={32} />
            <p>No monthly tour plans created yet. Plan your field beat itinerary for the upcoming month.</p>
          </div>
        ) : (
          <DataTable caption="Monthly Tour Plans">
            <thead>
              <tr>
                <th scope="col">Plan Month</th>
                <th scope="col">Medical Representative</th>
                <th scope="col">Remarks</th>
                <th scope="col">Status</th>
              </tr>
            </thead>
            <tbody>
              {plans.map((p) => (
                <tr key={p.id}>
                  <td>
                    <Link className="table-link" to={`/mr/tour-plans/${p.id}`}>
                      <strong>{p.planMonth}</strong>
                    </Link>
                  </td>
                  <td>{p.salespersonName || 'Me'}</td>
                  <td>{p.notes || 'â€”'}</td>
                  <td><StatusChip status={p.status} /></td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        )}
      </div>

      {isCreateOpen ? (
        <CreateTourPlanModal
          isPending={createMutation.isPending}
          onClose={() => setIsCreateOpen(false)}
          onSubmit={(payload) => createMutation.mutate(payload)}
        />
      ) : null}
    </section>
  )
}

function CreateTourPlanModal({
  onClose,
  onSubmit,
  isPending,
}: {
  onClose: () => void
  onSubmit: (payload: { planMonth: string; notes?: string }) => void
  isPending: boolean
}) {
  const [planMonth, setPlanMonth] = useState(new Date().toISOString().slice(0, 7) + '-01')
  const [notes, setNotes] = useState('')

  return (
    <div className="modal-backdrop">
      <div className="modal-card" style={{ maxWidth: 440 }}>
        <div className="modal-header">
          <h2 className="modal-title">Create Monthly Tour Plan</h2>
          <button aria-label="Close" className="button button--ghost" onClick={onClose} type="button">
            <X aria-hidden="true" size={18} />
          </button>
        </div>

        <form onSubmit={(e) => { e.preventDefault(); onSubmit({ planMonth, notes: notes || undefined }) }}>
          <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <div className="form-field">
              <label className="form-label" htmlFor="tp-month">Plan Month (First of Month) *</label>
              <input
                className="form-input"
                id="tp-month"
                onChange={(e) => setPlanMonth(e.target.value)}
                required
                type="date"
                value={planMonth}
              />
            </div>

            <div className="form-field">
              <label className="form-label" htmlFor="tp-notes">Notes / Coverage Objective</label>
              <textarea
                className="form-input"
                id="tp-notes"
                onChange={(e) => setNotes(e.target.value)}
                placeholder="Targeting key clinic clusters..."
                rows={2}
                value={notes}
              />
            </div>
          </div>

          <div className="modal-footer">
            <Button onClick={onClose} type="button" variant="secondary">Cancel</Button>
            <Button disabled={isPending} type="submit" variant="primary">
              {isPending ? 'Creating...' : 'Create Plan'}
            </Button>
          </div>
        </form>
      </div>
    </div>
  )
}
