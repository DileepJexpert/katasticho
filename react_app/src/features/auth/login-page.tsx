import { useEffect, useState } from 'react'
import { zodResolver } from '@hookform/resolvers/zod'
import {
  ArrowRight,
  Check,
  ChevronDown,
  ChevronUp,
  Copy,
  ShieldCheck,
  Zap,
} from 'lucide-react'
import { useForm } from 'react-hook-form'
import { useNavigate } from 'react-router-dom'
import { z } from 'zod'
import { Button } from '@/design-system/button'
import { TextField } from '@/design-system/text-field'
import { apiFetch, ApiError } from '@/api/client/api-client'
import { useSessionStore } from '@/shared/session/session-store'

const loginSchema = z.object({
  identifier: z.string().trim().min(1, 'Enter your phone number or email address.'),
  password: z.string().min(1, 'Enter your password.'),
})

type LoginValues = z.infer<typeof loginSchema>

type DemoUser = {
  phone: string
  fullName: string
  role: string
  password: string
}

type DemoInfo = {
  enabled: boolean
  orgName: string
  users: DemoUser[]
}

const DEFAULT_DEMO_USERS: DemoUser[] = [
  { phone: '9000000001', fullName: 'Demo Owner', role: 'OWNER', password: 'Demo@1234' },
  { phone: '9000000002', fullName: 'Demo Admin', role: 'ADMIN', password: 'Demo@1234' },
  { phone: '9000000003', fullName: 'Demo Accountant', role: 'ACCOUNTANT', password: 'Demo@1234' },
  { phone: '9000000004', fullName: 'Demo Cashier', role: 'OPERATOR', password: 'Demo@1234' },
  { phone: '9000000005', fullName: 'Demo Salesman', role: 'OPERATOR', password: 'Demo@1234' },
  { phone: '9000000006', fullName: 'Demo Manager', role: 'ADMIN', password: 'Demo@1234' },
  { phone: '9000000007', fullName: 'Demo Viewer', role: 'VIEWER', password: 'Demo@1234' },
]

