import { useState, useMemo } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import {
  ArrowLeftRight,
  ArrowRight,
  CheckCircle2,
  Clock,
  Package,
  Plus,
  RefreshCw,
  Search,
  Truck,
} from 'lucide-react'
import {
  Button,
  DataTable,
  DocumentCard,
  FilterTabs,
  PageHeader,
  Quantity,
  StatusChip,
} from '@/design-system'
import {
  listTransferOrders,
  type TransferOrder,
} from '@/features/inventory/transfer-orders-api'

type StatusFilter = 'ALL' | 'DRAFT' | 'SHIPPED' | 'RECEIVED' | 'CANCELLED'

export function TransferOrdersPage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const [searchTerm, setSearchTerm] = useState('')
  const [statusFilter, setStatusFilter] = useState<StatusFilter>('ALL')

  const { data, isLoading } = useQuery({
    queryKey: ['inventory', 'transfer-orders'],
    queryFn: () => listTransferOrders(0, 100),
  })

  function handleRefresh() {
    queryClient.invalidateQueries({ queryKey: ['inventory', 'transfer-orders'] })
  }

  const transferOrders = useMemo(() => data?.content ?? [], [data])

  const filteredOrders = useMemo(() => {
    return transferOrders.filter((order: TransferOrder) => {
      if (statusFilter !== 'ALL' && order.status !== statusFilter) {
        return false
      }
      if (searchTerm.trim()) {
        const term = searchTerm.trim().toLowerCase()
        const numMatch = order.transferNumber.toLowerCase().includes(term)
        const fromMatch = order.fromWarehouseName.toLowerCase().includes(term)
        const toMatch = order.toWarehouseName.toLowerCase().includes(term)
        if (!numMatch && !fromMatch && !toMatch) return false
      }
      return true
    })
  }, [transferOrders, statusFilter, searchTerm])

  // Count summaries
  const draftCount = transferOrders.filter((o) => o.status === 'DRAFT').length
  const shippedCount = transferOrders.filter((o) => o.status === 'SHIPPED').length
  const receivedCount = transferOrders.filter((o) => o.status === 'RECEIVED').length

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <div className="flex items-center gap-2">
            <Button
              aria-label="Refresh transfer orders"
              onClick={handleRefresh}
              variant="secondary"
            >
              <RefreshCw size={15} aria-hidden="true" />
              <span>Refresh</span>
            </Button>
            <Button onClick={() => navigate('/transfer-orders/new')} variant="primary">
              <Plus size={15} aria-hidden="true" />
              <span>New Transfer</span>
            </Button>
          </div>
        }
        eyebrow="Inventory & Logistics • Movement Control"
        title="Stock Transfer Orders"
        description="Multi-warehouse inventory transfers, in-transit dispatches, and receiving confirmations."
      />

      <div className="dashboard-workspace">
        {/* ── Metric Summary Strip ── */}
        <section aria-label="Transfer order status metrics" className="metric-grid">
          <article className="metric-card metric-card--brand">
            <span className="metric-icon">
              <ArrowLeftRight size={20} aria-hidden="true" />
            </span>
            <p>Total Transfers</p>
            <strong className="metric-value">
              <Quantity value={transferOrders.length} />
            </strong>
            <small>All historical inter-branch moves</small>
          </article>

          <article className="metric-card metric-card--warning">
            <span className="metric-icon">
              <Clock size={20} aria-hidden="true" />
            </span>
            <p>Pending Dispatch</p>
            <strong className="metric-value">
              <Quantity value={draftCount} />
            </strong>
            <small>Orders in draft awaiting shipment</small>
          </article>

          <article className="metric-card metric-card--brand">
            <span className="metric-icon">
              <Truck size={20} aria-hidden="true" />
            </span>
            <p>In Transit</p>
            <strong className="metric-value">
              <Quantity value={shippedCount} />
            </strong>
            <small>Dispatched, awaiting destination receipt</small>
          </article>

          <article className="metric-card metric-card--positive">
            <span className="metric-icon">
              <CheckCircle2 size={20} aria-hidden="true" />
            </span>
            <p>Completed Receipts</p>
            <strong className="metric-value">
              <Quantity value={receivedCount} />
            </strong>
            <small>Successfully received & stock updated</small>
          </article>
        </section>

        {/* ── Filter & Search Toolbar ── */}
        <section aria-label="Transfer order filters" className="dashboard-control-bar">
          <div className="dashboard-filter-group">
            <div className="search-input-wrapper">
              <Search size={14} className="text-muted flex-none ml-2" aria-hidden="true" />
              <input
                aria-label="Search by transfer number or warehouse"
                className="dashboard-branch-select"
                placeholder="Search transfer # or warehouse..."
                style={{ width: '250px', paddingLeft: '28px' }}
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
              />
            </div>

            <FilterTabs
              activeValue={statusFilter}
              ariaLabel="Transfer order status filter"
              items={[
                { value: 'ALL', label: 'All Transfers' },
                { value: 'DRAFT', label: 'Draft' },
                { value: 'SHIPPED', label: 'In Transit' },
                { value: 'RECEIVED', label: 'Received' },
                { value: 'CANCELLED', label: 'Cancelled' },
              ]}
              onChange={(val) => setStatusFilter(val as StatusFilter)}
            />
          </div>

          <div className="dashboard-filter-group">
            <StatusChip status="Multi-Branch Transit" />
          </div>
        </section>

        {/* ── Transfer Orders Data Table ── */}
        <DocumentCard title="Transfer Order Register">
          {isLoading ? (
            <div className="p-4 text-secondary text-sm">Loading transfer orders...</div>
          ) : filteredOrders.length > 0 ? (
            <DataTable caption="Directory of stock transfer orders">
              <thead>
                <tr>
                  <th scope="col">Transfer #</th>
                  <th scope="col">Date</th>
                  <th scope="col">Source (From)</th>
                  <th scope="col">Destination (To)</th>
                  <th className="numeric-cell" scope="col">Items</th>
                  <th scope="col">Status</th>
                  <th className="numeric-cell" scope="col">Actions</th>
                </tr>
              </thead>
              <tbody>
                {filteredOrders.map((order) => (
                  <tr key={order.id}>
                    <td>
                      <Link
                        to={`/transfer-orders/${order.id}`}
                        className="font-mono font-semibold text-brand hover:underline"
                      >
                        {order.transferNumber}
                      </Link>
                    </td>
                    <td>
                      <span className="font-mono text-xs">{order.transferDate}</span>
                    </td>
                    <td>
                      <strong>{order.fromWarehouseName}</strong>
                    </td>
                    <td>
                      <div className="flex items-center gap-1.5">
                        <ArrowRight size={13} className="text-muted flex-none" />
                        <strong>{order.toWarehouseName}</strong>
                      </div>
                    </td>
                    <td className="numeric-cell">
                      <span className="font-mono">{order.lineCount} item(s)</span>
                    </td>
                    <td>
                      <StatusChip status={order.status} />
                    </td>
                    <td className="numeric-cell">
                      <Button
                        onClick={() => navigate(`/transfer-orders/${order.id}`)}
                        variant="secondary"
                      >
                        <span>View</span>
                      </Button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          ) : (
            <div className="p-4">
              <div className="compact-zero-state">
                <Package size={16} className="text-muted flex-none" />
                <span>
                  {searchTerm || statusFilter !== 'ALL'
                    ? 'No transfer orders match the applied filters.'
                    : 'No stock transfer orders registered yet. Click "New Transfer" to start one.'}
                </span>
              </div>
            </div>
          )}
        </DocumentCard>
      </div>
    </section>
  )
}
