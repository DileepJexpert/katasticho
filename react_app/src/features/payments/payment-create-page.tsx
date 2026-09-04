import { useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, Save } from 'lucide-react'
import { Link, useNavigate, useSearchParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
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
      <div style={{ marginBottom: 'var(--space-3)' }}>
        <Link
          to={appRoutes.payments}
          style={{
            alignItems: 'center',
            color: 'var(--text-secondary)',
            display: 'inline-flex',
            fontSize: 'var(--text-sm)',
            gap: 'var(--space-1)',
            textDecoration: 'none',
          }}
        >
          <ArrowLeft size={16} /> Back to Customer Payments
        </Link>
      </div>

      <PageHeader
        eyebrow="Sales / Receivables"
        title="Record Customer Payment"
        description="Receive payment against outstanding customer invoices, update account balances, and record transaction references."
        actions={
          <div style={{ display: 'flex', gap: 'var(--space-2)' }}>
            <Button
              onClick={() => navigate(appRoutes.payments)}
              type="button"
              variant="secondary"
            >
              Cancel
            </Button>
            <Button
              disabled={createMutation.isPending || !invoiceId || amount <= 0}
              form="payment-form"
              type="submit"
              variant="primary"
            >
              <Save size={16} />
              {createMutation.isPending ? 'Recording...' : 'Record Payment'}
            </Button>
          </div>
        }
      />

      {feedback && (
        <div
          className={`directory-state ${feedback.type === 'error' ? 'directory-state--error' : ''}`}
          role="alert"
          style={{ marginBottom: 'var(--space-4)', minHeight: 'auto', padding: 'var(--space-3)' }}
        >
          <strong>{feedback.message}</strong>
        </div>
      )}

      <form id="payment-form" onSubmit={handleSubmit}>
        <div style={{ display: 'grid', gap: 'var(--space-4)', marginBottom: 'var(--space-6)' }}>
          <div className="document-card">
            <h2 style={{ marginBottom: 'var(--space-3)' }}>1. Customer & Invoice Details</h2>
            <div style={{ display: 'grid', gap: 'var(--space-4)', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))' }}>
              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Filter by Customer
                </label>
                <select
                  onChange={(e) => {
                    setContactId(e.target.value)
                    setInvoiceId('')
                  }}
                  style={{
                    background: 'var(--bg-surface)',
                    border: '1px solid var(--border-strong)',
                    borderRadius: 'var(--radius)',
                    color: 'var(--text-primary)',
                    height: 'var(--control-h)',
                    padding: '0 var(--space-2)',
                    width: '100%',
                  }}
                  value={contactId}
                >
                  <option value="">-- All Customers --</option>
                  {customers.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.displayName}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Invoice to Pay *
                </label>
                <select
                  onChange={(e) => handleSelectInvoice(e.target.value)}
                  required
                  style={{
                    background: 'var(--bg-surface)',
                    border: '1px solid var(--border-strong)',
                    borderRadius: 'var(--radius)',
                    color: 'var(--text-primary)',
                    height: 'var(--control-h)',
                    padding: '0 var(--space-2)',
                    width: '100%',
                  }}
                  value={invoiceId}
                >
                  <option value="">-- Select Unpaid Invoice --</option>
                  {eligibleInvoices.map((inv) => (
                    <option key={inv.id} value={inv.id}>
                      {inv.invoiceNumber} - {inv.contactName || 'Customer'} (Due: ₹{Number(inv.balanceDue || 0).toLocaleString('en-IN')})
                    </option>
                  ))}
                </select>
              </div>

              {selectedInvoice && (
                <div style={{ alignItems: 'center', background: 'var(--bg-subtle)', borderRadius: 'var(--radius)', display: 'flex', gap: 'var(--space-4)', padding: 'var(--space-2) var(--space-3)' }}>
                  <div>
                    <span style={{ color: 'var(--text-muted)', display: 'block', fontSize: '11px' }}>Total Amount</span>
                    <Money amount={selectedInvoice.totalAmount} />
                  </div>
                  <div>
                    <span style={{ color: 'var(--text-muted)', display: 'block', fontSize: '11px' }}>Balance Due</span>
                    <strong style={{ color: 'var(--brand-600)' }}><Money amount={selectedInvoice.balanceDue} /></strong>
                  </div>
                </div>
              )}
            </div>
          </div>

          <div className="document-card">
            <h2 style={{ marginBottom: 'var(--space-3)' }}>2. Payment Transaction</h2>
            <div style={{ display: 'grid', gap: 'var(--space-4)', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))' }}>
              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Amount Received (₹) *
                </label>
                <input
                  min="0.01"
                  onChange={(e) => setAmount(parseFloat(e.target.value) || 0)}
                  required
                  step="0.01"
                  style={{
                    background: 'var(--bg-surface)',
                    border: '1px solid var(--border-strong)',
                    borderRadius: 'var(--radius)',
                    color: 'var(--text-primary)',
                    height: 'var(--control-h)',
                    padding: '0 var(--space-2)',
                    width: '100%',
                  }}
                  type="number"
                  value={amount}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Payment Date *
                </label>
                <input
                  onChange={(e) => setPaymentDate(e.target.value)}
                  required
                  style={{
                    background: 'var(--bg-surface)',
                    border: '1px solid var(--border-strong)',
                    borderRadius: 'var(--radius)',
                    color: 'var(--text-primary)',
                    height: 'var(--control-h)',
                    padding: '0 var(--space-2)',
                    width: '100%',
                  }}
                  type="date"
                  value={paymentDate}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Payment Method *
                </label>
                <select
                  onChange={(e) => setPaymentMethod(e.target.value)}
                  style={{
                    background: 'var(--bg-surface)',
                    border: '1px solid var(--border-strong)',
                    borderRadius: 'var(--radius)',
                    color: 'var(--text-primary)',
                    height: 'var(--control-h)',
                    padding: '0 var(--space-2)',
                    width: '100%',
                  }}
                  value={paymentMethod}
                >
                  {PAYMENT_METHODS.map((pm) => (
                    <option key={pm.value} value={pm.value}>
                      {pm.label}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Reference / UTR / Cheque #
                </label>
                <input
                  onChange={(e) => setReferenceNumber(e.target.value)}
                  placeholder="e.g. UTR12345678"
                  style={{
                    background: 'var(--bg-surface)',
                    border: '1px solid var(--border-strong)',
                    borderRadius: 'var(--radius)',
                    color: 'var(--text-primary)',
                    height: 'var(--control-h)',
                    padding: '0 var(--space-2)',
                    width: '100%',
                  }}
                  type="text"
                  value={referenceNumber}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Bank Account / Ledger
                </label>
                <input
                  onChange={(e) => setBankAccount(e.target.value)}
                  placeholder="e.g. HDFC Current Account"
                  style={{
                    background: 'var(--bg-surface)',
                    border: '1px solid var(--border-strong)',
                    borderRadius: 'var(--radius)',
                    color: 'var(--text-primary)',
                    height: 'var(--control-h)',
                    padding: '0 var(--space-2)',
                    width: '100%',
                  }}
                  type="text"
                  value={bankAccount}
                />
              </div>
            </div>

            <div style={{ marginTop: 'var(--space-4)' }}>
              <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                Payment Notes
              </label>
              <textarea
                onChange={(e) => setNotes(e.target.value)}
                placeholder="Collection remarks, customer receipt note..."
                rows={2}
                style={{
                  background: 'var(--bg-surface)',
                  border: '1px solid var(--border-strong)',
                  borderRadius: 'var(--radius)',
                  color: 'var(--text-primary)',
                  padding: 'var(--space-2)',
                  width: '100%',
                }}
                value={notes}
              />
            </div>
          </div>
        </div>
      </form>
    </section>
  )
}
