import { useEffect, useState } from 'react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { Navigate } from 'react-router-dom'
import { Button, FilterTabs, FormCard, FormGrid, PageHeader } from '@/design-system'
import { TextField } from '@/design-system/text-field'
import { createPortalApi, type PortalApi, type PortalSession } from './portal-api'
import { usePortalSession } from './portal-session'
import { PortalDocuments, PortalLedger, PortalOrders, PortalOverview } from './portal-documents'
import { PortalCatalogPage } from './portal-catalog'

export function PortalPage() {
  const { session, revision } = usePortalSession()
  if (!session) return <Navigate to="/portal/login" replace />
  return <PortalWorkspace key={revision} session={session} revision={revision} />
}
function PortalWorkspace({ session, revision }: { session: PortalSession; revision: number }) {
  const [client] = useState(() => new QueryClient({ defaultOptions: { queries: { retry: false, refetchOnWindowFocus: false }, mutations: { retry: false } } }))
  const [api] = useState(() => createPortalApi(session.token, () => usePortalSession.getState().revision === revision && !!usePortalSession.getState().session, () => usePortalSession.getState().signOut('Your portal session expired. Please sign in again.')))
  useEffect(() => () => client.clear(), [client])
  return <QueryClientProvider client={client}><PortalHome api={api} session={session} /></QueryClientProvider>
}
function PortalHome({ api, session }: { api: PortalApi; session: PortalSession }) {
  const [tab, setTab] = useState('overview')
  const vendor = session.portalUser.kind === 'VENDOR'
  const tabs = [{ value: 'overview', label: 'Overview' }, ...(vendor ? [{ value: 'bills', label: 'Bills' }, { value: 'purchase-orders', label: 'Purchase orders' }] : [{ value: 'catalog', label: 'Quick reorder' }, { value: 'orders', label: 'Orders' }, { value: 'invoices', label: 'Invoices' }, { value: 'statement', label: 'Statement' }]), { value: 'security', label: 'Password' }]
  return <main className="workspace-page"><PageHeader eyebrow={`${vendor ? 'Vendor' : 'Customer'} portal`} title={session.portalUser.fullName || session.portalUser.email} description="Your documents and account activity, shared securely by your business partner." actions={<Button variant="secondary" onClick={() => usePortalSession.getState().signOut('You have signed out of the portal.')}>Sign out</Button>} /><FilterTabs items={tabs} activeValue={tab} onChange={setTab} ariaLabel="Portal sections" />
    {tab === 'overview' && <PortalOverview api={api} vendor={vendor} />}
    {(tab === 'invoices' || tab === 'bills') && <PortalDocuments api={api} vendor={vendor} />}
    {tab === 'purchase-orders' && <FormCard title="Purchase orders temporarily unavailable"><p>The existing portal service cannot reliably match vendor purchase orders to this account. Contact your business partner for purchase-order copies. No ERP administrator access is used as a workaround.</p></FormCard>}
    {!vendor && tab === 'catalog' && <PortalCatalogPage api={api} />}
    {!vendor && tab === 'orders' && <PortalOrders api={api} />}
    {!vendor && tab === 'statement' && <PortalLedger api={api} />}
    {tab === 'security' && <PortalPassword api={api} />}
  </main>
}
function PortalPassword({ api }: { api: PortalApi }) {
  const [current, setCurrent] = useState('')
  const [password, setPassword] = useState('')
  const [confirm, setConfirm] = useState('')
  const [pending, setPending] = useState(false)
  const [error, setError] = useState('')
  const valid = !!current && password.length >= 8 && password === confirm
  async function submit(event: React.FormEvent) {
    event.preventDefault(); if (!valid || pending) return
    setPending(true); setError('')
    try { await api.changePassword(current, password); usePortalSession.getState().signOut('Password changed. Sign in with your new password.') }
    catch (reason) { setError(reason instanceof Error ? reason.message : 'Unable to change password.') }
    finally { setPending(false) }
  }
  return <FormCard title="Change portal password"><p>Changing the password ends existing portal sessions. You will need to sign in again.</p><form onSubmit={submit}><FormGrid><TextField label="Current password" type="password" autoComplete="current-password" required value={current} onChange={(e) => setCurrent(e.target.value)} /><TextField label="New password" type="password" autoComplete="new-password" minLength={8} required value={password} onChange={(e) => setPassword(e.target.value)} /><TextField label="Confirm new password" type="password" autoComplete="new-password" required value={confirm} onChange={(e) => setConfirm(e.target.value)} /></FormGrid>{error && <p className="form-error" role="alert">{error}</p>}<Button type="submit" disabled={!valid || pending} loading={pending}>Change password</Button></form></FormCard>
}
