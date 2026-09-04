import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  UserCheck,
  XCircle,
} from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import {
  assignCaAlert,
  dismissCaAlert,
  listCaAlerts,
  listCaStaff,
  type CaAlert,
} from '@/features/ca/ca-api'

export function CaAlertsPage() {
  const queryClient = useQueryClient()
  const [selectedSeverity, setSelectedSeverity] = useState<string>('')
  const [activeAssignAlert, setActiveAssignAlert] = useState<CaAlert | null>(null)
  const [selectedStaffUser, setSelectedStaffUser] = useState<string>('')

  // Queries
  const alertsQuery = useQuery({
    queryKey: ['ca-alerts', selectedSeverity],
    queryFn: () => listCaAlerts(selectedSeverity || undefined),
  })

  const staffQuery = useQuery({
    queryKey: ['ca-staff'],
    queryFn: listCaStaff,
  })

  // Mutations
  const dismissMutation = useMutation({
    mutationFn: (suggestionId: string) => dismissCaAlert(suggestionId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['ca-alerts'] })
    },
  })

  const assignMutation = useMutation({
    mutationFn: ({ id, userId }: { id: string; userId: string }) =>
      assignCaAlert(id, { assignedUserId: userId }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['ca-alerts'] })
      setActiveAssignAlert(null)
    },
  })

  const alerts = alertsQuery.data ?? []
  const staff = staffQuery.data ?? []

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Practice Risk Intelligence & Audit Anomalies"
        title="Cross-Client Audit Risk & Anomaly Inbox"
        description="Continuous automated auditor sweeps detecting unbacked transactions, duplicate vendor claims, negative cash registers, and tax credit mismatches across linked clients."
      />

      <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 'var(--space-md)' }}>
          <h3 style={{ fontSize: '1.05rem', fontWeight: 600 }}>Active Audit Flags</h3>
          <select
            className="select-field"
            onChange={(e) => setSelectedSeverity(e.target.value)}
            style={{ padding: '6px 12px', borderRadius: 'var(--radius-md)', border: '1px solid var(--color-border)', fontSize: '0.85rem' }}
            value={selectedSeverity}
          >
            <option value="">All Priorities</option>
            <option value="CRITICAL">Critical Severity</option>
            <option value="HIGH">High Risk</option>
            <option value="MEDIUM">Medium Risk</option>
          </select>
        </div>

        <DataTable caption="Cross-Client CA Audit Alerts">
          <thead>
            <tr>
              <th scope="col">Client Organization</th>
              <th scope="col">Audit Flag / Anomaly</th>
              <th scope="col">Reasoning & Risk Assessment</th>
              <th scope="col">Priority</th>
              <th scope="col">Assigned Auditor</th>
              <th className="numeric-cell" scope="col">Actions</th>
            </tr>
          </thead>
          <tbody>
            {alerts.map((a) => (
              <tr key={a.id}>
                <td>
                  <strong>{a.clientOrgName}</strong>
                </td>
                <td>
                  <strong>{a.title || a.suggestionType}</strong>
                </td>
                <td style={{ maxWidth: 360 }}>
                  <p style={{ margin: 0, fontSize: '0.85rem' }}>{a.reasoning}</p>
                </td>
                <td>
                  <StatusChip status={a.priority} />
                </td>
                <td>
                  <span style={{ fontSize: '0.85rem' }}>
                    {staff.find((s) => s.userId === a.assignedUserId)?.fullName || 'Unassigned'}
                  </span>
                </td>
                <td className="numeric-cell">
                  <div style={{ display: 'flex', gap: 6, justifyContent: 'flex-end' }}>
                    <Button onClick={() => setActiveAssignAlert(a)} variant="secondary">
                      <UserCheck size={13} style={{ marginRight: 4 }} />
                      Assign
                    </Button>
                    <Button onClick={() => dismissMutation.mutate(a.id)} variant="ghost">
                      <XCircle size={13} style={{ marginRight: 4 }} />
                      Dismiss
                    </Button>
                  </div>
                </td>
              </tr>
            ))}
            {alerts.length === 0 && (
              <tr>
                <td colSpan={6} style={{ textAlign: 'center', padding: 'var(--space-lg)', color: 'var(--color-text-secondary)' }}>
                  Zero audit risks detected. All client books are healthy.
                </td>
              </tr>
            )}
          </tbody>
        </DataTable>
      </div>

      {/* ASSIGN AUDITOR MODAL */}
      {activeAssignAlert && (
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
              maxWidth: 440,
              backgroundColor: 'var(--color-surface)',
              borderRadius: 'var(--radius-lg)',
              padding: 'var(--space-lg)',
              border: '1px solid var(--color-border)',
            }}
          >
            <h3 style={{ fontSize: '1.15rem', fontWeight: 600, marginBottom: 'var(--space-md)' }}>
              Assign Audit Item to Practice Staff
            </h3>
            <p className="cell-muted" style={{ fontSize: '0.85rem', marginBottom: 'var(--space-md)' }}>
              Flag: <strong>{activeAssignAlert.title || activeAssignAlert.suggestionType}</strong> &bull; {activeAssignAlert.clientOrgName}
            </p>

            <div style={{ marginBottom: 'var(--space-lg)' }}>
              <label style={{ fontSize: '0.85rem', fontWeight: 600, display: 'block', marginBottom: 4 }}>
                Select Audit Staff / Article Clerk
              </label>
              <select
                className="select-field"
                onChange={(e) => setSelectedStaffUser(e.target.value)}
                style={{ width: '100%', padding: '8px 12px', borderRadius: 'var(--radius-md)', border: '1px solid var(--color-border)' }}
                value={selectedStaffUser}
              >
                <option value="">Choose Staff...</option>
                {staff.map((s) => (
                  <option key={s.userId} value={s.userId}>
                    {s.fullName} ({s.role})
                  </option>
                ))}
              </select>
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
              <Button onClick={() => setActiveAssignAlert(null)} variant="secondary">
                Cancel
              </Button>
              <Button
                disabled={assignMutation.isPending || !selectedStaffUser}
                onClick={() =>
                  assignMutation.mutate({
                    id: activeAssignAlert.id,
                    userId: selectedStaffUser,
                  })
                }
                variant="primary"
              >
                Assign Item
              </Button>
            </div>
          </div>
        </div>
      )}
    </section>
  )
}
