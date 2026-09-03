import { useDeferredValue, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { ChevronLeft, ChevronRight, Search, ShoppingBag } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import { listPurchaseOrders, type PurchaseOrder } from '@/features/purchase-orders/purchase-orders-api'

const statusTabs = [
  { label: 'All', value: 'ALL' },
  { label: 'Draft', value: 'DRAFT' },
  { label: 'Sent', value: 'SENT' },
  { label: 'Received', value: 'RECEIVED' },
  { label: 'Cancelled', value: 'CANCELLED' },
] as const

type StatusFilter = (typeof statusTabs)[number]['value']
const PAGE_SIZE = 25

export function PurchaseOrdersPage() {
  const [selectedTab, setSelectedTab] = useState<StatusFilter>('ALL')
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(0)
  const deferredSearch = useDeferredValue(search.trim().toLowerCase())
  const navigate = useNavigate()

  const orders = useQuery({
    queryKey: ['purchase-orders'],
    queryFn: listPurchaseOrders,
  })

  const allOrders = orders.data ?? []

  const filteredOrders = allOrders.filter((order) => {
    if (selectedTab !== 'ALL' && order.status?.toUpperCase() !== selectedTab) {
      return false
    }
    if (!deferredSearch) return true
    return (
      order.poNumber.toLowerCase().includes(deferredSearch) ||
      order.supplierName.toLowerCase().includes(deferredSearch) ||
      (order.notes ?? '').toLowerCase().includes(deferredSearch)
    )
  })

  const totalPages = Math.max(1, Math.ceil(filteredOrders.length / PAGE_SIZE))
  const paginatedOrders = filteredOrders.slice(page * PAGE_SIZE, (page + 1) * PAGE_SIZE)

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Purchases / Procurement"
        title="Purchase Orders"
        description="Supplier purchase commitments, expected delivery dates, and goods receipt tracking."
        actions={<StatusChip status="Read-only pilot" />}
      />

      <section className="list-panel" aria-label="Purchase order directory">
        <div className="list-toolbar list-toolbar--stacked">
          <div className="filter-chips" role="tablist" aria-label="Filter by order status">
            {statusTabs.map((tab) => {
              const count = tab.value === 'ALL'
                ? allOrders.length
                : allOrders.filter((o) => o.status?.toUpperCase() === tab.value).length

              return (
                <button
                  key={tab.value}
                  aria-selected={selectedTab === tab.value}
                  className={`filter-chip ${selectedTab === tab.value ? 'filter-chip--active' : ''}`}
                  onClick={() => {
                    setSelectedTab(tab.value)
                    setPage(0)
                  }}
                  role="tab"
                  type="button"
                >
                  <span>{tab.label}</span>
                  {orders.data ? <span className="filter-chip-count">{count}</span> : null}
                </button>
              )
            })}
          </div>

          <label className="directory-search">
            <Search aria-hidden="true" size={18} />
            <span className="sr-only">Search purchase orders</span>
            <input
              onChange={(event) => {
                setSearch(event.target.value)
                setPage(0)
              }}
              placeholder="Search by PO number, supplier name, notes..."
              value={search}
            />
          </label>
          <p className="list-toolbar-note">
            Purchase orders track procurement commitments before receiving goods into inventory and matching vendor bills.
          </p>
        </div>

        {orders.isError ? (
          <div className="directory-state directory-state--error" role="alert">
            <strong>Purchase orders could not be loaded.</strong>
            <p>Check your connection and permissions, then refresh the page.</p>
          </div>
        ) : orders.isLoading ? (
          <div aria-live="polite" className="directory-state">Loading purchase orders...</div>
        ) : paginatedOrders.length ? (
          <>
            <DataTable caption="Purchase orders">
              <thead>
                <tr>
                  <th scope="col">PO #</th>
                  <th scope="col">Supplier</th>
                  <th scope="col">Order date</th>
                  <th scope="col">Expected delivery</th>
                  <th scope="col">Lines</th>
                  <th className="numeric-cell" scope="col">Total amount</th>
                  <th scope="col">Status</th>
                </tr>
              </thead>
              <tbody>
                {paginatedOrders.map((order) => (
                  <PurchaseOrderRow
                    key={order.id}
                    onOpen={() => navigate(appRoutes.purchaseOrderDetail(order.id))}
                    order={order}
                  />
                ))}
              </tbody>
            </DataTable>
            <footer className="table-footer">
              <span>Showing {paginatedOrders.length} of {filteredOrders.length} orders · Page {page + 1} of {totalPages}</span>
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
                  disabled={page + 1 >= totalPages}
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
            <ShoppingBag aria-hidden="true" size={24} />
            <strong>No purchase orders found</strong>
            <p>Supplier procurement purchase orders will appear here.</p>
          </div>
        )}
      </section>

      <p className="directory-note">Creating purchase orders, generating GRNs from POs, and generating bills remain in Flutter during the parallel run.</p>
    </section>
  )
}

function PurchaseOrderRow({ order, onOpen }: { order: PurchaseOrder; onOpen: () => void }) {
  return (
    <tr>
      <td>
        <Button className="document-link" onClick={onOpen} variant="ghost">
          <code>{order.poNumber}</code>
        </Button>
      </td>
      <td>
        <strong>{order.supplierName}</strong>
      </td>
      <td>{formatDate(order.orderDate)}</td>
      <td>{order.expectedDeliveryDate ? formatDate(order.expectedDeliveryDate) : <span className="cell-muted">--</span>}</td>
      <td>{order.lines?.length ?? 0} items</td>
      <td className="numeric-cell">
        <Money amount={order.totalAmount} />
      </td>
      <td>
        <StatusChip status={formatStatusLabel(order.status)} />
      </td>
    </tr>
  )
}
