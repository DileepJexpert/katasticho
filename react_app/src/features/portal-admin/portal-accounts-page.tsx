import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Button, EntityPicker, FormGrid, Modal, PageHeader, StatusChip } from '@/design-system'
import { TextField } from '@/design-system/text-field'
import { listContacts, type Contact } from '@/features/contacts/contacts-api'
import { useSessionStore } from '@/shared/session/session-store'
import { WorkspaceBoundary } from '@/shared/workflows/workspace-boundary'
import { QueryFeedback } from '@/shared/workflows/query-feedback'
import { ConfirmedAction } from '@/shared/workflows/confirmed-action'
import { LocalDirectory } from '@/shared/workflows/local-directory'
import { invitePortalAccount, listPortalAccounts, portalAccountAction, resendPortalInvite, type PortalAccount, type PortalInvite } from './portal-admin-api'

export function PortalAccountsPage() { return <WorkspaceBoundary roles={['OWNER', 'ADMIN']}><PortalAccounts /></WorkspaceBoundary> }
function PortalAccounts() {
  const orgId = useSessionStore((s) => s.user!.orgId)
  const client = useQueryClient()
  const query = useQuery({ queryKey: ['portal-accounts', orgId], queryFn: listPortalAccounts })
  const [creating, setCreating] = useState(false)
  const [invite, setInvite] = useState<PortalInvite | null>(null)
  const [action, setAction] = useState<{ account: PortalAccount; action: 'suspend' | 'reactivate' | 'delete' | 'resend' } | null>(null)
  const refresh = () => { setAction(null); setCreating(false); void client.invalidateQueries({ queryKey: ['portal-accounts', orgId] }) }
  const showInvite = (result: PortalInvite) => {
    if (useSessionStore.getState().user?.orgId !== orgId) return
    setInvite(result)
  }
  return <section className="workspace-page"><PageHeader eyebrow="Settings / External access" title="Customer and vendor portal accounts" description="Manage external contact access separately from employee logins." actions={<Button onClick={() => setCreating(true)}>Invite contact</Button>} />
    <p className="banner">Invites generate a one-time activation token, not an email delivery. Share it securely with the intended contact and direct them to /portal/accept-invite. Returning contacts sign in at /portal/login. Never put invitation tokens in a URL.</p>
    <QueryFeedback query={query}><LocalDirectory rows={query.data ?? []} caption="Portal accounts" searchText={(a) => `${a.fullName} ${a.email} ${a.kind} ${a.status}`} header={<tr><th>Name</th><th>Email</th><th>Access kind</th><th>Status</th><th>Last login</th><th>Actions</th></tr>} renderRow={(a) => <tr key={a.id}><td>{a.fullName}</td><td>{a.email}</td><td>{a.kind}</td><td><StatusChip status={a.status} /></td><td>{a.lastLoginAt ?? '--'}</td><td>
      {a.status === 'INVITED' && <Button variant="ghost" onClick={() => setAction({ account: a, action: 'resend' })}>Regenerate invite</Button>}
      {a.status !== 'SUSPENDED' && <Button variant="ghost" onClick={() => setAction({ account: a, action: 'suspend' })}>Suspend {a.fullName}</Button>}
      {a.status === 'SUSPENDED' && <><Button variant="ghost" onClick={() => setAction({ account: a, action: 'reactivate' })}>Reactivate {a.fullName}</Button><Button variant="ghost" onClick={() => setAction({ account: a, action: 'resend' })}>Regenerate invite</Button></>}
      <Button variant="ghost" onClick={() => setAction({ account: a, action: 'delete' })}>Remove {a.fullName}</Button>
    </td></tr>} /></QueryFeedback>
    {creating && <InviteEditor onClose={() => setCreating(false)} onDone={(result) => { showInvite(result); refresh() }} />}
    {action && <ConfirmedAction title={`${action.action} portal account`} description={action.action === 'resend' ? `Generate a new activation token for ${action.account.email}? This replaces the previous invite token; suspended accounts become invited.` : `${action.action} portal access for ${action.account.fullName}? Reactivation requires a previously accepted invite. Removal or suspension invalidates existing sessions.`} destructive={action.action === 'delete' || action.action === 'suspend'} run={async () => { if (action.action === 'resend') showInvite(await resendPortalInvite(action.account.id)); else await portalAccountAction(action.account.id, action.action) }} onClose={() => setAction(null)} onDone={refresh} />}
    {invite && <InviteResult invite={invite} onClose={() => setInvite(null)} />}
  </section>
}
function InviteEditor({ onClose, onDone }: { onClose: () => void; onDone: (invite: PortalInvite) => void }) {
  const [contact, setContact] = useState<Contact | null>(null)
  const [email, setEmail] = useState('')
  const [name, setName] = useState('')
  const valid = !!contact && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim()) && !!name.trim()
  // Do not retain the one-time token in the mutation cache.
  const save = useMutation({ mutationFn: async () => { onDone(await invitePortalAccount({ contactId: contact!.id, email: email.trim(), fullName: name.trim() })) } })
  return <Modal isOpen title="Invite a portal contact" error={save.error?.message} onClose={() => { if (!save.isPending) onClose() }} footer={<><Button variant="secondary" disabled={save.isPending} onClick={onClose}>Cancel</Button><Button disabled={!valid || save.isPending} onClick={() => save.mutate()}>Create invite</Button></>}><FormGrid>
    <EntityPicker<Contact> ariaLabel="Portal contact" value={contact?.id ?? null} selectedEntity={contact} onSearch={async (search) => (await listContacts({ search, filter: 'ALL', page: 0, size: 25 })).content} getOptionId={(c) => c.id} getOptionLabel={(c) => c.displayName} getOptionDescription={(c) => [c.email, c.phone].filter(Boolean).join(' / ')} onChange={(_id, c) => { setContact(c ?? null); setName(c?.displayName ?? ''); setEmail(c?.email ?? '') }} />
    <TextField label="Full name" value={name} onChange={(e) => setName(e.target.value)} /><TextField label="Email" type="email" value={email} onChange={(e) => setEmail(e.target.value)} />
  </FormGrid><p>Vendor-only contacts receive vendor access; other contact types receive customer access under the existing contract.</p></Modal>
}
function InviteResult({ invite, onClose }: { invite: PortalInvite; onClose: () => void }) {
  const [visible, setVisible] = useState(false)
  const [notice, setNotice] = useState('')
  return <Modal isOpen title="Portal activation token" onClose={onClose} footer={<Button onClick={onClose}>Close and clear token</Button>}><p>For {invite.email}. Expires {invite.inviteExpiresAt}. Treat this token like a password; it is cleared when this dialog closes.</p><TextField label="One-time activation token" type={visible ? 'text' : 'password'} value={invite.inviteToken} readOnly autoComplete="off" /><Button variant="secondary" onClick={() => setVisible(!visible)}>{visible ? 'Hide token' : 'Reveal token'}</Button><Button variant="secondary" onClick={async () => { try { await navigator.clipboard.writeText(invite.inviteToken); setNotice('Token copied. Share only with the intended contact.') } catch { setNotice('Clipboard unavailable. Reveal the token to select it manually.') } }}>Copy token</Button>{notice && <p role="status">{notice}</p>}</Modal>
}
