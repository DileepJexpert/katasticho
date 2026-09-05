import { useState } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { Link, useParams } from 'react-router-dom'
import { Button, DataTable, Fact, FactList, FormCard, Money, PageHeader, Quantity, StatusChip } from '@/design-system'
import { useSessionStore } from '@/shared/session/session-store'
import { WorkspaceBoundary } from '@/shared/workflows/workspace-boundary'
import { QueryFeedback } from '@/shared/workflows/query-feedback'
import { LocalDirectory } from '@/shared/workflows/local-directory'
import { ConfirmedAction } from '@/shared/workflows/confirmed-action'
import { allowedOrderActions, getNetworkEvents, getNetworkOrder, listNetworkOrders, networkOrderAction, networkRoles, networkWriteBlockers, type OrderAction } from './partner-network-api'

export function NetworkOrdersPage({ direction }: { direction: 'incoming' | 'outgoing' }) {
  return <WorkspaceBoundary roles={networkRoles}><OrdersWorkspace key={direction} direction={direction} /></WorkspaceBoundary>
}
function OrdersWorkspace({ direction }: { direction: 'incoming' | 'outgoing' }) {
  const orgId = useSessionStore((s) => s.user!.orgId)
  const query = useQuery({ queryKey: ['network', orgId, 'orders', direction], queryFn: () => listNetworkOrders(direction) })
  return <section className="workspace-page"><PageHeader eyebrow="Partner network" title={direction === 'incoming' ? 'Incoming network orders' : 'Outgoing network orders'} description="Cross-organisation order history. Tracking is separate from local stock and accounting documents." />
    <p className="banner">{networkWriteBlockers.order}</p>
    <QueryFeedback query={query}><LocalDirectory rows={query.data ?? []} caption="Network orders" searchText={(o) => `${o.orderNumber} ${o.buyerOrgName} ${o.sellerOrgName} ${o.status}`}
      header={<tr><th>Order</th><th>Buyer</th><th>Seller</th><th>Requested delivery</th><th>Status</th><th className="numeric-cell">Ordered value</th></tr>}
      renderRow={(o) => <tr key={o.id}><td><Link className="table-row-link table-code" to={`/partner-network/orders/${o.id}`}>{o.orderNumber}</Link></td><td>{o.buyerOrgName}</td><td>{o.sellerOrgName}</td><td>{o.requestedDeliveryDate || '--'}</td><td><StatusChip status={o.status} /></td><td className="numeric-cell"><Money amount={o.totalAmount} /></td></tr>} /></QueryFeedback>
  </section>
}

export function NetworkOrderDetailPage() {
  const { orderId = '' } = useParams()
  return <WorkspaceBoundary roles={networkRoles}><OrderDetail key={orderId} id={orderId} /></WorkspaceBoundary>
}
function OrderDetail({ id }: { id: string }) {
  const orgId = useSessionStore((s) => s.user!.orgId)
  const client = useQueryClient()
  const query = useQuery({ queryKey: ['network', orgId, 'order', id], queryFn: () => getNetworkOrder(id) })
  const events = useQuery({ queryKey: ['network', orgId, 'events', id], queryFn: () => getNetworkEvents(id), enabled: !!query.data })
  const [action, setAction] = useState<OrderAction | null>(null)
  const order = query.data
  return <section className="workspace-page"><Link className="table-row-link" to={order?.sellerOrgId === orgId ? '/partner-network/incoming' : '/partner-network/outgoing'}>Back to network orders</Link>
    <PageHeader eyebrow="Partner network" title={order?.orderNumber ?? 'Network order'} />
    <QueryFeedback query={query}>{order && <>
      <FormCard title="Order summary" headerAction={<StatusChip status={order.status} />}><FactList><Fact label="Buyer" value={order.buyerOrgName} /><Fact label="Seller" value={order.sellerOrgName} /><Fact label="Requested delivery" value={order.requestedDeliveryDate} /><Fact label="Original ordered value" value={<Money amount={order.totalAmount} />} /><Fact label="Buyer notes" value={order.buyerNotes} /><Fact label="Seller notes" value={order.sellerNotes} /></FactList>
        {allowedOrderActions(order, orgId).map((value) => <Button key={value} variant="secondary" onClick={() => setAction(value)}>{value === 'deliver' ? 'Confirm delivery tracking' : value === 'dispatch' ? 'Mark dispatched (tracking)' : `${value} order`}</Button>)}
      </FormCard>
      <p className="banner">Dispatch and delivery here update the network record only. Use delivery challans and goods receipts for stock, and invoices/bills for accounting. Ordered totals are not recalculated after partial confirmation.</p>
      <DataTable caption="Network order lines"><thead><tr><th>Product</th><th className="numeric-cell">Ordered</th><th className="numeric-cell">Confirmed</th><th className="numeric-cell">Dispatched</th><th className="numeric-cell">Unit price</th><th className="numeric-cell">Ordered amount</th><th>Status</th></tr></thead><tbody>{order.lines.map((line) => <tr key={line.id}><td>{line.displayName ?? 'Product name unavailable'}</td><td className="numeric-cell"><Quantity value={line.orderedQty} /></td><td className="numeric-cell"><Quantity value={line.confirmedQty} /></td><td className="numeric-cell"><Quantity value={line.dispatchedQty} /></td><td className="numeric-cell"><Money amount={line.unitPrice} /></td><td className="numeric-cell"><Money amount={line.lineTotal} /></td><td><StatusChip status={line.status} /></td></tr>)}</tbody></DataTable>
      <FormCard title="Document references" description={networkWriteBlockers.linking}>
        {order.buyerOrgId === orgId && order.buyerPoId && <Link className="table-row-link" to={`/purchase-orders/${order.buyerPoId}`}>Open buyer purchase order</Link>}
        {order.sellerOrgId === orgId && order.sellerSoId && <Link className="table-row-link" to={`/sales-orders/${order.sellerSoId}`}>Open seller sales order</Link>}
      </FormCard>
      <FormCard title="Order activity"><QueryFeedback query={events}><LocalDirectory rows={events.data ?? []} caption="Network activity" searchText={(e) => e.eventType} header={<tr><th>Time</th><th>Event</th><th>Organisation</th><th>Reason</th></tr>} renderRow={(e) => <tr key={e.id}><td>{e.createdAt}</td><td>{e.eventType.replaceAll('_', ' ')}</td><td>{e.actorOrgId === order.buyerOrgId ? order.buyerOrgName : e.actorOrgId === order.sellerOrgId ? order.sellerOrgName : 'Organisation unavailable'}</td><td>{typeof e.payload?.reason === 'string' ? e.payload.reason : '--'}</td></tr>} /></QueryFeedback></FormCard>
    </>}</QueryFeedback>
    {action && <ConfirmedAction title={`${action} network order`} description={action === 'dispatch' || action === 'deliver' ? 'Update tracking status only? This will not move inventory or post accounting entries.' : `Confirm ${action} for this placed order?`} destructive={action === 'cancel' || action === 'reject'} run={() => networkOrderAction(id, action)} onClose={() => setAction(null)} onDone={() => { setAction(null); void client.invalidateQueries({ queryKey: ['network', orgId] }) }} />}
  </section>
}
