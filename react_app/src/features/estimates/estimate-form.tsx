import { useState, type FormEvent } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { Button, DataTable, EntityPicker, FormCard, FormField, FormGrid, Money, NumberInput, Quantity, SummaryRow, TextAreaInput, TextInput } from '@/design-system'
import { listContacts } from '@/features/contacts/contacts-api'
import { InventoryItemPicker } from '@/features/inventory/inventory-pickers'
import { useSessionStore } from '@/shared/session/session-store'
import { createEstimate, updateEstimate, type CreateEstimateRequest, type Estimate } from './estimates-api'
import { buildEstimateRequest, canEditEstimate, estimateFormLines, estimatePermissions, localEstimateDate, newEstimateLine, previewEstimate, type EstimateFormLine } from './estimate-form-model'

type Buyer = { id: string; displayName: string; phone?: string | null; gstin?: string | null; companyName?: string | null }
async function searchCustomers(search: string) {
  return (await listContacts({ filter: 'CUSTOMER', page: 0, size: 25, search })).content.filter((contact) => contact.active && contact.contactType !== 'VENDOR')
}

export function EstimateForm({ estimate, onSaved, onCancel }: { estimate?: Estimate; onSaved: (estimate: Estimate) => void; onCancel: () => void }) {
  const user = useSessionStore((state) => state.user)
  const queryClient = useQueryClient()
  const [customer, setCustomer] = useState<Buyer | null>(() => estimate ? { id: estimate.contactId, displayName: estimate.contactName } : null)
  const [estimateDate, setEstimateDate] = useState(estimate?.estimateDate ?? localEstimateDate())
  const [expiryDate, setExpiryDate] = useState(estimate?.expiryDate ?? '')
  const [referenceNumber, setReferenceNumber] = useState(estimate?.referenceNumber ?? '')
  const [subject, setSubject] = useState(estimate?.subject ?? '')
  const [currency, setCurrency] = useState(estimate?.currency ?? '')
  const [notes, setNotes] = useState(estimate?.notes ?? '')
  const [terms, setTerms] = useState(estimate?.terms ?? '')
  const [lines, setLines] = useState(() => estimateFormLines(estimate))
  const [error, setError] = useState<string | null>(null)
  const allowed = estimatePermissions(user?.role).write && (!estimate || canEditEstimate(estimate.status))
  const mutation = useMutation({
    mutationFn: (request: CreateEstimateRequest) => {
      if (!allowed) throw new Error('This estimate cannot be edited with your current role or status.')
      if (!estimate) return createEstimate(request)
      // Currency is create-only. Never send an unsupported currency change on update.
      const update = { ...request }
      delete update.currency
      return updateEstimate(estimate.id, update)
    },
    onSuccess: (saved) => {
      void queryClient.invalidateQueries({ queryKey: ['estimates-list', user?.orgId] })
      void queryClient.invalidateQueries({ queryKey: ['estimate-detail', user?.orgId, saved.id] })
      void queryClient.invalidateQueries({ queryKey: ['estimate-comments', user?.orgId, saved.id] })
      if (useSessionStore.getState().user?.orgId !== user?.orgId) return
      onSaved(saved)
    },
    onError: (failure: Error) => setError(failure.message),
  })
  const updateLine = (key: string, update: Partial<EstimateFormLine>) => setLines((previous) => previous.map((line) => line.key === key ? { ...line, ...update } : line))
  const preview = previewEstimate(lines)
  const validCurrency = /^[A-Z]{3}$/.test(currency)
  const amount = (value: number) => validCurrency ? <Money amount={value} currency={currency} /> : <Quantity value={value} />

  function submit(event: FormEvent) {
    event.preventDefault()
    if (mutation.isPending) return
    setError(null)
    try {
      if (!allowed) throw new Error('This estimate is read-only.')
      if (currency && !validCurrency) throw new Error('Use a three-letter currency code, or leave it blank for organisation currency.')
      if (!preview) throw new Error('Check line amounts and percentages. Values must be valid and within the supported display precision.')
      mutation.mutate(buildEstimateRequest({ contactId: customer?.id ?? '', estimateDate, expiryDate: expiryDate || undefined,
        currency: currency || undefined, referenceNumber: referenceNumber.trim(), subject: subject.trim(), notes: notes.trim(), terms: terms.trim() }, lines, estimate))
    } catch (failure) { setError(failure instanceof Error ? failure.message : 'Check the estimate fields.') }
  }

  return <form className="create-form-container" onSubmit={submit}>
    {error && <div className="banner banner--error" role="alert">{error}</div>}
    <FormCard title="Customer and validity" stepNumber={1} description="Search the full customer directory. Searches show up to 25 matches; refine the search for more specific results.">
      <FormGrid columns={3}>
        <FormField label="Customer" required>
          <EntityPicker<Buyer> ariaLabel="Search estimate customer" value={customer?.id ?? null} selectedEntity={customer} onChange={(_id, selected) => setCustomer(selected ?? null)} onSearch={searchCustomers} getOptionId={(entry) => entry.id} getOptionLabel={(entry) => entry.displayName} getOptionDescription={(entry) => [entry.companyName, entry.phone, entry.gstin].filter(Boolean).join(' / ')} disabled={mutation.isPending || !allowed} />
        </FormField>
        <FormField label="Estimate date" required><TextInput type="date" required value={estimateDate} onChange={(event) => setEstimateDate(event.target.value)} disabled={mutation.isPending || !allowed} /></FormField>
        <FormField label="Expiry date" hint={estimate?.expiryDate ? 'Existing expiry dates can be changed, but cannot be cleared through this API.' : 'Optional validity limit.'}><TextInput type="date" min={estimateDate} value={expiryDate} onChange={(event) => setExpiryDate(event.target.value)} disabled={mutation.isPending || !allowed} /></FormField>
        <FormField label="Reference"><TextInput value={referenceNumber} onChange={(event) => setReferenceNumber(event.target.value)} disabled={mutation.isPending || !allowed} /></FormField>
        <FormField label="Subject"><TextInput value={subject} onChange={(event) => setSubject(event.target.value)} disabled={mutation.isPending || !allowed} /></FormField>
        <FormField label="Currency" hint={estimate ? 'Currency is fixed after creation.' : 'Leave blank to use organisation currency.'}><TextInput placeholder="Organisation default" maxLength={3} pattern="[A-Z]{3}" value={currency} onChange={(event) => setCurrency(event.target.value.toUpperCase())} disabled={Boolean(estimate) || mutation.isPending || !allowed} /></FormField>
      </FormGrid>
    </FormCard>
    <FormCard title="Proposal lines" stepNumber={2} description="Catalog rates and tax percentages can be adjusted for this quote. No purchase-price fallback or automatic stock reservation.">
      <FormGrid columns={2}>
        <FormField label="Add catalog product"><InventoryItemPicker value={null} onChange={(item) => { if (item) setLines((previous) => [...previous, newEstimateLine(item)]) }} disabled={mutation.isPending || !allowed} /></FormField>
        <div className="document-actions"><Button variant="secondary" disabled={mutation.isPending || !allowed} onClick={() => setLines((previous) => [...previous, newEstimateLine()])}>Add service / free-text line</Button></div>
      </FormGrid>
      <DataTable caption="Editable estimate lines">
        <thead><tr><th>Description</th><th>HSN</th><th>Unit</th><th className="numeric-cell">Quantity</th><th className="numeric-cell">Rate</th><th className="numeric-cell">Discount %</th><th className="numeric-cell">Tax %</th><th>Action</th></tr></thead>
        <tbody>{lines.map((line, index) => <tr key={line.key}>
          <td><TextInput aria-label={`Line ${index + 1} description`} required value={line.description} onChange={(event) => updateLine(line.key, { description: event.target.value })} disabled={mutation.isPending || !allowed} /></td>
          <td><TextInput aria-label={`Line ${index + 1} HSN`} value={line.hsnCode} onChange={(event) => updateLine(line.key, { hsnCode: event.target.value })} disabled={mutation.isPending || !allowed} /></td>
          <td><TextInput aria-label={`Line ${index + 1} unit`} value={line.unit} onChange={(event) => updateLine(line.key, { unit: event.target.value })} disabled={mutation.isPending || !allowed} /></td>
          {(['quantity', 'rate', 'discountPct', 'taxRate'] as const).map((field) => <td key={field} className="numeric-cell"><NumberInput aria-label={`Line ${index + 1} ${field}`} required min={field === 'quantity' ? 0.001 : 0} max={field === 'discountPct' || field === 'taxRate' ? 100 : undefined} step="any" value={line[field]} onChange={(event) => updateLine(line.key, { [field]: event.target.value })} disabled={mutation.isPending || !allowed} /></td>)}
          <td><Button aria-label={`Remove line ${index + 1}`} variant="ghost" disabled={mutation.isPending || !allowed} onClick={() => setLines((previous) => previous.filter((entry) => entry.key !== line.key))}>Remove</Button></td>
        </tr>)}</tbody>
      </DataTable>
      {!lines.length && <p className="cell-muted">Add a catalog product or service line to begin.</p>}
      <div className="form-summary-card">
        <p className="cell-muted">Preview {currency || '(organisation currency)'}. Saved server totals are authoritative.</p>
        {preview ? <><SummaryRow label="Discount included below" value={amount(preview.discount)} />
          <SummaryRow label="Subtotal after discount" value={amount(preview.subtotal)} />
          <SummaryRow label="Tax" value={amount(preview.tax)} />
          <SummaryRow isTotal label="Estimated total" value={amount(preview.total)} /></>
          : <p role="status">Complete valid quantities, rates, discounts, and taxes to calculate the preview.</p>}
      </div>
    </FormCard>
    <FormCard title="Printed notes and terms" stepNumber={3} description="Only enter commercial terms agreed for this proposal.">
      <FormGrid columns={2}>
        <FormField label="Customer notes"><TextAreaInput rows={3} value={notes} onChange={(event) => setNotes(event.target.value)} disabled={mutation.isPending || !allowed} /></FormField>
        <FormField label="Terms"><TextAreaInput rows={3} value={terms} onChange={(event) => setTerms(event.target.value)} disabled={mutation.isPending || !allowed} /></FormField>
      </FormGrid>
    </FormCard>
    <div className="form-actions-bar"><Button variant="secondary" disabled={mutation.isPending} onClick={onCancel}>Cancel</Button><Button type="submit" disabled={mutation.isPending || !allowed}>{mutation.isPending ? 'Saving...' : estimate ? 'Save changes' : 'Save estimate'}</Button></div>
  </form>
}
