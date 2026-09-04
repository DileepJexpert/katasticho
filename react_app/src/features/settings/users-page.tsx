import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import {
  Users,
  Plus,
  Mail,
  Shield,
  Trash2,
  CheckCircle2,
  } from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate } from '@/shared/format/format'
import {
  listOrgUsers,
  listPendingInvites,
  sendUserInvite,
  updateUserRole,
  cancelUserInvite,
  type OrgUser,
} from '@/features/settings/settings-api'

type TabKey = 'users' | 'invites'

export function UsersPage() {
  const queryClient = useQueryClient()
  const [activeTab, setActiveTab] = useState<TabKey>('users')
  const [feedback, setFeedback] = useState<string | null>(null)

  // Invite Modal
  const [isInviteOpen, setIsInviteOpen] = useState(false)
  const [inviteEmail, setInviteEmail] = useState('')
  const [inviteRole, setInviteRole] = useState('ACCOUNTANT')

  // Edit Role Modal
  const [isRoleModalOpen, setIsRoleModalOpen] = useState(false)
  const [selectedUser, setSelectedUser] = useState<OrgUser | null>(null)
  const [newRole, setNewRole] = useState('ACCOUNTANT')

  // Queries
  const usersQuery = useQuery({
    queryKey: ['org-users'],
    queryFn: () => listOrgUsers(),
  })

  const invitesQuery = useQuery({
    queryKey: ['pending-invites'],
    queryFn: () => listPendingInvites(),
    enabled: activeTab === 'invites',
  })

  // Mutations
  const inviteMutation = useMutation({
    mutationFn: () => sendUserInvite({ email: inviteEmail, role: inviteRole }),
    onSuccess: () => {
      setIsInviteOpen(false)
      setInviteEmail('')
      queryClient.invalidateQueries({ queryKey: ['pending-invites'] })
      setFeedback('Invitation email sent to team member.')
    },
  })

  const updateRoleMutation = useMutation({
    mutationFn: () => updateUserRole(selectedUser!.id, newRole),
    onSuccess: () => {
      setIsRoleModalOpen(false)
      setSelectedUser(null)
      queryClient.invalidateQueries({ queryKey: ['org-users'] })
      setFeedback('User role updated successfully.')
    },
  })

  const cancelInviteMutation = useMutation({
    mutationFn: (id: string) => cancelUserInvite(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['pending-invites'] })
      setFeedback('Invitation revoked.')
    },
  })

  const users = usersQuery.data ?? []
  const invites = invitesQuery.data ?? []

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Settings / Administration"
        title="Team & User Management"
        description="Invite colleagues, assign organizational roles (OWNER, ADMIN, ACCOUNTANT, OPERATOR, VIEWER), and manage team permissions."
        actions={
          <div className="table-actions">
            <Button onClick={() => setIsInviteOpen(true)} variant="primary">
              <Plus aria-hidden="true" size={16} />
              Invite Team Member
            </Button>
          </div>
        }
      />

      {feedback && (
        <div className="feedback-alert feedback-alert--success" role="status">
          <CheckCircle2 size={16} />
          <span>{feedback}</span>
          <button className="feedback-alert__close" onClick={() => setFeedback(null)} type="button">×</button>
        </div>
      )}

      <div className="list-tabs" role="tablist">
        <button
          aria-selected={activeTab === 'users'}
          className={activeTab === 'users' ? 'list-tab list-tab--active' : 'list-tab'}
          onClick={() => setActiveTab('users')}
          role="tab"
          type="button"
        >
          <Users size={15} style={{ marginRight: '6px' }} />
          Active Team Members ({users.length})
        </button>
        <button
          aria-selected={activeTab === 'invites'}
          className={activeTab === 'invites' ? 'list-tab list-tab--active' : 'list-tab'}
          onClick={() => setActiveTab('invites')}
          role="tab"
          type="button"
        >
          <Mail size={15} style={{ marginRight: '6px' }} />
          Pending Invitations ({invites.length})
        </button>
      </div>

      {activeTab === 'users' && (
        <section className="document-card" style={{ marginTop: '16px' }}>
          {usersQuery.isLoading ? (
            <div className="directory-state">Loading team members...</div>
          ) : (
            <DataTable caption="Active team users">
              <thead>
                <tr>
                  <th scope="col">User</th>
                  <th scope="col">Email Address</th>
                  <th scope="col">Role</th>
                  <th scope="col">Status</th>
                  <th scope="col">Joined Date</th>
                  <th scope="col">Action</th>
                </tr>
              </thead>
              <tbody>
                {users.map((u) => (
                  <tr key={u.id}>
                    <td><strong>{u.fullName || u.email.split('@')[0]}</strong></td>
                    <td className="font-mono">{u.email}</td>
                    <td>
                      <span className={u.role === 'OWNER' ? 'status-badge status-badge--success' : 'status-badge status-badge--info'}>
                        {u.role}
                      </span>
                    </td>
                    <td><StatusChip status={u.active ? 'ACTIVE' : 'DEACTIVATED'} /></td>
                    <td>{u.createdAt ? formatDate(u.createdAt) : '—'}</td>
                    <td>
                      {u.role !== 'OWNER' && (
                        <Button
                          onClick={() => {
                            setSelectedUser(u)
                            setNewRole(u.role)
                            setIsRoleModalOpen(true)
                          }}
                          variant="secondary"
                        >
                          <Shield size={14} />
                          Change Role
                        </Button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          )}
        </section>
      )}

      {activeTab === 'invites' && (
        <section className="document-card" style={{ marginTop: '16px' }}>
          {invitesQuery.isLoading ? (
            <div className="directory-state">Loading invitations...</div>
          ) : invites.length === 0 ? (
            <div className="directory-state">
              <Mail size={24} />
              <strong>No pending invitations.</strong>
            </div>
          ) : (
            <DataTable caption="Pending invitations">
              <thead>
                <tr>
                  <th scope="col">Invited Email</th>
                  <th scope="col">Assigned Role</th>
                  <th scope="col">Sent Date</th>
                  <th scope="col">Status</th>
                  <th scope="col">Action</th>
                </tr>
              </thead>
              <tbody>
                {invites.map((inv) => (
                  <tr key={inv.id}>
                    <td className="font-mono"><strong>{inv.email}</strong></td>
                    <td><span className="status-badge status-badge--info">{inv.role}</span></td>
                    <td>{inv.createdAt ? formatDate(inv.createdAt) : '—'}</td>
                    <td><StatusChip status={inv.status} /></td>
                    <td>
                      <Button
                        disabled={cancelInviteMutation.isPending}
                        onClick={() => cancelInviteMutation.mutate(inv.id)}
                        variant="destructive"
                      >
                        <Trash2 size={14} />
                        Revoke
                      </Button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          )}
        </section>
      )}

      {/* Invite Member Modal */}
      {isInviteOpen && (
        <div className="modal-backdrop">
          <div className="modal-card">
            <h3>Invite Team Member</h3>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '14px', marginTop: '14px' }}>
              <label>
                <span style={{ fontSize: '13px', fontWeight: 600 }}>Colleague's Email Address:</span>
                <input
                  className="search-input"
                  onChange={(e) => setInviteEmail(e.target.value)}
                  placeholder="name@company.com"
                  style={{ width: '100%', marginTop: '4px' }}
                  type="email"
                  value={inviteEmail}
                />
              </label>

              <label>
                <span style={{ fontSize: '13px', fontWeight: 600 }}>Role & Permissions:</span>
                <select
                  className="search-input"
                  onChange={(e) => setInviteRole(e.target.value)}
                  style={{ width: '100%', marginTop: '4px' }}
                  value={inviteRole}
                >
                  <option value="ADMIN">ADMIN - Full operational and setting privileges</option>
                  <option value="ACCOUNTANT">ACCOUNTANT - Ledger, billing, journal & tax access</option>
                  <option value="OPERATOR">OPERATOR - Sales billing, inventory & warehouse operations</option>
                  <option value="VIEWER">VIEWER - Read-only reporting access</option>
                </select>
              </label>
            </div>

            <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end', marginTop: '18px' }}>
              <Button onClick={() => setIsInviteOpen(false)} variant="secondary">Cancel</Button>
              <Button
                disabled={inviteMutation.isPending || !inviteEmail.trim()}
                onClick={() => inviteMutation.mutate()}
                variant="primary"
              >
                Send Invite
              </Button>
            </div>
          </div>
        </div>
      )}

      {/* Change Role Modal */}
      {isRoleModalOpen && selectedUser && (
        <div className="modal-backdrop">
          <div className="modal-card">
            <h3>Change Role: {selectedUser.email}</h3>
            <div style={{ marginTop: '14px' }}>
              <label>
                <span style={{ fontSize: '13px', fontWeight: 600 }}>Select New Role:</span>
                <select
                  className="search-input"
                  onChange={(e) => setNewRole(e.target.value)}
                  style={{ width: '100%', marginTop: '4px' }}
                  value={newRole}
                >
                  <option value="ADMIN">ADMIN</option>
                  <option value="ACCOUNTANT">ACCOUNTANT</option>
                  <option value="OPERATOR">OPERATOR</option>
                  <option value="VIEWER">VIEWER</option>
                </select>
              </label>
            </div>

            <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end', marginTop: '18px' }}>
              <Button onClick={() => setIsRoleModalOpen(false)} variant="secondary">Cancel</Button>
              <Button
                disabled={updateRoleMutation.isPending}
                onClick={() => updateRoleMutation.mutate()}
                variant="primary"
              >
                Update Role
              </Button>
            </div>
          </div>
        </div>
      )}
    </section>
  )
}
