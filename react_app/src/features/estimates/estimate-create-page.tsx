import { Link, useNavigate } from 'react-router-dom'
import { PageHeader } from '@/design-system'
import { useSessionStore } from '@/shared/session/session-store'
import { EstimateForm } from './estimate-form'
import { estimatePermissions } from './estimate-form-model'

export function EstimateCreatePage() {
  const navigate = useNavigate()
  const user = useSessionStore((state) => state.user)
  return <section className="workspace-page">
    <Link className="form-back-link" to="/estimates">Back to estimates</Link>
    <PageHeader eyebrow="Sales / Quotations" title="New estimate" description="Prepare a customer proposal. Saving an estimate does not reserve stock or post accounting entries." />
    {estimatePermissions(user?.role).write
      ? <EstimateForm key={user?.orgId} onSaved={(estimate) => navigate(`/estimates/${estimate.id}`)} onCancel={() => navigate('/estimates')} />
      : <div role="alert" className="banner banner--error">Your role has read-only access to estimates.</div>}
  </section>
}
