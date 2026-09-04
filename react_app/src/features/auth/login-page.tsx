import { zodResolver } from '@hookform/resolvers/zod'
import { ArrowRight, ShieldCheck } from 'lucide-react'
import { useForm } from 'react-hook-form'
import { useNavigate } from 'react-router-dom'
import { z } from 'zod'
import { Button } from '@/design-system/button'
import { TextField } from '@/design-system/text-field'
import { ApiError } from '@/api/client/api-client'
import { useSessionStore } from '@/shared/session/session-store'

const loginSchema = z.object({
  identifier: z.string().trim().min(1, 'Enter your phone number or email address.'),
  password: z.string().min(1, 'Enter your password.'),
})

type LoginValues = z.infer<typeof loginSchema>

export function LoginPage() {
  const navigate = useNavigate()
  const login = useSessionStore((state) => state.login)

  const form = useForm<LoginValues>({
    resolver: zodResolver(loginSchema),
    defaultValues: { identifier: '', password: '' },
  })

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
            Enter your mobile number or company email and password to access your ERP organisation.
          </p>
        </div>

        <form className="login-form" noValidate onSubmit={form.handleSubmit(onSubmit)}>
          <TextField
            autoComplete="username"
            error={form.formState.errors.identifier?.message}
            label="Phone or email"
            placeholder="e.g. 9000000001 or admin@company.com"
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
