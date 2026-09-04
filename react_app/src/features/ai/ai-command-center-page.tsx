import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  AlertTriangle,
  Bot,
  BrainCircuit,
  CheckCircle2,
  Database,
  Download,
  FileCheck,
  FileText,
  FileUp,
  RefreshCw,
  Send,
  ShieldAlert,
  Sparkles,
  Upload,
  XCircle,
  Zap,
} from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import {
  approveEntryDraft,
  chatWithAgent,
  draftFromText,
  exportTrainingJsonl,
  getSuggestionSummary,
  getTrainingSummary,
  listSuggestions,
  rejectEntryDraft,
  reviewSuggestion,
  runProactiveSweep,
  runRuleChecks,
  scanBill,
  type AgentChatResponse,
  type BillScanResponse,
  type EntryDraftResult,
} from '@/features/ai/ai-api'

type ActiveTab = 'copilot' | 'inbox' | 'ocr' | 'training'

export function AiCommandCenterPage() {
  const queryClient = useQueryClient()
  const [activeTab, setActiveTab] = useState<ActiveTab>('copilot')

  // Copilot Chat state
  const [chatInput, setChatInput] = useState('')
  const [chatMessages, setChatMessages] = useState<Array<{ role: 'user' | 'agent'; text: string; data?: unknown; actionRequired?: boolean; draftId?: string }>>([
    {
      role: 'agent',
      text: 'Hello! I am your AI ERP Copilot. You can ask natural-language business questions ("What were top selling items this week?") or type bookkeeping sentences ("Paid ₹8,500 cash for shop internet bill").',
    },
  ])

  // Direct Sentence Voucher Draft state
  const [voucherSentence, setVoucherSentence] = useState('')
  const [latestDraftResult, setLatestDraftResult] = useState<EntryDraftResult | null>(null)

  // OCR state
  const [billImageBase64, setBillImageBase64] = useState<string>('')
  const [scanResult, setScanResult] = useState<BillScanResponse | null>(null)

  // Suggestion filters
  const [suggestionStatus, setSuggestionStatus] = useState<string>('PENDING')

  // Queries
  const summaryQuery = useQuery({
    queryKey: ['ai-suggestions-summary'],
    queryFn: getSuggestionSummary,
  })

  const suggestionsQuery = useQuery({
    queryKey: ['ai-suggestions', suggestionStatus],
    queryFn: () => listSuggestions(suggestionStatus),
  })

  const trainingQuery = useQuery({
    queryKey: ['ai-training-summary'],
    queryFn: getTrainingSummary,
  })

  // Mutations
  const agentChatMutation = useMutation({
    mutationFn: (msg: string) => chatWithAgent(msg),
    onSuccess: (res: AgentChatResponse) => {
      setChatMessages((prev) => [
        ...prev,
        {
          role: 'agent',
          text: res.reply,
          data: res.data,
          actionRequired: res.actionRequired,
          draftId: res.draftSuggestionId,
        },
      ])
    },
  })

  const draftVoucherMutation = useMutation({
    mutationFn: (text: string) => draftFromText(text),
    onSuccess: (res: EntryDraftResult) => {
      setLatestDraftResult(res)
      queryClient.invalidateQueries({ queryKey: ['ai-suggestions'] })
      queryClient.invalidateQueries({ queryKey: ['ai-suggestions-summary'] })
    },
  })

  const approveDraftMutation = useMutation({
    mutationFn: (suggestionId: string) => approveEntryDraft(suggestionId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['ai-suggestions'] })
      queryClient.invalidateQueries({ queryKey: ['ai-suggestions-summary'] })
      setLatestDraftResult(null)
    },
  })

  const rejectDraftMutation = useMutation({
    mutationFn: (suggestionId: string) => rejectEntryDraft(suggestionId, 'User discarded in Copilot'),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['ai-suggestions'] })
      queryClient.invalidateQueries({ queryKey: ['ai-suggestions-summary'] })
      setLatestDraftResult(null)
    },
  })

  const reviewSuggestionMutation = useMutation({
    mutationFn: ({ id, action }: { id: string; action: 'ACCEPT' | 'REJECT' }) =>
      reviewSuggestion(id, { reviewAction: action }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['ai-suggestions'] })
      queryClient.invalidateQueries({ queryKey: ['ai-suggestions-summary'] })
    },
  })

  const ruleCheckMutation = useMutation({
    mutationFn: () => runRuleChecks(30),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['ai-suggestions'] })
      queryClient.invalidateQueries({ queryKey: ['ai-suggestions-summary'] })
    },
  })

  const proactiveSweepMutation = useMutation({
    mutationFn: () => runProactiveSweep(),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['ai-suggestions'] })
      queryClient.invalidateQueries({ queryKey: ['ai-suggestions-summary'] })
    },
  })

  const scanBillMutation = useMutation({
    mutationFn: (img: string) => scanBill({ image: img, mediaType: 'image/png' }),
    onSuccess: (res: BillScanResponse) => {
      setScanResult(res)
    },
  })

  const handleSendMessage = () => {
    if (!chatInput.trim()) return
    const msg = chatInput.trim()
    setChatMessages((prev) => [...prev, { role: 'user', text: msg }])
    setChatInput('')
    agentChatMutation.mutate(msg)
  }

  const handleDraftVoucher = () => {
    if (!voucherSentence.trim()) return
    draftVoucherMutation.mutate(voucherSentence.trim())
  }

  const handleImageUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    const reader = new FileReader()
    reader.onload = (ev) => {
      const b64 = ev.target?.result as string
      setBillImageBase64(b64)
      const cleanB64 = (b64.includes(',') ? b64.split(',')[1] : b64) ?? ''
      if (cleanB64) {
        scanBillMutation.mutate(cleanB64)
      }
    }
    reader.readAsDataURL(file)
  }

  const handleExportJsonl = async () => {
    const jsonl = await exportTrainingJsonl()
    const blob = new Blob([jsonl], { type: 'application/x-ndjson' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = 'katasticho-lora-training.jsonl'
    a.click()
    URL.revokeObjectURL(url)
  }

  const summary = summaryQuery.data
  const suggestions = suggestionsQuery.data?.content ?? []
  const training = trainingQuery.data

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Artificial Intelligence & Autonomous Decisioning"
        title="AI Command Center & Copilot"
        description="Autonomous ledger intelligence, conversational transaction drafting, document OCR extraction, anomaly detection inbox, and human-in-the-loop LoRA fine-tuning."
        actions={
          <div style={{ display: 'flex', gap: 'var(--space-sm)' }}>
            <Button
              disabled={ruleCheckMutation.isPending}
              onClick={() => ruleCheckMutation.mutate()}
              variant="secondary"
            >
              <Zap aria-hidden="true" size={14} style={{ marginRight: 6 }} />
              Run Rule Check Sweep
            </Button>
            <Button
              disabled={proactiveSweepMutation.isPending}
              onClick={() => proactiveSweepMutation.mutate()}
              variant="primary"
            >
              <BrainCircuit aria-hidden="true" size={14} style={{ marginRight: 6 }} />
              Run Proactive Audit
            </Button>
          </div>
        }
      />

      {/* KPI Metrics Strip */}
      <div className="summary-strip">
        <div className="summary-card">
          <span className="summary-card__label">Pending AI Suggestions</span>
          <strong className="summary-card__value" style={{ color: 'var(--color-primary)' }}>
            <Quantity value={summary?.pendingCount ?? 0} /> Suggestions
          </strong>
          <span className="summary-card__hint">Awaiting human review</span>
        </div>

        <div className="summary-card">
          <span className="summary-card__label">Audit Anomalies & Risks</span>
          <strong className="summary-card__value" style={{ color: 'var(--color-warning)' }}>
            <Quantity value={summary?.riskAnomalyCount ?? 0} /> Risks Flagged
          </strong>
          <span className="summary-card__hint">Tax, duplicate & ledger checks</span>
        </div>

        <div className="summary-card summary-card--accent">
          <span className="summary-card__label">Supervised Training Examples</span>
          <strong className="summary-card__value" style={{ color: 'var(--color-success)' }}>
            <Quantity value={training?.totalExamples ?? 0} /> Data Points
          </strong>
          <span className="summary-card__hint">Verified for LoRA / SFT tuning</span>
        </div>
      </div>

      {/* Main Tab Navigation */}
      <div
        style={{
          display: 'flex',
          borderBottom: '1px solid var(--color-border)',
          gap: 'var(--space-md)',
          marginBottom: 'var(--space-md)',
        }}
      >
        <button
          className={`tab-button ${activeTab === 'copilot' ? 'tab-button--active' : ''}`}
          onClick={() => setActiveTab('copilot')}
          style={{
            padding: '8px 16px',
            border: 'none',
            background: 'none',
            fontWeight: 600,
            cursor: 'pointer',
            borderBottom: activeTab === 'copilot' ? '2px solid var(--color-primary)' : '2px solid transparent',
            color: activeTab === 'copilot' ? 'var(--color-primary)' : 'var(--color-text-secondary)',
          }}
        >
          <Bot size={15} style={{ display: 'inline', marginRight: 6 }} />
          Conversational Copilot & Fast Vouchers
        </button>

        <button
          className={`tab-button ${activeTab === 'inbox' ? 'tab-button--active' : ''}`}
          onClick={() => setActiveTab('inbox')}
          style={{
            padding: '8px 16px',
            border: 'none',
            background: 'none',
            fontWeight: 600,
            cursor: 'pointer',
            borderBottom: activeTab === 'inbox' ? '2px solid var(--color-primary)' : '2px solid transparent',
            color: activeTab === 'inbox' ? 'var(--color-primary)' : 'var(--color-text-secondary)',
          }}
        >
          <ShieldAlert size={15} style={{ display: 'inline', marginRight: 6 }} />
          Anomaly & Suggestion Inbox ({summary?.pendingCount ?? 0})
        </button>

        <button
          className={`tab-button ${activeTab === 'ocr' ? 'tab-button--active' : ''}`}
          onClick={() => setActiveTab('ocr')}
          style={{
            padding: '8px 16px',
            border: 'none',
            background: 'none',
            fontWeight: 600,
            cursor: 'pointer',
            borderBottom: activeTab === 'ocr' ? '2px solid var(--color-primary)' : '2px solid transparent',
            color: activeTab === 'ocr' ? 'var(--color-primary)' : 'var(--color-text-secondary)',
          }}
        >
          <FileUp size={15} style={{ display: 'inline', marginRight: 6 }} />
          Document OCR Scanner
        </button>

        <button
          className={`tab-button ${activeTab === 'training' ? 'tab-button--active' : ''}`}
          onClick={() => setActiveTab('training')}
          style={{
            padding: '8px 16px',
            border: 'none',
            background: 'none',
            fontWeight: 600,
            cursor: 'pointer',
            borderBottom: activeTab === 'training' ? '2px solid var(--color-primary)' : '2px solid transparent',
            color: activeTab === 'training' ? 'var(--color-primary)' : 'var(--color-text-secondary)',
          }}
        >
          <Database size={15} style={{ display: 'inline', marginRight: 6 }} />
          Model Training & Fine-Tuning
        </button>
      </div>

      {/* TAB 1: COPILOT & FAST VOUCHERS */}
      {activeTab === 'copilot' && (
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 'var(--space-md)' }}>
          {/* Conversational Assistant */}
          <div className="panel-card" style={{ padding: 'var(--space-md)', display: 'flex', flexDirection: 'column', height: '620px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 'var(--space-sm)' }}>
              <Sparkles size={18} color="var(--color-primary)" />
              <h3 style={{ fontSize: '1.05rem', fontWeight: 600 }}>Autonomous ERP Copilot</h3>
            </div>
            <p className="cell-muted" style={{ fontSize: '0.8rem', marginBottom: 'var(--space-md)' }}>
              Ask natural language queries about balances, receivables, or run transactional lookups.
            </p>

            <div
              style={{
                flex: 1,
                overflowY: 'auto',
                display: 'flex',
                flexDirection: 'column',
                gap: 'var(--space-sm)',
                paddingRight: 4,
                marginBottom: 'var(--space-md)',
              }}
            >
              {chatMessages.map((msg, i) => (
                <div
                  key={i}
                  style={{
                    alignSelf: msg.role === 'user' ? 'flex-end' : 'flex-start',
                    maxWidth: '85%',
                    padding: '10px 14px',
                    borderRadius: 'var(--radius-md)',
                    background: msg.role === 'user' ? 'var(--color-primary)' : 'var(--color-bg-subtle)',
                    color: msg.role === 'user' ? '#ffffff' : 'var(--color-text-primary)',
                    border: msg.role === 'user' ? 'none' : '1px solid var(--color-border)',
                    fontSize: '0.88rem',
                  }}
                >
                  <p style={{ margin: 0, whiteSpace: 'pre-wrap' }}>{msg.text}</p>
                </div>
              ))}
              {agentChatMutation.isPending && (
                <div
                  style={{
                    alignSelf: 'flex-start',
                    padding: '8px 12px',
                    borderRadius: 'var(--radius-md)',
                    background: 'var(--color-bg-subtle)',
                    fontSize: '0.85rem',
                    display: 'flex',
                    alignItems: 'center',
                    gap: 6,
                  }}
                >
                  <RefreshCw size={14} className="spin" />
                  <span>Copilot is reasoning and analyzing ledger state...</span>
                </div>
              )}
            </div>

            <div style={{ display: 'flex', gap: 8 }}>
              <input
                className="input-field"
                onChange={(e) => setChatInput(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && handleSendMessage()}
                placeholder="Ask Copilot e.g. 'Show me overdue customers above ₹1,00,000'..."
                style={{ flex: 1, padding: '8px 12px', borderRadius: 'var(--radius-md)', border: '1px solid var(--color-border)' }}
                type="text"
                value={chatInput}
              />
              <Button disabled={agentChatMutation.isPending} onClick={handleSendMessage} variant="primary">
                <Send size={14} />
              </Button>
            </div>
          </div>

          {/* Direct Sentence → Drafted Voucher Panel */}
          <div className="panel-card" style={{ padding: 'var(--space-md)', display: 'flex', flexDirection: 'column' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 'var(--space-sm)' }}>
              <FileCheck size={18} color="var(--color-success)" />
              <h3 style={{ fontSize: '1.05rem', fontWeight: 600 }}>One-Sentence Voucher Entry</h3>
            </div>
            <p className="cell-muted" style={{ fontSize: '0.8rem', marginBottom: 'var(--space-md)' }}>
              Type any raw financial event in plain English. The AI parses accounts, checks balances, builds balanced double-entry lines, and queues for instant sign-off.
            </p>

            <div style={{ marginBottom: 'var(--space-md)' }}>
              <textarea
                className="input-field"
                onChange={(e) => setVoucherSentence(e.target.value)}
                placeholder='e.g. "Paid ₹15,000 via HDFC Bank for office stationery and printing expenses to Sharma Paper Mart"'
                rows={3}
                style={{
                  width: '100%',
                  padding: '10px 12px',
                  borderRadius: 'var(--radius-md)',
                  border: '1px solid var(--color-border)',
                  fontFamily: 'inherit',
                  fontSize: '0.9rem',
                }}
                value={voucherSentence}
              />
              <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: 8 }}>
                <Button
                  disabled={draftVoucherMutation.isPending || !voucherSentence.trim()}
                  onClick={handleDraftVoucher}
                  variant="primary"
                >
                  <Sparkles size={14} style={{ marginRight: 6 }} />
                  Parse & Draft Double-Entry Voucher
                </Button>
              </div>
            </div>

            {/* Drafted Voucher Result Inspector */}
            {latestDraftResult && (
              <div
                style={{
                  padding: 'var(--space-md)',
                  borderRadius: 'var(--radius-md)',
                  background: latestDraftResult.drafted ? 'rgba(16, 185, 129, 0.05)' : 'rgba(239, 68, 68, 0.05)',
                  border: `1px solid ${latestDraftResult.drafted ? 'rgba(16, 185, 129, 0.25)' : 'rgba(239, 68, 68, 0.25)'}`,
                  flex: 1,
                }}
              >
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                    {latestDraftResult.drafted ? (
                      <CheckCircle2 color="var(--color-success)" size={18} />
                    ) : (
                      <AlertTriangle color="var(--color-error)" size={18} />
                    )}
                    <strong>
                      {latestDraftResult.drafted ? `Drafted ${latestDraftResult.voucherType} Voucher` : 'Uncertain Parsing'}
                    </strong>
                  </div>
                  <span style={{ fontSize: '0.8rem', fontWeight: 600 }}>
                    Confidence: {Math.round(latestDraftResult.confidence * 100)}%
                  </span>
                </div>

                <p style={{ fontSize: '0.85rem', marginBottom: 12 }}>
                  Narration: <em>"{latestDraftResult.narration}"</em>
                </p>

                {latestDraftResult.lines && latestDraftResult.lines.length > 0 && (
                  <table style={{ width: '100%', fontSize: '0.85rem', borderCollapse: 'collapse', marginBottom: 12 }}>
                    <thead>
                      <tr style={{ borderBottom: '1px solid var(--color-border)', textAlign: 'left' }}>
                        <th style={{ padding: '6px 0' }}>Account</th>
                        <th style={{ padding: '6px 0', textAlign: 'right' }}>Debit</th>
                        <th style={{ padding: '6px 0', textAlign: 'right' }}>Credit</th>
                      </tr>
                    </thead>
                    <tbody>
                      {latestDraftResult.lines.map((line, idx) => (
                        <tr key={idx} style={{ borderBottom: '1px solid rgba(0,0,0,0.04)' }}>
                          <td style={{ padding: '6px 0' }}>
                            <code>{line.accountCode}</code> - {line.accountName}
                          </td>
                          <td style={{ padding: '6px 0', textAlign: 'right' }}>
                            {line.debit > 0 ? <Money amount={line.debit} /> : '-'}
                          </td>
                          <td style={{ padding: '6px 0', textAlign: 'right' }}>
                            {line.credit > 0 ? <Money amount={line.credit} /> : '-'}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                )}

                {latestDraftResult.drafted && latestDraftResult.suggestionId && (
                  <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8, marginTop: 12 }}>
                    <Button
                      disabled={rejectDraftMutation.isPending}
                      onClick={() => rejectDraftMutation.mutate(latestDraftResult.suggestionId!)}
                      variant="destructive"
                    >
                      <XCircle size={14} style={{ marginRight: 4 }} />
                      Discard Draft
                    </Button>
                    <Button
                      disabled={approveDraftMutation.isPending}
                      onClick={() => approveDraftMutation.mutate(latestDraftResult.suggestionId!)}
                      variant="primary"
                    >
                      <CheckCircle2 size={14} style={{ marginRight: 4 }} />
                      Approve & Post to General Ledger
                    </Button>
                  </div>
                )}
              </div>
            )}
          </div>
        </div>
      )}

      {/* TAB 2: ANOMALY & SUGGESTION INBOX */}
      {activeTab === 'inbox' && (
        <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 'var(--space-md)' }}>
            <div>
              <h3 style={{ fontSize: '1.05rem', fontWeight: 600 }}>AI Audit Suggestions & Risk Monitor</h3>
              <p className="cell-muted" style={{ fontSize: '0.85rem' }}>
                Automated sweeps detect expense misclassifications, duplicate billing risk, and tax anomalies.
              </p>
            </div>
            <select
              className="select-field"
              onChange={(e) => setSuggestionStatus(e.target.value)}
              style={{
                padding: '6px 12px',
                borderRadius: 'var(--radius-md)',
                border: '1px solid var(--color-border)',
                fontWeight: 600,
                background: 'var(--color-surface)',
              }}
              value={suggestionStatus}
            >
              <option value="PENDING">Pending Review</option>
              <option value="ACCEPTED">Accepted / Posted</option>
              <option value="REJECTED">Rejected / Dismissed</option>
            </select>
          </div>

          <DataTable caption="AI Decision and Suggestion Inbox">
            <thead>
              <tr>
                <th scope="col">Suggestion Type</th>
                <th scope="col">Entity / Target</th>
                <th scope="col">Reasoning & AI Explanation</th>
                <th scope="col">Confidence</th>
                <th scope="col">Status</th>
                <th className="numeric-cell" scope="col">Review Action</th>
              </tr>
            </thead>
            <tbody>
              {suggestions.map((sug) => (
                <tr key={sug.id}>
                  <td>
                    <strong>{sug.suggestionType}</strong>
                    <div className="cell-muted" style={{ fontSize: '0.75rem' }}>
                      Agent: {sug.agentName || 'RuleEngine'}
                    </div>
                  </td>
                  <td>
                    <code>{sug.entityType}</code>
                  </td>
                  <td style={{ maxWidth: 380 }}>
                    <p style={{ margin: 0, fontSize: '0.85rem' }}>{sug.reasoning}</p>
                  </td>
                  <td>
                    <span style={{ fontWeight: 600, fontSize: '0.85rem' }}>
                      {Math.round(sug.confidence * 100)}%
                    </span>
                  </td>
                  <td>
                    <StatusChip status={sug.status} />
                  </td>
                  <td className="numeric-cell">
                    {sug.status === 'PENDING' ? (
                      <div style={{ display: 'flex', gap: 6, justifyContent: 'flex-end' }}>
                        <Button
                          onClick={() => reviewSuggestionMutation.mutate({ id: sug.id, action: 'REJECT' })}
                          variant="ghost"
                        >
                          <XCircle size={13} style={{ marginRight: 4 }} />
                          Reject
                        </Button>
                        <Button
                          onClick={() => reviewSuggestionMutation.mutate({ id: sug.id, action: 'ACCEPT' })}
                          variant="primary"
                        >
                          <CheckCircle2 size={13} style={{ marginRight: 4 }} />
                          Accept
                        </Button>
                      </div>
                    ) : (
                      <span className="cell-muted" style={{ fontSize: '0.8rem' }}>
                        Reviewed
                      </span>
                    )}
                  </td>
                </tr>
              ))}
              {suggestions.length === 0 && (
                <tr>
                  <td colSpan={6} style={{ textAlign: 'center', padding: 'var(--space-lg)', color: 'var(--color-text-secondary)' }}>
                    No suggestions found for status "{suggestionStatus}".
                  </td>
                </tr>
              )}
            </tbody>
          </DataTable>
        </div>
      )}

      {/* TAB 3: DOCUMENT OCR SCANNER */}
      {activeTab === 'ocr' && (
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 'var(--space-md)' }}>
          <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 'var(--space-sm)' }}>
              <FileUp size={18} color="var(--color-primary)" />
              <h3 style={{ fontSize: '1.05rem', fontWeight: 600 }}>Upload Vendor Invoice / Receipt</h3>
            </div>
            <p className="cell-muted" style={{ fontSize: '0.8rem', marginBottom: 'var(--space-md)' }}>
              Upload any vendor bill image or thermal receipt. Claude Vision extracts GSTIN, HSN rates, and line items.
            </p>

            <div
              style={{
                border: '2px dashed var(--color-border)',
                borderRadius: 'var(--radius-lg)',
                padding: 'var(--space-xl)',
                textAlign: 'center',
                cursor: 'pointer',
                marginBottom: 'var(--space-md)',
                backgroundColor: 'var(--color-bg-subtle)',
              }}
            >
              <Upload size={32} color="var(--color-text-secondary)" style={{ margin: '0 auto 12px' }} />
              <p style={{ fontWeight: 600, fontSize: '0.9rem' }}>Choose an image or drag & drop</p>
              <p className="cell-muted" style={{ fontSize: '0.8rem' }}>PNG, JPG, WEBP up to 10MB</p>
              <input
                accept="image/*"
                onChange={handleImageUpload}
                style={{ marginTop: 12 }}
                type="file"
              />
            </div>

            {billImageBase64 && (
              <div style={{ textAlign: 'center' }}>
                <img
                  alt="Invoice Preview"
                  src={billImageBase64}
                  style={{ maxHeight: 240, maxWidth: '100%', borderRadius: 'var(--radius-md)', border: '1px solid var(--color-border)' }}
                />
              </div>
            )}
          </div>

          <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 'var(--space-sm)' }}>
              <FileText size={18} color="var(--color-success)" />
              <h3 style={{ fontSize: '1.05rem', fontWeight: 600 }}>Extracted Bill Intelligence</h3>
            </div>

            {scanBillMutation.isPending && (
              <div className="directory-state">
                <RefreshCw size={18} className="spin" style={{ marginBottom: 8 }} />
                <span>Running Vision AI OCR extraction...</span>
              </div>
            )}

            {scanResult && !scanBillMutation.isPending && (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-sm)' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 12px', background: 'var(--color-bg-subtle)', borderRadius: 'var(--radius-md)' }}>
                  <div>
                    <span className="cell-muted" style={{ fontSize: '0.75rem' }}>Vendor Name</span>
                    <strong style={{ display: 'block' }}>{scanResult.vendorName || 'Unspecified'}</strong>
                  </div>
                  <div>
                    <span className="cell-muted" style={{ fontSize: '0.75rem' }}>GSTIN</span>
                    <strong style={{ display: 'block' }}><code>{scanResult.vendorGstin || 'None'}</code></strong>
                  </div>
                  <div>
                    <span className="cell-muted" style={{ fontSize: '0.75rem' }}>Invoice Total</span>
                    <strong style={{ display: 'block', color: 'var(--color-primary)' }}>
                      <Money amount={scanResult.totalAmount || 0} />
                    </strong>
                  </div>
                </div>

                <h4 style={{ fontSize: '0.9rem', fontWeight: 600, marginTop: 8 }}>Extracted Line Items</h4>
                <table style={{ width: '100%', fontSize: '0.8rem', borderCollapse: 'collapse' }}>
                  <thead>
                    <tr style={{ borderBottom: '1px solid var(--color-border)', textAlign: 'left' }}>
                      <th style={{ padding: '6px 0' }}>Item Description</th>
                      <th style={{ padding: '6px 0' }}>HSN</th>
                      <th style={{ padding: '6px 0', textAlign: 'right' }}>Qty</th>
                      <th style={{ padding: '6px 0', textAlign: 'right' }}>Rate</th>
                      <th style={{ padding: '6px 0', textAlign: 'right' }}>GST %</th>
                      <th style={{ padding: '6px 0', textAlign: 'right' }}>Total</th>
                    </tr>
                  </thead>
                  <tbody>
                    {scanResult.lineItems?.map((line, idx) => (
                      <tr key={idx} style={{ borderBottom: '1px solid rgba(0,0,0,0.04)' }}>
                        <td style={{ padding: '6px 0' }}>{line.description}</td>
                        <td style={{ padding: '6px 0' }}><code>{line.hsnCode || '-'}</code></td>
                        <td style={{ padding: '6px 0', textAlign: 'right' }}>{line.quantity}</td>
                        <td style={{ padding: '6px 0', textAlign: 'right' }}><Money amount={line.unitPrice} /></td>
                        <td style={{ padding: '6px 0', textAlign: 'right' }}>{line.gstRate}%</td>
                        <td style={{ padding: '6px 0', textAlign: 'right' }}><strong><Money amount={line.totalAmount} /></strong></td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}

            {!scanResult && !scanBillMutation.isPending && (
              <div className="directory-state">Upload a bill to inspect extracted structured data.</div>
            )}
          </div>
        </div>
      )}

      {/* TAB 4: MODEL TRAINING & LORA EXPORT */}
      {activeTab === 'training' && (
        <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 'var(--space-md)' }}>
            <div>
              <h3 style={{ fontSize: '1.05rem', fontWeight: 600 }}>Supervised Fine-Tuning & Dataset Export</h3>
              <p className="cell-muted" style={{ fontSize: '0.85rem' }}>
                Katasticho captures human accountant approvals and corrections into structured JSONL chat logs for domain fine-tuning.
              </p>
            </div>
            <Button onClick={handleExportJsonl} variant="primary">
              <Download size={14} style={{ marginRight: 6 }} />
              Export LoRA Fine-Tuning Dataset (.jsonl)
            </Button>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 'var(--space-md)', marginBottom: 'var(--space-lg)' }}>
            <div className="summary-card">
              <span className="summary-card__label">Total Validated Examples</span>
              <strong className="summary-card__value"><Quantity value={training?.totalExamples ?? 0} /></strong>
            </div>
            <div className="summary-card">
              <span className="summary-card__label">High Quality Corrections</span>
              <strong className="summary-card__value" style={{ color: 'var(--color-success)' }}>
                <Quantity value={training?.goodExamples ?? 0} />
              </strong>
            </div>
            <div className="summary-card">
              <span className="summary-card__label">Supported Tasks</span>
              <strong className="summary-card__value"><Quantity value={Object.keys(training?.taskBreakdown ?? {}).length} /> Tasks</strong>
            </div>
          </div>
        </div>
      )}
    </section>
  )
}
