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
      <div style={{ marginBottom: 'var(--space-3)' }}>
        <Link
          to={appRoutes.contacts}
          style={{
            alignItems: 'center',
            color: 'var(--text-secondary)',
            display: 'inline-flex',
            fontSize: 'var(--text-sm)',
            gap: 'var(--space-1)',
            textDecoration: 'none',
          }}
        >
          <ArrowLeft size={16} /> Back to Contacts
        </Link>
      </div>

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

      <form id="contact-form" onSubmit={handleSubmit}>
        <div style={{ display: 'grid', gap: 'var(--space-4)', marginBottom: 'var(--space-6)' }}>
          <div className="document-card">
            <h2 style={{ marginBottom: 'var(--space-3)' }}>1. General & Tax Details</h2>
            <div style={{ display: 'grid', gap: 'var(--space-4)', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))' }}>
              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Contact Role *
                </label>
                <select
                  onChange={(e) => setContactType(e.target.value as 'CUSTOMER' | 'VENDOR' | 'BOTH')}
                  style={{
                    background: 'var(--bg-surface)',
                    border: '1px solid var(--border-strong)',
                    borderRadius: 'var(--radius)',
                    color: 'var(--text-primary)',
                    height: 'var(--control-h)',
                    padding: '0 var(--space-2)',
                    width: '100%',
                  }}
                  value={contactType}
                >
                  <option value="CUSTOMER">Customer (Sales & Receivables)</option>
                  <option value="VENDOR">Vendor (Purchases & Payables)</option>
                  <option value="BOTH">Both (Customer & Vendor)</option>
                </select>
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Display Name *
                </label>
                <input
                  onChange={(e) => setDisplayName(e.target.value)}
                  placeholder="e.g. Apex Health Corp"
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
                  type="text"
                  value={displayName}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Company / Legal Entity Name
                </label>
                <input
                  onChange={(e) => setCompanyName(e.target.value)}
                  placeholder="Official registered company name"
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
                  value={companyName}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  GSTIN (15 characters)
                </label>
                <input
                  maxLength={15}
                  onChange={(e) => setGstin(e.target.value.toUpperCase())}
                  placeholder="e.g. 27AAAAA0000A1Z5"
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
                  value={gstin}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  PAN Number
                </label>
                <input
                  maxLength={10}
                  onChange={(e) => setPan(e.target.value.toUpperCase())}
                  placeholder="e.g. AAAAA0000A"
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
                  value={pan}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Email Address
                </label>
                <input
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="billing@company.com"
                  style={{
                    background: 'var(--bg-surface)',
                    border: '1px solid var(--border-strong)',
                    borderRadius: 'var(--radius)',
                    color: 'var(--text-primary)',
                    height: 'var(--control-h)',
                    padding: '0 var(--space-2)',
                    width: '100%',
                  }}
                  type="email"
                  value={email}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Phone / Landline
                </label>
                <input
                  onChange={(e) => setPhone(e.target.value)}
                  placeholder="022-28001234"
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
                  value={phone}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Mobile Number
                </label>
                <input
                  onChange={(e) => setMobile(e.target.value)}
                  placeholder="+91 98200 12345"
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
                  value={mobile}
                />
              </div>
            </div>
          </div>

          <div className="document-card">
            <h2 style={{ marginBottom: 'var(--space-3)' }}>2. Billing & Shipping Address</h2>
            <div style={{ display: 'grid', gap: 'var(--space-4)', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))' }}>
              <div style={{ gridColumn: 'span 2' }}>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Billing Address Line 1
                </label>
                <input
                  onChange={(e) => setBillingAddressLine1(e.target.value)}
                  placeholder="Street, suite, floor, industrial area"
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
                  value={billingAddressLine1}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  City
                </label>
                <input
                  onChange={(e) => setBillingCity(e.target.value)}
                  placeholder="e.g. Mumbai"
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
                  value={billingCity}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  State
                </label>
                <input
                  onChange={(e) => setBillingState(e.target.value)}
                  placeholder="e.g. Maharashtra"
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
                  value={billingState}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  State Code (GST)
                </label>
                <input
                  maxLength={2}
                  onChange={(e) => setBillingStateCode(e.target.value)}
                  placeholder="e.g. 27"
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
                  value={billingStateCode}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Postal Code
                </label>
                <input
                  onChange={(e) => setBillingPostalCode(e.target.value)}
                  placeholder="e.g. 400001"
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
                  value={billingPostalCode}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Country
                </label>
                <input
                  onChange={(e) => setBillingCountry(e.target.value)}
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
                  value={billingCountry}
                />
              </div>
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
                <div style={{ gridColumn: 'span 2' }}>
                  <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                    Shipping Address Line 1
                  </label>
                  <input
                    onChange={(e) => setShippingAddressLine1(e.target.value)}
                    placeholder="Shipping destination address"
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
                    value={shippingAddressLine1}
                  />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                    Shipping City
                  </label>
                  <input
                    onChange={(e) => setShippingCity(e.target.value)}
                    placeholder="e.g. Pune"
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
                    value={shippingCity}
                  />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                    Shipping State
                  </label>
                  <input
                    onChange={(e) => setShippingState(e.target.value)}
                    placeholder="e.g. Maharashtra"
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
                    value={shippingState}
                  />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                    Shipping State Code
                  </label>
                  <input
                    maxLength={2}
                    onChange={(e) => setShippingStateCode(e.target.value)}
                    placeholder="e.g. 27"
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
                    value={shippingStateCode}
                  />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                    Shipping Postal Code
                  </label>
                  <input
                    onChange={(e) => setShippingPostalCode(e.target.value)}
                    placeholder="e.g. 411001"
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
                    value={shippingPostalCode}
                  />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                    Shipping Country
                  </label>
                  <input
                    onChange={(e) => setShippingCountry(e.target.value)}
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
                    value={shippingCountry}
                  />
                </div>
              </div>
            )}
          </div>

          <div className="document-card">
            <h2 style={{ marginBottom: 'var(--space-3)' }}>3. Credit & Commercial Terms</h2>
            <div style={{ display: 'grid', gap: 'var(--space-4)', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))' }}>
              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Credit Limit (₹)
                </label>
                <input
                  min="0"
                  onChange={(e) => setCreditLimit(parseFloat(e.target.value) || 0)}
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
                  value={creditLimit}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Payment Terms (Days)
                </label>
                <input
                  min="0"
                  onChange={(e) => setPaymentTermsDays(parseInt(e.target.value) || 0)}
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
                  value={paymentTermsDays}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Opening Balance (₹)
                </label>
                <input
                  onChange={(e) => setOpeningBalance(parseFloat(e.target.value) || 0)}
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
                  value={openingBalance}
                />
              </div>
            </div>

            <div style={{ marginTop: 'var(--space-4)' }}>
              <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                Internal Notes
              </label>
              <textarea
                onChange={(e) => setNotes(e.target.value)}
                placeholder="Internal customer background, credit remarks, etc."
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
