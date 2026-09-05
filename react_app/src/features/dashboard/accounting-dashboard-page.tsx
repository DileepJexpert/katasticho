import { useMemo, useState, type ReactNode } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowUpRight, BookOpen, RefreshCw, WalletCards } from 'lucide-react'
import { Link } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
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
  getOutstandingReceivable,
  getRecentBills,
  getRecentJournals,
} from '@/features/dashboard/dashboard-api'
import { getProfitLoss } from '@/features/reports/reports-api'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import { useSessionStore } from '@/shared/session/session-store'

type AgingKind = 'AR' | 'AP'

const agingTabs = [
  { value: 'AR', label: 'Receivables' },
  { value: 'AP', label: 'Payables' },
] as const

const agingBuckets = [
  { key: 'current', label: 'Current', tone: 'current' },
  { key: 'days1to30', label: '1-30 days', tone: '1-30' },
  { key: 'days31to60', label: '31-60 days', tone: '31-60' },
  { key: 'days61to90', label: '61-90 days', tone: '61-90' },
  { key: 'days90plus', label: '90+ days', tone: '90plus' },
] as const

export function AccountingDashboardPage() {
  const [agingKind, setAgingKind] = useState<AgingKind>('AR')
  const queryClient = useQueryClient()
  const orgId = useSessionStore((state) => state.user?.orgId)
  const { monthStart, today } = useMemo(() => currentMonthRange(), [])

  const profitLossQuery = useQuery({
    queryKey: ['accounting-dashboard', 'profit-loss', orgId, monthStart, today],
    queryFn: () => getProfitLoss(monthStart, today),
  })
  const cashFlowQuery = useQuery({
    queryKey: ['accounting-dashboard', 'cash-flow', orgId, monthStart, today],
    queryFn: () => getCashFlow(monthStart, today),
  })
  const arSummaryQuery = useQuery({
    queryKey: ['accounting-dashboard', 'receivables', orgId],
    queryFn: getArSummary,
  })
  const apSummaryQuery = useQuery({
    queryKey: ['accounting-dashboard', 'payables', orgId, monthStart, today],
    queryFn: () => getApSummary(monthStart, today),
  })
  const arAgingQuery = useQuery({
    queryKey: ['accounting-dashboard', 'ar-aging', orgId, today],
    queryFn: () => getArAging(today),
    retry: false,
  })
  const apAgingQuery = useQuery({
    queryKey: ['accounting-dashboard', 'ap-aging', orgId, today],
    queryFn: () => getApAging(today),
    retry: false,
  })
  const outstandingQuery = useQuery({
    queryKey: ['accounting-dashboard', 'outstanding-receivable', orgId],
    queryFn: getOutstandingReceivable,
    retry: false,
  })
  const recentBillsQuery = useQuery({
    queryKey: ['accounting-dashboard', 'recent-bills', orgId],
    queryFn: () => getRecentBills(5),
    retry: false,
  })
  const recentJournalsQuery = useQuery({
    queryKey: ['accounting-dashboard', 'recent-journals', orgId],
    queryFn: () => getRecentJournals(5),
    retry: false,
  })

  const ar = arSummaryQuery.data
  const ap = apSummaryQuery.data
  const profitLoss = profitLossQuery.data
  const cashFlow = cashFlowQuery.data
  const activeAging = agingKind === 'AR' ? arAgingQuery.data : apAgingQuery.data
  const activeAgingLoading = agingKind === 'AR' ? arAgingQuery.isLoading : apAgingQuery.isLoading
  const activeAgingError = agingKind === 'AR' ? arAgingQuery.isError : apAgingQuery.isError
  const agingReportRoute = agingKind === 'AR' ? appRoutes.reportViewer('ar-aging') : appRoutes.reportViewer('ap-aging')
  const overdueAr = overdueAmount(arAgingQuery.data)
  const overdueAp = overdueAmount(apAgingQuery.data)

  function refreshDashboard() {
    queryClient.invalidateQueries({ queryKey: ['accounting-dashboard'] })
  }

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <Button disabled={isRefreshing([profitLossQuery, cashFlowQuery, arSummaryQuery, apSummaryQuery])} onClick={refreshDashboard} variant="secondary">
            <RefreshCw aria-hidden="true" size={16} /> Refresh
          </Button>
        }
        description="Ledger health, cash movement, open balances, and finance work queues from the current organisation."
        eyebrow="Accounting & GL / Financial Control"
        title="Accounting Dashboard"
      />

      <section aria-label="Month-to-date financial health" className="accounting-dashboard-metrics">
        <MetricCard amount={profitLoss?.totalRevenue} label="Revenue" note="Month to date" />
        <MetricCard amount={ar?.totalOutstanding} label="Receivables" note={`${ar?.overdueCount ?? 0} overdue customer balance${ar?.overdueCount === 1 ? '' : 's'}`} />
        <MetricCard amount={ap?.totalOutstanding} label="Payables" note={`${ap?.overdueCount ?? 0} overdue vendor balance${ap?.overdueCount === 1 ? '' : 's'}`} />
        <MetricCard amount={profitLoss?.netProfit} label="Net profit" note="Accrual basis, month to date" tone={toNumber(profitLoss?.netProfit) < 0 ? 'negative' : 'positive'} />
      </section>

      <section aria-label="Ledger health" className="accounting-dashboard-health">
        <HealthMetric amount={overdueAr} label="AR risk" note="Outstanding 1+ days overdue" tone="warning" />
        <HealthMetric amount={overdueAp} label="AP risk" note="Vendor bills 1+ days overdue" tone="warning" />
        <HealthMetric amount={cashFlow?.netCashFlow} label="Cash flow" note="Month-to-date net movement" tone={toNumber(cashFlow?.netCashFlow) < 0 ? 'negative' : 'positive'} />
        <HealthMetric amount={profitLoss?.netProfit} label="P&L" note="Profit after reported expenses" tone={toNumber(profitLoss?.netProfit) < 0 ? 'negative' : 'positive'} />
      </section>

      <div className="accounting-dashboard-grid">
        <div className="accounting-dashboard-stack">
          <DocumentCard
            headerAction={<Link className="document-card__link" to={appRoutes.reportViewer('cash-flow')}>Cash flow statement <ArrowUpRight aria-hidden="true" size={14} /></Link>}
            title="Cash flow snapshot"
          >
            <div className="accounting-dashboard-cash-flow">
              <CashFlowLine amount={cashFlow?.cashIn} label="Cash in" tone="positive" />
              <CashFlowLine amount={cashFlow?.cashOut} label="Cash out" tone="negative" />
              <CashFlowLine amount={cashFlow?.netCashFlow} label="Net cash movement" tone={toNumber(cashFlow?.netCashFlow) < 0 ? 'negative' : 'positive'} />
            </div>
          </DocumentCard>

          <DocumentCard
            headerAction={<Link className="document-card__link" to={agingReportRoute}>Open aging report <ArrowUpRight aria-hidden="true" size={14} /></Link>}
            title="Aging control"
          >
            <FilterTabs
              activeValue={agingKind}
              ariaLabel="Select receivables or payables aging"
              items={agingTabs}
              onChange={setAgingKind}
            />
            {activeAgingLoading && <p className="compact-zero-state">Loading server-calculated aging buckets...</p>}
            {activeAgingError && <p className="compact-zero-state" role="alert">The aging balance could not be loaded.</p>}
            {activeAging && (
              <dl className="accounting-dashboard-aging">
                {agingBuckets.map((bucket) => (
                  <div className={`accounting-dashboard-aging__bucket accounting-dashboard-aging__bucket--${bucket.tone}`} key={bucket.key}>
                    <dt>{bucket.label}</dt>
                    <dd><Money amount={activeAging[bucket.key]} /></dd>
                  </div>
                ))}
              </dl>
            )}
          </DocumentCard>

          <DocumentCard
            headerAction={<Link className="document-card__link" to={appRoutes.accounts}>Chart of accounts <ArrowUpRight aria-hidden="true" size={14} /></Link>}
            title="Recent journal postings"
          >
            {recentJournalsQuery.isLoading && <p className="compact-zero-state">Loading recent journal postings...</p>}
            {recentJournalsQuery.isError && <p className="compact-zero-state" role="alert">Recent journals could not be loaded.</p>}
            {!recentJournalsQuery.isLoading && !recentJournalsQuery.isError && (recentJournalsQuery.data?.length ?? 0) === 0 && (
              <p className="compact-zero-state">No recent journal postings were returned.</p>
            )}
            {(recentJournalsQuery.data?.length ?? 0) > 0 && (
              <DataTable caption="Recent journal postings">
                <thead>
                  <tr>
                    <th scope="col">Journal</th>
                    <th scope="col">Date</th>
                    <th scope="col">Source</th>
                    <th className="numeric-cell" scope="col">Debit</th>
                    <th scope="col">Status</th>
                  </tr>
                </thead>
                <tbody>
                  {recentJournalsQuery.data?.map((journal) => (
                    <tr key={journal.id}>
                      <td>
                        <Link className="table-row-link table-row-link--mono" to={appRoutes.journalDetail(journal.id)}>{journal.entryNumber}</Link>
                        {journal.description && <div className="cell-muted">{journal.description}</div>}
                      </td>
                      <td>{formatDate(journal.effectiveDate)}</td>
                      <td>{formatStatusLabel(journal.sourceModule)}</td>
                      <td className="numeric-cell"><Money amount={journal.totalDebit} /></td>
                      <td><StatusChip status={journal.status}>{formatStatusLabel(journal.status)}</StatusChip></td>
                    </tr>
                  ))}
                </tbody>
              </DataTable>
            )}
          </DocumentCard>
        </div>

        <aside className="accounting-dashboard-stack">
          <DocumentCard
            headerAction={<Link className="document-card__link" to={appRoutes.reportViewer('ar-aging')}>Receivables report <ArrowUpRight aria-hidden="true" size={14} /></Link>}
            title="Outstanding customers"
          >
            <div className="accounting-dashboard-total">
              <span>Total open balance</span>
              <Money amount={outstandingQuery.data?.totalOutstanding} />
            </div>
            {outstandingQuery.isLoading && <p className="compact-zero-state">Loading customer balances...</p>}
            {outstandingQuery.isError && <p className="compact-zero-state" role="alert">Customer balances could not be loaded.</p>}
            {(outstandingQuery.data?.topCustomers.length ?? 0) > 0 && (
              <ol className="accounting-dashboard-ranked-list">
                {outstandingQuery.data?.topCustomers.map((customer) => (
                  <li key={customer.contactId}>
                    <div>
                      <Link className="table-row-link" to={appRoutes.contactDetail(customer.contactId)}>{customer.name}</Link>
                      <span>{customer.invoiceCount} open invoice{customer.invoiceCount === 1 ? '' : 's'}</span>
                    </div>
                    <Money amount={customer.outstanding} />
                  </li>
                ))}
              </ol>
            )}
          </DocumentCard>

          <DocumentCard
            headerAction={<Link className="document-card__link" to={appRoutes.bills}>Bills <ArrowUpRight aria-hidden="true" size={14} /></Link>}
            title="Bills to pay"
          >
            {recentBillsQuery.isLoading && <p className="compact-zero-state">Loading vendor bills...</p>}
            {recentBillsQuery.isError && <p className="compact-zero-state" role="alert">Vendor bills could not be loaded.</p>}
            {!recentBillsQuery.isLoading && !recentBillsQuery.isError && (recentBillsQuery.data?.length ?? 0) === 0 && (
              <p className="compact-zero-state">No recent vendor bills were returned.</p>
            )}
            {(recentBillsQuery.data?.length ?? 0) > 0 && (
              <ol className="accounting-dashboard-ranked-list accounting-dashboard-ranked-list--bills">
                {recentBillsQuery.data?.map((bill) => (
                  <li key={bill.id}>
                    <div>
                      <Link className="table-row-link table-row-link--mono" to={appRoutes.billDetail(bill.id)}>{bill.billNumber}</Link>
                      <span>{bill.vendorName} · {formatDate(bill.billDate)}</span>
                    </div>
                    <div className="accounting-dashboard-bill-amount">
                      <StatusChip status={bill.status}>{formatStatusLabel(bill.status)}</StatusChip>
                      <Money amount={bill.totalAmount} />
                    </div>
                  </li>
                ))}
              </ol>
            )}
          </DocumentCard>

          <DocumentCard title="Financial statements">
            <nav aria-label="Financial statement shortcuts" className="accounting-dashboard-report-links">
              <ReportLink icon={<BookOpen aria-hidden="true" size={15} />} label="Trial Balance" to={appRoutes.reportViewer('trial-balance')} />
              <ReportLink icon={<WalletCards aria-hidden="true" size={15} />} label="Profit & Loss" to={appRoutes.reportViewer('profit-loss')} />
              <ReportLink icon={<ArrowUpRight aria-hidden="true" size={15} />} label="Balance Sheet" to={appRoutes.reportViewer('balance-sheet')} />
              <ReportLink icon={<ArrowUpRight aria-hidden="true" size={15} />} label="Journal Register" to={appRoutes.reportViewer('journal-register')} />
            </nav>
          </DocumentCard>
        </aside>
      </div>
    </section>
  )
}

