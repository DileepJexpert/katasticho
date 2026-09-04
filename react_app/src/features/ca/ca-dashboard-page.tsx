import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  Building,
  ExternalLink,
  Key,
  Plus,
} from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import {
  createCaFirm,
  getCaDashboard,
  getCurrentFirm,
  getDelegatedAccessToken,
  inviteClient,
  listCaStaff,
  type DelegatedAccess,
} from '@/features/ca/ca-api'

export function CaDashboardPage() {
  const queryClient = useQueryClient()
  const [selectedStaffFilter, setSelectedStaffFilter] = useState<string>('')
  const [selectedHealthFilter, setSelectedHealthFilter] = useState<string>('')
  const [isInviteModalOpen, setIsInviteModalOpen] = useState(false)
  const [isFirmCreateModalOpen, setIsFirmCreateModalOpen] = useState(false)
  const [delegatedSession, setDelegatedSession] = useState<DelegatedAccess | null>(null)

  // Form states
  const [inviteEmail, setInviteEmail] = useState('')
  const [inviteName, setInviteName] = useState('')
  const [inviteEngagement, setInviteEngagement] = useState('RETAINER_AUDIT')
  const [firmNameInput, setFirmNameInput] = useState('')
  const [firmIcaiInput, setFirmIcaiInput] = useState('')

  // Queries
  const dashboardQuery = useQuery({
    queryKey: ['ca-dashboard'],
    queryFn: getCaDashboard,
  })

  const firmQuery = useQuery({
    queryKey: ['ca-current-firm'],
    queryFn: getCurrentFirm,
  })

  const staffQuery = useQuery({
    queryKey: ['ca-staff'],
    queryFn: listCaStaff,
  })

  // Mutations
  const inviteMutation = useMutation({
    mutationFn: () =>
      inviteClient({
        emailOrPhone: inviteEmail,
        clientName: inviteName,
        engagementType: inviteEngagement,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['ca-dashboard'] })
      setIsInviteModalOpen(false)
      setInviteEmail('')
      setInviteName('')
    },
  })

  const createFirmMutation = useMutation({
    mutationFn: () => createCaFirm({ firmName: firmNameInput, icaiNumber: firmIcaiInput }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['ca-current-firm'] })
      queryClient.invalidateQueries({ queryKey: ['ca-dashboard'] })
      setIsFirmCreateModalOpen(false)
    },
  })

  const delegatedTokenMutation = useMutation({
    mutationFn: (linkId: string) => getDelegatedAccessToken(linkId),
    onSuccess: (res: DelegatedAccess) => {
      setDelegatedSession(res)
    },
  })

  const dashboard = dashboardQuery.data
  const firm = firmQuery.data
  const staff = staffQuery.data ?? []

  const clients = (dashboard?.clients ?? []).filter((c) => {
    if (selectedHealthFilter && c.healthStatus !== selectedHealthFilter) return false
    if (selectedStaffFilter && c.assignedUserId !== selectedStaffFilter) return false
    return true
  })

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Chartered Accountant Multi-Client Practice Console"
        title={firm ? `${firm.firmName} - Practice Command Console` : 'Chartered Accountant Command Console'}
        description="Unified practice management cockpit for audit, statutory tax compliance, risk anomalies, and delegated 1-click single sign-on across all linked client organizations."
        actions={
          <div style={{ display: 'flex', gap: 'var(--space-sm)' }}>
            {!firm && (
              <Button onClick={() => setIsFirmCreateModalOpen(true)} variant="secondary">
                <Building aria-hidden="true" size={14} style={{ marginRight: 6 }} />
                Register CA Firm
              </Button>
            )}
            <Button onClick={() => setIsInviteModalOpen(true)} variant="primary">
              <Plus aria-hidden="true" size={14} style={{ marginRight: 6 }} />
              Link Client Organization
            </Button>
          </div>
        }
      />

      {/* KPI Metrics */}
      <div className="summary-strip">
        <div className="summary-card">
          <span className="summary-card__label">Total Linked Clients</span>
          <strong className="summary-card__value" style={{ color: 'var(--color-primary)' }}>
            <Quantity value={dashboard?.totalClients ?? 0} /> Organizations
          </strong>
          <span className="summary-card__hint">Active audit engagements</span>
        </div>

        <div className="summary-card">
          <span className="summary-card__label">Critical Attention Required</span>
          <strong className="summary-card__value" style={{ color: 'var(--color-error)' }}>
            <Quantity value={dashboard?.criticalCount ?? 0} /> Clients
          </strong>
          <span className="summary-card__hint">Unbalanced TB / Audit flags</span>
        </div>

        <div className="summary-card">
          <span className="summary-card__label">GST Due This Week</span>
          <strong className="summary-card__value" style={{ color: 'var(--color-warning)' }}>
            <Quantity value={dashboard?.gstDueThisWeekCount ?? 0} /> Filings
          </strong>
          <span className="summary-card__hint">GSTR-1 / 3B approaching</span>
        </div>

        <div className="summary-card summary-card--accent">
          <span className="summary-card__label">Unbalanced Trial Balances</span>
          <strong className="summary-card__value" style={{ color: 'var(--color-text-primary)' }}>
            <Quantity value={dashboard?.unbalancedTrialBalanceCount ?? 0} /> Ledgers
          </strong>
          <span className="summary-card__hint">Automated integrity sweep</span>
        </div>
      </div>

      {/* Client Directory Matrix */}
      <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 'var(--space-md)' }}>
          <h3 style={{ fontSize: '1.05rem', fontWeight: 600 }}>Linked Client Registry & Health Matrix</h3>
          <div style={{ display: 'flex', gap: 'var(--space-sm)' }}>
            <select
              className="select-field"
              onChange={(e) => setSelectedHealthFilter(e.target.value)}
              style={{ padding: '6px 12px', borderRadius: 'var(--radius-md)', border: '1px solid var(--color-border)', fontSize: '0.85rem' }}
              value={selectedHealthFilter}
            >
              <option value="">All Health Statuses</option>
              <option value="HEALTHY">Healthy</option>
              <option value="ATTENTION">Attention Needed</option>
              <option value="CRITICAL">Critical Anomaly</option>
            </select>

            <select
              className="select-field"
              onChange={(e) => setSelectedStaffFilter(e.target.value)}
              style={{ padding: '6px 12px', borderRadius: 'var(--radius-md)', border: '1px solid var(--color-border)', fontSize: '0.85rem' }}
              value={selectedStaffFilter}
            >
              <option value="">All Audit Staff</option>
              {staff.map((st) => (
                <option key={st.userId} value={st.userId}>
                  {st.fullName} ({st.role})
                </option>
              ))}
            </select>
          </div>
        </div>

        <DataTable caption="CA Practice Client Organizations Registry">
          <thead>
            <tr>
              <th scope="col">Client Organization</th>
              <th scope="col">Industry & Engagement</th>
              <th scope="col">Audit Health</th>
              <th scope="col">Next Compliance Due</th>
              <th scope="col">Assigned Audit Staff</th>
              <th className="numeric-cell" scope="col">Delegated Access</th>
            </tr>
          </thead>
          <tbody>
            {clients.map((c) => (
              <tr key={c.linkId}>
                <td>
                  <strong>{c.clientOrgName}</strong>
                  <div className="cell-muted" style={{ fontSize: '0.75rem' }}>
                    Org ID: <code>{c.clientOrgId.slice(0, 8)}...</code>
                  </div>
                </td>
                <td>
                  <span>{c.industry || 'General Trading'}</span>
                  <div className="cell-muted" style={{ fontSize: '0.75rem' }}>
                    {c.engagementType}
                  </div>
                </td>
                <td>
                  <StatusChip status={c.healthStatus} />
                  {c.healthReasons && c.healthReasons.length > 0 && (
                    <span className="cell-muted" style={{ display: 'block', fontSize: '0.75rem', marginTop: 2 }}>
                      {c.healthReasons[0]}
                    </span>
                  )}
                </td>
                <td>
                  {c.nextDeadlineDate ? (
                    <div>
                      <strong>{c.nextDeadlineType}</strong>
                      <div className="cell-muted" style={{ fontSize: '0.75rem' }}>
                        Due: {c.nextDeadlineDate}
                      </div>
                    </div>
                  ) : (
                    <span className="cell-muted" style={{ fontSize: '0.8rem' }}>None pending</span>
                  )}
                </td>
                <td>
                  <span style={{ fontSize: '0.85rem' }}>{c.assignedStaffName || 'Unassigned'}</span>
                </td>
                <td className="numeric-cell">
                  <Button
                    disabled={delegatedTokenMutation.isPending}
                    onClick={() => delegatedTokenMutation.mutate(c.linkId)}
                    variant="secondary"
                  >
                    <Key size={13} style={{ marginRight: 4 }} />
                    1-Click Client Login
                  </Button>
                </td>
              </tr>
            ))}
            {clients.length === 0 && (
              <tr>
                <td colSpan={6} style={{ textAlign: 'center', padding: 'var(--space-lg)', color: 'var(--color-text-secondary)' }}>
                  No linked clients found. Click "Link Client Organization" to get started.
                </td>
              </tr>
            )}
          </tbody>
        </DataTable>
      </div>

      {/* DELEGATED ACCESS TOKEN MODAL */}
      {delegatedSession && (
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
              maxWidth: 520,
              backgroundColor: 'var(--color-surface)',
              borderRadius: 'var(--radius-lg)',
              padding: 'var(--space-lg)',
              border: '1px solid var(--color-border)',
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 'var(--space-md)' }}>
              <Key size={22} color="var(--color-primary)" />
              <h3 style={{ fontSize: '1.2rem', fontWeight: 600 }}>Delegated Client Session Active</h3>
            </div>
            <p className="cell-muted" style={{ fontSize: '0.85rem', marginBottom: 'var(--space-md)' }}>
              A secure ephemeral access token has been minted with audit trails. You can switch into the client's books with CA partner permissions.
            </p>

            <div style={{ padding: 'var(--space-md)', background: 'var(--color-bg-subtle)', borderRadius: 'var(--radius-md)', marginBottom: 'var(--space-md)' }}>
              <span className="cell-muted" style={{ fontSize: '0.75rem' }}>Session Token:</span>
              <code style={{ display: 'block', fontSize: '0.8rem', wordBreak: 'break-all', marginTop: 4 }}>
                {delegatedSession.token}
              </code>
              <span className="cell-muted" style={{ fontSize: '0.75rem', display: 'block', marginTop: 8 }}>
                Expires At: {new Date(delegatedSession.expiresAt).toLocaleTimeString()}
              </span>
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
              <Button onClick={() => setDelegatedSession(null)} variant="secondary">
                Close
              </Button>
              <Button
                onClick={() => {
                  window.open(delegatedSession.redirectUrl || '/', '_blank')
                  setDelegatedSession(null)
                }}
                variant="primary"
              >
                <ExternalLink size={14} style={{ marginRight: 6 }} />
                Open Client Books
              </Button>
            </div>
          </div>
        </div>
      )}

      {/* INVITE CLIENT MODAL */}
      {isInviteModalOpen && (
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
              Invite Client to Practice Portal
            </h3>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-md)', marginBottom: 'var(--space-lg)' }}>
              <div>
                <label style={{ fontSize: '0.85rem', fontWeight: 600, display: 'block', marginBottom: 4 }}>
                  Client Business Name
                </label>
                <input
                  className="input-field"
                  onChange={(e) => setInviteName(e.target.value)}
                  placeholder="e.g. Apex Global Distributors Pvt Ltd"
                  style={{ width: '100%', padding: '8px 12px', borderRadius: 'var(--radius-md)', border: '1px solid var(--color-border)' }}
                  type="text"
                  value={inviteName}
                />
              </div>

              <div>
                <label style={{ fontSize: '0.85rem', fontWeight: 600, display: 'block', marginBottom: 4 }}>
                  Client Owner Email / Mobile
                </label>
                <input
                  className="input-field"
                  onChange={(e) => setInviteEmail(e.target.value)}
                  placeholder="accounts@apexdistributors.com"
                  style={{ width: '100%', padding: '8px 12px', borderRadius: 'var(--radius-md)', border: '1px solid var(--color-border)' }}
                  type="text"
                  value={inviteEmail}
                />
              </div>

              <div>
                <label style={{ fontSize: '0.85rem', fontWeight: 600, display: 'block', marginBottom: 4 }}>
                  Engagement Type
                </label>
                <select
                  className="select-field"
                  onChange={(e) => setInviteEngagement(e.target.value)}
                  style={{ width: '100%', padding: '8px 12px', borderRadius: 'var(--radius-md)', border: '1px solid var(--color-border)' }}
                  value={inviteEngagement}
                >
                  <option value="RETAINER_AUDIT">Statutory Audit & Retainer</option>
                  <option value="GST_COMPLIANCE">GST & TDS Compliance</option>
                  <option value="VIRTUAL_CFO">Virtual CFO & Advisory</option>
                  <option value="ONE_TIME_AUDIT">One-Time Special Audit</option>
                </select>
              </div>
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
              <Button onClick={() => setIsInviteModalOpen(false)} variant="secondary">
                Cancel
              </Button>
              <Button
                disabled={inviteMutation.isPending || !inviteEmail}
                onClick={() => inviteMutation.mutate()}
                variant="primary"
              >
                Send Client Invitation
              </Button>
            </div>
          </div>
        </div>
      )}

      {/* REGISTER FIRM MODAL */}
      {isFirmCreateModalOpen && (
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
              Register Chartered Accountant Practice Firm
            </h3>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-md)', marginBottom: 'var(--space-lg)' }}>
              <div>
                <label style={{ fontSize: '0.85rem', fontWeight: 600, display: 'block', marginBottom: 4 }}>
                  CA Firm / Practice Name
                </label>
                <input
                  className="input-field"
                  onChange={(e) => setFirmNameInput(e.target.value)}
                  placeholder="e.g. Mehta & Singhania Associates"
                  style={{ width: '100%', padding: '8px 12px', borderRadius: 'var(--radius-md)', border: '1px solid var(--color-border)' }}
                  type="text"
                  value={firmNameInput}
                />
              </div>

              <div>
                <label style={{ fontSize: '0.85rem', fontWeight: 600, display: 'block', marginBottom: 4 }}>
                  ICAI Firm Registration Number (FRN)
                </label>
                <input
                  className="input-field"
                  onChange={(e) => setFirmIcaiInput(e.target.value)}
                  placeholder="e.g. 128490W"
                  style={{ width: '100%', padding: '8px 12px', borderRadius: 'var(--radius-md)', border: '1px solid var(--color-border)' }}
                  type="text"
                  value={firmIcaiInput}
                />
              </div>
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
              <Button onClick={() => setIsFirmCreateModalOpen(false)} variant="secondary">
                Cancel
              </Button>
              <Button
                disabled={createFirmMutation.isPending || !firmNameInput}
                onClick={() => createFirmMutation.mutate()}
                variant="primary"
              >
                Register Firm
              </Button>
            </div>
          </div>
        </div>
      )}
    </section>
  )
}
