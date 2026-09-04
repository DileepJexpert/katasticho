import { useState, useMemo } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import {
  AlertTriangle,
  ArrowDownRight,
  ArrowUpRight,
  BookOpen,
  Building2,
  Calendar,
  CheckCircle2,
  Clock,
  Coins,
  CreditCard,
  Package,
  Receipt,
  RefreshCw,
  ShieldCheck,
  TrendingDown,
  TrendingUp,
  Truck,
  WalletCards,
} from 'lucide-react'
import {
  Button,
  DataTable,
  DocumentCard,
  FilterTabs,
  Money,
  PageHeader,
  StatusChip,
} from '@/design-system'
import {
  getApAging,
  getApSummary,
  getArAging,
  getArSummary,
  getCashFlow,
  getDailySummary,
  getExpiringSoon,
  getMonthlyProfit,
  getOutstandingReceivable,
  getRecentBills,
  getRecentJournals,
  getRecentTransactions,
  getRevenueTrend,
  getSoAlerts,
  getTodaySales,
  getTopSelling,
  listBranches,
} from '@/features/dashboard/dashboard-api'
import { useSessionStore } from '@/shared/session/session-store'

type DatePreset = 'today' | 'week' | 'month' | 'all'

function getTodayIso(): string {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

function getStartOfWeekIso(): string {
  const d = new Date()
  const day = d.getDay()
  const diff = d.getDate() - day + (day === 0 ? -6 : 1)
  const monday = new Date(d.setDate(diff))
  return `${monday.getFullYear()}-${String(monday.getMonth() + 1).padStart(2, '0')}-${String(monday.getDate()).padStart(2, '0')}`
}

function getStartOfMonthIso(): string {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-01`
}

export function DashboardPage() {
  const queryClient = useQueryClient()
  const user = useSessionStore((state) => state.user)

  // ── Global Filter State (Date Range & Branch Selection) ──
  const [datePreset, setDatePreset] = useState<DatePreset>('today')
  const [selectedBranchId, setSelectedBranchId] = useState<string>('')
  const [revenueDays, setRevenueDays] = useState<number>(30)
  const [agingTab, setAgingTab] = useState<'ar' | 'ap'>('ar')

  const { fromDate, toDate } = useMemo(() => {
    if (datePreset === 'today') {
      const today = getTodayIso()
      return { fromDate: today, toDate: today }
    }
    if (datePreset === 'week') {
      return { fromDate: getStartOfWeekIso(), toDate: getTodayIso() }
    }
    if (datePreset === 'month') {
      return { fromDate: getStartOfMonthIso(), toDate: getTodayIso() }
    }
    return { fromDate: undefined, toDate: undefined }
  }, [datePreset])

  const effectiveBranchId = selectedBranchId || undefined

  // ── Multi-Branch Directory Query ──
  const branchesQuery = useQuery({
    queryKey: ['branches', user?.orgId],
    queryFn: () => listBranches(),
  })

  // ── Resilient Modular Queries ──
  const todaySalesQuery = useQuery({
    queryKey: ['dashboard', 'today-sales', user?.orgId, fromDate, toDate, effectiveBranchId],
    queryFn: () => getTodaySales(fromDate, toDate, effectiveBranchId),
  })

  const arQuery = useQuery({
    queryKey: ['dashboard', 'ar', user?.orgId],
    queryFn: () => getArSummary(),
  })

  const apQuery = useQuery({
    queryKey: ['dashboard', 'ap', user?.orgId, fromDate, toDate, effectiveBranchId],
    queryFn: () => getApSummary(fromDate, toDate, effectiveBranchId),
  })

  const profitQuery = useQuery({
    queryKey: ['dashboard', 'monthly-profit', user?.orgId, fromDate, toDate],
    queryFn: () => getMonthlyProfit(fromDate, toDate),
  })

  const soAlertsQuery = useQuery({
    queryKey: ['dashboard', 'so-alerts', user?.orgId],
    queryFn: () => getSoAlerts(),
  })

  const topSellingQuery = useQuery({
    queryKey: ['dashboard', 'top-selling', user?.orgId, fromDate, toDate],
    queryFn: () => getTopSelling(fromDate, toDate, 5),
  })

  const revenueTrendQuery = useQuery({
    queryKey: ['dashboard', 'revenue-trend', user?.orgId, revenueDays],
    queryFn: () => getRevenueTrend(revenueDays),
  })

  const cashFlowQuery = useQuery({
    queryKey: ['dashboard', 'cash-flow', user?.orgId, fromDate, toDate],
    queryFn: () => getCashFlow(fromDate, toDate),
  })

  const expiringSoonQuery = useQuery({
    queryKey: ['dashboard', 'expiring-soon', user?.orgId],
    queryFn: () => getExpiringSoon(90),
    retry: false,
  })

  const recentTransactionsQuery = useQuery({
    queryKey: ['dashboard', 'recent-transactions', user?.orgId, fromDate, toDate],
    queryFn: () => getRecentTransactions(fromDate, toDate, 5),
  })

  const dailySummaryQuery = useQuery({
    queryKey: ['dashboard', 'daily-summary', user?.orgId],
    queryFn: () => getDailySummary(7),
    retry: false,
  })

  const arAgingQuery = useQuery({
    queryKey: ['dashboard', 'ar-aging', user?.orgId],
    queryFn: () => getArAging(),
    retry: false,
  })

  const apAgingQuery = useQuery({
    queryKey: ['dashboard', 'ap-aging', user?.orgId],
    queryFn: () => getApAging(),
    retry: false,
  })

  const outstandingReceivableQuery = useQuery({
    queryKey: ['dashboard', 'outstanding-receivable', user?.orgId],
    queryFn: () => getOutstandingReceivable(),
    retry: false,
  })

  const recentBillsQuery = useQuery({
    queryKey: ['dashboard', 'recent-bills', user?.orgId],
    queryFn: () => getRecentBills(5),
    retry: false,
  })

  const recentJournalsQuery = useQuery({
    queryKey: ['dashboard', 'recent-journals', user?.orgId],
    queryFn: () => getRecentJournals(5),
    retry: false,
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
    queryClient.invalidateQueries({ queryKey: ['branches'] })
  }

  const branches = branchesQuery.data ?? []
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
  const dailySummary = dailySummaryQuery.data
  const arAging = arAgingQuery.data
  const apAging = apAgingQuery.data
  const outstandingRec = outstandingReceivableQuery.data
  const recentBills = recentBillsQuery.data ?? []
  const recentJournals = recentJournalsQuery.data ?? []

  // Daily performance net margin metric
  const earning = dailySummary?.today.earning ?? (Number(todaySales?.totalSales ?? 0) - Number(profit?.cogs ?? 0))
  const earningPositive = Number(earning) >= 0

  // ── Aging Calculations for Segmented Risk Bar ──
  const activeAging = agingTab === 'ar' ? arAging : apAging
  const agingTotal = Number(activeAging?.totalOutstanding ?? 0)
  const currentVal = Number(activeAging?.current ?? 0)
  const d1to30Val = Number(activeAging?.days1to30 ?? 0)
  const d31to60Val = Number(activeAging?.days31to60 ?? 0)
  const d61to90Val = Number(activeAging?.days61to90 ?? 0)
  const d90plusVal = Number(activeAging?.days90plus ?? 0)

  const currentPct = agingTotal > 0 ? Math.round((currentVal / agingTotal) * 100) : 100
  const d1to30Pct = agingTotal > 0 ? Math.round((d1to30Val / agingTotal) * 100) : 0
  const d31to60Pct = agingTotal > 0 ? Math.round((d31to60Val / agingTotal) * 100) : 0
  const d61to90Pct = agingTotal > 0 ? Math.round((d61to90Val / agingTotal) * 100) : 0
  const d90plusPct = agingTotal > 0 ? Math.max(0, 100 - (currentPct + d1to30Pct + d31to60Pct + d61to90Pct)) : 0

  // ── Revenue SVG Sparkline Chart Calculations ──
  const trendPoints = revenueTrend?.trend ?? []
  const maxRevenue = Math.max(...trendPoints.map((p) => Number(p.revenue)), 1000)

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
        description="Live business intelligence, financial health, multi-branch performance, and fulfillment telemetry."
      />

      <div className="dashboard-workspace">
        {/* ── Executive Control Toolbar (Period Filter & Multi-Branch Selector) ── */}
        <section aria-label="Dashboard controls" className="dashboard-control-bar">
          <div className="dashboard-filter-group">
            <span className="dashboard-filter-label">
              <Calendar size={14} aria-hidden="true" />
              <span>Period:</span>
            </span>
            <FilterTabs
              activeValue={datePreset}
              ariaLabel="Dashboard period filter"
              items={[
                { value: 'today', label: 'Today' },
                { value: 'week', label: 'This week' },
                { value: 'month', label: 'This month' },
                { value: 'all', label: 'All time' },
              ]}
              onChange={(val) => setDatePreset(val as DatePreset)}
            />
          </div>

          <div className="dashboard-filter-group">
            <label htmlFor="dashboard-branch-select" className="dashboard-filter-label">
              <Building2 size={14} aria-hidden="true" />
              <span>Branch:</span>
            </label>
            <select
              id="dashboard-branch-select"
              aria-label="Filter by branch"
              className="dashboard-branch-select"
              value={selectedBranchId}
              onChange={(e) => setSelectedBranchId(e.target.value)}
            >
              <option value="">All Branches</option>
              {branches.map((b) => (
                <option key={b.id} value={b.id}>
                  {b.name} ({b.code}){b.isDefault ? ' [Primary]' : ''}
                </option>
              ))}
            </select>
          </div>
        </section>

        {/* ── Top Metric Cards Row (4 Core KPIs) ── */}
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

        {/* ── Daily Performance Snapshot Card (Margins & Settlements) ── */}
        <DocumentCard title="Daily Performance Snapshot — Margins & Settlements">
          <div className="p-4 flex flex-col gap-4">
            <div className="daily-performance-hero">
              <div className="flex items-center gap-3">
                <div className={`p-2.5 rounded-md ${earningPositive ? 'bg-pos text-pos' : 'bg-neg text-neg'}`}>
                  {earningPositive ? <TrendingUp size={22} /> : <TrendingDown size={22} />}
                </div>
                <div>
                  <span className="text-secondary text-xs uppercase tracking-wide font-medium">Today's Net Earning / Margin</span>
                  <div className="text-xl font-bold font-mono">
                    <Money amount={earning} currency={todaySales?.currency ?? 'INR'} />
                  </div>
                  {dailySummary?.thisWeek && (
                    <span className="text-xs text-secondary">
                      vs last week: <strong>{String(dailySummary.thisWeek.vsLastWeekEarningPct)}%</strong>
                    </span>
                  )}
                </div>
              </div>
              <div className="flex items-center gap-2">
                <StatusChip status={`${todaySales?.transactionCount ?? dailySummary?.today.billCount ?? 0} bills today`} />
              </div>
            </div>

            <dl className="daily-performance-stats">
              <div className="daily-performance-stat">
                <dt>
                  <Receipt size={14} aria-hidden="true" />
                  <span>Total Sales</span>
                </dt>
                <dd>
                  <Money amount={todaySales?.totalSales ?? dailySummary?.today.totalSale ?? 0} currency={todaySales?.currency ?? 'INR'} />
                </dd>
                <span className="text-xs text-muted">POS: {todaySales?.posTransactionCount ?? 0} • B2B: {todaySales?.invoiceTransactionCount ?? 0}</span>
              </div>
              <div className="daily-performance-stat">
                <dt>
                  <Coins size={14} aria-hidden="true" />
                  <span>Total Cost (COGS)</span>
                </dt>
                <dd>
                  <Money amount={dailySummary?.today.totalCost ?? profit?.cogs ?? 0} currency={todaySales?.currency ?? 'INR'} />
                </dd>
                <span className="text-xs text-muted">Stock valuation basis</span>
              </div>
              <div className="daily-performance-stat">
                <dt>
                  <WalletCards size={14} aria-hidden="true" />
                  <span>Cash / UPI Received</span>
                </dt>
                <dd className="text-pos">
                  <Money amount={todaySales?.cashUpiTotal ?? dailySummary?.today.cashUpiIn ?? 0} currency={todaySales?.currency ?? 'INR'} />
                </dd>
                <span className="text-xs text-muted">Instant settlement</span>
              </div>
              <div className="daily-performance-stat">
                <dt>
                  <CreditCard size={14} aria-hidden="true" />
                  <span>Credit Sales</span>
                </dt>
                <dd className="text-neg">
                  <Money amount={todaySales?.creditTotal ?? dailySummary?.today.creditSale ?? 0} currency={todaySales?.currency ?? 'INR'} />
                </dd>
                <span className="text-xs text-muted">Accounts receivable</span>
              </div>
            </dl>
          </div>
        </DocumentCard>

        {/* ── Distribution & Fulfillment Telemetry (SO Alerts Card) ── */}
        {soAlerts && (
          <DocumentCard
            headerAction={
              <StatusChip status={soAlerts.overdueCount > 0 ? 'Action required' : 'Optimal'} />
            }
            title="Distribution & Fulfillment Telemetry"
          >
            <div className="p-4 flex flex-col gap-4">
              <div className={`dashboard-alerts-card ${soAlerts.overdueCount > 0 ? 'dashboard-alerts-card--has-overdue' : ''}`}>
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
                      <strong>{soAlerts.dispatchedChallanCount}</strong> challans in transit ({soAlerts.draftChallanCount} draft, {soAlerts.deliveredChallanCount} delivered)
                    </span>
                  </div>
                </div>
              </div>

              {soAlerts.recentOrders && soAlerts.recentOrders.length > 0 ? (
                <div>
                  <h3 className="text-sm font-semibold mb-2">Recent Pending Orders</h3>
                  <DataTable caption="Recent orders awaiting dispatch">
                    <thead>
                      <tr>
                        <th scope="col">Order #</th>
                        <th scope="col">Customer</th>
                        <th scope="col">Date</th>
                        <th scope="col">Pending</th>
                        <th scope="col">Status</th>
                        <th className="numeric-cell" scope="col">Amount</th>
                      </tr>
                    </thead>
                    <tbody>
                      {soAlerts.recentOrders.map((ord) => (
                        <tr key={ord.id}>
                          <td>
                            <span className="code-pill font-mono">{ord.orderNumber}</span>
                          </td>
                          <td>
                            <strong>{ord.contactName}</strong>
                          </td>
                          <td>
                            <span className="font-mono text-sm">{ord.orderDate}</span>
                          </td>
                          <td>
                            <span className={ord.daysPending > 2 ? 'text-neg font-semibold' : 'text-secondary'}>
                              {ord.daysPending}d
                            </span>
                          </td>
                          <td>
                            <StatusChip status={ord.status} />
                          </td>
                          <td className="numeric-cell">
                            <Money amount={ord.totalAmount} />
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </DataTable>
                </div>
              ) : (
                <div className="compact-zero-state">
                  <CheckCircle2 size={16} className="text-pos flex-none" />
                  <span>Fulfillment optimal • All confirmed sales orders dispatched on schedule</span>
                </div>
              )}
            </div>
          </DocumentCard>
        )}

        {/* ── AR & AP Aging Risk Distribution Bar (DualEntry / Zoho Style) ── */}
        <DocumentCard
          headerAction={
            <FilterTabs
              activeValue={agingTab}
              ariaLabel="Aging buckets selector"
              items={[
                { value: 'ar', label: 'Receivables Aging' },
                { value: 'ap', label: 'Payables Aging' },
              ]}
              onChange={(val) => setAgingTab(val as 'ar' | 'ap')}
            />
          }
          title={agingTab === 'ar' ? 'Accounts Receivable Aging' : 'Accounts Payable Aging'}
        >
          <div className="p-4 flex flex-col gap-4">
            {/* Visual Risk Distribution Segmented Bar */}
            <div className="flex flex-col gap-2">
              <div className="flex items-center justify-between text-xs text-secondary">
                <span>Aging Distribution Exposure:</span>
                <span>Total: <strong><Money amount={agingTotal} /></strong></span>
              </div>
              <div className="aging-segmented-bar" aria-label="Aging distribution bar">
                <div
                  className="aging-bar-segment aging-bar-segment--current"
                  style={{ width: `${currentPct}%` }}
                  title={`Current: ${currentPct}%`}
                />
                <div
                  className="aging-bar-segment aging-bar-segment--1-30"
                  style={{ width: `${d1to30Pct}%` }}
                  title={`1-30d: ${d1to30Pct}%`}
                />
                <div
                  className="aging-bar-segment aging-bar-segment--31-60"
                  style={{ width: `${d31to60Pct}%` }}
                  title={`31-60d: ${d31to60Pct}%`}
                />
                <div
                  className="aging-bar-segment aging-bar-segment--61-90"
                  style={{ width: `${d61to90Pct}%` }}
                  title={`61-90d: ${d61to90Pct}%`}
                />
                <div
                  className="aging-bar-segment aging-bar-segment--90plus"
                  style={{ width: `${d90plusPct}%` }}
                  title={`90+d: ${d90plusPct}%`}
                />
              </div>
            </div>

            {/* Dense Aging Buckets Stat Cards */}
            <dl className="aging-buckets-grid">
              <div className="aging-bucket-card aging-bucket-card--current">
                <dt>Current (Not Due)</dt>
                <dd>
                  <Money amount={currentVal} />
                </dd>
                <span className="text-xs text-muted">{currentPct}% of total</span>
              </div>
              <div className="aging-bucket-card aging-bucket-card--1-30">
                <dt>1–30 Days</dt>
                <dd>
                  <Money amount={d1to30Val} />
                </dd>
                <span className="text-xs text-muted">{d1to30Pct}% of total</span>
              </div>
              <div className="aging-bucket-card aging-bucket-card--31-60">
                <dt>31–60 Days</dt>
                <dd className="text-warn">
                  <Money amount={d31to60Val} />
                </dd>
                <span className="text-xs text-muted">{d31to60Pct}% of total</span>
              </div>
              <div className="aging-bucket-card aging-bucket-card--61-90">
                <dt>61–90 Days</dt>
                <dd className="text-warn font-bold">
                  <Money amount={d61to90Val} />
                </dd>
                <span className="text-xs text-muted">{d61to90Pct}% of total</span>
              </div>
              <div className="aging-bucket-card aging-bucket-card--90plus">
                <dt>90+ Days (Critical)</dt>
                <dd className="text-neg font-bold">
                  <Money amount={d90plusVal} />
                </dd>
                <span className="text-xs text-muted">{d90plusPct}% of total</span>
              </div>
            </dl>

            {agingTab === 'ar' && (
              <div>
                <h3 className="text-sm font-semibold mb-2">Top Debtors Outstanding</h3>
                {outstandingRec?.topCustomers && outstandingRec.topCustomers.length > 0 ? (
                  <DataTable caption="Top customers with outstanding balances">
                    <thead>
                      <tr>
                        <th scope="col">Customer Name</th>
                        <th scope="col">Pending Invoices</th>
                        <th className="numeric-cell" scope="col">Total Balance</th>
                      </tr>
                    </thead>
                    <tbody>
                      {outstandingRec.topCustomers.map((cust) => (
                        <tr key={cust.contactId}>
                          <td>
                            <strong>{cust.name}</strong>
                          </td>
                          <td>
                            <span className="font-mono">{cust.invoiceCount} invoices</span>
                          </td>
                          <td className="numeric-cell">
                            <Money amount={cust.outstanding} currency={outstandingRec.currency ?? 'INR'} />
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </DataTable>
                ) : (
                  <div className="compact-zero-state">
                    <CheckCircle2 size={16} className="text-pos flex-none" />
                    <span>All customer ledgers in order • Zero overdue receivables</span>
                  </div>
                )}
              </div>
            )}
          </div>
        </DocumentCard>

        {/* ── Two-Column Operational & Analytical Workspace ── */}
        <div className="dashboard-columns">
          {/* ── Left Column: Interactive Revenue Chart, Top Products, Branch Breakdown, Activity ── */}
          <div className="dashboard-column dashboard-column--main">
            {/* Interactive SVG Revenue Trend Chart Card */}
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
              title="Revenue trend & sales velocity"
            >
              <div className="p-4 flex flex-col gap-4 revenue-chart-card">
                <div className="revenue-chart-header">
                  <div>
                    <span className="text-secondary text-xs uppercase tracking-wide">Period Total Revenue ({revenueDays} days)</span>
                    <div className="text-lg font-bold">
                      <Money amount={revenueTrend?.totalRevenue ?? 0} currency={revenueTrend?.currency ?? 'INR'} />
                    </div>
                  </div>
                  <span className="text-xs text-muted">Daily breakdown</span>
                </div>

                {trendPoints.length > 0 ? (
                  <div className="flex flex-col gap-2">
                    {/* SVG Bar Visualization */}
                    <div className="bg-subtle p-3 rounded border border-subtle">
                      <svg className="revenue-chart-svg" viewBox="0 0 500 100" preserveAspectRatio="none" role="img" aria-label="Daily revenue trend chart">
                        {/* Grid lines */}
                        <line x1="0" y1="25" x2="500" y2="25" stroke="var(--border)" strokeDasharray="3 3" />
                        <line x1="0" y1="55" x2="500" y2="55" stroke="var(--border)" strokeDasharray="3 3" />
                        <line x1="0" y1="85" x2="500" y2="85" stroke="var(--border)" />

                        {/* Trend Bars */}
                        {trendPoints.slice(-14).map((pt, i, arr) => {
                          const w = Math.min(22, Math.max(8, (480 / arr.length) * 0.65))
                          const x = 10 + i * (480 / arr.length)
                          const h = Math.max(4, (Number(pt.revenue) / maxRevenue) * 75)
                          const y = 85 - h
                          return (
                            <g key={pt.date}>
                              <rect
                                x={x}
                                y={y}
                                width={w}
                                height={h}
                                rx="3"
                                fill="var(--brand-600)"
                                opacity="0.85"
                              >
                                <title>{`${pt.date}: ₹${Number(pt.revenue).toLocaleString('en-IN')}`}</title>
                              </rect>
                            </g>
                          )
                        })}
                      </svg>
                      <div className="flex justify-between text-xs text-muted font-mono mt-1 px-2">
                        <span>{trendPoints[0]?.date ?? ''}</span>
                        <span>Latest: {trendPoints[trendPoints.length - 1]?.date ?? ''}</span>
                      </div>
                    </div>

                    {/* Compact tabular preview */}
                    <div className="max-h-40 overflow-y-auto">
                      <DataTable caption="Daily revenue trend breakdown">
                        <thead>
                          <tr>
                            <th scope="col">Date</th>
                            <th className="numeric-cell" scope="col">Daily revenue</th>
                          </tr>
                        </thead>
                        <tbody>
                          {trendPoints.slice(-7).reverse().map((pt) => (
                            <tr key={pt.date}>
                              <td>
                                <span className="font-mono text-xs">{pt.date}</span>
                              </td>
                              <td className="numeric-cell">
                                <Money amount={pt.revenue} currency={revenueTrend?.currency ?? 'INR'} />
                              </td>
                            </tr>
                          ))}
                        </tbody>
                      </DataTable>
                    </div>
                  </div>
                ) : (
                  <div className="compact-zero-state">
                    <Calendar size={16} className="text-muted flex-none" />
                    <span>No sales revenue recorded for this interval</span>
                  </div>
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
                  <div className="compact-zero-state">
                    <Package size={16} className="text-muted flex-none" />
                    <span>No top product sales recorded for this period</span>
                  </div>
                </div>
              )}
            </DocumentCard>

            {/* Multi-Branch Performance Breakdown */}
            {todaySales?.byBranch && todaySales.byBranch.length > 0 && (
              <DocumentCard title="Branch Sales Rollup">
                <DataTable caption="Sales rollup by branch">
                  <thead>
                    <tr>
                      <th scope="col">Branch</th>
                      <th scope="col">Transactions</th>
                      <th className="numeric-cell" scope="col">Revenue</th>
                    </tr>
                  </thead>
                  <tbody>
                    {todaySales.byBranch.map((row) => (
                      <tr key={row.branchId}>
                        <td>
                          <strong>{row.branchName}</strong>
                        </td>
                        <td>
                          <span className="font-mono">{row.transactionCount}</span>
                        </td>
                        <td className="numeric-cell">
                          <Money amount={row.totalSales} currency={todaySales.currency ?? 'INR'} />
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </DataTable>
              </DocumentCard>
            )}

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
                  <div className="compact-zero-state">
                    <Calendar size={16} className="text-muted flex-none" />
                    <span>No transactions posted today • Create your first sale or invoice via Quick create</span>
                  </div>
                </div>
              )}
            </DocumentCard>
          </div>

          {/* ── Right Column: Cash Flow, Bills to Pay, Journals, Expiring Batches ── */}
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

            {/* Bills to Pay */}
            <DocumentCard title="Bills to Pay (Payables Watch)">
              {recentBills.length > 0 ? (
                <DataTable caption="Vendor bills awaiting payment">
                  <thead>
                    <tr>
                      <th scope="col">Vendor & Bill</th>
                      <th scope="col">Status</th>
                      <th className="numeric-cell" scope="col">Amount</th>
                    </tr>
                  </thead>
                  <tbody>
                    {recentBills.map((bill) => (
                      <tr key={bill.id}>
                        <td>
                          <div className="cell-stack">
                            <strong>{bill.vendorName}</strong>
                            <span className="code-pill font-mono">{bill.billNumber}</span>
                          </div>
                        </td>
                        <td>
                          <StatusChip status={bill.status} />
                        </td>
                        <td className="numeric-cell">
                          <Money amount={bill.totalAmount} />
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </DataTable>
              ) : (
                <div className="p-4">
                  <div className="compact-zero-state">
                    <CheckCircle2 size={16} className="text-pos flex-none" />
                    <span>No pending bills • All vendor obligations up to date</span>
                  </div>
                </div>
              )}
            </DocumentCard>

            {/* Recent Journals */}
            <DocumentCard title="General Ledger Activity">
              {recentJournals.length > 0 ? (
                <DataTable caption="Recent posted journal entries">
                  <thead>
                    <tr>
                      <th scope="col">Entry & Date</th>
                      <th scope="col">Description</th>
                      <th className="numeric-cell" scope="col">Debit</th>
                    </tr>
                  </thead>
                  <tbody>
                    {recentJournals.map((je) => (
                      <tr key={je.id}>
                        <td>
                          <div className="cell-stack">
                            <span className="code-pill font-mono">{je.entryNumber}</span>
                            <span className="text-xs text-muted font-mono">{je.effectiveDate}</span>
                          </div>
                        </td>
                        <td>
                          <span className="text-sm">{je.description || je.sourceModule}</span>
                        </td>
                        <td className="numeric-cell">
                          <Money amount={je.totalDebit} />
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </DataTable>
              ) : (
                <div className="p-4">
                  <div className="compact-zero-state">
                    <BookOpen size={16} className="text-muted flex-none" />
                    <span>No journal entries recorded • Ready for manual or system postings</span>
                  </div>
                </div>
              )}
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
                  <div className="compact-zero-state">
                    <ShieldCheck size={16} className="text-pos flex-none" />
                    <span>No batches expiring soon • 100% stock shelf life compliant</span>
                  </div>
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
