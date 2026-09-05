import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { Button, DataTable, DocumentCard, Fact, FactList, Modal, Money, PageHeader, Quantity, StatusChip, SummaryRow } from '@/design-system'
import { useSessionStore } from '@/shared/session/session-store'
import { formatDate, formatDateTime } from '@/shared/format/format'
import { downloadBlob } from '@/shared/files/download-blob'
import { acceptEstimate, declineEstimate, deleteEstimate, getEstimate, getEstimatePdf, getEstimateWhatsAppLink, sendEstimate } from './estimates-api'
import { canEditEstimate, estimateConversionBlocker, estimatePermissions } from './estimate-form-model'
import { EstimateForm } from './estimate-form'
import { EstimateActivity } from './estimate-activity'

type Action = 'send' | 'accept' | 'decline' | 'delete'
const actionLabels: Record<Action, string> = { send: 'Send estimate', accept: 'Record acceptance', decline: 'Record decline', delete: 'Delete draft' }
const actionDescriptions: Record<Action, string> = {
  send: 'This marks the estimate SENT and may email it if the customer has an email address. Check activity for the email attempt result; SENT does not guarantee delivery.',
  accept: 'Record that the customer accepted this proposal. This does not create an invoice or post a journal.',
  decline: 'Record that the customer declined this proposal. This replaces the current status, including a previously recorded acceptance.',
  delete: 'Soft-delete this draft estimate. It will no longer appear in the estimate directory.',
}

export function EstimateDetailPage() {
  const { estimateId = '' } = useParams<{ estimateId: string }>()
  const orgId = useSessionStore((state) => state.user?.orgId)
  return <EstimateDetail key={`${orgId}:${estimateId}`} estimateId={estimateId} />
}

