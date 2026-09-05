import { useState } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { Button, Fact, FactList, FormCard, Money, PageHeader, StatusChip } from '@/design-system'
import { useSessionStore } from '@/shared/session/session-store'
import { WorkspaceBoundary } from '@/shared/workflows/workspace-boundary'
import { ConfirmedAction } from '@/shared/workflows/confirmed-action'
import { LocalDirectory } from '@/shared/workflows/local-directory'
import { QueryFeedback } from '@/shared/workflows/query-feedback'
import { listPartners, networkRoles, networkWriteBlockers, partnerAction, type TradingPartner } from './partner-network-api'

export function PartnersPage() {
  return <WorkspaceBoundary roles={networkRoles}><PartnersWorkspace /></WorkspaceBoundary>
}

function PartnersWorkspace() {
  const orgId = useSessionStore((s) => s.user!.orgId)
  const client = useQueryClient()
  const query = useQuery({ queryKey: ['network', orgId, 'partners'], queryFn: listPartners })
  const [selected, setSelected] = useState<TradingPartner | null>(null)
  const [action, setAction] = useState<{ partner: TradingPartner; action: 'approve' | 'reject' | 'suspend' } | null>(null)
  const name = (p: TradingPartner) => p.buyerOrgId === orgId ? p.sellerOrgName : p.buyerOrgName
  return <section className="workspace-page">
    <PageHeader eyebrow="Partner network" title="Trading partners" description="Review buyer/seller relationships and incoming partnership requests." />
    <p className="banner">{networkWriteBlockers.request}</p>
    <QueryFeedback query={query}><LocalDirectory rows={query.data ?? []} caption="Trading partners" searchText={(p) => `${p.sellerOrgName} ${p.buyerOrgName} ${p.status}`}
      header={<tr><th>Organisation</th><th>Your role</th><th>Status</th><th className="numeric-cell">Credit limit</th><th>Actions</th></tr>}
      renderRow={(p) => <tr key={p.id}><td><Button variant="ghost" onClick={() => setSelected(p)}>{name(p)}</Button></td><td>{p.buyerOrgId === orgId ? 'Buyer' : 'Seller'}</td><td><StatusChip status={p.status} /></td><td className="numeric-cell">{p.creditLimit == null ? '--' : <Money amount={p.creditLimit} />}</td><td>
        {p.status === 'PENDING' && <>{p.requestedByOrgId !== orgId && <Button variant="ghost" onClick={() => setAction({ partner: p, action: 'approve' })}>Approve {name(p)}</Button>}<Button variant="ghost" onClick={() => setAction({ partner: p, action: 'reject' })}>Reject {name(p)}</Button></>}
        {p.status === 'APPROVED' && <Button variant="ghost" onClick={() => setAction({ partner: p, action: 'suspend' })}>Suspend {name(p)}</Button>}
      </td></tr>} /></QueryFeedback>
    {selected && <FormCard title={name(selected)} headerAction={<Button variant="ghost" onClick={() => setSelected(null)}>Close details</Button>}><FactList><Fact label="Payment terms" value={selected.paymentTerms} /><Fact label="Delivery terms" value={selected.deliveryTerms} /><Fact label="Notes" value={selected.notes} /><Fact label="Approved" value={selected.approvedAt} /></FactList></FormCard>}
    {action && <ConfirmedAction title={`${action.action} partnership`} description={`${action.action} the relationship with ${name(action.partner)}? This changes whether new network orders are allowed.`} destructive={action.action !== 'approve'} run={() => partnerAction(action.partner.id, action.action)} onClose={() => setAction(null)} onDone={() => { setAction(null); setSelected(null); void client.invalidateQueries({ queryKey: ['network', orgId] }) }} />}
  </section>
}
