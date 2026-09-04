import { useState, useMemo } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import {
  AlertTriangle,
  ArrowDownRight,
  ArrowUpRight,
  Calendar,
  Clock,
  Package,
  RefreshCw,
  ShieldAlert,
  TrendingUp,
  Truck,
  WalletCards,
} from 'lucide-react'
import {
  Button,
  DataTable,
  DocumentCard,
  EmptyState,
  FilterTabs,
  Money,
  PageHeader,
  StatusChip,
} from '@/design-system'
import {
  getApSummary,
  getArSummary,
  getCashFlow,
  getExpiringSoon,
  getMonthlyProfit,
  getRecentTransactions,
  getRevenueTrend,
  getSoAlerts,
  getTodaySales,
  getTopSelling,
} from '@/features/dashboard/dashboard-api'
import { useSessionStore } from '@/shared/session/session-store'

export function DashboardPage() {
  const queryClient = useQueryClient()
  const user = useSessionStore((state) => state.user)
  const [revenueDays, setRevenueDays] = useState<number>(30)

  // ── Independent Resilient Queries ──

  const todaySalesQuery = useQuery({
    queryKey: ['dashboard', 'today-sales', user?.orgId],
    queryFn: () => getTodaySales(),
  })

  const arQuery = useQuery({
    queryKey: ['dashboard', 'ar', user?.orgId],
    queryFn: () => getArSummary(),
  })

  const apQuery = useQuery({
    queryKey: ['dashboard', 'ap', user?.orgId],
    queryFn: () => getApSummary(),
  })

  const profitQuery = useQuery({
    queryKey: ['dashboard', 'monthly-profit', user?.orgId],
    queryFn: () => getMonthlyProfit(),
  })

  const soAlertsQuery = useQuery({
    queryKey: ['dashboard', 'so-alerts', user?.orgId],
    queryFn: () => getSoAlerts(),
  })

  const topSellingQuery = useQuery({
    queryKey: ['dashboard', 'top-selling', user?.orgId],
    queryFn: () => getTopSelling(undefined, undefined, 5),
  })

  const revenueTrendQuery = useQuery({
    queryKey: ['dashboard', 'revenue-trend', user?.orgId, revenueDays],
    queryFn: () => getRevenueTrend(revenueDays),
  })

  const cashFlowQuery = useQuery({
    queryKey: ['dashboard', 'cash-flow', user?.orgId],
    queryFn: () => getCashFlow(),
  })

  const expiringSoonQuery = useQuery({
    queryKey: ['dashboard', 'expiring-soon', user?.orgId],
    queryFn: () => getExpiringSoon(90),
    retry: false,
  })

  const recentTransactionsQuery = useQuery({
    queryKey: ['dashboard', 'recent-transactions', user?.orgId],
    queryFn: () => getRecentTransactions(undefined, undefined, 5),
  })

  // Dynamic greeting based on user's local time
  const greetingTime = useMemo(() => {
    const hr = new Date().getHours()
    if (hr < 12) return 'morning'
    if (hr < 17) return 'afternoon'
    return 'evening'
  }, [])

  const firstName = user?.fullName ? user.fullName.split(' ')[0] : 'there'

  function handleRefresh() {
    queryClient.invalidateQueries({ queryKey: ['dashboard'] })
  }

  const todaySales = todaySalesQuery.data
  const ar = arQuery.data
  const ap = apQuery.data
  const profit = profitQuery.data
  const soAlerts = soAlertsQuery.data
  const topSelling = topSellingQuery.data ?? []
  const revenueTrend = revenueTrendQuery.data
  const cashFlow = cashFlowQuery.data
  const expiringSoon = expiringSoonQuery.data ?? []
  const recentTransactions = recentTransactionsQuery.data ?? []

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <div className="flex items-center gap-2">
            <Button
              aria-label="Refresh dashboard data"
              onClick={handleRefresh}
              variant="secondary"
            >
              <RefreshCw size={15} aria-hidden="true" />
              <span>Refresh</span>
            </Button>
            <StatusChip status="Live" />
          </div>
        }
        eyebrow={`Executive Overview • ${user?.orgName ?? 'Katasticho ERP'}`}
        title={`Good ${greetingTime}, ${firstName}`}
        description="Live business intelligence, financial health, and fulfillment telemetry."
      />

      <div className="dashboard-workspace">
        {/* ── Top Metric Cards Row ── */}
        <section aria-label="Key performance indicators" className="metric-grid">
          <MetricCard
            detail={`${todaySales?.transactionCount ?? 0} transactions • Cash/UPI: ${todaySales?.cashUpiTotal ?? 0} • Credit: ${todaySales?.creditTotal ?? 0}`}
            icon={<WalletCards size={20} aria-hidden="true" />}
            label="Today’s sales"
            loading={todaySalesQuery.isLoading}
            tone="brand"
            value={
              <Money
                amount={todaySales?.totalSales}
                currency={todaySales?.currency ?? 'INR'}
              />
            }
          />
          <MetricCard
            detail={`${ar?.overdueCount ?? 0} overdue accounts • Due this week: ${ar?.dueThisWeekCount ?? 0}`}
            icon={<ArrowDownRight size={20} aria-hidden="true" />}
            label="Receivables"
            loading={arQuery.isLoading}
            tone="positive"
            value={
              <Money
                amount={ar?.totalOutstanding}
                currency={ar?.currency ?? 'INR'}
              />
            }
          />
          <MetricCard
            detail={`${ap?.overdueCount ?? 0} overdue bills • Due this week: ${ap?.dueThisWeekCount ?? 0}`}
            icon={<ArrowUpRight size={20} aria-hidden="true" />}
            label="Payables"
            loading={apQuery.isLoading}
            tone="warning"
            value={<Money amount={ap?.totalOutstanding} />}
          />
          <MetricCard
            detail={`Revenue: ${profit?.revenue ?? 0} • COGS: ${profit?.cogs ?? 0}`}
            icon={<TrendingUp size={20} aria-hidden="true" />}
            label="Monthly gross profit"
            loading={profitQuery.isLoading}
            tone="neutral"
            value={
              <Money
                amount={profit?.grossProfit}
                currency={profit?.currency ?? 'INR'}
              />
            }
          />
        </section>

        {/* ── Distribution & Fulfillment Alerts Banner ── */}
        {soAlerts && (
          <section
            aria-label="Distribution and fulfillment alerts"
            className={`dashboard-alerts-card ${soAlerts.overdueCount > 0 ? 'dashboard-alerts-card--has-overdue' : ''}`}
          >
            <div className="dashboard-alerts-list">
              <div className="dashboard-alert-item">
                <Package size={16} aria-hidden="true" />
                <span>
                  <strong>{soAlerts.confirmedCount}</strong> pending dispatch
                </span>
              </div>
              <div className="dashboard-alert-item">
                <Clock size={16} aria-hidden="true" />
                <span>
                  <strong>{soAlerts.backorderCount}</strong> on backorder
                </span>
              </div>
              {soAlerts.overdueCount > 0 && (
                <div className="dashboard-alert-item text-neg">
                  <AlertTriangle size={16} aria-hidden="true" />
                  <span>
                    <strong>{soAlerts.overdueCount}</strong> delayed &gt;2 days
                  </span>
                </div>
              )}
              <div className="dashboard-alert-item">
                <Truck size={16} aria-hidden="true" />
                <span>
                  <strong>{soAlerts.dispatchedChallanCount}</strong> challans in transit ({soAlerts.draftChallanCount} draft)
                </span>
              </div>
            </div>
            <StatusChip status={soAlerts.overdueCount > 0 ? 'Action required' : 'Optimal'} />
          </section>
        )}

        {/* ── Two-Column Operational & Analytical Workspace ── */}
        <div className="dashboard-columns">
          {/* ── Left Column: Revenue Trend, Top Products, Activity ── */}
          <div className="dashboard-column dashboard-column--main">
            {/* Revenue Trend Card */}
            <DocumentCard
              headerAction={
                <FilterTabs
                  activeValue={String(revenueDays)}
                  ariaLabel="Revenue trend days filter"
                  items={[
                    { value: '7', label: '7 days' },
                    { value: '30', label: '30 days' },
                    { value: '90', label: '90 days' },
                  ]}
                  onChange={(val) => setRevenueDays(Number(val))}
                />
              }
              title="Revenue trend"
            >
              <div className="p-4 flex flex-col gap-3">
                <div className="flex items-baseline justify-between border-b border-subtle pb-3">
                  <div>
                    <span className="text-secondary text-sm">Period revenue ({revenueDays} days): </span>
                    <strong>
                      <Money amount={revenueTrend?.totalRevenue ?? 0} currency={revenueTrend?.currency ?? 'INR'} />
                    </strong>
                  </div>
                  <span className="text-muted text-xs">Updated live</span>
                </div>

                {revenueTrend?.trend && revenueTrend.trend.length > 0 ? (
                  <div className="max-h-56 overflow-y-auto">
                    <DataTable caption="Daily revenue trend breakdown">
                      <thead>
                        <tr>
                          <th scope="col">Date</th>
                          <th className="numeric-cell" scope="col">Daily revenue</th>
                        </tr>
                      </thead>
                      <tbody>
                        {revenueTrend.trend.slice(-7).reverse().map((pt) => (
                          <tr key={pt.date}>
                            <td>
                              <span className="font-mono text-sm">{pt.date}</span>
                            </td>
                            <td className="numeric-cell">
                              <Money amount={pt.revenue} currency={revenueTrend.currency ?? 'INR'} />
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </DataTable>
                  </div>
                ) : (
                  <p className="text-secondary text-sm">No revenue data recorded for this interval.</p>
                )}
              </div>
            </DocumentCard>

            {/* Top Selling Products */}
            <DocumentCard title="Top selling items">
              {topSelling.length > 0 ? (
                <DataTable caption="Top selling products">
                  <thead>
                    <tr>
                      <th scope="col">Rank</th>
                      <th scope="col">Product & SKU</th>
                      <th className="numeric-cell" scope="col">Qty sold</th>
                      <th className="numeric-cell" scope="col">Revenue</th>
                    </tr>
                  </thead>
                  <tbody>
                    {topSelling.map((item) => (
                      <tr key={item.itemId || item.sku}>
                        <td>
                          <span className="font-mono font-medium">#{item.rank}</span>
                        </td>
                        <td>
                          <div className="cell-stack">
                            <strong>{item.name}</strong>
                            <span className="code-pill font-mono">{item.sku}</span>
                          </div>
                        </td>
                        <td className="numeric-cell">
                          <span className="font-mono">{item.quantity} {item.unit}</span>
                        </td>
                        <td className="numeric-cell">
                          <Money amount={item.revenue} />
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </DataTable>
              ) : (
                <div className="p-4">
                  <EmptyState
                    description="No top product sales recorded for this period."
                    icon={Package}
                    title="No top selling items"
                  />
                </div>
              )}
            </DocumentCard>

            {/* Recent Transactions */}
            <DocumentCard title="Recent transactions">
              {recentTransactions.length > 0 ? (
                <DataTable caption="Recent sales and receipts">
                  <thead>
                    <tr>
                      <th scope="col">Type</th>
                      <th scope="col">Number</th>
                      <th scope="col">Customer</th>
                      <th scope="col">Mode</th>
                      <th className="numeric-cell" scope="col">Amount</th>
                    </tr>
                  </thead>
                  <tbody>
                    {recentTransactions.map((tx) => (
                      <tr key={tx.id}>
                        <td>
                          <span className="text-secondary text-sm">{tx.type}</span>
                        </td>
                        <td>
                          <span className="code-pill font-mono">{tx.number}</span>
                        </td>
                        <td>
                          <strong>{tx.customerName || 'Walk-in customer'}</strong>
                        </td>
                        <td>
                          <span className="text-secondary text-xs">{tx.paymentMode || 'Cash'}</span>
                        </td>
                        <td className="numeric-cell">
                          <Money amount={tx.amount} />
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </DataTable>
              ) : (
                <div className="p-4">
                  <EmptyState
                    description="No transactions posted today."
                    icon={Calendar}
                    title="No recent transactions"
                  />
                </div>
              )}
            </DocumentCard>
          </div>

          {/* ── Right Column: Cash Flow, Expiring Batches ── */}
          <div className="dashboard-column dashboard-column--side">
            {/* Cash Flow Snapshot */}
            <DocumentCard title="Cash flow overview">
              <div className="p-4 flex flex-col gap-4">
                <dl className="cash-flow-breakdown">
                  <div className="cash-flow-item">
                    <dt>Cash In</dt>
                    <dd className="text-pos font-semibold text-sm">
                      <Money amount={cashFlow?.cashIn ?? 0} currency={cashFlow?.currency ?? 'INR'} />
                    </dd>
                  </div>
                  <div className="cash-flow-item">
                    <dt>Cash Out</dt>
                    <dd className="text-neg font-semibold text-sm">
                      <Money amount={cashFlow?.cashOut ?? 0} currency={cashFlow?.currency ?? 'INR'} />
                    </dd>
                  </div>
                  <div className="cash-flow-item">
                    <dt>Net Flow</dt>
                    <dd className="font-bold text-sm">
                      <Money amount={cashFlow?.netCashFlow ?? 0} currency={cashFlow?.currency ?? 'INR'} />
                    </dd>
                  </div>
                </dl>
              </div>
            </DocumentCard>

            {/* Near-Expiry Batch Watch */}
            <DocumentCard title="Near-expiry batch watch">
              {expiringSoon.length > 0 ? (
                <DataTable caption="Batches expiring within 90 days">
                  <thead>
                    <tr>
                      <th scope="col">Product & Batch</th>
                      <th scope="col">Days left</th>
                      <th className="numeric-cell" scope="col">On hand</th>
                    </tr>
                  </thead>
                  <tbody>
                    {expiringSoon.map((batch) => (
                      <tr key={`${batch.itemId}-${batch.batchNumber}`}>
                        <td>
                          <div className="cell-stack">
                            <strong>{batch.itemName}</strong>
                            <span className="code-pill font-mono">{batch.batchNumber}</span>
                          </div>
                        </td>
                        <td>
                          <StatusChip status={`${batch.daysLeft}d left`} />
                        </td>
                        <td className="numeric-cell">
                          <span className="font-mono">{batch.quantityOnHand}</span>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </DataTable>
              ) : (
                <div className="p-4">
                  <EmptyState
                    description="All tracked inventory batches are within safe shelf life parameters."
                    icon={ShieldAlert}
                    title="No batches expiring soon"
                  />
                </div>
              )}
            </DocumentCard>
          </div>
        </div>
      </div>
    </section>
  )
}

type MetricCardProps = {
  icon: React.ReactNode
  label: string
  value: React.ReactNode
  detail: string
  loading: boolean
  tone: 'brand' | 'positive' | 'warning' | 'neutral'
}

function MetricCard({ detail, icon, label, loading, tone, value }: MetricCardProps) {
  return (
    <article className={`metric-card metric-card--${tone}`}>
      <span className="metric-icon">{icon}</span>
      <p>{label}</p>
      <strong className={loading ? 'metric-value metric-value--loading' : 'metric-value'}>
        {loading ? 'Loading' : value}
      </strong>
      <small>{detail}</small>
    </article>
  )
}
