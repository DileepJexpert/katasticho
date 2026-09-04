import { useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, Save } from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  CheckboxInput,
  FormCard,
  FormField,
  FormGrid,
  NumberInput,
  PageHeader,
  SelectInput,
  TextAreaInput,
  TextInput,
} from '@/design-system'
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
          description="Contact roles, legal identity, GSTIN, and direct communication coordinates."
          stepNumber={1}
          title="General & Tax Details"
        >
          <FormGrid columns={3}>
            <FormField label="Contact Role" required>
              <SelectInput
                onChange={(e) => setContactType(e.target.value as 'CUSTOMER' | 'VENDOR' | 'BOTH')}
                options={[
                  { value: 'CUSTOMER', label: 'Customer (Sales & Receivables)' },
                  { value: 'VENDOR', label: 'Vendor (Purchases & Payables)' },
                  { value: 'BOTH', label: 'Both (Customer & Vendor)' },
                ]}
                required
                value={contactType}
              />
            </FormField>

            <FormField label="Display Name" required>
              <TextInput
                onChange={(e) => setDisplayName(e.target.value)}
                placeholder="e.g. Apex Health Corp"
                required
                value={displayName}
              />
            </FormField>

            <FormField label="Company / Legal Entity Name">
              <TextInput
                onChange={(e) => setCompanyName(e.target.value)}
                placeholder="Official registered company name"
                value={companyName}
              />
            </FormField>

            <FormField label="GSTIN (15 characters)">
              <TextInput
                maxLength={15}
                onChange={(e) => setGstin(e.target.value.toUpperCase())}
                placeholder="e.g. 27AAAAA0000A1Z5"
                value={gstin}
              />
            </FormField>

            <FormField label="PAN Number">
              <TextInput
                maxLength={10}
                onChange={(e) => setPan(e.target.value.toUpperCase())}
                placeholder="e.g. AAAAA0000A"
                value={pan}
              />
            </FormField>

            <FormField label="Email Address">
              <TextInput
                onChange={(e) => setEmail(e.target.value)}
                placeholder="billing@company.com"
                type="email"
                value={email}
              />
            </FormField>

            <FormField label="Phone / Landline">
              <TextInput
                onChange={(e) => setPhone(e.target.value)}
                placeholder="022-28001234"
                value={phone}
              />
            </FormField>

            <FormField label="Mobile Number">
              <TextInput
                onChange={(e) => setMobile(e.target.value)}
                placeholder="+91 98200 12345"
                value={mobile}
              />
            </FormField>
          </FormGrid>
        </FormCard>

        <FormCard
          description="Principal place of business and dispatch delivery coordinates."
          stepNumber={2}
          title="Billing & Shipping Address"
        >
          <FormGrid columns={3}>
            <div style={{ gridColumn: 'span 2' }}>
              <FormField label="Billing Address Line 1">
                <TextInput
                  onChange={(e) => setBillingAddressLine1(e.target.value)}
                  placeholder="Street, suite, floor, industrial area"
                  value={billingAddressLine1}
                />
              </FormField>
            </div>

            <FormField label="City">
              <TextInput
                onChange={(e) => setBillingCity(e.target.value)}
                placeholder="e.g. Mumbai"
                value={billingCity}
              />
            </FormField>

            <FormField label="State">
              <TextInput
                onChange={(e) => setBillingState(e.target.value)}
                placeholder="e.g. Maharashtra"
                value={billingState}
              />
            </FormField>

            <FormField label="State Code (GST)">
              <TextInput
                maxLength={2}
                onChange={(e) => setBillingStateCode(e.target.value)}
                placeholder="e.g. 27"
                value={billingStateCode}
              />
            </FormField>

            <FormField label="Postal Code">
              <TextInput
                onChange={(e) => setBillingPostalCode(e.target.value)}
                placeholder="e.g. 400001"
                value={billingPostalCode}
              />
            </FormField>

            <FormField label="Country">
              <TextInput
                onChange={(e) => setBillingCountry(e.target.value)}
                value={billingCountry}
              />
            </FormField>
          </FormGrid>

          <div style={{ marginTop: 'var(--space-4)' }}>
            <CheckboxInput
              checked={sameAsBilling}
              description="Shipping address is identical to billing address"
              onChange={(e) => setSameAsBilling(e.target.checked)}
              title="Same as Billing Address"
            />
          </div>

          {!sameAsBilling && (
            <div style={{ marginTop: 'var(--space-4)', paddingTop: 'var(--space-3)', borderTop: '1px dashed var(--color-border)' }}>
              <h4 style={{ fontSize: 'var(--text-sm)', marginBottom: 'var(--space-3)' }}>Shipping Address</h4>
              <FormGrid columns={3}>
                <div style={{ gridColumn: 'span 2' }}>
                  <FormField label="Shipping Address Line 1">
                    <TextInput
                      onChange={(e) => setShippingAddressLine1(e.target.value)}
                      placeholder="Shipping destination address"
                      value={shippingAddressLine1}
                    />
                  </FormField>
                </div>

                <FormField label="Shipping City">
                  <TextInput
                    onChange={(e) => setShippingCity(e.target.value)}
                    placeholder="e.g. Pune"
                    value={shippingCity}
                  />
                </FormField>

                <FormField label="Shipping State">
                  <TextInput
                    onChange={(e) => setShippingState(e.target.value)}
                    placeholder="e.g. Maharashtra"
                    value={shippingState}
                  />
                </FormField>

                <FormField label="Shipping State Code">
                  <TextInput
                    maxLength={2}
                    onChange={(e) => setShippingStateCode(e.target.value)}
                    placeholder="e.g. 27"
                    value={shippingStateCode}
                  />
                </FormField>

                <FormField label="Shipping Postal Code">
                  <TextInput
                    onChange={(e) => setShippingPostalCode(e.target.value)}
                    placeholder="e.g. 411001"
                    value={shippingPostalCode}
                  />
                </FormField>

                <FormField label="Shipping Country">
                  <TextInput
                    onChange={(e) => setShippingCountry(e.target.value)}
                    value={shippingCountry}
                  />
                </FormField>
              </FormGrid>
            </div>
          )}
        </FormCard>

        <FormCard
          description="Set credit policies, default payment terms, and opening receivables/payables."
          stepNumber={3}
          title="Credit & Commercial Terms"
        >
          <FormGrid columns={3}>
            <FormField label="Credit Limit">
              <NumberInput
                currencyPrefix="₹"
                min={0}
                onChange={(e) => setCreditLimit(parseFloat(e.target.value) || 0)}
                value={creditLimit}
              />
            </FormField>

            <FormField label="Payment Terms">
              <NumberInput
                min={0}
                onChange={(e) => setPaymentTermsDays(parseInt(e.target.value) || 0)}
                unitSuffix="Days"
                value={paymentTermsDays}
              />
            </FormField>

            <FormField label="Opening Balance">
              <NumberInput
                currencyPrefix="₹"
                onChange={(e) => setOpeningBalance(parseFloat(e.target.value) || 0)}
                value={openingBalance}
              />
            </FormField>
          </FormGrid>

          <div style={{ marginTop: 'var(--space-4)' }}>
            <FormField label="Internal Notes">
              <TextAreaInput
                onChange={(e) => setNotes(e.target.value)}
                placeholder="Internal customer background, credit remarks, etc."
                rows={2}
                value={notes}
              />
            </FormField>
          </div>
        </FormCard>

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
