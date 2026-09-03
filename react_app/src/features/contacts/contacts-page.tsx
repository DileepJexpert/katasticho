import { useDeferredValue, useEffect, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { ChevronLeft, ChevronRight, Search, UsersRound } from 'lucide-react'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { getContactSummary, listContacts, type Contact, type ContactFilter } from '@/features/contacts/contacts-api'

type RoleTab = {
  label: string
  value: ContactFilter
  countKey: 'total' | 'customers' | 'vendors' | 'suppliers'
}

const roleTabs: RoleTab[] = [
  { label: 'All', value: 'ALL', countKey: 'total' },
  { label: 'Customers', value: 'CUSTOMER', countKey: 'customers' },
  { label: 'Vendors', value: 'VENDOR', countKey: 'vendors' },
  { label: 'Suppliers', value: 'SUPPLIER', countKey: 'suppliers' },
]

export function ContactsPage() {
  const [filter, setFilter] = useState<ContactFilter>('ALL')
  const [page, setPage] = useState(0)
  const [search, setSearch] = useState('')
  const deferredSearch = useDeferredValue(search)

  useEffect(() => {
    setPage(0)
  }, [filter, deferredSearch])

  const summary = useQuery({ queryKey: ['contacts', 'summary'], queryFn: getContactSummary })
  const contacts = useQuery({
    queryKey: ['contacts', { filter, page, search: deferredSearch }],
    queryFn: () => listContacts({ filter, page, search: deferredSearch }),
  })

  const contactPage = contacts.data
  const currentTab = roleTabs.find((tab) => tab.value === filter) ?? roleTabs[0]!
  const contactCount = summary.data?.[currentTab.countKey]

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Master data"
        title="Contacts"
        description="One party master, with customer, vendor, and procurement supplier roles visible in one place."
        actions={<StatusChip status="Read-only pilot" />}
      />

      <section className="list-panel" aria-label="Contact directory">
        <div className="list-toolbar">
          <div className="role-tabs" aria-label="Filter contacts by role" role="tablist">
            {roleTabs.map((tab) => (
              <button
                aria-selected={filter === tab.value}
                className={filter === tab.value ? 'role-tab role-tab--active' : 'role-tab'}
                key={tab.value}
                onClick={() => setFilter(tab.value)}
                role="tab"
                type="button"
              >
                {tab.label}
                <span>{summary.isLoading ? '...' : summary.data?.[tab.countKey] ?? 0}</span>
              </button>
            ))}
          </div>
          <label className="directory-search">
            <Search size={18} aria-hidden="true" />
            <span className="sr-only">Search contacts</span>
            <input
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Search name, company, phone or GSTIN"
              value={search}
            />
          </label>
        </div>

        {contacts.isError ? (
          <div className="directory-state directory-state--error" role="alert">
            <strong>Contacts could not be loaded.</strong>
            <p>Check your connection and permissions, then refresh the page.</p>
          </div>
        ) : contacts.isLoading ? (
          <div className="directory-state" aria-live="polite">Loading contacts...</div>
        ) : contactPage?.content.length ? (
          <>
            <DataTable caption="Contacts">
              <thead>
                <tr>
                  <th scope="col">Contact</th>
                  <th scope="col">Roles</th>
                  <th scope="col">Company and identifiers</th>
                  <th scope="col">Phone</th>
                  <th className="numeric-cell" scope="col">Receivable</th>
                  <th className="numeric-cell" scope="col">Payable</th>
                  <th scope="col">Status</th>
                </tr>
              </thead>
              <tbody>
                {contactPage.content.map((contact) => <ContactRow contact={contact} key={contact.id} />)}
              </tbody>
            </DataTable>
            <footer className="table-footer">
              <span>{contactPage.totalElements} contact{contactPage.totalElements === 1 ? '' : 's'} {deferredSearch ? 'matching this search' : `in ${currentTab.label.toLowerCase()}`}</span>
              <div className="pagination-actions">
                <button aria-label="Previous page" disabled={contactPage.number === 0} onClick={() => setPage((current) => current - 1)} type="button"><ChevronLeft size={16} /></button>
                <span>Page {contactPage.number + 1} of {Math.max(contactPage.totalPages, 1)}</span>
                <button aria-label="Next page" disabled={contactPage.number + 1 >= contactPage.totalPages} onClick={() => setPage((current) => current + 1)} type="button"><ChevronRight size={16} /></button>
              </div>
            </footer>
          </>
        ) : (
          <div className="directory-state">
            <UsersRound size={24} aria-hidden="true" />
            <strong>No {currentTab.label.toLowerCase()} found.</strong>
            <p>{deferredSearch ? 'Try a different name, phone, company, or GSTIN.' : 'Create or enable the required party role in the existing Flutter app during this pilot.'}</p>
          </div>
        )}
      </section>

      <p className="directory-note">Showing {contactCount ?? 0} {currentTab.label.toLowerCase()} across the organisation. Supplier is a procurement role; vendors without supplier enablement stay out of purchase pickers.</p>
    </section>
  )
}

function ContactRow({ contact }: { contact: Contact }) {
  const phone = contact.phone ?? contact.mobile ?? '--'
  const company = contact.companyName ?? contact.email ?? '--'
  const identifier = contact.gstin ? `GSTIN ${contact.gstin}` : contact.email ?? '--'

  return (
    <tr>
      <td>
        <div className="contact-primary"><span className="contact-avatar" aria-hidden="true">{contact.displayName.slice(0, 1).toUpperCase()}</span><strong>{contact.displayName}</strong></div>
      </td>
      <td><ContactRoles contact={contact} /></td>
      <td><div className="cell-stack"><span>{company}</span><code>{identifier}</code></div></td>
      <td className="cell-muted">{phone}</td>
      <td className="numeric-cell"><Money amount={contact.outstandingAr} /></td>
      <td className="numeric-cell"><Money amount={contact.outstandingAp} /></td>
      <td><StatusChip status={contact.active ? 'Active' : 'Inactive'} /></td>
    </tr>
  )
}

function ContactRoles({ contact }: { contact: Contact }) {
  const roles = contact.contactType === 'BOTH' ? ['Customer', 'Vendor'] : [contact.contactType === 'CUSTOMER' ? 'Customer' : 'Vendor']
  if (contact.supplierEnabled) roles.push('Supplier')

  return <div className="contact-roles">{roles.map((role) => <span className={`role-badge role-badge--${role.toLowerCase()}`} key={role}>{role}</span>)}</div>
}
