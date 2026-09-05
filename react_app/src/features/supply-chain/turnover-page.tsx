import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { FormField, Money, PageHeader, Quantity, SelectInput } from '@/design-system'
import { useSessionStore } from '@/shared/session/session-store'
import { LocalDirectory } from '@/shared/workflows/local-directory'
import { QueryFeedback } from '@/shared/workflows/query-feedback'
import { WorkspaceBoundary } from '@/shared/workflows/workspace-boundary'
import { getInventoryTurnover, planningRoles } from './supply-chain-api'

export function InventoryTurnoverPage() { return <WorkspaceBoundary roles={planningRoles}><Turnover /></WorkspaceBoundary> }
function Turnover() {
  const orgId = useSessionStore((s) => s.user!.orgId)
  const [months, setMonths] = useState(12)
  const query = useQuery({ queryKey: ['supply', orgId, 'turnover', months], queryFn: () => getInventoryTurnover(months) })
  return <section className="workspace-page"><PageHeader eyebrow="Supply planning / Operational analytics" title="Inventory turnover" description="Recorded sale costs compared with current on-hand stock value." /><p className="banner">This existing service uses current on-hand quantity multiplied by average cost, not period-average inventory or FIFO valuation. Ratios are for the selected period, not annualised. The service's days-on-hand estimate is omitted because it assumes 365 days for every period and uses 999 as a no-sales sentinel. Use accounting reports for audited balances.</p><FormField label="Sale-cost lookback"><SelectInput value={months} onChange={(e) => setMonths(Number(e.target.value))}>{[1, 3, 6, 12].map((value) => <option key={value} value={value}>{value} months</option>)}</SelectInput></FormField><QueryFeedback query={query}><LocalDirectory rows={(query.data ?? []).map((row) => ({ ...row, id: row.itemId }))} caption="Operational inventory turnover" searchText={(row) => row.itemName} header={<tr><th>Item</th><th className="numeric-cell">Recorded sale cost</th><th className="numeric-cell">Current average-cost stock value</th><th className="numeric-cell">Period ratio</th></tr>} renderRow={(row) => <tr key={row.id}><td>{row.itemName}</td><td className="numeric-cell"><Money amount={row.cogs} /></td><td className="numeric-cell"><Money amount={row.avgInventoryValue} /></td><td className="numeric-cell">{Number(row.avgInventoryValue) > 0 ? <Quantity value={row.turnoverRatio} /> : 'Not available'}</td></tr>} /></QueryFeedback></section>
}
