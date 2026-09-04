import { useDeferredValue, useEffect, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { FileText, Plus } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  DataTable,
  DirectoryToolbar,
  EmptyState,
  FilterTabs,
  Money,
  PageHeader,
  SearchInput,
  StatusChip,
  TablePagination,
} from '@/design-system'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import { listInvoices, type Invoice } from '@/features/invoices/invoices-api'

const invoiceFilters = [
  { label: 'All', value: '' },
  { label: 'Draft', value: 'DRAFT' },
  { label: 'Sent', value: 'SENT' },
  { label: 'Partial', value: 'PARTIALLY_PAID' },
  { label: 'Paid', value: 'PAID' },
  { label: 'Overdue', value: 'OVERDUE' },
  { label: 'Cancelled', value: 'CANCELLED' },
] as const

type InvoiceFilter = typeof invoiceFilters[number]['value']

export function InvoicesPage() {
  const [filter, setFilter] = useState<InvoiceFilter>('')
  const [page, setPage] = useState(0)
  const [search, setSearch] = useState('')
  const deferredSearch = useDeferredValue(search)
  const navigate = useNavigate()

  useEffect(() => {
    setPage(0)
  }, [deferredSearch, filter])

  const effectiveStatus = filter === '' ? null : filter
  const invoices = useQuery({
    queryKey: ['invoices', { page, search: deferredSearch, status: effectiveStatus }],
    queryFn: () => listInvoices({ page, search: deferredSearch, status: effectiveStatus }),
  })
  const invoicePage = invoices.data

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Sales / Receivables"
        title="Invoices"
        description="Customer invoices with server-returned payment progress and balance due."
        actions={
          <Button onClick={() => navigate(appRoutes.invoiceCreate)} variant="primary">
            <Plus aria-hidden="true" size={16} />
            <span>New Invoice</span>
          </Button>
        }
      />

      <section className="list-panel" aria-label="Invoice directory">
        <DirectoryToolbar ariaLabel="Filter invoices by status and search">
          <FilterTabs
            activeValue={filter}
            ariaLabel="Filter invoices by status"
            items={invoiceFilters}
            onChange={(val) => setFilter(val as InvoiceFilter)}
          />
          <SearchInput
            ariaLabel="Search invoices"
            onChange={setSearch}
            onClear={() => setSearch('')}
            placeholder="Search invoice or customer"
            value={search}
          />
        </DirectoryToolbar>

        {invoices.isError ? (
          <div className="directory-state directory-state--error" role="alert">
            <strong>Invoices could not be loaded.</strong>
            <p>Check your connection and permissions, then refresh the page.</p>
          </div>
        ) : invoices.isLoading ? (
          <div aria-live="polite" className="directory-state">Loading invoices...</div>
        ) : invoicePage?.content.length ? (
          <>
            <DataTable caption="Invoices">
              <thead>
                <tr>
                  <th scope="col">Invoice</th>
                  <th scope="col">Customer</th>
                  <th scope="col">Invoiced</th>
                  <th scope="col">Due</th>
                  <th scope="col">Status</th>
                  <th className="numeric-cell" scope="col">Total</th>
                  <th className="numeric-cell" scope="col">Paid</th>
                  <th className="numeric-cell" scope="col">Balance due</th>
                </tr>
              </thead>
              <tbody>
                {invoicePage.content.map((invoice) => <InvoiceRow invoice={invoice} key={invoice.id} onOpen={() => navigate(appRoutes.invoiceDetail(invoice.id))} />)}
              </tbody>
            </DataTable>
            <TablePagination
              filterDescription={
                deferredSearch
                  ? 'matching this search'
                  : filter
                    ? `with ${formatStatusLabel(filter).toLowerCase()} status`
                    : 'in this organisation'
              }
              isFiltered={Boolean(deferredSearch || filter)}
              itemLabel="invoice"
              onPageChange={setPage}
              page={invoicePage.page}
              totalElements={invoicePage.totalElements}
              totalPages={invoicePage.totalPages}
            />
          </>
        ) : (
          <EmptyState
            action={
              <Button onClick={() => navigate(appRoutes.invoiceCreate)} variant="primary">
                <Plus aria-hidden="true" size={16} />
                <span>New Invoice</span>
              </Button>
            }
            description={
              deferredSearch
                ? 'Try a different invoice number or customer name.'
                : 'Create your first invoice to bill customers and manage receivables.'
            }
            icon={FileText}
            title={`No ${filter ? formatStatusLabel(filter).toLowerCase() : ''} invoices found.`}
          />
        )}
      </section>
    </section>
  )
}

function InvoiceRow({ invoice, onOpen }: { invoice: Invoice; onOpen: () => void }) {
  const currency = invoice.currency ?? 'INR'

  return (
    <tr>
      <td><div className="cell-stack"><Button className="document-link" onClick={onOpen} variant="ghost"><code>{invoice.invoiceNumber}</code></Button></div></td>
      <td><strong>{invoice.contactName ?? '--'}</strong></td>
      <td>{formatDate(invoice.invoiceDate)}</td>
      <td>{formatDate(invoice.dueDate)}</td>
      <td><StatusChip status={formatStatusLabel(invoice.status)} /></td>
      <td className="numeric-cell"><Money amount={invoice.totalAmount} currency={currency} /></td>
      <td className="numeric-cell"><Money amount={invoice.amountPaid} currency={currency} /></td>
      <td className="numeric-cell"><Money amount={invoice.balanceDue} currency={currency} /></td>
    </tr>
  )
}