function MetricCard({
  amount,
  label,
  note,
  tone = 'neutral',
}: {
  amount: number | string | null | undefined
  label: string
  note: string
  tone?: 'positive' | 'negative' | 'neutral'
}) {
  return (
    <div className={`accounting-dashboard-metric accounting-dashboard-metric--${tone}`}>
      <span>{label}</span>
      <strong><Money amount={amount} /></strong>
      <small>{note}</small>
    </div>
  )
}

function HealthMetric({
  amount,
  label,
  note,
  tone,
}: {
  amount: number | string | null | undefined
  label: string
  note: string
  tone: 'positive' | 'negative' | 'warning'
}) {
  return (
    <div className={`accounting-dashboard-health__metric accounting-dashboard-health__metric--${tone}`}>
      <div>
        <span>{label}</span>
        <small>{note}</small>
      </div>
      <Money amount={amount} />
    </div>
  )
}

function CashFlowLine({
  amount,
  label,
  tone,
}: {
  amount: number | string | null | undefined
  label: string
  tone: 'positive' | 'negative'
}) {
  return (
    <div className={`accounting-dashboard-cash-flow__line accounting-dashboard-cash-flow__line--${tone}`}>
      <span>{label}</span>
      <Money amount={amount} />
    </div>
  )
}

function ReportLink({ icon, label, to }: { icon: ReactNode; label: string; to: string }) {
  return <Link to={to}>{icon}<span>{label}</span><ArrowUpRight aria-hidden="true" size={14} /></Link>
}

function overdueAmount(aging: {
  days1to30: number | string
  days31to60: number | string
  days61to90: number | string
  days90plus: number | string
} | undefined): number {
  if (!aging) return 0
  return toNumber(aging.days1to30) + toNumber(aging.days31to60) + toNumber(aging.days61to90) + toNumber(aging.days90plus)
}

function toNumber(value: number | string | null | undefined): number {
  const parsed = Number(value ?? 0)
  return Number.isFinite(parsed) ? parsed : 0
}

function currentMonthRange(): { monthStart: string; today: string } {
  const now = new Date()
  const format = (date: Date) => [date.getFullYear(), String(date.getMonth() + 1).padStart(2, '0'), String(date.getDate()).padStart(2, '0')].join('-')
  return { monthStart: format(new Date(now.getFullYear(), now.getMonth(), 1)), today: format(now) }
}

function isRefreshing(queries: Array<{ isFetching: boolean }>): boolean {
  return queries.some((query) => query.isFetching)
}
