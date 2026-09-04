import { apiFetch } from '@/api/client/api-client'

export type AiSuggestion = {
  id: string
  orgId: string
  entityType: string
  entityId?: string
  entityLineId?: string
  suggestionType: string
  suggestedAction: string
  suggestedValue: Record<string, unknown>
  reasoning: string
  confidence: number
  agentName?: string
  modelName?: string
  modelVersion?: string
  promptVersion?: string
  status: 'PENDING' | 'ACCEPTED' | 'REJECTED' | 'MODIFIED'
  reviewedBy?: string
  reviewedAt?: string
  reviewAction?: string
  reviewedValue?: Record<string, unknown>
  correctionReason?: string
  priority?: string
  priorityScore?: number
  dueBy?: string
  createdAt: string
  updatedAt?: string
}

export type AiInboxSummary = {
  pendingCount: number
  highPriorityCount: number
  categorizationCount: number
  riskAnomalyCount: number
  actionableDraftsCount: number
}

export type AiModelSettings = {
  provider: string
  modelName: string
  baseUrl?: string | null
}

export type AiStatus = {
  useLocal: boolean
  provider: string
  model: string
  baseUrl: string
  reachable: boolean
  ollamaBaseUrl?: string
  ollamaModel?: string
}

export type EntryLine = {
  accountCode: string
  accountName: string
  debit: number
  credit: number
}

export type EntryDraftResult = {
  drafted: boolean
  suggestionId?: string
  entryId?: string
  voucherType?: 'PAYMENT' | 'RECEIPT' | 'JOURNAL'
  narration?: string
  amount?: number
  confidence: number
  lines?: EntryLine[]
  warnings?: string[]
  message?: string
}

export type AgentChatResponse = {
  reply: string
  tool: string
  data?: unknown
  draftSuggestionId?: string
  actionRequired: boolean
  warnings?: string[]
}

export type BillScanLineItem = {
  description: string
  hsnCode?: string
  quantity: number
  unitPrice: number
  gstRate: number
  taxableAmount: number
  cgstAmount: number
  sgstAmount: number
  igstAmount: number
  totalAmount: number
}

export type BillScanResponse = {
  vendorName?: string
  vendorGstin?: string
  invoiceNumber?: string
  invoiceDate?: string
  subtotal?: number
  taxTotal?: number
  totalAmount?: number
  lineItems?: BillScanLineItem[]
  confidence: number
  rawText?: string
}

export type ItemScanResponse = {
  itemName?: string
  brand?: string
  category?: string
  barcode?: string
  hsnCode?: string
  mrp?: number
  purchasePrice?: number
  sellingPrice?: number
  unit?: string
  gstRate?: number
}

export type TrainingSummary = {
  totalExamples: number
  goodExamples: number
  taskBreakdown: Record<string, number>
}

export async function listSuggestions(status?: string, page = 0, size = 50): Promise<{ content: AiSuggestion[]; totalElements: number }> {
  const params = new URLSearchParams()
  if (status) params.set('status', status)
  params.set('page', String(page))
  params.set('size', String(size))
  const data = await apiFetch<{ content?: AiSuggestion[]; totalElements?: number } | AiSuggestion[]>(
    `/api/v1/ai/suggestions?${params.toString()}`
  )
  if (data && typeof data === 'object' && 'content' in data && Array.isArray(data.content)) {
    return { content: data.content, totalElements: data.totalElements || data.content.length }
  }
  return { content: Array.isArray(data) ? data : [], totalElements: Array.isArray(data) ? data.length : 0 }
}

export async function getSuggestionSummary(): Promise<AiInboxSummary> {
  return apiFetch<AiInboxSummary>('/api/v1/ai/suggestions/summary')
}

export async function getSuggestion(id: string): Promise<AiSuggestion> {
  return apiFetch<AiSuggestion>(`/api/v1/ai/suggestions/${id}`)
}

export async function reviewSuggestion(
  id: string,
  data: { reviewAction: 'ACCEPT' | 'REJECT' | 'MODIFY'; reviewedValue?: Record<string, unknown>; correctionReason?: string }
): Promise<AiSuggestion> {
  return apiFetch<AiSuggestion>(`/api/v1/ai/suggestions/${id}/review`, {
    method: 'POST',
    body: data,
  })
}

