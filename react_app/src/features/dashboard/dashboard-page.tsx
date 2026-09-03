import { useQuery } from '@tanstack/react-query'
import { AlertTriangle, ArrowDownRight, ArrowUpRight, ReceiptText, WalletCards } from 'lucide-react'
import { PageHeader } from '@/design-system/page-header'
import { Money } from '@/design-system/money'
import { StatusChip } from '@/design-system/status-chip'
import { getDashboardOverview } from '@/features/dashboard/dashboard-api'
import { useSessionStore } from '@/shared/session/session-store'

export function DashboardPage() {
  const user = useSessionStore((state) => state.user)
  const overview = useQuery({
    queryKey: ['dashboard', 'overview', user?.orgId],
    queryFn: getDashboardOverview,
  })

  return (
    <section className="workspace-page">
      <PageHeader
        actions={<StatusChip status="Connected" />}
        eyebrow="Overview"
        title={`Good morning, ${user?.fullName.split(' ')[0] ?? 'there'}`}
        description="A live snapshot from your existing Katasticho organisation."
      />

      {overview.isError && (
        <div className="error-state" role="alert">
          <AlertTriangle size={20} aria-hidden="true" />
          <div><strong>Dashboard data could not be loaded.</strong><p>The server is reachable, but this account may not have permission for the selected dashboard data.</p></div>
        </div>
      )}

      <div className="metric-grid" aria-busy={overview.isLoading}>
        <MetricCard
          icon={<WalletCards size={20} aria-hidden="true" />}
          label="Today’s sales"
          loading={overview.isLoading}
          value={<Money amount={overview.data?.todaySales.totalSales} currency={overview.data?.todaySales.currency ?? 'INR'} />}
          detail={`${overview.data?.todaySales.transactionCount ?? 0} transactions today`}
          tone="brand"
        />
        <MetricCard
          icon={<ArrowDownRight size={20} aria-hidden="true" />}
          label="Receivables"
          loading={overview.isLoading}
          value={<Money amount={overview.data?.receivables.totalOutstanding} currency={overview.data?.receivables.currency ?? 'INR'} />}
          detail={`${overview.data?.receivables.overdueCount ?? 0} overdue customer accounts`}
          tone="positive"
        />
        <MetricCard
          icon={<ArrowUpRight size={20} aria-hidden="true" />}
          label="Payables"
          loading={overview.isLoading}
          value={<Money amount={overview.data?.payables.totalOutstanding} />}
          detail={`${overview.data?.payables.overdueCount ?? 0} overdue supplier accounts`}
          tone="warning"
        />
        <MetricCard
          icon={<ReceiptText size={20} aria-hidden="true" />}
          label="Monthly gross profit"
          loading={overview.isLoading}
          value={<Money amount={overview.data?.monthlyProfit.grossProfit} currency={overview.data?.monthlyProfit.currency ?? 'INR'} />}
          detail="Revenue less cost of goods sold"
          tone="neutral"
        />
      </div>

      <section className="dashboard-note">
        <div>
          <p className="eyebrow">Migration status</p>
          <h2>Overview is connected to live backend data.</h2>
          <p>Contacts, purchase-to-pay, and order-to-cash will be migrated next only after their API contracts and acceptance checks are complete.</p>
        </div>
        <StatusChip status="Wave 1" />
      </section>
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
      <strong className={loading ? 'metric-value metric-value--loading' : 'metric-value'}>{loading ? 'Loading' : value}</strong>
      <small>{detail}</small>
    </article>
  )
}
