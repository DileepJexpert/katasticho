import { useDeferredValue, useEffect, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Plus, UsersRound } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
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
  const navigate = useNavigate()

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
        actions={
          <Button onClick={() => navigate(appRoutes.contactCreate)} variant="primary">
            <Plus aria-hidden="true" size={16} />
            <span>New Contact</span>
          </Button>
        }
      />

      <section className="list-panel" aria-label="Contact directory">
        <DirectoryToolbar ariaLabel="Filter contacts by role and search">
          <FilterTabs
            activeValue={filter}
            ariaLabel="Filter contacts by role"
            items={roleTabs.map((t) => ({
              value: t.value,
              label: t.label,
              count: summary.isLoading ? undefined : (summary.data?.[t.countKey] ?? 0),
            }))}
            onChange={(val) => setFilter(val as ContactRoleFilter)}
          />
          <SearchInput
            ariaLabel="Search contacts"
            onChange={setSearch}
            onClear={() => setSearch('')}
            placeholder="Search name, company, phone or GSTIN"
            value={search}
          />
        </DirectoryToolbar>

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
            <TablePagination
              filterDescription={deferredSearch ? 'matching this search' : `in ${currentTab.label.toLowerCase()}`}
              isFiltered={Boolean(deferredSearch || filter !== 'ALL')}
              itemLabel="contact"
              onPageChange={(p) => setPage(p)}
              page={contactPage.number}
              totalElements={contactPage.totalElements}
              totalPages={contactPage.totalPages}
            />
          </>
        ) : (
          <EmptyState
            action={
              <Button onClick={() => navigate(appRoutes.contactCreate)} variant="primary">
                <Plus aria-hidden="true" size={16} />
                <span>New Contact</span>
              </Button>
            }
            description={deferredSearch ? 'Try a different name, phone, company, or GSTIN.' : 'Add your first contact to get started.'}
            icon={UsersRound}
            title={`No ${currentTab.label.toLowerCase()} found.`}
          />
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
