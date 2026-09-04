import { useEffect, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  RefreshCw,
  Save,
  Server,
} from 'lucide-react'
import { Button } from '@/design-system/button'
import { PageHeader } from '@/design-system/page-header'
import {
  getAiSettings,
  getAiStatus,
  listInstalledModels,
  testAiConnection,
  updateAiSettings,
  type AiModelSettings,
} from '@/features/ai/ai-api'

export function AiSettingsPage() {
  const queryClient = useQueryClient()
  const [provider, setProvider] = useState<string>('CLAUDE')
  const [modelName, setModelName] = useState<string>('claude-sonnet-4-20250514')
  const [baseUrl, setBaseUrl] = useState<string>('http://localhost:11434')
  const [testResult, setTestResult] = useState<{ success: boolean; message: string } | null>(null)
  const [installedModels, setInstalledModels] = useState<string[]>([])

  const settingsQuery = useQuery({
    queryKey: ['ai-settings'],
    queryFn: getAiSettings,
  })

  const statusQuery = useQuery({
    queryKey: ['ai-status'],
    queryFn: getAiStatus,
  })

  useEffect(() => {
    if (settingsQuery.data) {
      setProvider(settingsQuery.data.provider || 'CLAUDE')
      setModelName(settingsQuery.data.modelName || 'claude-sonnet-4-20250514')
      if (settingsQuery.data.baseUrl) setBaseUrl(settingsQuery.data.baseUrl)
    }
  }, [settingsQuery.data])

  const updateMutation = useMutation({
    mutationFn: (req: AiModelSettings) => updateAiSettings(req),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['ai-settings'] })
      queryClient.invalidateQueries({ queryKey: ['ai-status'] })
    },
  })

  const testMutation = useMutation({
    mutationFn: (url: string) => testAiConnection(url),
    onSuccess: (res) => {
      setTestResult(res)
    },
  })

  const loadModelsMutation = useMutation({
    mutationFn: (url: string) => listInstalledModels(url),
    onSuccess: (models) => {
      setInstalledModels(models)
    },
  })

  const handleSave = () => {
    updateMutation.mutate({
      provider,
      modelName,
      baseUrl: provider === 'OLLAMA' ? baseUrl : null,
    })
  }

  const handleTestOllama = () => {
    testMutation.mutate(baseUrl)
    loadModelsMutation.mutate(baseUrl)
  }

  const status = statusQuery.data

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="System Configuration & LLM Infrastructure"
        title="AI Model & Provider Settings"
        description="Configure cloud LLMs (Anthropic Claude, OpenAI, Gemini) or connect private on-premise local inference servers (Ollama) with complete data confidentiality."
        actions={
          <Button disabled={updateMutation.isPending} onClick={handleSave} variant="primary">
            <Save aria-hidden="true" size={14} style={{ marginRight: 6 }} />
            {updateMutation.isPending ? 'Saving...' : 'Save AI Configuration'}
          </Button>
        }
      />

      {/* Connection Status Card */}
      <div
        className="panel-card"
        style={{
          padding: 'var(--space-md)',
          marginBottom: 'var(--space-md)',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          backgroundColor: status?.reachable ? 'rgba(16, 185, 129, 0.05)' : 'rgba(239, 68, 68, 0.05)',
          border: `1px solid ${status?.reachable ? 'rgba(16, 185, 129, 0.25)' : 'rgba(239, 68, 68, 0.25)'}`,
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <Server size={22} color={status?.reachable ? 'var(--color-success)' : 'var(--color-error)'} />
          <div>
            <strong style={{ fontSize: '0.95rem', display: 'block' }}>
              Active AI Engine: {status?.provider || provider} ({status?.model || modelName})
            </strong>
            <span className="cell-muted" style={{ fontSize: '0.8rem' }}>
              Status: {status?.reachable ? 'Connected & Ready for Autonomous Workflows' : 'Unreachable / API Key Missing'}
            </span>
          </div>
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 'var(--space-md)' }}>
        {/* Provider Selection */}
        <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
          <h3 style={{ fontSize: '1.05rem', fontWeight: 600, marginBottom: 'var(--space-sm)' }}>
            LLM Provider & Hosting Mode
          </h3>
          <p className="cell-muted" style={{ fontSize: '0.8rem', marginBottom: 'var(--space-md)' }}>
            Select whether Katasticho uses cloud frontier models or on-premise air-gapped models.
          </p>

          <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-sm)' }}>
            <label style={{ display: 'flex', alignItems: 'flex-start', gap: 10, padding: '10px 12px', border: '1px solid var(--color-border)', borderRadius: 'var(--radius-md)', cursor: 'pointer' }}>
              <input
                checked={provider === 'CLAUDE'}
                name="ai-provider"
                onChange={() => {
                  setProvider('CLAUDE')
                  setModelName('claude-sonnet-4-20250514')
                }}
                type="radio"
              />
              <div>
                <strong style={{ fontSize: '0.9rem', display: 'block' }}>Anthropic Claude (Recommended)</strong>
                <span className="cell-muted" style={{ fontSize: '0.78rem' }}>
                  Top-tier reasoning, vision parsing for receipts, and complex double-entry extraction.
                </span>
              </div>
            </label>

            <label style={{ display: 'flex', alignItems: 'flex-start', gap: 10, padding: '10px 12px', border: '1px solid var(--color-border)', borderRadius: 'var(--radius-md)', cursor: 'pointer' }}>
              <input
                checked={provider === 'OLLAMA'}
                name="ai-provider"
                onChange={() => {
                  setProvider('OLLAMA')
                  setModelName('llama3:latest')
                }}
                type="radio"
              />
              <div>
                <strong style={{ fontSize: '0.9rem', display: 'block' }}>Local On-Premise Ollama (Air-Gapped)</strong>
                <span className="cell-muted" style={{ fontSize: '0.78rem' }}>
                  Zero data leaves your local network. Requires local GPU/server running Ollama.
                </span>
              </div>
            </label>

            <label style={{ display: 'flex', alignItems: 'flex-start', gap: 10, padding: '10px 12px', border: '1px solid var(--color-border)', borderRadius: 'var(--radius-md)', cursor: 'pointer' }}>
              <input
                checked={provider === 'OPENAI'}
                name="ai-provider"
                onChange={() => {
                  setProvider('OPENAI')
                  setModelName('gpt-4o')
                }}
                type="radio"
              />
              <div>
                <strong style={{ fontSize: '0.9rem', display: 'block' }}>OpenAI GPT-4o</strong>
                <span className="cell-muted" style={{ fontSize: '0.78rem' }}>
                  High speed multimodal reasoning and function calling.
                </span>
              </div>
            </label>
          </div>
        </div>

        {/* Server & Model Parameters */}
        <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
          <h3 style={{ fontSize: '1.05rem', fontWeight: 600, marginBottom: 'var(--space-sm)' }}>
            Model Selection & Endpoint
          </h3>
          <p className="cell-muted" style={{ fontSize: '0.8rem', marginBottom: 'var(--space-md)' }}>
            Configure model tags, endpoints, and test connection latency.
          </p>

          <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-md)' }}>
            <div>
              <label style={{ fontSize: '0.85rem', fontWeight: 600, display: 'block', marginBottom: 4 }}>
                Model Identifier
              </label>
              <input
                className="input-field"
                onChange={(e) => setModelName(e.target.value)}
                style={{ width: '100%', padding: '8px 12px', borderRadius: 'var(--radius-md)', border: '1px solid var(--color-border)' }}
                type="text"
                value={modelName}
              />
            </div>

            {provider === 'OLLAMA' && (
              <div>
                <label style={{ fontSize: '0.85rem', fontWeight: 600, display: 'block', marginBottom: 4 }}>
                  Local Ollama Base URL
                </label>
                <div style={{ display: 'flex', gap: 8 }}>
                  <input
                    className="input-field"
                    onChange={(e) => setBaseUrl(e.target.value)}
                    placeholder="http://localhost:11434"
                    style={{ flex: 1, padding: '8px 12px', borderRadius: 'var(--radius-md)', border: '1px solid var(--color-border)' }}
                    type="text"
                    value={baseUrl}
                  />
                  <Button disabled={testMutation.isPending} onClick={handleTestOllama} variant="secondary">
                    <RefreshCw size={14} style={{ marginRight: 4 }} />
                    Test & Fetch Models
                  </Button>
                </div>

                {testResult && (
                  <p
                    style={{
                      fontSize: '0.8rem',
                      fontWeight: 600,
                      marginTop: 6,
                      color: testResult.success ? 'var(--color-success)' : 'var(--color-error)',
                    }}
                  >
                    {testResult.message}
                  </p>
                )}

                {installedModels.length > 0 && (
                  <div style={{ marginTop: 8 }}>
                    <span className="cell-muted" style={{ fontSize: '0.75rem' }}>Installed models on server:</span>
                    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginTop: 4 }}>
                      {installedModels.map((m) => (
                        <button
                          key={m}
                          onClick={() => setModelName(m)}
                          style={{
                            padding: '3px 8px',
                            borderRadius: 'var(--radius-sm)',
                            border: '1px solid var(--color-border)',
                            background: modelName === m ? 'var(--color-primary)' : 'var(--color-surface)',
                            color: modelName === m ? '#fff' : 'inherit',
                            fontSize: '0.75rem',
                            cursor: 'pointer',
                          }}
                        >
                          {m}
                        </button>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            )}
          </div>
        </div>
      </div>
    </section>
  )
}
