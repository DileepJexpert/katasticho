import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { Play, Calculator, ShoppingBag, Factory, CheckCircle2 } from 'lucide-react'
import {
  Button,
  DataTable,
  FormField,
  Modal,
  NumberInput,
  PageHeader,
  Quantity,
  StatusChip,
} from '@/design-system'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import { listMrpRuns, runMrp, convertPlannedToPO, convertPlannedToWO, getMrpRun } from '@/features/mrp/mrp-api'

export function MrpPage() {
  const queryClient = useQueryClient()
  const [selectedRunId, setSelectedRunId] = useState<string | null>(null)
  const [horizonDays, setHorizonDays] = useState(90)
  const [isRunModalOpen, setIsRunModalOpen] = useState(false)

  const runsQuery = useQuery({
    queryKey: ['mrp-runs'],
    queryFn: listMrpRuns,
  })

  const runDetailQuery = useQuery({
    queryKey: ['mrp-run', selectedRunId],
    queryFn: () => getMrpRun(selectedRunId!),
    enabled: Boolean(selectedRunId),
  })

  const runMutation = useMutation({
    mutationFn: () => runMrp(horizonDays),
    onSuccess: (data) => {
      setIsRunModalOpen(false)
      setSelectedRunId(data.id)
      queryClient.invalidateQueries({ queryKey: ['mrp-runs'] })
    },
  })

  const convertPoMutation = useMutation({
    mutationFn: (id: string) => convertPlannedToPO(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['mrp-run', selectedRunId] })
    },
  })

  const convertWoMutation = useMutation({
    mutationFn: (id: string) => convertPlannedToWO(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['mrp-run', selectedRunId] })
    },
  })

  const runs = runsQuery.data ?? []
  const activeRun = runDetailQuery.data ?? (runs.length > 0 && !selectedRunId ? runs[0] : null)

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Manufacturing / Planning"
        title="Material Requirements Planning (MRP)"
        description="Demand forecasting, gross-to-net BOM explosion, lead-time offsets, and automated PO/WO conversion."
        actions={
          <div className="table-actions">
            <Button onClick={() => setIsRunModalOpen(true)} variant="primary">
              <Play aria-hidden="true" size={16} />
              Run MRP Engine
            </Button>
          </div>
        }
      />

      <div className="document-layout">
        <section className="document-card" style={{ flex: 1 }}>
          <h2>MRP Simulation Runs</h2>
          {runsQuery.isLoading ? (
            <div className="directory-state">Loading MRP runs...</div>
          ) : runs.length > 0 ? (
            <DataTable caption="Past MRP simulation executions">
              <thead>
                <tr>
                  <th scope="col">Run #</th>
                  <th scope="col">Date</th>
                  <th className="numeric-cell" scope="col">Horizon</th>
                  <th scope="col">Status</th>
                </tr>
              </thead>
              <tbody>
                {runs.map((r) => (
                  <tr
                    key={r.id}
                    onClick={() => setSelectedRunId(r.id)}
                    style={{ cursor: 'pointer', background: selectedRunId === r.id ? 'var(--bg-muted)' : undefined }}
                  >
                    <td><strong>{r.runNumber}</strong></td>
                    <td>{formatDate(r.runDate)}</td>
                    <td className="numeric-cell">{r.horizonDays} days</td>
                    <td><StatusChip status={formatStatusLabel(r.status)} /></td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          ) : (
            <div className="directory-state">
              <Calculator size={24} />
              <strong>No MRP runs found. Click Run MRP Engine to simulate.</strong>
            </div>
          )}
        </section>

        <section className="document-card" style={{ flex: 2 }}>
          <h2>Planned Orders & Material Requirements</h2>
          {activeRun ? (
            <div>
              <p className="cell-muted" style={{ marginBottom: '16px' }}>
                Run <strong>{activeRun.runNumber}</strong> (Horizon: {activeRun.horizonDays} days) · Planned Demand vs Supply recommendations.
              </p>

              {activeRun.plannedOrders && activeRun.plannedOrders.length > 0 ? (
                <DataTable caption="Planned Purchase & Production orders">
                  <thead>
                    <tr>
                      <th scope="col">Type</th>
                      <th scope="col">Item</th>
                      <th className="numeric-cell" scope="col">Suggested Qty</th>
                      <th scope="col">Release Date</th>
                      <th scope="col">Required Date</th>
                      <th scope="col">Status</th>
                      <th className="numeric-cell" scope="col">Action</th>
                    </tr>
                  </thead>
                  <tbody>
                    {activeRun.plannedOrders.map((order) => (
                      <tr key={order.id}>
                        <td>
                          <span className={order.orderType === 'PURCHASE' ? 'status-badge status-badge--info' : 'status-badge status-badge--warning'}>
                            {order.orderType}
                          </span>
                        </td>
                        <td><strong>{order.itemName || order.itemId}</strong></td>
                        <td className="numeric-cell"><Quantity value={order.suggestedQty} /></td>
                        <td>{formatDate(order.releaseDate)}</td>
                        <td>{formatDate(order.requiredDate)}</td>
                        <td><StatusChip status={formatStatusLabel(order.status)} /></td>
                        <td className="numeric-cell">
                          {order.status === 'PLANNED' ? (
                            order.orderType === 'PURCHASE' ? (
                              <Button
                                disabled={convertPoMutation.isPending}
                                onClick={() => convertPoMutation.mutate(order.id)}
                                variant="secondary"
                              >
                                <ShoppingBag size={14} />
                                Convert to PO
                              </Button>
                            ) : (
                              <Button
                                disabled={convertWoMutation.isPending}
                                onClick={() => convertWoMutation.mutate(order.id)}
                                variant="secondary"
                              >
                                <Factory size={14} />
                                Convert to WO
                              </Button>
                            )
                          ) : (
                            <span className="text-success"><CheckCircle2 size={16} /> Converted</span>
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </DataTable>
              ) : (
                <div className="directory-state">
                  <CheckCircle2 size={24} />
                  <strong>Zero stock deficits detected in this horizon.</strong>
                </div>
              )}
            </div>
          ) : (
            <div className="directory-state">Select an MRP run from the left panel.</div>
          )}
        </section>
      </div>

      <Modal
        description="Explodes open Sales Orders, minimum reorder thresholds, and active BOMs to calculate net procurement and production requirements."
        footer={
          <>
            <Button onClick={() => setIsRunModalOpen(false)} variant="secondary">Cancel</Button>
            <Button
              disabled={runMutation.isPending}
              onClick={() => runMutation.mutate()}
              variant="primary"
            >
              {runMutation.isPending ? 'Calculating...' : 'Run MRP Calculation'}
            </Button>
          </>
        }
        isOpen={isRunModalOpen}
        onClose={() => setIsRunModalOpen(false)}
        size="md"
        title="Execute MRP Planning Run"
      >
        <FormField label="Planning Horizon (Days)" required>
          <NumberInput
            min={1}
            onChange={(e) => setHorizonDays(Number(e.target.value))}
            required
            value={horizonDays}
          />
        </FormField>
      </Modal>
    </section>
  )
}