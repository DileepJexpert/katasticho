import { useEffect, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { CheckCircle2, ExternalLink, ShieldAlert, Sliders } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  CheckboxInput,
  DataTable,
  DocumentCard,
  EmptyState,
  FormCard,
  FormField,
  FormGrid,
  Money,
  NumberInput,
  PageHeader,
  Quantity,
  StatusChip,
} from '@/design-system'
import { formatStatusLabel } from '@/shared/format/format'
import {
  getThreeWayMatchSettings,
  listThreeWayMatchExceptions,
  updateThreeWayMatchSettings,
  type ThreeWayMatchSettings,
} from './three-way-match-api'

type ToleranceField = Exclude<keyof ThreeWayMatchSettings, 'required'>

function safeNumber(value: string) {
  const parsed = Number(value)
  return Number.isFinite(parsed) ? parsed : 0
}

function fractionToPercentage(value: string) {
  return safeNumber(value) * 100
}

export function ThreeWayMatchPage() {
  const [tab, setTab] = useState<'exceptions' | 'settings'>('exceptions')
  const [page] = useState(0)
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [settingsForm, setSettingsForm] = useState<ThreeWayMatchSettings>({
    required: 'true', qty_tolerance_pct: '0', price_tolerance_abs: '1', price_tolerance_pct: '0.005', bypass_threshold: '0',
  })
  const [feedback, setFeedback] = useState<{ message: string; tone: 'error' | 'success' } | null>(null)

  const exceptionsQuery = useQuery({
    queryKey: ['three-way-match', 'exceptions', page],
    queryFn: () => listThreeWayMatchExceptions(page),
    enabled: tab === 'exceptions',
  })
  const settingsQuery = useQuery({
    queryKey: ['three-way-match', 'settings'],
    queryFn: getThreeWayMatchSettings,
    enabled: tab === 'settings',
  })
  useEffect(() => {
    if (settingsQuery.data) setSettingsForm(settingsQuery.data)
  }, [settingsQuery.data])

  const saveSettingsMutation = useMutation({
    mutationFn: () => updateThreeWayMatchSettings(settingsForm),
    onSuccess: () => {
      setFeedback({ message: '3-way match tolerance rules saved.', tone: 'success' })
      queryClient.invalidateQueries({ queryKey: ['three-way-match', 'settings'] })
    },
    onError: (error: Error) => setFeedback({ message: error.message, tone: 'error' }),
  })
  const exceptions = exceptionsQuery.data?.content ?? []
  const updateTolerance = (field: ToleranceField, value: number) => {
    setSettingsForm((current) => ({ ...current, [field]: String(value) }))
  }

  return (
    <section className="workspace-page">
      <PageHeader
        actions={<>
          <Button onClick={() => { setTab('exceptions'); setFeedback(null) }} variant={tab === 'exceptions' ? 'primary' : 'secondary'}><ShieldAlert size={16} /> Exception inbox ({exceptionsQuery.data?.totalElements ?? 0})</Button>
          <Button onClick={() => { setTab('settings'); setFeedback(null) }} variant={tab === 'settings' ? 'primary' : 'secondary'}><Sliders size={16} /> Tolerance rules</Button>
        </>}
        description="Server-side reconciliation of purchase orders, received stock, and vendor bills before disbursement."
        eyebrow="Purchases / AP Controls"
        title="3-Way Match"
      />
      {feedback ? <div className={`banner banner--${feedback.tone}`} role={feedback.tone === 'error' ? 'alert' : 'status'}>{feedback.message}</div> : null}

      {tab === 'exceptions' ? (
        <>
          <div className="summary-strip">
            <div className="summary-card"><span className="summary-card__label">Open exceptions</span><strong className="summary-card__value">{exceptionsQuery.data?.totalElements ?? 0}</strong><span className="summary-card__hint">Require review before payment</span></div>
            <div className="summary-card summary-card--accent"><span className="summary-card__label">Payment control</span><strong className="summary-card__value">Active gate</strong><span className="summary-card__hint">The server enforces current settings</span></div>
          </div>
          <DocumentCard title="Exceptions requiring resolution">
            {exceptionsQuery.isLoading ? <p aria-live="polite" className="document-loading">Loading match exceptions...</p> : exceptions.length === 0 ? (
              <EmptyState description="All evaluated vendor bills are within the configured price and quantity tolerances." icon={CheckCircle2} title="No 3-way match exceptions" />
            ) : (
              <DataTable caption="3-way match exceptions">
                <thead><tr><th scope="col">Status</th><th scope="col">Bill</th><th className="numeric-cell" scope="col">Billed</th><th className="numeric-cell" scope="col">Received</th><th className="numeric-cell" scope="col">Qty variance</th><th className="numeric-cell" scope="col">Bill price</th><th className="numeric-cell" scope="col">PO price</th><th className="numeric-cell" scope="col">Price variance</th><th className="numeric-cell" scope="col">Total variance</th><th scope="col">Action</th></tr></thead>
                <tbody>{exceptions.map((exception) => (
                  <tr className="match-variance-row" key={exception.id}>
                    <td><StatusChip status={formatStatusLabel(exception.status)} /></td>
                    <td><code>{exception.billId.slice(0, 8)}...</code></td>
                    <td className="numeric-cell"><Quantity value={exception.billedQty} /></td>
                    <td className="numeric-cell"><Quantity value={exception.receivedQty ?? 0} /></td>
                    <td className="numeric-cell match-variance"><Quantity value={exception.qtyVariance ?? 0} /></td>
                    <td className="numeric-cell"><Money amount={exception.billUnitPrice} /></td>
                    <td className="numeric-cell"><Money amount={exception.poUnitPrice ?? 0} /></td>
                    <td className="numeric-cell match-variance"><Money amount={exception.priceVariance ?? 0} /></td>
                    <td className="numeric-cell match-variance"><Money amount={exception.amountVariance ?? 0} /></td>
                    <td><Button onClick={() => navigate(appRoutes.threeWayMatchWorkbench(exception.billId))} variant="secondary"><ExternalLink size={14} /> Inspect</Button></td>
                  </tr>
                ))}</tbody>
              </DataTable>
            )}
          </DocumentCard>
        </>
      ) : (
        <form className="create-form-container" onSubmit={(event) => { event.preventDefault(); saveSettingsMutation.mutate() }}>
          <FormCard description="These organisation-wide tolerances are enforced by the server when a bill is matched or paid." stepNumber={1} title="Payment gate and tolerances">
            <FormGrid columns={2}>
              <FormField label="Payment gate" span="full"><CheckboxInput checked={settingsForm.required === 'true'} description="Exception bills must be corrected or formally overridden before payment." onChange={(event) => setSettingsForm((current) => ({ ...current, required: event.target.checked ? 'true' : 'false' }))} title="Enforce 3-way match before payment" /></FormField>
              <FormField label="Quantity tolerance"><NumberInput min={0} onChange={(event) => updateTolerance('qty_tolerance_pct', Number(event.target.value) || 0)} step="0.01" unitSuffix="%" value={safeNumber(settingsForm.qty_tolerance_pct)} /></FormField>
              <FormField label="Price tolerance"><NumberInput currencyPrefix="INR" min={0} onChange={(event) => updateTolerance('price_tolerance_abs', Number(event.target.value) || 0)} step="0.01" value={safeNumber(settingsForm.price_tolerance_abs)} /></FormField>
              <FormField hint="Stored by the API as a fraction: 0.5% is sent as 0.005." label="Price tolerance percentage"><NumberInput min={0} onChange={(event) => updateTolerance('price_tolerance_pct', (Number(event.target.value) || 0) / 100)} step="0.01" unitSuffix="%" value={fractionToPercentage(settingsForm.price_tolerance_pct)} /></FormField>
              <FormField label="Auto-bypass threshold"><NumberInput currencyPrefix="INR" min={0} onChange={(event) => updateTolerance('bypass_threshold', Number(event.target.value) || 0)} step="0.01" value={safeNumber(settingsForm.bypass_threshold)} /></FormField>
            </FormGrid>
          </FormCard>
          <div className="form-actions-bar"><Button disabled={saveSettingsMutation.isPending} type="submit" variant="primary">{saveSettingsMutation.isPending ? 'Saving...' : 'Save tolerance rules'}</Button></div>
        </form>
      )}
    </section>
  )
}
