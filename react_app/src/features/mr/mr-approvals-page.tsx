import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  CheckCircle2,
  ClipboardCheck,
} from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import {
  approveTourPlan,
  listPendingTourPlans,
  rejectTourPlan,
  type TourPlan,
} from '@/features/field-sales/field-sales-api'

export function MrApprovalsPage() {
  const queryClient = useQueryClient()

  const { data: plans = [], isLoading: isPlansLoading } = useQuery({
    queryKey: ['mr', 'tour-plans', 'pending'],
    queryFn: () => listPendingTourPlans(),
  })

  const approvePlanMutation = useMutation({
    mutationFn: approveTourPlan,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['mr', 'tour-plans'] })
    },
  })

  const rejectPlanMutation = useMutation({
    mutationFn: (id: string) => rejectTourPlan(id, 'Manager rejection'),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['mr', 'tour-plans'] })
    },
  })

  return (
    <section className="workspace-page">
      <PageHeader
        actions={null}
        description="Unified manager inbox for signing off Monthly Tour Plans (MTP), Daily Call Reports (DCR), and Field Allowances."
        eyebrow="Pharma MR Governance"
        title="MR Approvals Hub"
      />

      <div className="summary-strip">
        <div className="metric-cell">
          <span className="metric-label">Pending Tour Plans</span>
          <strong className="metric-value">{plans.length}</strong>
        </div>
      </div>

      <div className="table-card">
        <div className="card-header" style={{ padding: '16px 20px', borderBottom: '1px solid var(--k-color-border)' }}>
          <h3 style={{ margin: 0, fontSize: '1rem', fontWeight: 600 }}>Submitted Tour Plans Awaiting Signoff</h3>
        </div>

        {isPlansLoading ? (
          <div className="directory-state">Loading pending approvals...</div>
        ) : plans.length === 0 ? (
          <div className="directory-state">
            <ClipboardCheck aria-hidden="true" size={32} />
            <p>All caught up! No tour plans or daily reports pending manager review.</p>
          </div>
        ) : (
          <DataTable caption="Pending Tour Plans">
            <thead>
              <tr>
                <th scope="col">Plan Month</th>
                <th scope="col">Representative</th>
                <th scope="col">Notes</th>
                <th scope="col" style={{ textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {plans.map((p: TourPlan) => (
                <tr key={p.id}>
                  <td><strong>{p.planMonth}</strong></td>
                  <td>{p.salespersonName || 'Representative'}</td>
                  <td>{p.notes || 'â€”'}</td>
                  <td style={{ textAlign: 'right' }}>
                    <div style={{ display: 'inline-flex', gap: 6 }}>
                      <Button
                        disabled={approvePlanMutation.isPending}
                        onClick={() => approvePlanMutation.mutate(p.id)}
                        type="button"
                        variant="secondary"
                      >
                        <CheckCircle2 aria-hidden="true" size={14} />
                        <span>Approve MTP</span>
                      </Button>
                      <Button
                        disabled={rejectPlanMutation.isPending}
                        onClick={() => rejectPlanMutation.mutate(p.id)}
                        type="button"
                        variant="ghost"
                      >
                        <span>Reject</span>
                      </Button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        )}
      </div>
    </section>
  )
}
