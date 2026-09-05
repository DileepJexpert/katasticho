import { useEffect, useRef, useState } from 'react'
import { Link, Navigate, useLocation } from 'react-router-dom'
import { Button } from '@/design-system'
import { TextField } from '@/design-system/text-field'
import { portalRequest, type PortalSession } from './portal-api'
import { usePortalSession } from './portal-session'

export function PortalAuthPage() {
  const { pathname } = useLocation()
  return <PortalAuthForm key={pathname} invite={pathname === '/portal/accept-invite'} />
}
function PortalAuthForm({ invite }: { invite: boolean }) {
  const session = usePortalSession((s) => s.session)
  const notice = usePortalSession((s) => s.notice)
  const [identifier, setIdentifier] = useState('')
  const [password, setPassword] = useState('')
  const [confirm, setConfirm] = useState('')
  const [pending, setPending] = useState(false)
  const [error, setError] = useState('')
  const controller = useRef<AbortController | null>(null)
  useEffect(() => () => controller.current?.abort(), [])
  if (session) return <Navigate to="/portal" replace />
  async function submit(event: React.FormEvent) {
    event.preventDefault()
    if (pending || !identifier.trim() || !password || (invite && (password.length < 8 || password !== confirm))) return
    setPending(true); setError('')
    const request = new AbortController(); controller.current = request
    try {
      const result = await portalRequest<PortalSession>(`/api/v1/portal/auth/${invite ? 'accept-invite' : 'login'}`, { body: invite ? { token: identifier.trim(), password } : { email: identifier.trim(), password }, signal: request.signal })
      if (!request.signal.aborted) usePortalSession.getState().signIn(result)
    } catch (reason) { if (!request.signal.aborted) setError(reason instanceof Error ? reason.message : 'Sign in failed.') }
    finally { if (!request.signal.aborted) setPending(false) }
  }
  return <main className="login-page"><section className="login-panel" aria-labelledby="portal-login-title"><div className="brand-lockup"><span className="brand-mark" aria-hidden="true">K</span><span>Katasticho Partner Portal</span></div><h1 id="portal-login-title">{invite ? 'Activate your invitation' : 'Customer and vendor sign in'}</h1><p>Use your portal account, not your ERP administrator login.</p>{notice && <p role="status">{notice}</p>}<form className="login-form" onSubmit={submit}>
    <TextField label={invite ? 'Invitation token' : 'Email'} type={invite ? 'password' : 'email'} required autoComplete={invite ? 'off' : 'username'} value={identifier} onChange={(e) => setIdentifier(e.target.value)} />
    <TextField label={invite ? 'New password' : 'Password'} type="password" required minLength={invite ? 8 : undefined} autoComplete={invite ? 'new-password' : 'current-password'} value={password} onChange={(e) => setPassword(e.target.value)} />
    {invite && <TextField label="Confirm new password" type="password" required autoComplete="new-password" value={confirm} onChange={(e) => setConfirm(e.target.value)} error={confirm && confirm !== password ? 'Passwords must match.' : undefined} />}
    {error && <p className="form-error" role="alert">{error}</p>}<Button type="submit" loading={pending} disabled={pending || !identifier.trim() || !password || (invite && (password.length < 8 || confirm !== password))}>{invite ? 'Activate account' : 'Sign in'}</Button>
  </form><Link to={invite ? '/portal/login' : '/portal/accept-invite'}>{invite ? 'Already activated? Sign in' : 'Accept an invitation'}</Link><p>Your portal session stays in memory. Reloading this page requires signing in again.</p><Link to="/login">ERP staff sign in</Link></section></main>
}
