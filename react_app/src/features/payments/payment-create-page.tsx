import { useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, Save } from 'lucide-react'
import { Link, useNavigate, useSearchParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
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
import { listContacts } from '@/features/contacts/contacts-api'
import { listInvoices } from '@/features/invoices/invoices-api'
import { recordPayment, type RecordPaymentRequest } from '@/features/payments/payments-api'

const PAYMENT_METHODS = [
  { value: 'BANK_TRANSFER', label: 'Bank Transfer / NEFT / RTGS' },
  { value: 'UPI', label: 'UPI' },
  { value: 'CASH', label: 'Cash' },
  { value: 'CHEQUE', label: 'Cheque' },
  { value: 'CARD', label: 'Card' },
]

export function PaymentCreatePage() {
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()
  const initialInvoiceId = searchParams.get('invoiceId') || ''
  const queryClient = useQueryClient()

  const [contactId, setContactId] = useState('')
  const [invoiceId, setInvoiceId] = useState(initialInvoiceId)
  const [paymentDate, setPaymentDate] = useState(() => new Date().toISOString().split('T')[0] || '')
  const [amount, setAmount] = useState(0)
  const [paymentMethod, setPaymentMethod] = useState('BANK_TRANSFER')
  const [referenceNumber, setReferenceNumber] = useState('')
  const [bankAccount, setBankAccount] = useState('')
  const [notes, setNotes] = useState('')
  const [feedback, setFeedback] = useState<{ type: 'error' | 'success'; message: string } | null>(null)

  const contactsQuery = useQuery({
    queryKey: ['contacts-for-payments'],
    queryFn: () => listContacts({ filter: 'CUSTOMER', page: 0 }),
  })

  const invoicesQuery = useQuery({
    queryKey: ['invoices-for-payments'],
    queryFn: () => listInvoices({ page: 0, search: '', status: null }),
  })

  const customers = contactsQuery.data?.content ?? []
  const allInvoices = invoicesQuery.data?.content ?? []

  const eligibleInvoices = useMemo(() => {
    return allInvoices.filter((inv) => {
      const hasBalance = Number(inv.balanceDue) > 0 || inv.status !== 'PAID'
      if (!hasBalance) return false
      if (contactId) return inv.contactId === contactId
      return true
    })
  }, [allInvoices, contactId])

  const selectedInvoice = useMemo(() => {
    return allInvoices.find((inv) => inv.id === invoiceId)
  }, [allInvoices, invoiceId])

  const handleSelectInvoice = (invId: string) => {
    setInvoiceId(invId)
    const inv = allInvoices.find((i) => i.id === invId)
    if (inv) {
      if (inv.contactId && !contactId) setContactId(inv.contactId)
      const due = Number(inv.balanceDue) || Number(inv.totalAmount) || 0
      setAmount(due)
    }
  }

  const createMutation = useMutation({
    mutationFn: (req: RecordPaymentRequest) => recordPayment(req),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['payments'] })
      queryClient.invalidateQueries({ queryKey: ['invoices'] })
      navigate(appRoutes.payments)
    },
    onError: (err: unknown) => {
      const msg = err instanceof Error ? err.message : 'Failed to record payment.'
      setFeedback({ type: 'error', message: msg })
    },
  })

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    setFeedback(null)

    if (!invoiceId) {
      setFeedback({ type: 'error', message: 'Please select an invoice to record payment against.' })
      return
    }

    if (!amount || amount <= 0) {
      setFeedback({ type: 'error', message: 'Payment amount must be greater than 0.' })
      return
    }

    createMutation.mutate({
      invoiceId,
      contactId: contactId || undefined,
      paymentDate,
      amount,
      paymentMethod,
      referenceNumber: referenceNumber.trim() || undefined,
      bankAccount: bankAccount.trim() || undefined,
      notes: notes.trim() || undefined,
    })
  }

  return (
    <section className="workspace-page">
      <Link className="form-back-link" to={appRoutes.payments}>
        <ArrowLeft size={16} /> Back to Customer Payments
      </Link>

      <PageHeader
        eyebrow="Sales / Receivables"
        title="Record Customer Payment"
        description="Receive payment against outstanding customer invoices, update account balances, and record transaction references."
      />

      {feedback && (
        <div
          className={`banner ${feedback.type === 'success' ? 'banner--success' : 'banner--error'}`}
          role="alert"
          style={{ marginBottom: 'var(--space-4)' }}
        >
          <span>{feedback.message}</span>
          <button className="banner-dismiss" onClick={() => setFeedback(null)} type="button">
            ✕
          </button>
        </div>
      )}

      <form className="create-form-container" onSubmit={handleSubmit}>
        <FormCard
          description="Select customer and choose from unpaid invoices."
          stepNumber={1}
          title="Customer & Invoice Details"
        >
          <FormGrid columns={2}>
            <FormField label="Filter by Customer">
              <SelectInput
                onChange={(e) => {
                  setContactId(e.target.value)
                  setInvoiceId('')
                }}
                options={customers.map((c) => ({
                  value: c.id,
                  label: c.displayName || c.name,
                }))}
                placeholderOption="-- All Customers --"
                value={contactId}
              />
            </FormField>

            <FormField label="Invoice to Pay" required>
              <SelectInput
                onChange={(e) => handleSelectInvoice(e.target.value)}
                options={eligibleInvoices.map((inv) => ({
                  value: inv.id,
                  label: `${inv.invoiceNumber} - ${inv.contactName || 'Customer'} (Due: ₹${Number(inv.balanceDue || 0).toLocaleString('en-IN')})`,
                }))}
                placeholderOption="-- Select Unpaid Invoice --"
                required
                value={invoiceId}
              />
            </FormField>
          </FormGrid>

          {selectedInvoice && (
            <div className="form-summary-card" style={{ marginTop: 'var(--space-3)', width: '100%', maxWidth: 360 }}>
              <div className="form-summary-row">
                <span className="cell-muted">Total Invoice Amount:</span>
                <Money amount={selectedInvoice.totalAmount} />
              </div>
              <div className="form-summary-row form-summary-row--total">
                <span>Balance Due:</span>
                <Money amount={selectedInvoice.balanceDue} />
              </div>
            </div>
          )}
        </FormCard>

        <FormCard
          description="Enter the amount collected, payment channel, transaction ID, and banking details."
          stepNumber={2}
          title="Payment Transaction"
        >
          <FormGrid columns={3}>
            <FormField label="Amount Received" required>
              <NumberInput
                currencyPrefix="₹"
                min={0.01}
                onChange={(e) => setAmount(parseFloat(e.target.value) || 0)}
                required
                step="0.01"
                value={amount}
              />
            </FormField>

            <FormField label="Payment Date" required>
              <TextInput
                onChange={(e) => setPaymentDate(e.target.value)}
                required
                type="date"
                value={paymentDate}
              />
            </FormField>

            <FormField label="Payment Method" required>
              <SelectInput
                onChange={(e) => setPaymentMethod(e.target.value)}
                options={PAYMENT_METHODS}
                required
                value={paymentMethod}
              />
            </FormField>

            <FormField label="Reference / UTR / Cheque #">
              <TextInput
                onChange={(e) => setReferenceNumber(e.target.value)}
                placeholder="e.g. UTR12345678"
                value={referenceNumber}
              />
            </FormField>

            <FormField label="Bank Account / Ledger">
              <TextInput
                onChange={(e) => setBankAccount(e.target.value)}
                placeholder="e.g. HDFC Current Account"
                value={bankAccount}
              />
            </FormField>
          </FormGrid>

          <div style={{ marginTop: 'var(--space-4)' }}>
            <FormField label="Payment Notes">
              <TextAreaInput
                onChange={(e) => setNotes(e.target.value)}
                placeholder="Collection remarks, customer receipt note..."
                rows={2}
                value={notes}
              />
            </FormField>
          </div>
        </FormCard>

        <div className="form-actions-bar">
          <Button
            onClick={() => navigate(appRoutes.payments)}
            type="button"
            variant="secondary"
          >
            Cancel
          </Button>
          <Button
            disabled={createMutation.isPending || !invoiceId || amount <= 0}
            type="submit"
            variant="primary"
          >
            <Save size={16} />
            {createMutation.isPending ? 'Recording...' : 'Record Payment'}
          </Button>
        </div>
      </form>
    </section>
  )
}
