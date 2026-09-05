import { useState } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { Button, FormGrid, PageHeader, Quantity } from '@/design-system'
import type { Item } from '@/features/items/items-api'
import type { Warehouse } from '@/features/warehouses/warehouses-api'
import { useSessionStore } from '@/shared/session/session-store'
import { WorkspaceBoundary } from '@/shared/workflows/workspace-boundary'
import { QueryFeedback } from '@/shared/workflows/query-feedback'
import { ConfirmedAction } from '@/shared/workflows/confirmed-action'
import { LocalDirectory } from '@/shared/workflows/local-directory'
import { calculateReorder, classifyAbc, listReorderPolicies, planningRoles } from './supply-chain-api'
import { PlanningItemPicker, PlanningWarehousePicker } from './planning-pickers'

export function ReorderPoliciesPage() { return <WorkspaceBoundary roles={planningRoles}><Policies /></WorkspaceBoundary> }
function Policies() {
  const orgId = useSessionStore((s) => s.user!.orgId)
  const client = useQueryClient()
  const [item, setItem] = useState<Item | null>(null)
  const [warehouse, setWarehouse] = useState<Warehouse | null>(null)
  const [action, setAction] = useState<'abc' | 'reorder' | null>(null)
  const query = useQuery({ queryKey: ['supply', orgId, 'policies'], queryFn: listReorderPolicies })
  return <section className="workspace-page"><PageHeader eyebrow="Supply planning" title="ABC and reorder policies" description="Review calculated safety stock and economic order quantities. These are planning values, not purchase orders." actions={<Button onClick={() => setAction('abc')}>Run ABC classification</Button>} />
    <FormGrid><PlanningItemPicker value={item} onChange={setItem} /><PlanningWarehousePicker value={warehouse} onChange={setWarehouse} /><Button disabled={!item} onClick={() => setAction('reorder')}>Calculate reorder parameters</Button></FormGrid>
    <QueryFeedback query={query}><LocalDirectory rows={query.data ?? []} caption="Reorder policies" searchText={(p) => `${p.itemName ?? ''} ${p.abcClass ?? ''}`} header={<tr><th>Item</th><th>Class</th><th className="numeric-cell">Safety stock</th><th className="numeric-cell">Reorder point</th><th className="numeric-cell">Reorder quantity</th><th className="numeric-cell">EOQ</th><th>Lead days</th><th>Calculated</th></tr>} renderRow={(p) => <tr key={p.id}><td>{p.itemName ?? 'Item name unavailable'}</td><td>{p.abcClass ?? '--'}</td><td className="numeric-cell"><Quantity value={p.safetyStock} /></td><td className="numeric-cell"><Quantity value={p.reorderPoint} /></td><td className="numeric-cell"><Quantity value={p.reorderQty} /></td><td className="numeric-cell"><Quantity value={p.eoq} /></td><td>{p.leadTimeDays}</td><td>{p.lastCalculated ?? '--'}</td></tr>} /></QueryFeedback>
    {action && <ConfirmedAction title={action === 'abc' ? 'Classify organisation inventory' : 'Recalculate reorder policy'} description={action === 'abc' ? 'Recalculate ABC classes for the entire organisation?' : `Recalculate and save the policy for ${item?.name}, ${warehouse?.name ?? 'all warehouses'}?`} run={() => action === 'abc' ? classifyAbc() : calculateReorder(item!.id, warehouse?.id)} onClose={() => setAction(null)} onDone={() => { setAction(null); void client.invalidateQueries({ queryKey: ['supply', orgId] }) }} />}
  </section>
}
