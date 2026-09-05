import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, DollarSign, Send, ShieldAlert, ShieldCheck, Trash2, XCircle } from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  DataTable,
  DocumentCard,
  DocumentError,
  Fact,
  FactList,
  Money,
  PageHeader,
  Quantity,
  StatusChip,
  SummaryRow,
} from '@/design-system'
import { deleteBill, getBill, getBillPayments, postBill, voidBill } from '@/features/bills/bills-api'
import { formatDate, formatStatusLabel } from '@/shared/format/format'

export function BillDetailPage() {
  const { billId } = useParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [feedback, setFeedback] = useState<string | null>(null)
  const bill = useQuery({ queryKey: ['bills', billId], queryFn: () => getBill(billId!), enabled: Boolean(billId) })
  const payments = useQuery({ queryKey: ['bills', billId, 'payments'], queryFn: () => getBillPayments(billId!), enabled: Boolean(billId) })

  const refreshBill = () => {
    queryClient.invalidateQueries({ queryKey: ['bills'] })
    queryClient.invalidateQueries({ queryKey: ['bills', billId] })
    queryClient.invalidateQueries({ queryKey: ['bills', billId, 'payments'] })
  }
  const postMutation = useMutation({
    mutationFn: () => postBill(billId!),
    onSuccess: () => { setFeedback('Bill posted. The server created its AP and tax journal entries.'); refreshBill() },
    onError: (error: Error) => setFeedback(error.message),
  })
  const discardMutation = useMutation({
    mutationFn: () => deleteBill(billId!),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ['bills'] }); navigate(appRoutes.bills) },
    onError: (error: Error) => setFeedback(error.message),
  })
  const voidMutation = useMutation({
    mutationFn: () => voidBill(billId!, 'Voided by user'),
    onSuccess: () => { setFeedback('Bill voided and the server reversed its eligible postings.'); refreshBill() },
    onError: (error: Error) => setFeedback(error.message),
  })

  if (!billId) return <DocumentError onBack={() => navigate(appRoutes.bills)} />
  if (bill.isLoading) return <section className="workspace-page"><div aria-live="polite" className="directory-state">Loading vendor bill...</div></section>
  if (bill.isError || !bill.data) return <DocumentError onBack={() => navigate(appRoutes.bills)} />

  const document = bill.data
  const currency = document.currency ?? 'INR'
  const matchStatus = document.threeWayMatchStatus ?? 'NOT_RUN'
  const matchException = matchStatus === 'EXCEPTION'
  const payable = Number(document.balanceDue) > 0 && !['DRAFT', 'VOID', 'PAID'].includes(document.status)

  return (
    <section className="workspace-page">
      <PageHeader
        actions={<><StatusChip status={formatStatusLabel(document.status)} /><Button onClick={() => navigate(appRoutes.bills)} variant="secondary"><ArrowLeft size={16} /> Back to bills</Button></>}
        description={`${document.vendorName ?? 'Unknown vendor'} / billed ${formatDate(document.billDate)}`}
        eyebrow="Purchases / Payables / Vendor bill"
        title={document.billNumber}
      />
      {feedback ? <div className="banner banner--success" role="status">{feedback}</div> : null}

      <div className={matchException ? 'banner banner--error' : 'banner banner--success'} role="status">
        <div className="cell-stack">
          <strong>{matchException ? <ShieldAlert size={16} /> : <ShieldCheck size={16} />} 3-Way Match: {formatStatusLabel(matchStatus)}</strong>
          <span>Purchase order, goods receipt, and vendor bill quantity and price verification.</span>
        </div>
        <Button onClick={() => navigate(appRoutes.threeWayMatchWorkbench(document.id))} variant="secondary">Review match</Button>
      </div>

      <div className="document-layout">
        <DocumentCard title="Bill information">
          <FactList columns={2}>
            <Fact label="Vendor" value={document.vendorName} />
            <Fact label="Bill date" value={formatDate(document.billDate)} />
            <Fact label="Due date" value={formatDate(document.dueDate)} />
            <Fact label="Vendor invoice" mono value={document.vendorBillNumber} />
            <Fact label="Place of supply" value={document.placeOfSupply} />
            <Fact label="Reverse charge" value={document.reverseCharge ? 'Yes' : 'No'} />
            <Fact label="Source purchase order" mono value={document.purchaseOrderId ? 'Linked PO' : 'Direct bill'} />
          </FactList>
        </DocumentCard>
        <DocumentCard title="Settlement status" variant="summary">
          <SummaryRow label="Bill amount" value={<Money amount={document.totalAmount} currency={currency} />} />
          <SummaryRow label="Amount paid" value={<Money amount={document.amountPaid ?? document.paidAmount} currency={currency} />} />
          <SummaryRow isTotal label="Balance due" value={<Money amount={document.balanceDue} currency={currency} />} />
          <div className="document-card__actions">
            {document.status === 'DRAFT' ? <Button disabled={postMutation.isPending} onClick={() => postMutation.mutate()} variant="primary"><Send size={16} />{postMutation.isPending ? 'Posting...' : 'Post bill'}</Button> : null}
            {payable ? <Button onClick={() => navigate(`${appRoutes.vendorPaymentCreate}?contactId=${encodeURIComponent(document.contactId ?? '')}&billId=${encodeURIComponent(document.id)}&amount=${encodeURIComponent(String(document.balanceDue ?? ''))}`)} variant="primary"><DollarSign size={16} /> Record payment</Button> : null}
            {document.status === 'DRAFT' ? <Button disabled={discardMutation.isPending} onClick={() => discardMutation.mutate()} variant="destructive"><Trash2 size={16} /> Delete draft</Button> : null}
            {['POSTED', 'PARTIALLY_PAID', 'OPEN', 'OVERDUE'].includes(document.status) ? <Button disabled={voidMutation.isPending} onClick={() => voidMutation.mutate()} variant="destructive"><XCircle size={16} /> Void bill</Button> : null}
          </div>
        </DocumentCard>
      </div>

      <DocumentCard title="Billed line items" variant="lines">
        <DataTable caption="Vendor bill lines">
          <thead>
            <tr>
              <th scope="col">#</th><th scope="col">Description</th><th scope="col">HSN</th><th className="numeric-cell" scope="col">Qty</th><th className="numeric-cell" scope="col">Unit cost</th><th className="numeric-cell" scope="col">Discount</th><th className="numeric-cell" scope="col">GST</th><th className="numeric-cell" scope="col">Tax</th><th className="numeric-cell" scope="col">Line total</th>
            </tr>
          </thead>
          <tbody>
            {document.lines.map((line) => (
              <tr key={line.id}>
                <td>{line.lineNumber}</td>
                <td><div className="cell-stack"><strong>{line.description || line.itemName || '--'}</strong>{line.itemName && line.description ? <span className="cell-muted">{line.itemName}</span> : null}</div></td>
                <td>{line.hsnCode ? <code>{line.hsnCode}</code> : '--'}</td>
                <td className="numeric-cell"><Quantity value={line.quantity} /></td>
                <td className="numeric-cell"><Money amount={line.unitPrice} currency={currency} /></td>
                <td className="numeric-cell">{line.discountPercent ?? 0}%</td>
                <td className="numeric-cell">{line.gstRate ?? 0}%</td>
                <td className="numeric-cell"><Money amount={line.lineTax ?? line.taxAmount} currency={currency} /></td>
                <td className="numeric-cell"><strong><Money amount={line.lineTotal} currency={currency} /></strong></td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      </DocumentCard>

      <div className="document-layout">
        <DocumentCard title="Payment history">
          {payments.isLoading ? <p aria-live="polite" className="document-loading">Loading payments...</p> : payments.data?.length ? (
            <DataTable caption="Payments applied to this bill"><thead><tr><th scope="col">Payment</th><th scope="col">Date</th><th scope="col">Mode</th><th className="numeric-cell" scope="col">Amount</th></tr></thead><tbody>{payments.data.map((payment) => <tr key={payment.id}><td><strong>{payment.paymentNumber}</strong>{payment.referenceNumber ? <span className="cell-muted"> / {payment.referenceNumber}</span> : null}</td><td>{formatDate(payment.paymentDate)}</td><td>{formatStatusLabel(payment.paymentMode ?? '')}</td><td className="numeric-cell"><Money amount={payment.amount} currency={currency} /></td></tr>)}</tbody></DataTable>
          ) : <p className="document-loading">No payments recorded for this bill.</p>}
        </DocumentCard>
        <DocumentCard title="Bill total" variant="summary">
          <SummaryRow label="Taxable subtotal" value={<Money amount={document.subtotal} currency={currency} />} />
          <SummaryRow label="Input GST" value={<Money amount={document.taxAmount} currency={currency} />} />
          <SummaryRow isTotal label="Bill amount" value={<Money amount={document.totalAmount} currency={currency} />} />
        </DocumentCard>
      </div>
    </section>
  )
}
