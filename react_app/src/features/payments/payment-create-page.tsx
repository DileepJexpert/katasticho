import { useEffect, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, Save } from 'lucide-react'
import { Link, useNavigate, useSearchParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  EntityPicker,
  FormCard,
  FormField,
  FormGrid,
  Money,
  NumberInput,
  PageHeader,
  SelectInput,
  TextAreaInput,
  TextInput,
} from '@/design-system'
import {
  getInvoice,
  listInvoices,
  recordInvoicePayment,
  type Invoice,
  type RecordInvoicePaymentRequest,
} from '@/features/invoices/invoices-api'

const paymentMethods = [
  { value: 'BANK_TRANSFER', label: 'Bank transfer / NEFT / RTGS' },
  { value: 'UPI', label: 'UPI' },
  { value: 'CASH', label: 'Cash' },
  { value: 'CHEQUE', label: 'Cheque' },
  { value: 'CARD', label: 'Card' },
]

function isPayable(invoice: Invoice) {
  return ['SENT', 'PARTIALLY_PAID', 'OVERDUE'].includes(invoice.status) && Number(invoice.balanceDue) > 0
}

export function PaymentCreatePage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [searchParams] = useSearchParams()
  const initialInvoiceId = searchParams.get('invoiceId') || ''
  const [invoiceId, setInvoiceId] = useState(initialInvoiceId)
  const [selectedInvoice, setSelectedInvoice] = useState<Invoice | null>(null)
  const [paymentDate, setPaymentDate] = useState(() => new Date().toISOString().split('T')[0] || '')
  const [amount, setAmount] = useState(0)
  const [paymentMethod, setPaymentMethod] = useState('BANK_TRANSFER')
  const [referenceNumber, setReferenceNumber] = useState('')
  const [notes, setNotes] = useState('')
  const [feedback, setFeedback] = useState<string | null>(null)
  const sourceInvoice = useQuery({
    queryKey: ['invoices', initialInvoiceId, 'payment-source'],
    queryFn: () => getInvoice(initialInvoiceId),
    enabled: Boolean(initialInvoiceId),
  })

  useEffect(() => {
    if (!sourceInvoice.data || invoiceId !== initialInvoiceId || selectedInvoice?.id === sourceInvoice.data.id) return
    setInvoiceId(sourceInvoice.data.id)
    setSelectedInvoice(sourceInvoice.data)
    setAmount(Number(sourceInvoice.data.balanceDue) || 0)
  }, [initialInvoiceId, invoiceId, selectedInvoice?.id, sourceInvoice.data])

  const selectInvoice = (invoice: Invoice | null | undefined) => {
    setSelectedInvoice(invoice ?? null)
    setInvoiceId(invoice?.id ?? '')
    setAmount(Number(invoice?.balanceDue) || 0)
  }

  const createMutation = useMutation({
    mutationFn: (request: RecordInvoicePaymentRequest) => recordInvoicePayment(invoiceId, request),
    onSuccess: (payment) => {
      queryClient.invalidateQueries({ queryKey: ['payments'] })
      queryClient.invalidateQueries({ queryKey: ['invoices'] })
      queryClient.invalidateQueries({ queryKey: ['invoices', invoiceId] })
      queryClient.invalidateQueries({ queryKey: ['invoices', invoiceId, 'payments'] })
      navigate(appRoutes.paymentDetail(payment.id))
    },
    onError: (error: Error) => setFeedback(error.message),
  })

  const handleSubmit = (event: React.FormEvent) => {
    event.preventDefault()
    setFeedback(null)
    if (!selectedInvoice || !invoiceId) {
      setFeedback('Select a sent, partially paid, or overdue invoice before recording payment.')
      return
    }
    if (!isPayable(selectedInvoice)) {
      setFeedback('The selected invoice is not currently payable. Refresh the invoice and review its status.')
      return
    }
    if (amount <= 0) {
      setFeedback('Payment amount must be greater than zero.')
      return
    }
    if (amount > Number(selectedInvoice.balanceDue)) {
      setFeedback('Payment cannot exceed the current balance due. The server also validates this at submission time.')
      return
    }
    createMutation.mutate({
      amount,
      paymentDate,
      paymentMethod,
      referenceNumber: referenceNumber.trim() || undefined,
      notes: notes.trim() || undefined,
    })
  }

  return (
    <section className="workspace-page">
      <Link className="form-back-link" to={appRoutes.payments}><ArrowLeft size={16} /> Back to customer payments</Link>
      <PageHeader eyebrow="Sales / Receivables" title="Record customer payment" description="Apply a full or partial receipt to one sent invoice. The server protects against over-collection and posts the accounting entry." />
      {feedback ? <div className="banner banner--error" role="alert">{feedback}</div> : null}
      {sourceInvoice.isError ? <div className="banner banner--error" role="alert">The invoice requested by this link could not be loaded. Search for a payable invoice below.</div> : null}

      <form className="create-form-container" onSubmit={handleSubmit}>
        <FormCard description="Search only payable sales invoices. Customer identity is derived from the selected invoice so it cannot drift from the receivable." stepNumber={1} title="Invoice to settle">
          <FormField label="Customer invoice" required>
            <EntityPicker
              ariaLabel="Search payable customer invoices"
              getOptionDescription={(invoice) => `${invoice.contactName ?? 'Unknown customer'} / ${invoice.status}`}
              getOptionId={(invoice) => invoice.id}
              getOptionLabel={(invoice) => invoice.invoiceNumber}
              onChange={(_id, invoice) => selectInvoice(invoice)}
              onSearch={async (search) => (await listInvoices({ page: 0, search, status: null })).content.filter(isPayable)}
              placeholder="Search invoice number or customer"
              selectedEntity={selectedInvoice}
              value={invoiceId || null}
            />
          </FormField>
          {selectedInvoice ? <div className="form-summary-card"><div className="form-summary-row"><span>Customer</span><strong>{selectedInvoice.contactName ?? '--'}</strong></div><div className="form-summary-row"><span>Invoice total</span><Money amount={selectedInvoice.totalAmount} currency={selectedInvoice.currency ?? 'INR'} /></div><div className="form-summary-row form-summary-row--total"><span>Balance due</span><Money amount={selectedInvoice.balanceDue} currency={selectedInvoice.currency ?? 'INR'} /></div></div> : null}
        </FormCard>

        <FormCard description="Enter the actual collection. Use a lower amount for a part-payment; the outstanding balance remains open for the next receipt." stepNumber={2} title="Receipt details">
          <FormGrid columns={3}>
            <FormField label="Amount received" required><NumberInput currencyPrefix="INR" max={selectedInvoice ? Number(selectedInvoice.balanceDue) : undefined} min={0.01} onChange={(event) => setAmount(Number(event.target.value) || 0)} required step="0.01" value={amount} /></FormField>
            <FormField label="Payment date" required><TextInput onChange={(event) => setPaymentDate(event.target.value)} required type="date" value={paymentDate} /></FormField>
            <FormField label="Payment method" required><SelectInput onChange={(event) => setPaymentMethod(event.target.value)} options={paymentMethods} required value={paymentMethod} /></FormField>
            <FormField label="Reference, UTR, or cheque number" span={2}><TextInput onChange={(event) => setReferenceNumber(event.target.value)} placeholder="e.g. UTR123456789" value={referenceNumber} /></FormField>
            <FormField label="Collection notes" span="full"><TextAreaInput onChange={(event) => setNotes(event.target.value)} placeholder="Customer collection or reconciliation remarks" rows={3} value={notes} /></FormField>
          </FormGrid>
        </FormCard>

        <div className="form-actions-bar">
          <Button onClick={() => navigate(appRoutes.payments)} type="button" variant="secondary">Cancel</Button>
          <Button disabled={createMutation.isPending || !selectedInvoice || amount <= 0} type="submit" variant="primary"><Save size={16} />{createMutation.isPending ? 'Recording...' : 'Record payment'}</Button>
        </div>
      </form>
    </section>
  )
}