export async function runRuleChecks(days?: number): Promise<{ processed: number; generatedSuggestions: number }> {
  const params = days ? `?days=${days}` : ''
  return apiFetch<{ processed: number; generatedSuggestions: number }>(`/api/v1/ai/agents/rule-checks/run${params}`, {
    method: 'POST',
    body: {},
  })
}

export async function runProactiveSweep(): Promise<{ swept: number; generatedSuggestions: number }> {
  return apiFetch<{ swept: number; generatedSuggestions: number }>('/api/v1/ai/agents/proactive/run', {
    method: 'POST',
    body: {},
  })
}

export async function queryNaturalLanguage(message: string): Promise<{ answer: string; sqlQuery?: string; queryResults?: unknown[] }> {
  return apiFetch<{ answer: string; sqlQuery?: string; queryResults?: unknown[] }>('/api/v1/ai/query', {
    method: 'POST',
    body: { message },
  })
}

export async function chatWithAgent(message: string): Promise<AgentChatResponse> {
  return apiFetch<AgentChatResponse>('/api/v1/ai/agent', {
    method: 'POST',
    body: { message },
  })
}

export async function draftFromText(text: string): Promise<EntryDraftResult> {
  return apiFetch<EntryDraftResult>('/api/v1/ai/entry', {
    method: 'POST',
    body: { text },
  })
}

export async function approveEntryDraft(suggestionId: string): Promise<EntryDraftResult> {
  return apiFetch<EntryDraftResult>(`/api/v1/ai/entry/${suggestionId}/approve`, {
    method: 'POST',
    body: {},
  })
}

export async function rejectEntryDraft(suggestionId: string, reason?: string): Promise<void> {
  await apiFetch<void>(`/api/v1/ai/entry/${suggestionId}/reject`, {
    method: 'POST',
    body: { reason },
  })
}

export async function scanBill(data: { image: string; mediaType?: string }): Promise<BillScanResponse> {
  return apiFetch<BillScanResponse>('/api/v1/ai/scan-bill', {
    method: 'POST',
    body: data,
  })
}

export async function scanProductLabel(data: { image: string; mediaType?: string }): Promise<ItemScanResponse> {
  return apiFetch<ItemScanResponse>('/api/v1/ai/scan-product-label', {
    method: 'POST',
    body: data,
  })
}

export async function scanPurchaseInvoice(data: { image: string; mediaType?: string }): Promise<ItemScanResponse> {
  return apiFetch<ItemScanResponse>('/api/v1/ai/scan-purchase-invoice', {
    method: 'POST',
    body: data,
  })
}

export async function getTrainingSummary(): Promise<TrainingSummary> {
  return apiFetch<TrainingSummary>('/api/v1/ai/training/summary')
}

export async function exportTrainingJsonl(taskType?: string, goodOnly = true): Promise<string> {
  const params = new URLSearchParams()
  if (taskType) params.set('taskType', taskType)
  params.set('goodOnly', String(goodOnly))
  const data = await apiFetch<string | Record<string, unknown>>(`/api/v1/ai/training/export?${params.toString()}`)
  return typeof data === 'string' ? data : JSON.stringify(data)
}

export async function getAiSettings(): Promise<AiModelSettings> {
  return apiFetch<AiModelSettings>('/api/v1/settings/ai')
}

export async function updateAiSettings(req: AiModelSettings): Promise<AiModelSettings> {
  return apiFetch<AiModelSettings>('/api/v1/settings/ai', {
    method: 'PUT',
    body: req,
  })
}

export async function testAiConnection(baseUrl: string): Promise<{ success: boolean; message: string }> {
  return apiFetch<{ success: boolean; message: string }>('/api/v1/settings/ai/test', {
    method: 'POST',
    body: { baseUrl },
  })
}

export async function listInstalledModels(baseUrl: string): Promise<string[]> {
  return apiFetch<string[]>(`/api/v1/settings/ai/models?baseUrl=${encodeURIComponent(baseUrl)}`)
}

export async function getAiStatus(): Promise<AiStatus> {
  return apiFetch<AiStatus>('/api/v1/settings/ai/status')
}
