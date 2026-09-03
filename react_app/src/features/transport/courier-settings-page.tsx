import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Check, Copy, ShieldCheck, Zap } from 'lucide-react'
import { Button } from '@/design-system/button'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import {
  getCourierSettings,
  updateCourierSettings,
  testCourierConnection,
  getCourierWebhookUrl,
} from '@/features/transport/transport-api'

const partners = [
  { id: 'BLUEDART', name: 'Blue Dart Express', desc: 'Direct API for Domestic Apex & Surface consignments' },
  { id: 'DELHIVERY', name: 'Delhivery', desc: 'B2B & B2C express logistics and surface cargo API' },
  { id: 'SHIPROCKET', name: 'Shiprocket', desc: 'Aggregator gateway multi-carrier dispatch & rate sync' },
  { id: 'DTDC', name: 'DTDC Courier', desc: 'Domestic express & DotZot eCommerce API' },
  { id: 'INDIA_POST', name: 'India Post (Speed Post)', desc: 'Government postal service & BNPL integration' },
]

export function CourierSettingsPage() {
  const [activePartner, setActivePartner] = useState('BLUEDART')
  const [feedback, setFeedback] = useState<string | null>(null)
  const [errorFeedback, setErrorFeedback] = useState<string | null>(null)
  const [copied, setCopied] = useState(false)
  const queryClient = useQueryClient()

  const settingsQuery = useQuery({
    queryKey: ['courier-settings'],
    queryFn: getCourierSettings,
  })

  const webhookQuery = useQuery({
    queryKey: ['courier-webhook-url', activePartner],
    queryFn: () => getCourierWebhookUrl(activePartner),
  })

  const updateMutation = useMutation({
    mutationFn: ({ partner, body }: { partner: string; body: Record<string, string> }) =>
      updateCourierSettings(partner, body),
    onSuccess: () => {
      setFeedback('Carrier settings and credentials saved.')
      setErrorFeedback(null)
      queryClient.invalidateQueries({ queryKey: ['courier-settings'] })
    },
    onError: (err: Error) => {
      setErrorFeedback(err.message || 'Failed to save settings.')
    },
  })

  const testMutation = useMutation({
    mutationFn: (partner: string) => testCourierConnection(partner),
    onSuccess: (res) => {
      if (res.success) {
        setFeedback(res.message || 'Connection test successful! Carrier gateway responded.')
        setErrorFeedback(null)
      } else {
        setErrorFeedback(res.message || 'Connection test failed. Verify credentials.')
      }
    },
    onError: (err: Error) => {
      setErrorFeedback(err.message || 'Gateway connection test failed.')
    },
  })

  const currentSettings = settingsQuery.data?.[activePartner] ?? {}

  const handleCopyWebhook = () => {
    if (webhookQuery.data?.path) {
      const fullUrl = `${window.location.origin}${webhookQuery.data.path}`
      navigator.clipboard.writeText(fullUrl)
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    }
  }

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Settings & Integration"
        title="Courier Gateways"
        description="Configure carrier API credentials, aggregator webhooks, and live tracking automated sync."
        actions={<StatusChip status="Admin only" />}
      />

      {feedback ? (
        <div className="notification-banner notification-banner--success" role="status">
          <p>{feedback}</p>
          <button className="banner-dismiss" onClick={() => setFeedback(null)} type="button">×</button>
        </div>
      ) : null}

      {errorFeedback ? (
        <div className="notification-banner notification-banner--error" role="alert">
          <p>{errorFeedback}</p>
          <button className="banner-dismiss" onClick={() => setErrorFeedback(null)} type="button">×</button>
        </div>
      ) : null}

      <div className="settings-grid">
        <aside className="settings-sidebar">
          <nav className="settings-nav">
            {partners.map((p) => (
              <button
                className={activePartner === p.id ? 'settings-nav-item settings-nav-item--active' : 'settings-nav-item'}
                key={p.id}
                onClick={() => {
                  setActivePartner(p.id)
                  setFeedback(null)
                  setErrorFeedback(null)
                }}
                type="button"
              >
                <strong>{p.name}</strong>
                <small>{p.desc}</small>
              </button>
            ))}
          </nav>
        </aside>

        <main className="settings-content">
          <article className="document-card">
            <header className="document-card-header">
              <div>
                <h2>{partners.find((p) => p.id === activePartner)?.name} Integration</h2>
                <p className="cell-muted">Enter production API keys and account details for dispatch generation.</p>
              </div>
              <Button
                disabled={testMutation.isPending}
                onClick={() => testMutation.mutate(activePartner)}
                variant="secondary"
              >
                <Zap aria-hidden="true" size={16} />
                {testMutation.isPending ? 'Testing...' : 'Test Gateway Connection'}
              </Button>
            </header>

            <PartnerSettingsForm
              initialValues={currentSettings}
              isSaving={updateMutation.isPending}
              key={activePartner}
              onSave={(body) => updateMutation.mutate({ partner: activePartner, body })}
            />

            <hr className="divider" style={{ margin: '1.5rem 0' }} />

            <div>
              <h3>Inbound Status Webhook URL</h3>
              <p className="cell-muted" style={{ marginBottom: '0.75rem' }}>
                Paste this webhook endpoint in your carrier dashboard to receive real-time delivery and RTO notifications.
              </p>
              <div className="code-snippet-box" style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                <code style={{ flex: 1, padding: '0.5rem', background: 'var(--k-color-bg-subtle, #f5f5f5)', borderRadius: '4px' }}>
                  {webhookQuery.data?.path ? `${window.location.origin}${webhookQuery.data.path}` : 'Generating webhook endpoint...'}
                </code>
                <Button onClick={handleCopyWebhook} variant="secondary">
                  {copied ? <Check size={16} /> : <Copy size={16} />}
                  {copied ? 'Copied' : 'Copy'}
                </Button>
              </div>
            </div>
          </article>
        </main>
      </div>
    </section>
  )
}

