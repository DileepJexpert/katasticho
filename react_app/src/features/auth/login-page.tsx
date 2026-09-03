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
      <section className="login-panel" aria-labelledby="login-heading">
        <div className="brand-lockup">
          <span className="brand-mark" aria-hidden="true">K</span>
          <span>Katasticho</span>
        </div>
        <div className="login-copy">
          <p className="eyebrow">React workspace</p>
          <h1 id="login-heading">Sign in to your business.</h1>
          <p>Use the same account you use in Katasticho today. Your financial and inventory data stays in the existing ERP backend.</p>
        </div>

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
          {form.formState.errors.root && <p className="form-error" role="alert">{form.formState.errors.root.message}</p>}
          <Button loading={form.formState.isSubmitting} type="submit">
            Sign in <ArrowRight size={17} aria-hidden="true" />
          </Button>
        </form>

        <div className="session-note">
          <ShieldCheck size={18} aria-hidden="true" />
          <p>Your browser keeps only a short-lived access token in memory. The rotating session token is protected in an HttpOnly cookie.</p>
        </div>
      </section>
      <aside className="login-aside" aria-label="React migration information">
        <p className="eyebrow">Wave 1</p>
        <h2>One workspace, staged safely.</h2>
        <p>React and Flutter run against the same Spring API and database while each operational workflow is migrated and verified.</p>
        <ul>
          <li>Shared business rules and organisation security</li>
          <li>No token persistence in browser storage</li>
          <li>Flutter remains available during parallel testing</li>
        </ul>
      </aside>
    </main>
  )
}
