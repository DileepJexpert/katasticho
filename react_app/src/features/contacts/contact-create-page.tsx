import { useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, Save } from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { PageHeader } from '@/design-system/page-header'
import { createContact, type CreateContactRequest } from '@/features/contacts/contacts-api'

export function ContactCreatePage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const [contactType, setContactType] = useState<'CUSTOMER' | 'VENDOR' | 'BOTH'>('CUSTOMER')
  const [displayName, setDisplayName] = useState('')
  const [companyName, setCompanyName] = useState('')
  const [email, setEmail] = useState('')
  const [phone, setPhone] = useState('')
  const [mobile, setMobile] = useState('')
  const [gstin, setGstin] = useState('')
  const [pan, setPan] = useState('')

  // Billing address
  const [billingAddressLine1, setBillingAddressLine1] = useState('')
  const [billingCity, setBillingCity] = useState('')
  const [billingState, setBillingState] = useState('')
  const [billingStateCode, setBillingStateCode] = useState('')
  const [billingPostalCode, setBillingPostalCode] = useState('')
  const [billingCountry, setBillingCountry] = useState('IN')

  // Shipping address
  const [sameAsBilling, setSameAsBilling] = useState(true)
  const [shippingAddressLine1, setShippingAddressLine1] = useState('')
  const [shippingCity, setShippingCity] = useState('')
  const [shippingState, setShippingState] = useState('')
  const [shippingStateCode, setShippingStateCode] = useState('')
  const [shippingPostalCode, setShippingPostalCode] = useState('')
  const [shippingCountry, setShippingCountry] = useState('IN')

  // Commercial
  const [creditLimit, setCreditLimit] = useState(0)
  const [paymentTermsDays, setPaymentTermsDays] = useState(30)
  const [openingBalance, setOpeningBalance] = useState(0)
  const [notes, setNotes] = useState('')
  const [feedback, setFeedback] = useState<{ type: 'error' | 'success'; message: string } | null>(null)

  const createMutation = useMutation({
    mutationFn: (req: CreateContactRequest) => createContact(req),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['contacts'] })
      navigate(appRoutes.contacts)
    },
    onError: (err: unknown) => {
      const msg = err instanceof Error ? err.message : 'Failed to create contact.'
      setFeedback({ type: 'error', message: msg })
    },
  })

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    setFeedback(null)

    if (!displayName.trim()) {
      setFeedback({ type: 'error', message: 'Display Name is required.' })
      return
    }

    createMutation.mutate({
      contactType,
      displayName: displayName.trim(),
      companyName: companyName.trim() || undefined,
      email: email.trim() || undefined,
      phone: phone.trim() || undefined,
      mobile: mobile.trim() || undefined,
      gstin: gstin.trim() || undefined,
      pan: pan.trim() || undefined,
      billingAddressLine1: billingAddressLine1.trim() || undefined,
      billingCity: billingCity.trim() || undefined,
      billingState: billingState.trim() || undefined,
      billingStateCode: billingStateCode.trim() || undefined,
      billingPostalCode: billingPostalCode.trim() || undefined,
      billingCountry: billingCountry.trim() || 'IN',
      shippingAddressLine1: (sameAsBilling ? billingAddressLine1 : shippingAddressLine1).trim() || undefined,
      shippingCity: (sameAsBilling ? billingCity : shippingCity).trim() || undefined,
      shippingState: (sameAsBilling ? billingState : shippingState).trim() || undefined,
      shippingStateCode: (sameAsBilling ? billingStateCode : shippingStateCode).trim() || undefined,
      shippingPostalCode: (sameAsBilling ? billingPostalCode : shippingPostalCode).trim() || undefined,
      shippingCountry: (sameAsBilling ? billingCountry : shippingCountry).trim() || 'IN',
      creditLimit: Number(creditLimit) || 0,
      paymentTermsDays: Number(paymentTermsDays) || 30,
      openingBalance: Number(openingBalance) || 0,
      notes: notes.trim() || undefined,
    })
  }

  return (
    <section className="workspace-page">
      <Link className="form-back-link" to={appRoutes.contacts}>
        <ArrowLeft size={16} /> Back to Contacts
        
      </Link>

      <PageHeader
        eyebrow="Master Data"
        title="New Contact"
        description="Add a customer, vendor, or dual-role commercial partner with GST registration and address masters."
        actions={
          <div style={{ display: 'flex', gap: 'var(--space-2)' }}>
            <Button
              onClick={() => navigate(appRoutes.contacts)}
              type="button"
              variant="secondary"
            >
              Cancel
            </Button>
            <Button
              disabled={createMutation.isPending || !displayName.trim()}
              form="contact-form"
              type="submit"
              variant="primary"
            >
              <Save size={16} />
              {createMutation.isPending ? 'Saving...' : 'Save Contact'}
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

      <form className="create-form-container" id="contact-form" onSubmit={handleSubmit}>
          <div className="form-card">
          <div className="form-card-header">
            <h2 className="form-card-title">1. General & Tax Details</h2>
          </div>
            <div className="form-grid--auto">
              <label className="field-group">
                <span>Contact Role *</span>
                <select
                  onChange={(e) => setContactType(e.target.value as 'CUSTOMER' | 'VENDOR' | 'BOTH')}
                  value={contactType}
                >
                  <option value="CUSTOMER">Customer (Sales & Receivables)</option>
                  <option value="VENDOR">Vendor (Purchases & Payables)</option>
                  <option value="BOTH">Both (Customer & Vendor)</option>
                </select>
              </label>

              <label className="field-group">
                <span>Display Name *</span>
                <input
                  onChange={(e) => setDisplayName(e.target.value)}
                  placeholder="e.g. Apex Health Corp"
                  required
                  type="text"
                  value={displayName}
                />
              </label>

              <label className="field-group">
                <span>Company / Legal Entity Name</span>
                <input
                  onChange={(e) => setCompanyName(e.target.value)}
                  placeholder="Official registered company name"
                  type="text"
                  value={companyName}
                />
              </label>

              <label className="field-group">
                <span>GSTIN (15 characters)</span>
                <input
                  maxLength={15}
                  onChange={(e) => setGstin(e.target.value.toUpperCase())}
                  placeholder="e.g. 27AAAAA0000A1Z5"
                  type="text"
                  value={gstin}
                />
              </label>

              <label className="field-group">
                <span>PAN Number</span>
                <input
                  maxLength={10}
                  onChange={(e) => setPan(e.target.value.toUpperCase())}
                  placeholder="e.g. AAAAA0000A"
                  type="text"
                  value={pan}
                />
              </label>

              <label className="field-group">
                <span>Email Address</span>
                <input
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="billing@company.com"
                  type="email"
                  value={email}
                />
              </label>

              <label className="field-group">
                <span>Phone / Landline</span>
                <input
                  onChange={(e) => setPhone(e.target.value)}
                  placeholder="022-28001234"
                  type="text"
                  value={phone}
                />
              </label>

              <label className="field-group">
                <span>Mobile Number</span>
                <input
                  onChange={(e) => setMobile(e.target.value)}
                  placeholder="+91 98200 12345"
                  type="text"
                  value={mobile}
                />
              </label>
            </div>
          </div>

          <div className="form-card">
          <div className="form-card-header">
            <h2 className="form-card-title">2. Billing & Shipping Address</h2>
          </div>
            <div className="form-grid--auto">
              <label className="field-group field-group--span-2">
                <span>Billing Address Line 1</span>
                <input
                  onChange={(e) => setBillingAddressLine1(e.target.value)}
                  placeholder="Street, suite, floor, industrial area"
                  type="text"
                  value={billingAddressLine1}
                />
              </label>

              <label className="field-group">
                <span>City</span>
                <input
                  onChange={(e) => setBillingCity(e.target.value)}
                  placeholder="e.g. Mumbai"
                  type="text"
                  value={billingCity}
                />
              </label>

              <label className="field-group">
                <span>State</span>
                <input
                  onChange={(e) => setBillingState(e.target.value)}
                  placeholder="e.g. Maharashtra"
                  type="text"
                  value={billingState}
                />
              </label>

              <label className="field-group">
                <span>State Code (GST)</span>
                <input
                  maxLength={2}
                  onChange={(e) => setBillingStateCode(e.target.value)}
                  placeholder="e.g. 27"
                  type="text"
                  value={billingStateCode}
                />
              </label>

              <label className="field-group">
                <span>Postal Code</span>
                <input
                  onChange={(e) => setBillingPostalCode(e.target.value)}
                  placeholder="e.g. 400001"
                  type="text"
                  value={billingPostalCode}
                />
              </label>

              <label className="field-group">
                <span>Country</span>
                <input
                  onChange={(e) => setBillingCountry(e.target.value)}
                  type="text"
                  value={billingCountry}
                />
              </label>
            </div>

            <div style={{ marginTop: 'var(--space-4)' }}>
              <label style={{ display: 'inline-flex', alignItems: 'center', gap: '8px', cursor: 'pointer' }}>
                <input
                  checked={sameAsBilling}
                  onChange={(e) => setSameAsBilling(e.target.checked)}
                  type="checkbox"
                />
                <span style={{ fontSize: 'var(--text-sm)', fontWeight: 'var(--fw-medium)' }}>
                  Shipping address is identical to billing address
                </span>
              </label>
            </div>

            {!sameAsBilling && (
              <div style={{ display: 'grid', gap: 'var(--space-4)', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', marginTop: 'var(--space-4)' }}>
                <label className="field-group field-group--span-2">
                <span>Shipping Address Line 1</span>
                  <input
                    onChange={(e) => setShippingAddressLine1(e.target.value)}
                    placeholder="Shipping destination address"
                    type="text"
                    value={shippingAddressLine1}
                  />
              </label>
                <label className="field-group">
                <span>Shipping City</span>
                  <input
                    onChange={(e) => setShippingCity(e.target.value)}
                    placeholder="e.g. Pune"
                    type="text"
                    value={shippingCity}
                  />
              </label>
                <label className="field-group">
                <span>Shipping State</span>
                  <input
                    onChange={(e) => setShippingState(e.target.value)}
                    placeholder="e.g. Maharashtra"
                    type="text"
                    value={shippingState}
                  />
              </label>
                <label className="field-group">
                <span>Shipping State Code</span>
                  <input
                    maxLength={2}
                    onChange={(e) => setShippingStateCode(e.target.value)}
                    placeholder="e.g. 27"
                    type="text"
                    value={shippingStateCode}
                  />
              </label>
                <label className="field-group">
                <span>Shipping Postal Code</span>
                  <input
                    onChange={(e) => setShippingPostalCode(e.target.value)}
                    placeholder="e.g. 411001"
                    type="text"
                    value={shippingPostalCode}
                  />
              </label>
                <label className="field-group">
                <span>Shipping Country</span>
                  <input
                    onChange={(e) => setShippingCountry(e.target.value)}
                    type="text"
                    value={shippingCountry}
                  />
              </label>
              </div>
            )}
          </div>

          <div className="form-card">
          <div className="form-card-header">
            <h2 className="form-card-title">3. Credit & Commercial Terms</h2>
          </div>
            <div className="form-grid--auto">
              <label className="field-group">
                <span>Credit Limit (₹)</span>
                <input
                  min="0"
                  onChange={(e) => setCreditLimit(parseFloat(e.target.value) || 0)}
                  type="number"
                  value={creditLimit}
                />
              </label>

              <label className="field-group">
                <span>Payment Terms (Days)</span>
                <input
                  min="0"
                  onChange={(e) => setPaymentTermsDays(parseInt(e.target.value) || 0)}
                  type="number"
                  value={paymentTermsDays}
                />
              </label>

              <label className="field-group">
                <span>Opening Balance (₹)</span>
                <input
                  onChange={(e) => setOpeningBalance(parseFloat(e.target.value) || 0)}
                  type="number"
                  value={openingBalance}
                />
              </label>
            </div>

            <label className="field-group" style={{ marginTop: 'var(--space-4)' }}>
              <span>Internal Notes</span>
              <textarea
                onChange={(e) => setNotes(e.target.value)}
                placeholder="Internal customer background, credit remarks, etc."
                rows={2}
                value={notes}
              />
            </label>
          </div>

          <div className="form-actions-bar">
            <Button
              onClick={() => navigate(appRoutes.contacts)}
              type="button"
              variant="secondary"
            >
              Cancel
            </Button>
            <Button
              disabled={createMutation.isPending || !displayName.trim()}
              type="submit"
              variant="primary"
            >
              <Save size={16} />
              {createMutation.isPending ? 'Saving...' : 'Save Contact'}
            </Button>
          </div>
      </form>
    </section>
  )
}