export function LoginPage() {
  const navigate = useNavigate()
  const login = useSessionStore((state) => state.login)
  const [demoInfo, setDemoInfo] = useState<DemoInfo>({
    enabled: true,
    orgName: 'Demo Distributor',
    users: DEFAULT_DEMO_USERS,
  })
  const [isDemoExpanded, setIsDemoExpanded] = useState(true)
  const [copiedPhone, setCopiedPhone] = useState<string | null>(null)
  const [signingInPhone, setSigningInPhone] = useState<string | null>(null)

  const form = useForm<LoginValues>({
    resolver: zodResolver(loginSchema),
    defaultValues: { identifier: '9000000001', password: 'Demo@1234' },
  })

  useEffect(() => {
    async function loadDemoInfo() {
      try {
        const res = await apiFetch<DemoInfo>('/api/v1/auth/demo-info')
        if (res && res.users && res.users.length > 0) {
          setDemoInfo(res)
        }
      } catch {
        // Fallback to default demo presets
      }
    }
    loadDemoInfo()
  }, [])

  async function onSubmit(values: LoginValues) {
    try {
      await login(values)
      navigate('/', { replace: true })
    } catch (error) {
      form.setError('root', {
        message: error instanceof ApiError ? error.message : 'Unable to sign in. Please try again.',
      })
    }
  }

  async function handleQuickLogin(user: DemoUser) {
    form.setValue('identifier', user.phone)
    form.setValue('password', user.password)
    setSigningInPhone(user.phone)
    try {
      await login({ identifier: user.phone, password: user.password })
      navigate('/', { replace: true })
    } catch (error) {
      form.setError('root', {
        message: error instanceof ApiError ? error.message : 'Unable to sign in. Please try again.',
      })
    } finally {
      setSigningInPhone(null)
    }
  }

  function handleCopyPhone(e: React.MouseEvent, phone: string) {
    e.stopPropagation()
    navigator.clipboard.writeText(phone)
    setCopiedPhone(phone)
    setTimeout(() => setCopiedPhone(null), 1500)
  }

  const getRoleBadgeStyle = (role: string) => {
    switch (role) {
      case 'OWNER':
        return { background: 'rgba(15, 133, 118, 0.12)', color: 'var(--brand-700)', border: '1px solid rgba(15, 133, 118, 0.3)' }
      case 'ADMIN':
        return { background: 'rgba(37, 99, 235, 0.12)', color: '#2563eb', border: '1px solid rgba(37, 99, 235, 0.3)' }
      case 'ACCOUNTANT':
        return { background: 'rgba(147, 51, 234, 0.12)', color: '#9333ea', border: '1px solid rgba(147, 51, 234, 0.3)' }
      case 'VIEWER':
        return { background: 'rgba(107, 114, 128, 0.12)', color: '#6b7280', border: '1px solid rgba(107, 114, 128, 0.3)' }
      default:
        return { background: 'rgba(217, 119, 6, 0.12)', color: '#d97706', border: '1px solid rgba(217, 119, 6, 0.3)' }
    }
  }

  return (
    <main className="login-page">
      <section aria-labelledby="login-heading" className="login-panel">
        <div className="brand-lockup">
          <span aria-hidden="true" className="brand-mark">K</span>
          <span>Katasticho ERP</span>
        </div>
        <div className="login-copy">
          <p className="eyebrow">Enterprise Web Workspace</p>
          <h1 id="login-heading">Sign in to your business</h1>
          <p>
            Choose a demo profile below for one-click access, or sign in with your phone number or email credentials.
          </p>
        </div>

        {/* DEMO CREDENTIALS SELECTOR CARD */}
        {demoInfo.enabled && demoInfo.users.length > 0 && (
          <div
            style={{
              marginTop: 'var(--space-6)',
              padding: '12px 14px',
              borderRadius: 'var(--radius)',
              border: '1px solid rgba(15, 133, 118, 0.35)',
              backgroundColor: 'rgba(15, 133, 118, 0.04)',
            }}
          >
            {/* Header / Accordion Toggle */}
            <div
              onClick={() => setIsDemoExpanded(!isDemoExpanded)}
              onKeyDown={(e) => (e.key === 'Enter' || e.key === ' ') && setIsDemoExpanded(!isDemoExpanded)}
              role="button"
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                cursor: 'pointer',
                userSelect: 'none',
              }}
              tabIndex={0}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                <Zap color="var(--brand-600)" size={16} />
                <strong style={{ fontSize: '0.85rem', color: 'var(--brand-700)' }}>
                  Demo Credentials &bull; {demoInfo.orgName}
                </strong>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                <span style={{ fontSize: '0.75rem', color: 'var(--text-secondary)' }}>
                  {demoInfo.users.length} roles
                </span>
                {isDemoExpanded ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
              </div>
            </div>

            {/* Expanded List of Demo Users */}
            {isDemoExpanded && (
              <div style={{ marginTop: 10 }}>
                <p style={{ fontSize: '0.75rem', color: 'var(--text-secondary)', marginBottom: 8 }}>
                  Click any role to auto-fill and sign in instantly. Password for all users is{' '}
                  <code style={{ background: 'rgba(0,0,0,0.06)', padding: '1px 4px', borderRadius: 3 }}>
                    {demoInfo.users[0]?.password || 'Demo@1234'}
                  </code>
                  .
                </p>

                <div style={{ display: 'flex', flexDirection: 'column', gap: 6, maxHeight: 220, overflowY: 'auto' }}>
                  {demoInfo.users.map((user) => {
                    const badge = getRoleBadgeStyle(user.role)
                    const isCurrentSigningIn = signingInPhone === user.phone
                    return (
                      <div
                        key={user.phone}
                        onClick={() => handleQuickLogin(user)}
                        onKeyDown={(e) => (e.key === 'Enter' || e.key === ' ') && handleQuickLogin(user)}
                        role="button"
                        style={{
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'space-between',
                          padding: '6px 8px',
                          borderRadius: 'var(--radius)',
                          border: '1px solid var(--border)',
                          backgroundColor: 'var(--bg-surface)',
                          cursor: 'pointer',
                          transition: 'background 0.15s ease',
                        }}
                        tabIndex={0}
                      >
                        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                          <span
                            style={{
                              ...badge,
                              fontSize: '0.68rem',
                              fontWeight: 700,
                              padding: '2px 6px',
                              borderRadius: 4,
                              textTransform: 'uppercase',
                              letterSpacing: '0.04em',
                            }}
                          >
                            {user.role}
                          </span>
                          <div>
                            <strong style={{ fontSize: '0.82rem', display: 'block' }}>{user.fullName}</strong>
                            <code style={{ fontSize: '0.72rem', color: 'var(--text-secondary)' }}>{user.phone}</code>
                          </div>
                        </div>

                        <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                          <button
                            onClick={(e) => handleCopyPhone(e, user.phone)}
                            style={{
                              border: 'none',
                              background: 'transparent',
                              padding: '4px',
                              cursor: 'pointer',
                              color: 'var(--text-muted)',
                            }}
                            title="Copy Phone Number"
                            type="button"
                          >
                            {copiedPhone === user.phone ? <Check color="var(--pos-text)" size={13} /> : <Copy size={13} />}
                          </button>

                          <span
                            style={{
                              fontSize: '0.75rem',
                              fontWeight: 600,
                              color: 'var(--brand-600)',
                              display: 'inline-flex',
                              alignItems: 'center',
                              gap: 2,
                            }}
                          >
                            {isCurrentSigningIn ? 'Signing in...' : 'Sign in'} <ArrowRight size={11} />
                          </span>
                        </div>
                      </div>
                    )
                  })}
                </div>
              </div>
            )}
          </div>
        )}

        <form className="login-form" noValidate onSubmit={form.handleSubmit(onSubmit)}>
          <TextField
            autoComplete="username"
            error={form.formState.errors.identifier?.message}
            label="Phone or email"
            placeholder="e.g. 9000000001"
            {...form.register('identifier')}
          />
          <TextField
            autoComplete="current-password"
            error={form.formState.errors.password?.message}
            label="Password"
            placeholder="Enter your password"
            type="password"
            {...form.register('password')}
          />
          {form.formState.errors.root && (
            <p className="form-error" role="alert">
              {form.formState.errors.root.message}
            </p>
          )}
          <Button loading={form.formState.isSubmitting} type="submit">
            Sign in <ArrowRight aria-hidden="true" size={17} />
          </Button>
        </form>

        <div className="session-note">
          <ShieldCheck aria-hidden="true" size={18} />
          <p>
            Your browser keeps only a short-lived access token in memory. The rotating session token is protected in an
            HttpOnly cookie.
          </p>
        </div>
      </section>

      <aside aria-label="React migration information" className="login-aside">
        <p className="eyebrow">Enterprise Unified Suite</p>
        <h2>One workspace, shared ledger.</h2>
        <p>
          Katasticho React web workspace runs seamlessly against the Spring Boot PostgreSQL ERP backend with real-time
          accounting, inventory, field sales, and manufacturing depth.
        </p>
        <ul>
          <li>Role-based access control (Owner, Admin, Accountant, Operator, Viewer)</li>
          <li>Double-entry general ledger, Indian GST, TDS/TCS, and Kenya eTIMS compliance</li>
          <li>Autonomous AI Copilot, conversational bookkeeping, and OCR receipt scanner</li>
        </ul>
      </aside>
    </main>
  )
}
