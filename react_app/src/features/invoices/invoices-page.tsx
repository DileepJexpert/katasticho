import { useDeferredValue, useEffect, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { ChevronLeft, ChevronRight, FileText, Plus, Search } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import { listInvoices, type Invoice } from '@/features/invoices/invoices-api'

const invoiceFilters = [
  { label: 'All', value: null },
  { label: 'Draft', value: 'DRAFT' },
  { label: 'Sent', value: 'SENT' },
  { label: 'Partial', value: 'PARTIALLY_PAID' },
  { label: 'Paid', value: 'PAID' },
  { label: 'Overdue', value: 'OVERDUE' },
  { label: 'Cancelled', value: 'CANCELLED' },
] as const

type InvoiceFilter = typeof invoiceFilters[number]['value']

export function InvoicesPage() {
  const [filter, setFilter] = useState<InvoiceFilter>(null)
  const [page, setPage] = useState(0)
  const [search, setSearch] = useState('')
  const deferredSearch = useDeferredValue(search)
  const navigate = useNavigate()

  useEffect(() => {
    setPage(0)
  }, [deferredSearch, filter])

  const invoices = useQuery({
    queryKey: ['invoices', { page, search: deferredSearch, status: filter }],
    queryFn: () => listInvoices({ page, search: deferredSearch, status: filter }),
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
        <div className="list-toolbar">
          <div className="role-tabs" aria-label="Filter invoices by status" role="tablist">
            {invoiceFilters.map((option) => (
              <button
                aria-selected={filter === option.value}
                className={filter === option.value ? 'role-tab role-tab--active' : 'role-tab'}
                key={option.label}
                onClick={() => setFilter(option.value)}
                role="tab"
                type="button"
              >
                {option.label}
              </button>
            ))}
          </div>
          <label className="directory-search">
            <Search aria-hidden="true" size={18} />
            <span className="sr-only">Search invoices</span>
            <input onChange={(event) => setSearch(event.target.value)} placeholder="Search invoice or customer" value={search} />
          </label>
        </div>

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
            <footer className="table-footer">
              <span>{invoicePage.totalElements} invoice{invoicePage.totalElements === 1 ? '' : 's'} {deferredSearch ? 'matching this search' : filter ? `with ${formatStatusLabel(filter).toLowerCase()} status` : 'in this organisation'}</span>
              <div className="pagination-actions">
                <button aria-label="Previous page" disabled={invoicePage.page === 0} onClick={() => setPage((current) => current - 1)} type="button"><ChevronLeft aria-hidden="true" size={16} /></button>
                <span>Page {invoicePage.page + 1} of {Math.max(invoicePage.totalPages, 1)}</span>
                <button aria-label="Next page" disabled={invoicePage.last} onClick={() => setPage((current) => current + 1)} type="button"><ChevronRight aria-hidden="true" size={16} /></button>
              </div>
            </footer>
          </>
        ) : (
          <div className="directory-state">
            <FileText aria-hidden="true" size={24} />
            <strong>No {filter ? formatStatusLabel(filter).toLowerCase() : ''} invoices found.</strong>
            <p>{deferredSearch ? 'Try a different invoice number or customer name.' : 'Create your first invoice to bill customers and manage receivables.'}</p>
            <Button onClick={() => navigate(appRoutes.invoiceCreate)} variant="primary">
              <Plus aria-hidden="true" size={16} />
              <span>New Invoice</span>
            </Button>
          </div>
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
