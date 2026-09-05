import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { Button, PageHeader, CheckboxInput, FilterTabs, FormField, FormGrid, SelectInput, TextAreaInput } from '@/design-system'
import { TextField } from '@/design-system/text-field'
import { useSessionStore } from '@/shared/session/session-store'
import { getPdfTemplate, savePdfTemplate, type PdfTemplateSetting } from './settings-api'

const documentTypes = ['INVOICE', 'QUOTATION', 'BILL', 'DELIVERY_CHALLAN']
export function PdfTemplateCustomizerPage() {
  const user = useSessionStore((s) => s.user)
  const allowed = ['OWNER', 'ADMIN'].includes(user?.role ?? '')
  const [doc, setDoc] = useState('INVOICE')
  const query = useQuery({ queryKey: ['pdf-template', user?.orgId, doc], queryFn: () => getPdfTemplate(doc), enabled: allowed })
  if (!allowed) return <p role="alert">Template settings require Owner or Admin access.</p>
  return <section className="workspace-page"><PageHeader eyebrow="Settings" title="PDF template settings" description="Configure the document options supported by the existing API. Verify exported PDFs separately; this is not a rendered PDF preview." />
    <FilterTabs ariaLabel="Document template" activeValue={doc} onChange={setDoc} items={documentTypes.map((type) => ({ value: type, label: type.replaceAll('_', ' ') }))} />
    {query.isPending ? <p role="status">Loading template...</p> : query.isError ? <div role="alert">{query.error.message}<Button onClick={() => query.refetch()}>Retry</Button></div> : <TemplateEditor key={`${user?.orgId}:${doc}`} initial={query.data} doc={doc} orgId={user?.orgId} />}
  </section>
}
function TemplateEditor({ initial, doc, orgId }: { initial: PdfTemplateSetting; doc: string; orgId?: string }) {
  const [draft, setDraft] = useState(initial)
  const client = useQueryClient()
  const mutation = useMutation({ mutationFn: () => savePdfTemplate({ ...draft, documentType: doc }), onSuccess: (saved) => { setDraft(saved); client.setQueryData(['pdf-template', orgId, doc], saved) } })
  const flags = [['showGstColumns', 'GST columns'], ['showHsnColumn', 'HSN column'], ['showPaymentQr', 'Payment QR'], ['showTerms', 'Terms'], ['showSignature', 'Signature'], ['active', 'Template active']] as const
  return <div className="document-card">
    {mutation.isError && <p className="banner banner--error" role="alert">{mutation.error.message}</p>}{mutation.isSuccess && <p role="status">Template configuration saved.</p>}
    <FormGrid>
      <FormField label="Theme"><SelectInput value={draft.templateTheme} onChange={(e) => setDraft({ ...draft, templateTheme: e.target.value })}>{['CLASSIC', 'MODERN', 'MINIMAL', 'COMPACT_THERMAL'].map((t) => <option key={t}>{t}</option>)}</SelectInput></FormField>
      <FormField label="Header layout"><SelectInput value={draft.headerLayout} onChange={(e) => setDraft({ ...draft, headerLayout: e.target.value })}>{['LOGO_LEFT', 'LOGO_RIGHT', 'LOGO_CENTER'].map((t) => <option key={t}>{t}</option>)}</SelectInput></FormField>
      <TextField label="Primary color" value={draft.primaryColor} onChange={(e) => setDraft({ ...draft, primaryColor: e.target.value })} pattern="#[0-9a-fA-F]{6}" />
      <TextField label="Signature label" value={draft.signatureLabel ?? ''} onChange={(e) => setDraft({ ...draft, signatureLabel: e.target.value })} />
      <TextField label="Watermark" value={draft.watermarkText ?? ''} onChange={(e) => setDraft({ ...draft, watermarkText: e.target.value })} />
      {flags.map(([key, label]) => <CheckboxInput key={key} label={label} checked={draft[key]} onChange={(e) => setDraft({ ...draft, [key]: e.target.checked })} />)}
      <FormField label="Terms and conditions" span="full"><TextAreaInput rows={4} value={draft.termsAndConditions ?? ''} onChange={(e) => setDraft({ ...draft, termsAndConditions: e.target.value })} /></FormField>
    </FormGrid><Button disabled={mutation.isPending || !/^#[0-9a-fA-F]{6}$/.test(draft.primaryColor)} onClick={() => mutation.mutate()}>Save template</Button>
  </div>
}
