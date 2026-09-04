import { useDeferredValue, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Plus, ShoppingBag } from 'lucide-react'
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
        actions={
          <Button onClick={() => navigate(appRoutes.purchaseOrderCreate)} variant="primary">
            <Plus aria-hidden="true" size={16} />
            <span>New Purchase Order</span>
          </Button>
        }
      />

      <section className="list-panel" aria-label="Purchase order directory">
        <DirectoryToolbar ariaLabel="Filter purchase orders by status and search" stacked>
          <FilterTabs
            activeValue={selectedTab}
            ariaLabel="Filter by order status"
            items={statusTabs.map((t) => ({
              value: t.value,
              label: t.label,
              count: t.value === 'ALL'
                ? allOrders.length
                : allOrders.filter((o) => o.status?.toUpperCase() === t.value).length,
            }))}
            onChange={(val) => {
              setSelectedTab(val);
              setPage(0);
            }}
          />
          <SearchInput
            ariaLabel="Search purchase orders"
            onChange={(val) => {
              setSearch(val);
              setPage(0);
            }}
            onClear={() => {
              setSearch('');
              setPage(0);
            }}
            placeholder="Search by PO number, supplier name, notes..."
            value={search}
          />
          <p className="list-toolbar-note">
            Purchase orders track procurement commitments before receiving goods into inventory and matching vendor bills.
          </p>
        </DirectoryToolbar>

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
            <TablePagination
              filterDescription={search ? 'matching this search' : selectedTab !== 'ALL' ? `with ${selectedTab.toLowerCase()} status` : 'in this organisation'}
              isFiltered={Boolean(search || selectedTab !== 'ALL')}
              itemLabel="purchase order"
              onPageChange={(p) => setPage(p)}
              page={page}
              totalElements={filteredOrders.length}
              totalPages={totalPages}
            />
          </>
        ) : (
          <EmptyState
            action={
              <Button onClick={() => navigate(appRoutes.purchaseOrderCreate)} variant="primary">
                <Plus aria-hidden="true" size={16} />
                <span>New Purchase Order</span>
              </Button>
            }
            description="Supplier procurement purchase orders will appear here."
            icon={ShoppingBag}
            title="No purchase orders found"
          />
        )}
      </section>
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
