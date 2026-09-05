import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, FileSpreadsheet, RefreshCw, ShieldAlert, ShieldCheck } from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  DataTable,
  DocumentCard,
  EmptyState,
  Fact,
  FactList,
  FormField,
  Modal,
  Money,
  PageHeader,
  Quantity,
  StatusChip,
  TextAreaInput,
} from '@/design-system'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import { getThreeWayMatch, overrideThreeWayMatch, runThreeWayMatch } from './three-way-match-api'

export function ThreeWayMatchWorkbenchPage() {
  const { billId } = useParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [overrideModalOpen, setOverrideModalOpen] = useState(false)
  const [overrideReason, setOverrideReason] = useState('')
  const [feedback, setFeedback] = useState<{ message: string; tone: 'error' | 'success' } | null>(null)

  const matchQuery = useQuery({
    queryKey: ['three-way-match', billId],
    queryFn: () => getThreeWayMatch(billId!),
    enabled: Boolean(billId),
  })

  const refreshMatch = () => {
    queryClient.invalidateQueries({ queryKey: ['three-way-match', billId] })
    queryClient.invalidateQueries({ queryKey: ['bills', billId] })
  }
  const runMutation = useMutation({
    mutationFn: () => runThreeWayMatch(billId!),
    onSuccess: (status) => {
      setFeedback({ message: `Match completed: ${formatStatusLabel(status)}.`, tone: 'success' })
      refreshMatch()
    },
    onError: (error: Error) => setFeedback({ message: error.message, tone: 'error' }),
  })
  const overrideMutation = useMutation({
    mutationFn: () => overrideThreeWayMatch(billId!, overrideReason.trim()),
    onSuccess: () => {
      setFeedback({ message: 'The authorised override was recorded in the match audit trail.', tone: 'success' })
      setOverrideModalOpen(false)
      setOverrideReason('')
      refreshMatch()
    },
    onError: (error: Error) => setFeedback({ message: error.message, tone: 'error' }),
  })

  if (!billId) {
    return <EmptyState action={<Button onClick={() => navigate(appRoutes.bills)} variant="secondary">Back to bills</Button>} icon={ShieldAlert} title="A bill is required for 3-way matching" />
  }
  if (matchQuery.isLoading) return <section className="workspace-page"><div aria-live="polite" className="directory-state">Loading 3-way match data...</div></section>
  if (matchQuery.isError || !matchQuery.data) {
    return (
      <section className="workspace-page">
        <EmptyState
          action={<Button disabled={runMutation.isPending} onClick={() => runMutation.mutate()} variant="primary"><RefreshCw size={16} />{runMutation.isPending ? 'Evaluating...' : 'Run initial match'}</Button>}
          icon={ShieldAlert}
          secondaryAction={<Button onClick={() => navigate(appRoutes.billDetail(billId))} variant="secondary">Back to bill</Button>}
          title="No match has been run for this bill"
          description="Run a server-side evaluation to compare the linked purchase order, received stock, and vendor bill."
        />
      </section>
    )
  }

  const snapshot = matchQuery.data
  const lines = snapshot.lines ?? []
  const isException = snapshot.status === 'EXCEPTION'
  const isOverridden = snapshot.status === 'OVERRIDDEN'

  return (
    <section className="workspace-page">
      <PageHeader
        actions={<>
          <StatusChip status={formatStatusLabel(snapshot.status ?? 'PENDING')} />
          <Button onClick={() => navigate(appRoutes.billDetail(billId))} variant="secondary"><ArrowLeft size={16} /> View bill</Button>
        </>}
        description="Review server-calculated PO, GRN, and bill quantity and price variances before a payment is released."
        eyebrow="Purchases / AP Controls / 3-Way Match"
        title={`3-Way Match: ${snapshot.billNumber}`}
      />
      {feedback ? <div className={`banner banner--${feedback.tone}`} role={feedback.tone === 'error' ? 'alert' : 'status'}>{feedback.message}</div> : null}
      {isOverridden ? <div className="banner banner--warning" role="status"><strong>Variance overridden.</strong> {snapshot.overrideReason || 'An authorised user approved this exception.'}</div> : null}

      <div className="document-layout">
        <DocumentCard title="Reconciliation summary">
          <FactList columns={2}>
            <Fact mono label="Bill number" value={snapshot.billNumber} />
            <Fact label="Match status" value={<StatusChip status={formatStatusLabel(snapshot.status ?? 'PENDING')} />} />
            <Fact label="Last evaluated" value={snapshot.matchedAt ? formatDate(snapshot.matchedAt) : 'Not yet evaluated'} />
            <Fact label="Lines checked" value={`${lines.length} line${lines.length === 1 ? '' : 's'}`} />
          </FactList>
        </DocumentCard>
        <DocumentCard title="Verification actions" variant="summary">
          <p className="document-loading">Re-evaluate after correcting the PO, receipt, or bill. An override is auditable and remains subject to server authority.</p>
          <div className="document-card__actions">
            <Button disabled={runMutation.isPending} onClick={() => runMutation.mutate()} variant="primary"><RefreshCw size={16} />{runMutation.isPending ? 'Evaluating...' : 'Re-run match'}</Button>
            {isException && !isOverridden ? <Button onClick={() => setOverrideModalOpen(true)} variant="secondary"><ShieldCheck size={16} /> Request authorised override</Button> : null}
            <Button onClick={() => navigate(appRoutes.debitNotes)} variant="ghost"><FileSpreadsheet size={16} /> Open debit notes</Button>
          </div>
        </DocumentCard>
      </div>

      <DocumentCard title="Line-by-line comparison" variant="lines">
        <DataTable caption="Purchase order, goods receipt, and vendor bill comparison">
          <thead>
            <tr>
              <th scope="col">Status</th><th scope="col">Item</th><th className="numeric-cell" scope="col">Ordered</th><th className="numeric-cell" scope="col">Received</th><th className="numeric-cell" scope="col">Billed</th><th className="numeric-cell" scope="col">Qty variance</th><th className="numeric-cell" scope="col">PO price</th><th className="numeric-cell" scope="col">Bill price</th><th className="numeric-cell" scope="col">Price variance</th><th className="numeric-cell" scope="col">Amount variance</th>
            </tr>
          </thead>
          <tbody>
            {lines.map((line) => {
              const hasVariance = !['MATCHED', 'BYPASSED'].includes(line.status)
              return (
                <tr className={hasVariance ? 'match-variance-row' : undefined} key={line.id}>
                  <td><StatusChip status={formatStatusLabel(line.status)} /></td>
                  <td><code>{line.itemId.slice(0, 8)}...</code></td>
                  <td className="numeric-cell"><Quantity value={line.orderedQty ?? 0} /></td>
                  <td className="numeric-cell"><Quantity value={line.receivedQty ?? 0} /></td>
                  <td className="numeric-cell"><Quantity value={line.billedQty} /></td>
                  <td className={Number(line.qtyVariance) !== 0 ? 'numeric-cell match-variance' : 'numeric-cell'}><Quantity value={line.qtyVariance ?? 0} /></td>
                  <td className="numeric-cell"><Money amount={line.poUnitPrice ?? 0} /></td>
                  <td className="numeric-cell"><Money amount={line.billUnitPrice} /></td>
                  <td className={Number(line.priceVariance) !== 0 ? 'numeric-cell match-variance' : 'numeric-cell'}><Money amount={line.priceVariance ?? 0} /></td>
                  <td className={Number(line.amountVariance) !== 0 ? 'numeric-cell match-variance' : 'numeric-cell'}><Money amount={line.amountVariance ?? 0} /></td>
                </tr>
              )
            })}
          </tbody>
        </DataTable>
      </DocumentCard>

      <Modal
        description="The reason is retained with the bill and visible in the audit trail. The server remains the final permission check."
        footer={<><Button onClick={() => setOverrideModalOpen(false)} variant="secondary">Cancel</Button><Button disabled={!overrideReason.trim() || overrideMutation.isPending} onClick={() => overrideMutation.mutate()} variant="primary">{overrideMutation.isPending ? 'Recording...' : 'Confirm override'}</Button></>}
        isOpen={overrideModalOpen}
        onClose={() => setOverrideModalOpen(false)}
        title="Authorise 3-way match override"
      >
        <FormField label="Override reason" required>
          <TextAreaInput onChange={(event) => setOverrideReason(event.target.value)} placeholder="Explain the approved price or quantity variance" rows={4} value={overrideReason} />
        </FormField>
      </Modal>
    </section>
  )
}
