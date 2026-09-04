import { useQuery } from '@tanstack/react-query'
import { AlertTriangle, ArrowLeft } from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  DataTable,
  DocumentCard,
  Fact,
  FactList,
  Money,
  PageHeader,
  StatusChip,
} from '@/design-system'
import { getContact, type Contact } from '@/features/contacts/contacts-api'
import { formatDateTime, formatStatusLabel } from '@/shared/format/format'

export function ContactDetailPage() {
  const { contactId } = useParams()
  const navigate = useNavigate()
  const contactQuery = useQuery({
    queryKey: ['contacts', contactId],
    queryFn: () => getContact(contactId!),
    enabled: Boolean(contactId),
  })

  if (!contactId) return <ContactLoadError onBack={() => navigate(appRoutes.contacts)} />
  if (contactQuery.isLoading) {
    return <section className="workspace-page"><div aria-live="polite" className="directory-state">Loading contact details...</div></section>
  }
  if (contactQuery.isError || !contactQuery.data) return <ContactLoadError onBack={() => navigate(appRoutes.contacts)} />

  const contact = contactQuery.data
  const roles = contactRoles(contact)
  const currency = contact.currency ?? 'INR'
  const billingAddress = formatAddress(
    contact.billingAddressLine1,
    contact.billingAddressLine2,
    contact.billingCity,
    contact.billingState,
    contact.billingPostalCode,
    contact.billingCountry,
  )
  const shippingAddress = formatAddress(
    contact.shippingAddressLine1,
    contact.shippingAddressLine2,
    contact.shippingCity,
    contact.shippingState,
    contact.shippingPostalCode,
    contact.shippingCountry,
  )

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <div className="document-actions">
            <StatusChip status={contact.active ? 'Active' : 'Inactive'} />
            <Button onClick={() => navigate(appRoutes.contactStatement(contact.id))} variant="secondary">
              View statement
            </Button>
            <Button onClick={() => navigate(appRoutes.contacts)} variant="secondary">
              <ArrowLeft aria-hidden="true" size={16} />
              Back to contacts
            </Button>
          </div>
        }
        description={contact.companyName ?? contact.email ?? contact.phone ?? 'Contact master record'}
        eyebrow="Master data / Contacts"
        title={contact.displayName}
      />

      <div className="document-layout">
        <DocumentCard title="Contact profile">
          <FactList columns={2}>
            <Fact label="Roles" value={roles.join(' · ')} />
            <Fact label="Company" value={contact.companyName} />
            <Fact label="Email" value={contact.email} />
            <Fact label="Phone" value={contact.phone ?? contact.mobile} />
            <Fact label="Website" value={contact.website} />
            <Fact label="Created" value={formatDateTime(contact.createdAt)} />
          </FactList>
        </DocumentCard>

        <DocumentCard title="Balances" variant="summary">
          <Fact label="Receivable" value={<Money amount={contact.outstandingAr} currency={currency} />} />
          <Fact label="Payable" value={<Money amount={contact.outstandingAp} currency={currency} />} />
          <Fact label="Credit limit" value={<Money amount={contact.creditLimit} currency={currency} />} />
          <Fact label="Payment terms" value={contact.paymentTermsDays !== null && contact.paymentTermsDays !== undefined ? `${contact.paymentTermsDays} days` : '--'} />
        </DocumentCard>
      </div>

      <div className="document-layout">
        <DocumentCard title="Tax and compliance">
          <FactList columns={2}>
            <Fact label="GSTIN" mono value={contact.gstin} />
            <Fact label="PAN" mono value={contact.pan} />
            <Fact label="GST treatment" value={formatStatusLabel(contact.gstTreatment)} />
            <Fact label="Place of supply" value={contact.placeOfSupply} />
            <Fact label="TDS" value={contact.tdsApplicable ? 'Applicable' : 'Not applicable'} />
            <Fact label="TDS section / rate" value={contact.tdsApplicable ? [contact.tdsSection, contact.tdsRate !== null && contact.tdsRate !== undefined ? `${contact.tdsRate}%` : null].filter(Boolean).join(' · ') : '--'} />
            <Fact label="MSME" value={contact.msmeRegistered ? 'Registered' : 'Not registered'} />
            <Fact label="MSME registration" mono value={contact.msmeRegistrationNo} />
          </FactList>
        </DocumentCard>

        <DocumentCard title="Sales controls" variant="summary">
          <Fact label="Sales hold" value={contact.salesHold ? 'On hold' : 'Available for sales'} />
          <Fact label="Hold until" value={contact.salesHoldUntil} />
          <Fact label="Hold reason" value={contact.salesHoldReason} />
          <Fact label="Supplier role" value={contact.supplierEnabled ? 'Enabled for procurement' : 'Not enabled'} />
        </DocumentCard>
      </div>

      <div className="document-layout">
        <DocumentCard title="Addresses">
          <FactList columns={2}>
            <Fact label="Billing address" value={billingAddress} />
            <Fact label="Shipping address" value={shippingAddress} />
          </FactList>
        </DocumentCard>

        <DocumentCard title="Payment details" variant="summary">
          <Fact label="Bank" value={contact.bankName} />
          <Fact label="Account number" mono value={contact.bankAccountNo} />
          <Fact label="IFSC" mono value={contact.bankIfsc} />
          <Fact label="UPI ID" mono value={contact.upiId} />
        </DocumentCard>
      </div>

      <DocumentCard title="Contact persons" variant="lines">
        {contact.persons?.length ? (
          <DataTable caption="Contact persons">
            <thead>
              <tr>
                <th scope="col">Person</th>
                <th scope="col">Department / designation</th>
                <th scope="col">Email</th>
                <th scope="col">Phone</th>
                <th scope="col">Role</th>
              </tr>
            </thead>
            <tbody>
              {contact.persons.map((person) => (
                <tr key={person.id}>
                  <td>{[person.salutation, person.firstName, person.lastName].filter(Boolean).join(' ') || '--'}</td>
                  <td>{[person.department, person.designation].filter(Boolean).join(' · ') || '--'}</td>
                  <td>{person.email ?? '--'}</td>
                  <td>{person.phone ?? person.mobile ?? '--'}</td>
                  <td>{person.primary ? <StatusChip status="Primary" /> : '--'}</td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        ) : (
          <div className="directory-state">No individual contact persons are recorded.</div>
        )}
      </DocumentCard>

      {contact.notes && (
        <DocumentCard title="Internal notes" variant="notes">
          <div className="document-notes"><p>{contact.notes}</p></div>
        </DocumentCard>
      )}
    </section>
  )
}

function ContactLoadError({ onBack }: { onBack: () => void }) {
  return (
    <section className="workspace-page">
      <div className="directory-state directory-state--error" role="alert">
        <AlertTriangle aria-hidden="true" size={24} />
        <strong>Contact details could not be loaded.</strong>
        <p>The contact may have been removed, or your role may not be allowed to view it.</p>
        <Button onClick={onBack} variant="secondary">Back to contacts</Button>
      </div>
    </section>
  )
}

function contactRoles(contact: Contact) {
  const roles = contact.contactType === 'BOTH'
    ? ['Customer', 'Vendor']
    : [contact.contactType === 'CUSTOMER' ? 'Customer' : 'Vendor']
  if (contact.supplierEnabled) roles.push('Supplier')
  return roles
}

function formatAddress(...parts: Array<string | null | undefined>) {
  return parts
    .map((part) => part?.trim())
    .filter((part): part is string => Boolean(part))
    .join(', ') || '--'
}
