import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  Award,
  Plus,
  X,
} from 'lucide-react'
import {
  Button,
  DataTable,
  Money,
  PageHeader,
} from '@/design-system'
import { formatDate } from '@/shared/format/format'
import {
  createSalesmanTarget,
  listSalesmanTargets,
  updateTargetAchievement,
  type SalesmanTarget,
} from '@/features/field-sales/field-sales-api'

export function SalesmanTargetsPage() {
  const [isCreateOpen, setIsCreateOpen] = useState(false)
  const [selectedTarget, setSelectedTarget] = useState<SalesmanTarget | null>(null)
  const queryClient = useQueryClient()

  const { data, isLoading, isError } = useQuery({
    queryKey: ['field-sales', 'targets'],
    queryFn: () => listSalesmanTargets(0, 50),
  })

  const targets: SalesmanTarget[] = data?.content || []

  const createMutation = useMutation({
    mutationFn: createSalesmanTarget,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['field-sales', 'targets'] })
      setIsCreateOpen(false)
    },
  })

  const updateMutation = useMutation({
    mutationFn: ({ id, achieved }: { id: string; achieved: number }) => updateTargetAchievement(id, achieved),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['field-sales', 'targets'] })
      setSelectedTarget(null)
    },
  })

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <Button onClick={() => setIsCreateOpen(true)} type="button" variant="primary">
            <Plus aria-hidden="true" size={16} />
            <span>Create Target</span>
          </Button>
        }
        description="Sales quotas, monthly revenue targets, and achievement tracking."
        eyebrow="Sales Quotas & KPIs"
        title="Salesman Targets"
      />

      <div className="summary-strip">
        <div className="metric-cell">
          <span className="metric-label">Active Targets</span>
          <strong className="metric-value">{targets.length}</strong>
        </div>
      </div>

      <div className="table-card">
        {isLoading ? (
          <div className="directory-state">Loading targets...</div>
        ) : isError ? (
          <div className="directory-state directory-state--error">Failed to load salesman targets.</div>
        ) : targets.length === 0 ? (
          <div className="directory-state">
            <Award aria-hidden="true" size={32} />
            <p>No sales quotas defined. Create a target to measure rep performance.</p>
          </div>
        ) : (
          <DataTable caption="Salesman Targets and Achievement">
            <thead>
              <tr>
                <th scope="col">Salesperson</th>
                <th scope="col">Period</th>
                <th scope="col">Target Type</th>
                <th scope="col" style={{ textAlign: 'right' }}>Target Value</th>
                <th scope="col" style={{ textAlign: 'right' }}>Achieved</th>
                <th scope="col">Progress</th>
                <th scope="col" style={{ textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {targets.map((t: SalesmanTarget) => {
                const targetVal = Number(t.targetValue) || 1
                const achievedVal = Number(t.achievedValue) || 0
                const pct = Math.min(100, Math.round((achievedVal / targetVal) * 100))
                return (
                  <tr key={t.id}>
                    <td><strong>{t.salespersonName || 'Agent'}</strong></td>
                    <td>{formatDate(t.periodStart)} â€“ {formatDate(t.periodEnd)}</td>
                    <td>{t.targetType}</td>
                    <td style={{ textAlign: 'right' }}>
                      <strong>{t.targetType === 'REVENUE' ? <Money amount={t.targetValue} /> : t.targetValue}</strong>
                    </td>
                    <td style={{ textAlign: 'right' }}>
                      {t.targetType === 'REVENUE' ? <Money amount={t.achievedValue || 0} /> : (t.achievedValue || 0)}
                    </td>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                        <div style={{ flex: 1, height: 6, background: 'var(--k-color-border)', borderRadius: 3, overflow: 'hidden' }}>
                          <div style={{ width: `${pct}%`, height: '100%', background: pct >= 100 ? 'var(--k-color-success)' : 'var(--k-color-brand)' }} />
                        </div>
                        <span style={{ fontSize: '0.8rem', fontWeight: 600 }}>{pct}%</span>
                      </div>
                    </td>
                    <td style={{ textAlign: 'right' }}>
                      <Button
                        onClick={() => setSelectedTarget(t)}
                        type="button"
                        variant="secondary"
                      >
                        Update
                      </Button>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </DataTable>
        )}
      </div>

      {isCreateOpen ? (
        <CreateTargetModal
          isPending={createMutation.isPending}
          onClose={() => setIsCreateOpen(false)}
          onSubmit={(payload) => createMutation.mutate(payload)}
        />
      ) : null}

      {selectedTarget ? (
        <UpdateAchievementModal
          currentAchieved={Number(selectedTarget.achievedValue) || 0}
          isPending={updateMutation.isPending}
          onClose={() => setSelectedTarget(null)}
          onSubmit={(achieved) => updateMutation.mutate({ id: selectedTarget.id, achieved })}
        />
      ) : null}
    </section>
  )
}

function CreateTargetModal({
  onClose,
  onSubmit,
  isPending,
}: {
  onClose: () => void
  onSubmit: (payload: { salespersonId: string; periodType: string; periodStart: string; periodEnd: string; targetType: string; targetValue: number }) => void
  isPending: boolean
}) {
  const [salespersonId, setSalespersonId] = useState('')
  const periodType = 'MONTHLY'
  const [periodStart, setPeriodStart] = useState(new Date().toISOString().slice(0, 7) + '-01')
  const [periodEnd, setPeriodEnd] = useState(new Date().toISOString().slice(0, 10))
  const [targetType, setTargetType] = useState('REVENUE')
  const [targetValue, setTargetValue] = useState(100000)

  return (
    <div className="modal-backdrop">
      <div className="modal-card" style={{ maxWidth: 440 }}>
        <div className="modal-header">
          <h2 className="modal-title">Create Salesman Target</h2>
          <button aria-label="Close" className="button button--ghost" onClick={onClose} type="button">
            <X aria-hidden="true" size={18} />
          </button>
        </div>

        <form
          onSubmit={(e) => {
            e.preventDefault()
            onSubmit({
              salespersonId,
              periodType,
              periodStart,
              periodEnd,
              targetType,
              targetValue,
            })
          }}
        >
          <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <div className="form-field">
              <label className="form-label" htmlFor="tgt-sp">Salesperson UUID *</label>
              <input
                className="form-input"
                id="tgt-sp"
                onChange={(e) => setSalespersonId(e.target.value)}
                placeholder="User UUID"
                required
                value={salespersonId}
              />
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              <div className="form-field">
                <label className="form-label" htmlFor="tgt-start">Start Date *</label>
                <input
                  className="form-input"
                  id="tgt-start"
                  onChange={(e) => setPeriodStart(e.target.value)}
                  required
                  type="date"
                  value={periodStart}
                />
              </div>

              <div className="form-field">
                <label className="form-label" htmlFor="tgt-end">End Date *</label>
                <input
                  className="form-input"
                  id="tgt-end"
                  onChange={(e) => setPeriodEnd(e.target.value)}
                  required
                  type="date"
                  value={periodEnd}
                />
              </div>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              <div className="form-field">
                <label className="form-label" htmlFor="tgt-type">Target Metric</label>
                <select
                  className="form-input"
                  id="tgt-type"
                  onChange={(e) => setTargetType(e.target.value)}
                  value={targetType}
                >
                  <option value="REVENUE">Revenue ₹</option>
                  <option value="VISITS">Visits Count</option>
                  <option value="NEW_ACCOUNTS">New Accounts</option>
                </select>
              </div>

              <div className="form-field">
                <label className="form-label" htmlFor="tgt-val">Target Goal *</label>
                <input
                  className="form-input"
                  id="tgt-val"
                  min={1}
                  onChange={(e) => setTargetValue(parseFloat(e.target.value) || 0)}
                  required
                  type="number"
                  value={targetValue || ''}
                />
              </div>
            </div>
          </div>

          <div className="modal-footer">
            <Button onClick={onClose} type="button" variant="secondary">Cancel</Button>
            <Button disabled={isPending || !salespersonId || targetValue <= 0} type="submit" variant="primary">
              {isPending ? 'Creating...' : 'Set Target'}
            </Button>
          </div>
        </form>
      </div>
    </div>
  )
}

function UpdateAchievementModal({
  currentAchieved,
  onClose,
  onSubmit,
  isPending,
}: {
  currentAchieved: number
  onClose: () => void
  onSubmit: (achieved: number) => void
  isPending: boolean
}) {
  const [achieved, setAchieved] = useState(currentAchieved)

  return (
    <div className="modal-backdrop">
      <div className="modal-card" style={{ maxWidth: 400 }}>
        <div className="modal-header">
          <h2 className="modal-title">Update Achievement</h2>
          <button aria-label="Close" className="button button--ghost" onClick={onClose} type="button">
            <X aria-hidden="true" size={18} />
          </button>
        </div>

        <form onSubmit={(e) => { e.preventDefault(); onSubmit(achieved) }}>
          <div className="modal-body">
            <div className="form-field">
              <label className="form-label" htmlFor="ach-val">Total Achieved Value *</label>
              <input
                className="form-input"
                id="ach-val"
                min={0}
                onChange={(e) => setAchieved(parseFloat(e.target.value) || 0)}
                required
                type="number"
                value={achieved}
              />
            </div>
          </div>

          <div className="modal-footer">
            <Button onClick={onClose} type="button" variant="secondary">Cancel</Button>
            <Button disabled={isPending} type="submit" variant="primary">
              {isPending ? 'Updating...' : 'Save Achievement'}
            </Button>
          </div>
        </form>
      </div>
    </div>
  )
}
