import { useState, useMemo } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import {
  AlertTriangle,
  Boxes,
  CheckCircle2,
  Coins,
  Layers,
  Package,
  RefreshCw,
  Search,
  ShieldCheck,
  TrendingDown,
} from 'lucide-react'
import {
  Button,
  DataTable,
  DocumentCard,
  FilterTabs,
  Money,
  PageHeader,
  Quantity,
  StatusChip,
} from '@/design-system'
import {
  getStockSummary,
  getFifoValuation,
  getLowStockAlert,
  type StockSummaryItem,
} from '@/features/inventory/stock-summary-api'

type StatusFilter = 'all' | 'low_stock' | 'out_of_stock' | 'in_stock'
type ValuationMethod = 'weighted_average' | 'fifo'

export function StockSummaryPage() {
  const queryClient = useQueryClient()

  const [searchTerm, setSearchTerm] = useState('')
  const [statusFilter, setStatusFilter] = useState<StatusFilter>('all')
  const [valuationMethod, setValuationMethod] = useState<ValuationMethod>('weighted_average')

  const summaryQuery = useQuery({
    queryKey: ['inventory', 'stock-summary'],
    queryFn: () => getStockSummary(),
  })

  const lowStockQuery = useQuery({
    queryKey: ['inventory', 'low-stock-alert'],
    queryFn: () => getLowStockAlert(),
  })

  const fifoQuery = useQuery({
    queryKey: ['inventory', 'fifo-valuation'],
    queryFn: () => getFifoValuation(),
    enabled: valuationMethod === 'fifo',
  })

  function handleRefresh() {
    queryClient.invalidateQueries({ queryKey: ['inventory', 'stock-summary'] })
    queryClient.invalidateQueries({ queryKey: ['inventory', 'low-stock-alert'] })
    queryClient.invalidateQueries({ queryKey: ['inventory', 'fifo-valuation'] })
  }

  const report = summaryQuery.data
  const lowStockAlert = lowStockQuery.data
  const fifoReport = fifoQuery.data

  const items = useMemo(() => report?.items ?? [], [report])

  // Filter items by status and search keyword
  const filteredItems = useMemo(() => {
    return items.filter((item: StockSummaryItem) => {
      // Status filter
      if (statusFilter === 'low_stock') {
        const isLow = Number(item.quantityOnHand) <= Number(item.reorderLevel) && Number(item.reorderLevel) > 0
        if (!isLow) return false
      } else if (statusFilter === 'out_of_stock') {
        if (Number(item.quantityOnHand) > 0) return false
      } else if (statusFilter === 'in_stock') {
        if (Number(item.quantityOnHand) <= 0) return false
      }

      // Keyword search
      if (searchTerm.trim()) {
        const term = searchTerm.trim().toLowerCase()
        const nameMatch = item.itemName.toLowerCase().includes(term)
        const skuMatch = item.sku.toLowerCase().includes(term)
        if (!nameMatch && !skuMatch) return false
      }

      return true
    })
  }, [items, statusFilter, searchTerm])

  // Aggregate stats
  const totalUnits = useMemo(() => {
    return items.reduce((acc, item) => acc + Number(item.quantityOnHand || 0), 0)
  }, [items])

  const totalValue = report?.totalInventoryValue ?? items.reduce((acc, item) => acc + Number(item.inventoryValue || 0), 0)
  const lowStockCount = report?.lowStockCount ?? items.filter((i) => Number(i.quantityOnHand) <= Number(i.reorderLevel) && Number(i.reorderLevel) > 0).length
  const outOfStockCount = report?.outOfStockCount ?? items.filter((i) => Number(i.quantityOnHand) <= 0).length

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <div className="flex items-center gap-2">
            <Button
              aria-label="Refresh stock summary data"
              onClick={handleRefresh}
              variant="secondary"
            >
              <RefreshCw size={15} aria-hidden="true" />
              <span>Refresh</span>
            </Button>
            <StatusChip status="Live Ledger" />
          </div>
        }
        eyebrow="Inventory & Logistics • Live Stock Control"
        title="Stock Summary & Valuation"
        description="Live on-hand balances, valuation basis (FIFO lots vs Weighted Average cost), and low-stock reorder alerts."
      />

      <div className="dashboard-workspace">
        {/* ── Summary KPI Cards ── */}
        <section aria-label="Inventory valuation metrics" className="metric-grid">
          <article className="metric-card metric-card--brand">
            <span className="metric-icon">
              <Coins size={20} aria-hidden="true" />
            </span>
            <p>Total Inventory Valuation</p>
            <strong className="metric-value">
              <Money amount={totalValue} currency="INR" />
            </strong>
            <small>Valuation basis: {valuationMethod === 'fifo' ? 'FIFO Cost Lots' : 'Weighted Average Cost'}</small>
          </article>

          <article className="metric-card metric-card--positive">
            <span className="metric-icon">
              <Boxes size={20} aria-hidden="true" />
            </span>
            <p>Total Units on Hand</p>
            <strong className="metric-value">
              <Quantity value={totalUnits} />
            </strong>
            <small>{items.length} trackable SKUs cataloged</small>
          </article>

          <article className="metric-card metric-card--warning">
            <span className="metric-icon">
              <AlertTriangle size={20} aria-hidden="true" />
            </span>
            <p>Low Stock Warnings</p>
            <strong className="metric-value">
              <Quantity value={lowStockCount} />
            </strong>
            <small>Below configured reorder threshold</small>
          </article>

          <article className="metric-card metric-card--neutral">
            <span className="metric-icon">
              <TrendingDown size={20} aria-hidden="true" />
            </span>
            <p>Out of Stock SKUs</p>
            <strong className="metric-value">
              <Quantity value={outOfStockCount} />
            </strong>
            <small>Immediate replenishment required</small>
          </article>
        </section>

        {/* ── Low-Stock Deficit Alert Banner ── */}
        {lowStockAlert && lowStockAlert.itemCount > 0 && (
          <DocumentCard
            headerAction={
              <StatusChip status={lowStockAlert.itemCount > 0 ? 'Deficit Alert' : 'Stocked'} />
            }
            title="Replenishment & Deficit Advisory"
          >
            <div className="p-4 flex flex-col gap-3">
              <div className="flex items-center justify-between text-sm">
                <span className="text-secondary">
                  <strong>{lowStockAlert.itemCount} item(s)</strong> are currently short of safe buffer levels.
                </span>
                <span>
                  Estimated replenishment outlay:{' '}
                  <strong>
                    <Money amount={lowStockAlert.estimatedPurchaseCost} currency="INR" />
                  </strong>
                </span>
              </div>
              <div className="flex items-center gap-2">
                <Button
                  onClick={() => setStatusFilter('low_stock')}
                  variant={statusFilter === 'low_stock' ? 'primary' : 'secondary'}
                >
                  <AlertTriangle size={14} />
                  <span>Filter Low-Stock SKUs</span>
                </Button>
                {statusFilter === 'low_stock' && (
                  <Button onClick={() => setStatusFilter('all')} variant="secondary">
                    Clear Filter
                  </Button>
                )}
              </div>
            </div>
          </DocumentCard>
        )}

        {/* ── Toolbar & Control Filters ── */}
        <section aria-label="Stock summary filters" className="dashboard-control-bar">
          <div className="dashboard-filter-group">
            <div className="search-input-wrapper">
              <Search size={14} className="text-muted flex-none ml-2" aria-hidden="true" />
              <input
                aria-label="Search by item name or SKU"
                className="dashboard-branch-select"
                placeholder="Search SKU or item name..."
                style={{ width: '220px', paddingLeft: '28px' }}
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
              />
            </div>

            <FilterTabs
              activeValue={statusFilter}
              ariaLabel="Stock status filter"
              items={[
                { value: 'all', label: 'All Items' },
                { value: 'low_stock', label: 'Low Stock' },
                { value: 'out_of_stock', label: 'Out of Stock' },
                { value: 'in_stock', label: 'In Stock' },
              ]}
              onChange={(val) => setStatusFilter(val as StatusFilter)}
            />
          </div>

          <div className="dashboard-filter-group">
            <span className="dashboard-filter-label">
              <Layers size={14} aria-hidden="true" />
              <span>Valuation Method:</span>
            </span>
            <FilterTabs
              activeValue={valuationMethod}
              ariaLabel="Valuation method selector"
              items={[
                { value: 'weighted_average', label: 'Weighted Average' },
                { value: 'fifo', label: 'FIFO Lot Basis' },
              ]}
              onChange={(val) => setValuationMethod(val as ValuationMethod)}
            />
          </div>
        </section>

        {/* ── Stock Inventory Data Table ── */}
        {valuationMethod === 'weighted_average' ? (
          <DocumentCard title="On-Hand Inventory Ledger">
            {filteredItems.length > 0 ? (
              <DataTable caption="Live stock balances and inventory valuation">
                <thead>
                  <tr>
                    <th scope="col">Product & SKU</th>
                    <th scope="col">Unit</th>
                    <th className="numeric-cell" scope="col">On Hand</th>
                    <th className="numeric-cell" scope="col">Avg Unit Cost</th>
                    <th className="numeric-cell" scope="col">Inventory Value</th>
                    <th className="numeric-cell" scope="col">Reorder Level</th>
                    <th scope="col">Stock Status</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredItems.map((item) => {
                    const isLow = Number(item.quantityOnHand) <= Number(item.reorderLevel) && Number(item.reorderLevel) > 0
                    const isOut = Number(item.quantityOnHand) <= 0
                    return (
                      <tr key={item.itemId}>
                        <td>
                          <div className="cell-stack">
                            <strong>{item.itemName}</strong>
                            <span className="code-pill font-mono">{item.sku}</span>
                          </div>
                        </td>
                        <td>
                          <span className="text-secondary text-sm">{item.unit || 'Units'}</span>
                        </td>
                        <td className="numeric-cell">
                          <span className={isOut ? 'text-neg font-bold font-mono' : 'font-mono font-medium'}>
                            <Quantity value={item.quantityOnHand} />
                          </span>
                        </td>
                        <td className="numeric-cell">
                          <Money amount={item.averageCost ?? item.purchasePrice} />
                        </td>
                        <td className="numeric-cell">
                          <strong>
                            <Money amount={item.inventoryValue} />
                          </strong>
                        </td>
                        <td className="numeric-cell">
                          <span className="font-mono text-muted">
                            <Quantity value={item.reorderLevel} />
                          </span>
                        </td>
                        <td>
                          {isOut ? (
                            <StatusChip status="Out of stock" />
                          ) : isLow ? (
                            <StatusChip status="Low stock" />
                          ) : (
                            <StatusChip status="Optimal" />
                          )}
                        </td>
                      </tr>
                    )
                  })}
                </tbody>
              </DataTable>
            ) : (
              <div className="p-4">
                <div className="compact-zero-state">
                  <Package size={16} className="text-muted flex-none" />
                  <span>
                    {searchTerm || statusFilter !== 'all'
                      ? 'No inventory items match your search or status filter.'
                      : 'No stock movements or catalog items recorded yet.'}
                  </span>
                </div>
              </div>
            )}
          </DocumentCard>
        ) : (
          /* ── FIFO Lot Valuation View ── */
          <DocumentCard title="FIFO Cost Lot Valuation Breakdown">
            <div className="p-4 flex flex-col gap-4">
              <div className="flex items-center gap-2 text-xs text-secondary bg-subtle p-3 rounded border border-subtle">
                <ShieldCheck size={16} className="text-pos flex-none" />
                <span>
                  FIFO valuation tracks each goods receipt lot sequentially. Dispatches consume oldest active lots first, preserving accurate COGS posting.
                </span>
              </div>

              {fifoReport?.rows && fifoReport.rows.length > 0 ? (
                <DataTable caption="FIFO lot valuation breakdown">
                  <thead>
                    <tr>
                      {fifoReport.columns.map((col) => (
                        <th
                          key={col.key}
                          className={col.type === 'amount' || col.type === 'quantity' ? 'numeric-cell' : ''}
                          scope="col"
                        >
                          {col.label}
                        </th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {fifoReport.rows.map((row, idx) => (
                      <tr key={String(row.item_id || row.sku || idx)}>
                        {fifoReport.columns.map((col) => {
                          const val = row[col.key]
                          const isAmount = col.type === 'amount'
                          const isQty = col.type === 'quantity'
                          return (
                            <td
                              key={col.key}
                              className={isAmount || isQty ? 'numeric-cell' : ''}
                            >
                              {isAmount ? (
                                <Money amount={Number(val ?? 0)} currency={fifoReport.currency ?? 'INR'} />
                              ) : isQty ? (
                                <span className="font-mono">
                                  <Quantity value={Number(val ?? 0)} />
                                </span>
                              ) : (
                                <span>{String(val ?? '')}</span>
                              )}
                            </td>
                          )
                        })}
                      </tr>
                    ))}
                  </tbody>
                </DataTable>
              ) : (
                <div className="compact-zero-state">
                  <CheckCircle2 size={16} className="text-pos flex-none" />
                  <span>All FIFO inventory lots reconciled with physical warehouse balance.</span>
                </div>
              )}
            </div>
          </DocumentCard>
        )}
      </div>
    </section>
  )
}
