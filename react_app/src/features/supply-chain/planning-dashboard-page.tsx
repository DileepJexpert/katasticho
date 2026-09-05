import { useQuery } from '@tanstack/react-query'
import { Link } from 'react-router-dom'
import { Fact, FactList, FormCard, PageHeader } from '@/design-system'
import { useSessionStore } from '@/shared/session/session-store'
import { WorkspaceBoundary } from '@/shared/workflows/workspace-boundary'
import { QueryFeedback } from '@/shared/workflows/query-feedback'
import { getPlanningDashboard, planningReadRoles } from './supply-chain-api'

export function PlanningDashboardPage() { return <WorkspaceBoundary roles={planningReadRoles}><Dashboard /></WorkspaceBoundary> }
function Dashboard() {
  const user = useSessionStore((s) => s.user!)
  const query = useQuery({ queryKey: ['supply', user.orgId, 'dashboard'], queryFn: getPlanningDashboard })
  return <section className="workspace-page"><PageHeader eyebrow="Supply planning" title="Supply planning overview" description="Review replenishment signals, purchase requests and shipment tracking." />
    <QueryFeedback query={query}>{query.data && <FormCard title="Planning signals"><FactList columns={3}><Fact label="Open alerts" value={query.data.openAlerts} /><Fact label="Low-stock balances" value={query.data.lowStockCount} /><Fact label="Auto-reorder policies" value={query.data.autoReorderItems} /><Fact label="Class A policies" value={query.data.abcClassification.A} /><Fact label="Class B policies" value={query.data.abcClassification.B} /><Fact label="Class C policies" value={query.data.abcClassification.C} /></FactList></FormCard>}</QueryFeedback>
    <FormCard title="Planning workspaces"><div className="page-header-actions">
      {user.role !== 'OPERATOR' && <><Link className="button button--secondary" to="/supply-chain/requisitions">Purchase requisitions</Link><Link className="button button--secondary" to="/supply-chain/forecasts">Demand forecasts</Link><Link className="button button--secondary" to="/supply-chain/reorder-policies">ABC and reorder policies</Link><Link className="button button--secondary" to="/supply-chain/item-suppliers">Item suppliers</Link><Link className="button button--secondary" to="/supply-chain/alerts">Supply alerts</Link><Link className="button button--secondary" to="/supply-chain/supplier-performance">Supplier performance</Link></>}
      <Link className="button button--secondary" to="/supply-chain/shipments">Shipment tracking</Link>
    </div></FormCard><p className="cell-muted">Low-stock counts are warehouse balance records, not necessarily unique products. Use Inventory valuation reports for financial stock value.</p>
  </section>
}
