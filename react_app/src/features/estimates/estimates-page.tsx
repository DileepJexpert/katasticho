import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Link } from 'react-router-dom'
import { Button, DataTable, DirectoryToolbar, EntityPicker, FilterTabs, Money, PageHeader, SearchInput, StatusChip, TablePagination } from '@/design-system'
import { listContacts, type Contact } from '@/features/contacts/contacts-api'
import { useSessionStore } from '@/shared/session/session-store'
import { formatDate } from '@/shared/format/format'
import { listEstimates } from './estimates-api'
import { estimatePermissions } from './estimate-form-model'

async function searchCustomers(search: string) { return (await listContacts({ filter: 'CUSTOMER', search, page: 0, size: 25 })).content }

export function EstimatesPage() {
  const orgId = useSessionStore((state) => state.user?.orgId)
  return <EstimatesDirectory key={orgId} />
}

function EstimatesDirectory() {
  const user = useSessionStore((state) => state.user)
  const [page, setPage] = useState(0)
  const [status, setStatus] = useState('all')
  const [customer, setCustomer] = useState<Contact | null>(null)
  const [search, setSearch] = useState('')
  const query = useQuery({
    queryKey: ['estimates-list', user?.orgId, status, customer?.id, page],
    queryFn: () => listEstimates(status, customer?.id, page, 25),
    enabled: Boolean(user?.orgId),
  })
  const term = search.trim().toLowerCase()
  const rows = (query.data?.content ?? []).filter((estimate) => [estimate.estimateNumber, estimate.contactName, estimate.referenceNumber].some((value) => value?.toLowerCase().includes(term)))
  return <section className="workspace-page">
    <PageHeader eyebrow="Sales / Quotations" title="Estimates & quotations" description="Prepare proposals, record customer decisions, and review the document history. Estimates do not post to the ledger."
      actions={estimatePermissions(user?.role).write ? <Link className="button button--primary" to="/estimates/new">New estimate</Link> : undefined} />
    <DirectoryToolbar ariaLabel="Estimate filters">
      <FilterTabs ariaLabel="Estimate status" activeValue={status} items={[
        { value: 'all', label: 'All statuses' }, { value: 'DRAFT', label: 'Draft' }, { value: 'SENT', label: 'Sent' },
        { value: 'ACCEPTED', label: 'Accepted' }, { value: 'DECLINED', label: 'Declined' },
        { value: 'INVOICED', label: 'Invoiced' }, { value: 'EXPIRED', label: 'Expired' },
      ]} onChange={(value) => { setStatus(value); setCustomer(null); setPage(0) }} />
      <EntityPicker<Contact> ariaLabel="Filter estimates by customer" value={customer?.id ?? null} selectedEntity={customer} onSearch={searchCustomers} onChange={(_id, entry) => { setCustomer(entry ?? null); setStatus('all'); setPage(0) }} getOptionId={(entry) => entry.id} getOptionLabel={(entry) => entry.displayName} getOptionDescription={(entry) => [entry.companyName, entry.phone, entry.gstin].filter(Boolean).join(' / ')} placeholder="All customers" />
      <SearchInput ariaLabel="Search current estimate page" placeholder="Search this page" value={search} onChange={setSearch} onClear={() => setSearch('')} />
    </DirectoryToolbar>
    <p className="cell-muted">Customer and status filters are alternatives in the existing API. Keyword search filters only the current page; use the customer picker to find a customer across pages.</p>
    {query.isPending ? <div className="directory-state" role="status">Loading estimates...</div>
      : query.isError ? <div className="directory-state directory-state--error" role="alert">{query.error.message}<Button variant="secondary" onClick={() => void query.refetch()}>Retry estimates</Button></div>
      : <>
        <DataTable caption="Estimates and quotations"><thead><tr><th>Estimate</th><th>Customer</th><th>Date</th><th>Valid until</th><th>Status</th><th className="numeric-cell">Total</th><th>Invoice</th></tr></thead>
          <tbody>{rows.map((estimate) => <tr key={estimate.id}>
            <td><div className="cell-stack"><Link className="table-row-link table-code" to={`/estimates/${estimate.id}`}>{estimate.estimateNumber}</Link>{estimate.referenceNumber && <span className="cell-muted">{estimate.referenceNumber}</span>}</div></td>
            <td>{estimate.contactName}</td><td>{formatDate(estimate.estimateDate)}</td><td>{formatDate(estimate.expiryDate)}</td><td><StatusChip status={estimate.status} /></td>
            <td className="numeric-cell"><Money amount={estimate.total} currency={estimate.currency} /></td>
            <td>{estimate.convertedToInvoiceId ? <Link className="table-row-link" to={`/invoices/${estimate.convertedToInvoiceId}`}>View invoice</Link> : '--'}</td>
          </tr>)}</tbody>
        </DataTable>
        {!rows.length && <div className="directory-state">{search ? 'No matches on this page. Clear the keyword or try another page.' : 'No estimates match this filter.'}</div>}
        <TablePagination page={page} totalPages={query.data?.totalPages ?? 0} totalElements={query.data?.totalElements ?? 0} onPageChange={setPage} itemLabel="estimate" filterDescription={customer ? 'for this customer (all statuses)' : status !== 'all' ? `with status ${status}` : undefined} />
      </>}
  </section>
}