function EstimateDetail({ estimateId }: { estimateId: string }) {
  const user = useSessionStore((state) => state.user)
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [editing, setEditing] = useState(false)
  const [action, setAction] = useState<Action | null>(null)
  const [feedback, setFeedback] = useState<string | null>(null)
  const [shareMessage, setShareMessage] = useState<string | null>(null)
  const permissions = estimatePermissions(user?.role)
  const queryKey = ['estimate-detail', user?.orgId, estimateId]
  const query = useQuery({ queryKey, queryFn: () => getEstimate(estimateId), enabled: Boolean(user?.orgId && estimateId) })
  const estimate = query.data
  const documentCurrencySupported = estimate?.currency === 'INR'
  const mutation = useMutation({
    retry: false,
    mutationFn: async (chosen: Action) => {
      if (!estimate || !permissions.write) throw new Error('Your role cannot change this estimate.')
      if (chosen === 'delete') {
        if (!permissions.delete || estimate.status !== 'DRAFT') throw new Error('Only authorised users can delete draft estimates.')
        await deleteEstimate(estimateId)
        return null
      }
      if (chosen === 'decline') {
        if (estimate.status === 'INVOICED' || estimate.status === 'DECLINED') throw new Error('This estimate cannot be declined.')
        return declineEstimate(estimateId)
      }
      if (!canEditEstimate(estimate.status)) throw new Error('This action requires a draft or sent estimate.')
      if (chosen === 'send' && !documentCurrencySupported) throw new Error('The current backend formats estimate emails and PDFs in INR only.')
      return chosen === 'send' ? sendEstimate(estimateId) : acceptEstimate(estimateId)
    },
    onSuccess: (updated, chosen) => {
      void queryClient.invalidateQueries({ queryKey: ['estimates-list', user?.orgId] })
      void queryClient.invalidateQueries({ queryKey: ['estimate-comments', user?.orgId, estimateId] })
      if (useSessionStore.getState().user?.orgId !== user?.orgId) return
      setAction(null)
      if (!updated) { navigate('/estimates'); return }
      queryClient.setQueryData(queryKey, updated)
      setFeedback(chosen === 'send' ? 'Estimate marked SENT. Check activity for the email attempt result.' : 'Customer decision recorded.')
    },
  })
  const pdf = useMutation({ retry: false, mutationFn: () => {
    if (!documentCurrencySupported) throw new Error('The current backend formats estimate PDFs in INR only.')
    return getEstimatePdf(estimateId)
  }, onSuccess: (blob) => downloadBlob(blob, `estimate-${(estimate?.estimateNumber ?? 'quotation').replace(/[^a-zA-Z0-9_-]/g, '_')}.pdf`) })
  const share = useMutation({
    retry: false,
    mutationFn: async () => {
      if (!permissions.write) throw new Error('Your role cannot prepare a share message.')
      if (!documentCurrencySupported) throw new Error('The current backend formats estimate share messages in INR only.')
      const result = await getEstimateWhatsAppLink(estimateId)
      if (!result.message?.trim() || !result.shareUrl) throw new Error('The server did not return a complete share message.')
      const url = new URL(result.shareUrl)
      if (!['https:', 'http:'].includes(url.protocol)) throw new Error('The server returned an unsupported share link.')
      return result.message
    },
    onSuccess: setShareMessage,
  })
  const busy = mutation.isPending || pdf.isPending || share.isPending
  if (query.isPending) return <section className="workspace-page"><div className="directory-state" role="status">Loading estimate...</div></section>
  if (query.isError || !estimate) return <section className="workspace-page"><Link to="/estimates">Back to estimates</Link><div className="banner banner--error" role="alert">{query.error?.message ?? 'Estimate unavailable.'}<Button variant="secondary" onClick={() => void query.refetch()}>Retry estimate</Button></div></section>
  if (editing && permissions.write && canEditEstimate(estimate.status)) return <section className="workspace-page"><PageHeader eyebrow="Sales / Quotations" title={`Edit ${estimate.estimateNumber}`} description="Update the proposal without creating stock or accounting transactions." /><EstimateForm estimate={estimate} onCancel={() => setEditing(false)} onSaved={(saved) => { queryClient.setQueryData(queryKey, saved); setEditing(false); setFeedback('Estimate updated.') }} /></section>

  function choose(next: Action) { mutation.reset(); setAction(next) }
  return <section className="workspace-page">
    <Link className="form-back-link" to="/estimates">Back to estimates</Link>
    <PageHeader eyebrow="Sales / Quotations" title={estimate.estimateNumber} description={estimate.contactName} actions={<div className="document-actions">
      <Button variant="secondary" disabled={busy || !documentCurrencySupported} onClick={() => pdf.mutate()}>Download PDF</Button>
      {permissions.write && <Button variant="secondary" disabled={busy || !documentCurrencySupported} onClick={() => share.mutate()}>Prepare WhatsApp message</Button>}
      {permissions.write && canEditEstimate(estimate.status) && <>
        <Button variant="secondary" disabled={busy} onClick={() => setEditing(true)}>Edit estimate</Button>
        <Button disabled={busy || !documentCurrencySupported} onClick={() => choose('send')}>{estimate.status === 'SENT' ? 'Resend estimate' : 'Send estimate'}</Button>
        <Button variant="secondary" disabled={busy} onClick={() => choose('accept')}>Record acceptance</Button>
      </>}
      {permissions.write && !['INVOICED', 'DECLINED'].includes(estimate.status) && <Button variant="secondary" disabled={busy} onClick={() => choose('decline')}>Record decline</Button>}
      {permissions.delete && estimate.status === 'DRAFT' && <Button variant="destructive" disabled={busy} onClick={() => choose('delete')}>Delete draft</Button>}
    </div>} />
    {feedback && <div className="banner banner--success" role="status">{feedback}</div>}
    {(pdf.error || share.error) && <div className="banner banner--error" role="alert">{pdf.error?.message ?? share.error?.message}</div>}
    {!documentCurrencySupported && <div className="banner banner--error" role="status">External documents are unavailable for this currency: the existing backend hard-codes INR in PDFs and share messages. The saved quote values below retain their original currency.</div>}
    {Number(estimate.discountAmount) > 0 && <p className="cell-muted">PDF review required: the backend prints a separate negative discount row although its subtotal already includes that discount. The saved total below is authoritative; do not subtract the discount again.</p>}
    <div className="document-layout">
      <DocumentCard title="Proposal details"><FactList columns={2}>
        <Fact label="Customer" value={<Link className="table-row-link" to={`/contacts/${estimate.contactId}`}>{estimate.contactName}</Link>} />
        <Fact label="Status" value={<StatusChip status={estimate.status} />} />
        <Fact label="Estimate date" value={formatDate(estimate.estimateDate)} /><Fact label="Expiry date" value={formatDate(estimate.expiryDate)} />
        <Fact label="Reference" mono value={estimate.referenceNumber || '--'} /><Fact label="Subject" value={estimate.subject || '--'} />
        <Fact label="Currency" value={estimate.currency} /><Fact label="Invoice" value={estimate.convertedToInvoiceId ? <Link className="table-row-link" to={`/invoices/${estimate.convertedToInvoiceId}`}>View converted invoice</Link> : 'Not converted'} />
      </FactList></DocumentCard>
      <DocumentCard title="Server totals" variant="summary">
        <SummaryRow label="Discount included in subtotal" value={<Money amount={estimate.discountAmount} currency={estimate.currency} />} />
        <SummaryRow label="Subtotal after discount" value={<Money amount={estimate.subtotal} currency={estimate.currency} />} />
        <SummaryRow label="Tax" value={<Money amount={estimate.taxAmount} currency={estimate.currency} />} />
        <SummaryRow isTotal label="Total" value={<Money amount={estimate.total} currency={estimate.currency} />} />
      </DocumentCard>
    </div>
    {permissions.delete && !estimate.convertedToInvoiceId && !['INVOICED', 'DECLINED'].includes(estimate.status) && <DocumentCard title="Invoice conversion"><p>{estimateConversionBlocker}</p><Button disabled>Convert to invoice unavailable</Button></DocumentCard>}
    <DocumentCard title="Proposal lines" variant="lines"><DataTable caption="Saved estimate lines">
      <thead><tr><th>Description</th><th>HSN</th><th className="numeric-cell">Quantity</th><th className="numeric-cell">Rate</th><th className="numeric-cell">Discount</th><th className="numeric-cell">Tax rate</th><th className="numeric-cell">Amount incl. tax</th></tr></thead>
      <tbody>{estimate.lines.map((line) => <tr key={line.id}><td>{line.description}</td><td className="table-code">{line.hsnCode || '--'}</td><td className="numeric-cell"><Quantity value={line.quantity} unit={line.unit} /></td><td className="numeric-cell"><Money amount={line.rate} currency={estimate.currency} /></td><td className="numeric-cell"><Quantity value={line.discountPct} unit="%" /></td><td className="numeric-cell"><Quantity value={line.taxRate} unit="%" /></td><td className="numeric-cell"><Money amount={line.amount} currency={estimate.currency} /></td></tr>)}</tbody>
    </DataTable></DocumentCard>
    <DocumentCard title="Printed notes and terms" variant="notes"><div className="document-notes"><span>Customer notes</span><p>{estimate.notes || 'No notes.'}</p></div><div className="document-notes"><span>Terms</span><p>{estimate.terms || 'No terms.'}</p></div></DocumentCard>
    <DocumentCard title="Recorded milestones"><FactList columns={3}><Fact label="Created" value={formatDateTime(estimate.createdAt)} /><Fact label="Sent" value={formatDateTime(estimate.sentAt)} /><Fact label="Accepted" value={formatDateTime(estimate.acceptedAt)} /><Fact label="Declined" value={formatDateTime(estimate.declinedAt)} /><Fact label="Converted" value={formatDateTime(estimate.convertedAt)} /></FactList></DocumentCard>
    <EstimateActivity estimateId={estimateId} />
    <Modal isOpen={action !== null} title={action ? actionLabels[action] : ''} error={mutation.error?.message} onClose={() => { if (!mutation.isPending) setAction(null) }} footer={<><Button variant="secondary" disabled={mutation.isPending} onClick={() => setAction(null)}>Cancel</Button><Button variant={action === 'delete' ? 'destructive' : 'primary'} disabled={mutation.isPending} onClick={() => { if (action && !mutation.isPending) mutation.mutate(action) }}>{mutation.isPending ? 'Saving...' : 'Confirm'}</Button></>}>
      <p>{action ? actionDescriptions[action] : ''}</p>
      {action === 'send' && Number(estimate.discountAmount) > 0 && <p>Review the backend PDF before sending: its discount row is shown separately from an already-discounted subtotal.</p>}
    </Modal>
    <Modal isOpen={shareMessage !== null} title="Review WhatsApp message" onClose={() => setShareMessage(null)} footer={<Button variant="secondary" onClick={() => setShareMessage(null)}>Close</Button>}>
      <p>This opens a message draft. Select and verify the recipient in WhatsApp before sending. It does not change estimate status.</p>
      <div className="document-notes"><p>{shareMessage}</p></div>
      <a className="button button--primary" href={`https://wa.me/?text=${encodeURIComponent(shareMessage ?? '')}`} target="_blank" rel="noopener noreferrer">Open WhatsApp draft</a>
    </Modal>
  </section>
}
