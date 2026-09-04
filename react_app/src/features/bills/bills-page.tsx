import { useDeferredValue, useEffect, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import {
  BarChart2,
  FileBadge,
  FileSpreadsheet,
  Layers,
  Plus,
} from 'lucide-react'
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
  const [filter, setFilter] = useState<BillFilter>('')
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
        <DirectoryToolbar ariaLabel="Filter vendor bills by status and search">
          <FilterTabs
            activeValue={filter}
            ariaLabel="Filter vendor bills by status"
            items={billFilters}
            onChange={(val) => setFilter(val as BillFilter)}
          />
          <SearchInput
            ariaLabel="Search vendor bills"
            onChange={setSearch}
            onClear={() => setSearch('')}
            placeholder="Search bill or vendor"
            value={search}
          />
        </DirectoryToolbar>

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
            <TablePagination
              filterDescription={deferredSearch ? 'matching this search' : filter ? `with ${formatStatusLabel(filter).toLowerCase()} status` : 'in this organisation'}
              isFiltered={Boolean(deferredSearch || filter)}
              itemLabel="bill"
              onPageChange={(p) => setPage(p)}
              page={billPage.page}
              totalElements={billPage.totalElements}
              totalPages={billPage.totalPages}
            />
          </>
        ) : (
          <EmptyState
            action={
              <Button onClick={() => navigate(appRoutes.billCreate)} variant="primary">
                <Plus size={16} />
                New Bill
              </Button>
            }
            description={deferredSearch ? 'Try a different bill number or vendor keyword.' : 'Vendor bills recorded from purchase orders or manual entry will appear here.'}
            icon={FileSpreadsheet}
            title="No vendor bills match your filters"
          />
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
