import { useDeferredValue, useEffect, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import {
  BarChart2,
  ChevronLeft,
  ChevronRight,
  FileBadge,
  FileSpreadsheet,
  Layers,
  Plus,
  Search,
} from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import { listBills, type PurchaseBill } from '@/features/bills/bills-api'

const billFilters = [
  { label: 'All', value: null },
  { label: 'Draft', value: 'DRAFT' },
  { label: 'Pending approval', value: 'PENDING_APPROVAL' },
  { label: 'Posted', value: 'POSTED' },
  { label: 'Partial', value: 'PARTIALLY_PAID' },
  { label: 'Paid', value: 'PAID' },
  { label: 'Overdue', value: 'OVERDUE' },
  { label: 'Void', value: 'VOID' },
] as const

type BillFilter = typeof billFilters[number]['value']

export function BillsPage() {
  const [filter, setFilter] = useState<BillFilter>(null)
  const [page, setPage] = useState(0)
  const [search, setSearch] = useState('')
  const deferredSearch = useDeferredValue(search)
  const navigate = useNavigate()

  useEffect(() => {
    setPage(0)
  }, [deferredSearch, filter])

  const bills = useQuery({
    queryKey: ['bills', { page, search: deferredSearch, status: filter }],
    queryFn: () => listBills({ page, search: deferredSearch, status: filter }),
  })
  const billPage = bills.data

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Purchases / Payables"
        title="Bills"
        description="Vendor bills, purchase invoicing, three-way match status, and accounts payable balances."
        actions={
          <div style={{ display: 'flex', gap: '8px' }}>
            <Button onClick={() => navigate(appRoutes.billCreate)} variant="primary">
              <Plus size={16} />
              New Bill
            </Button>
            <Button onClick={() => navigate('/three-way-match')} variant="secondary">
              <Layers size={16} />
              3-Way Match Inbox
            </Button>
            <Button onClick={() => navigate('/vendor-credits')} variant="secondary">
              <FileBadge size={16} />
              Vendor Credits
            </Button>
            <Button onClick={() => navigate('/reports/ap-aging')} variant="secondary">
              <BarChart2 size={16} />
              AP Aging
            </Button>
          </div>
        }
      />

      <section className="list-panel" aria-label="Vendor bill directory">
        <div className="list-toolbar">
          <div className="role-tabs" aria-label="Filter vendor bills by status" role="tablist">
            {billFilters.map((option) => (
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
            <span className="sr-only">Search vendor bills</span>
            <input
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Search bill or vendor"
              value={search}
            />
          </label>
        </div>

        {bills.isError ? (
          <div className="directory-state directory-state--error" role="alert">
            <strong>Vendor bills could not be loaded.</strong>
            <p>Check your connection and permissions, then refresh the page.</p>
          </div>
        ) : bills.isLoading ? (
          <div aria-live="polite" className="directory-state">Loading vendor bills...</div>
        ) : billPage?.content.length ? (
          <>
            <DataTable caption="Vendor bills">
              <thead>
                <tr>
                  <th scope="col">Bill</th>
                  <th scope="col">Vendor</th>
                  <th scope="col">Bill date</th>
                  <th scope="col">Due date</th>
                  <th scope="col">Status</th>
                  <th className="numeric-cell" scope="col">Total</th>
                  <th className="numeric-cell" scope="col">Paid</th>
                  <th className="numeric-cell" scope="col">Balance due</th>
                </tr>
              </thead>
              <tbody>
                {billPage.content.map((bill) => (
                  <BillRow
                    bill={bill}
                    key={bill.id}
                    onOpen={() => navigate(appRoutes.billDetail(bill.id))}
                  />
                ))}
              </tbody>
            </DataTable>
            <footer className="table-footer">
              <span>Showing {billPage.content.length} of {billPage.totalElements} bills · Page {billPage.page + 1} of {Math.max(billPage.totalPages, 1)}</span>
              <div className="pagination-actions">
                <Button
                  aria-label="Previous page"
                  disabled={page === 0}
                  onClick={() => setPage((current) => Math.max(0, current - 1))}
                  variant="secondary"
                >
                  <ChevronLeft aria-hidden="true" size={16} />
                </Button>
                <Button
                  aria-label="Next page"
                  disabled={billPage.last || page + 1 >= billPage.totalPages}
                  onClick={() => setPage((current) => current + 1)}
                  variant="secondary"
                >
                  <ChevronRight aria-hidden="true" size={16} />
                </Button>
              </div>
            </footer>
          </>
        ) : (
          <div className="directory-state">
            <FileSpreadsheet aria-hidden="true" size={24} />
            <strong>No vendor bills match your filters</strong>
            <p>Vendor bills recorded from purchase orders or manual entry will appear here.</p>
            <Button onClick={() => navigate(appRoutes.billCreate)} variant="primary">
              <Plus size={16} />
              New Bill
            </Button>
          </div>
        )}
      </section>
    </section>
  )
}

function BillRow({ bill, onOpen }: { bill: PurchaseBill; onOpen: () => void }) {
  const currency = bill.currency ?? 'INR'

  return (
    <tr>
      <td>
        <Button className="document-link" onClick={onOpen} variant="ghost">
          <code>{bill.billNumber}</code>
        </Button>
      </td>
      <td>
        <div className="cell-stack">
          <strong>{bill.vendorName ?? 'Unknown vendor'}</strong>
          {bill.vendorBillNumber ? (
            <span className="cell-muted">Ref: {bill.vendorBillNumber}</span>
          ) : null}
        </div>
      </td>
      <td>{formatDate(bill.billDate)}</td>
      <td>{formatDate(bill.dueDate)}</td>
      <td>
        <StatusChip status={formatStatusLabel(bill.status)} />
      </td>
      <td className="numeric-cell">
        <Money amount={bill.totalAmount} currency={currency} />
      </td>
      <td className="numeric-cell">
        <Money amount={bill.amountPaid} currency={currency} />
      </td>
      <td className="numeric-cell">
        <strong><Money amount={bill.balanceDue} currency={currency} /></strong>
      </td>
    </tr>
  )
}