function PartnerSettingsForm({
  initialValues,
  isSaving,
  onSave,
}: {
  initialValues: Record<string, string>
  isSaving: boolean
  onSave: (body: Record<string, string>) => void
}) {
  const [apiKey, setApiKey] = useState(initialValues.apiKey ?? '')
  const [apiSecret, setApiSecret] = useState(initialValues.apiSecret ?? '')
  const [customerId, setCustomerId] = useState(initialValues.customerId ?? '')
  const [licenseKey, setLicenseKey] = useState(initialValues.licenseKey ?? '')
  const [loginId, setLoginId] = useState(initialValues.loginId ?? '')
  const [baseUrl, setBaseUrl] = useState(initialValues.baseUrl ?? '')

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    onSave({
      apiKey,
      apiSecret,
      customerId,
      licenseKey,
      loginId,
      baseUrl,
    })
  }

  return (
    <form onSubmit={handleSubmit} style={{ marginTop: '1rem' }}>
      <div className="form-row">
        <div className="form-group">
          <label htmlFor="cfg-key">API Key / Token</label>
          <input
            id="cfg-key"
            placeholder="Carrier API Key"
            type="password"
            value={apiKey}
            onChange={(e) => setApiKey(e.target.value)}
          />
        </div>
        <div className="form-group">
          <label htmlFor="cfg-secret">API Secret</label>
          <input
            id="cfg-secret"
            placeholder="Carrier API Secret"
            type="password"
            value={apiSecret}
            onChange={(e) => setApiSecret(e.target.value)}
          />
        </div>
      </div>

      <div className="form-row">
        <div className="form-group">
          <label htmlFor="cfg-customer">Customer / Merchant Code</label>
          <input
            id="cfg-customer"
            placeholder="e.g. 109283"
            type="text"
            value={customerId}
            onChange={(e) => setCustomerId(e.target.value)}
          />
        </div>
        <div className="form-group">
          <label htmlFor="cfg-login">Login ID / User Account</label>
          <input
            id="cfg-login"
            placeholder="e.g. BLUEDART_ACC_01"
            type="text"
            value={loginId}
            onChange={(e) => setLoginId(e.target.value)}
          />
        </div>
      </div>

      <div className="form-row">
        <div className="form-group">
          <label htmlFor="cfg-license">License Key (if applicable)</label>
          <input
            id="cfg-license"
            type="password"
            value={licenseKey}
            onChange={(e) => setLicenseKey(e.target.value)}
          />
        </div>
        <div className="form-group">
          <label htmlFor="cfg-url">Custom API Base URL (optional)</label>
          <input
            id="cfg-url"
            placeholder="https://api.carrier.com"
            type="url"
            value={baseUrl}
            onChange={(e) => setBaseUrl(e.target.value)}
          />
        </div>
      </div>

      <footer className="form-actions" style={{ marginTop: '1rem' }}>
        <Button disabled={isSaving} type="submit" variant="primary">
          <ShieldCheck aria-hidden="true" size={16} />
          {isSaving ? 'Saving...' : 'Save Carrier Credentials'}
        </Button>
      </footer>
    </form>
  )
}