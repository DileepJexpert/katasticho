import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Button, DataTable, Fact, FactList, FormCard, FormGrid, Modal, Money as DesignMoney, Quantity, StatusChip } from '@/design-system'
import { TextField } from '@/design-system/text-field'
import { LocalDirectory } from '@/shared/workflows/local-directory'
import { QueryFeedback } from '@/shared/workflows/query-feedback'
import type { PortalApi, PortalDocument } from './portal-api'

function Money({ amount }: { amount: number | string | null | undefined }) {
  return <DesignMoney amount={amount} showCurrency={false} />
}

export function PortalOverview({ api, vendor }: { api: PortalApi; vendor: boolean }) {
  const query = useQuery({ queryKey: ['overview'], queryFn: api.dashboard })
  return <QueryFeedback query={query}>{query.data && <FormCard title="Account snapshot"><FactList><Fact label={vendor ? 'Bill balances payable to you' : 'Invoice balances due'} value={<Money amount={(vendor ? query.data.payableToYou : query.data.outstanding) ?? 0} />} /><Fact label={vendor ? 'Unpaid bills' : 'Open invoices'} value={vendor ? query.data.unpaidBillCount : query.data.openInvoiceCount} /></FactList><p>This snapshot covers up to 500 documents returned by the server. It is not a full account statement and does not include opening balances. Amounts omit a currency symbol because the portal API does not return the organisation currency.</p></FormCard>}</QueryFeedback>
}

export function PortalDocuments({ api, vendor }: { api: PortalApi; vendor: boolean }) {
  const query = useQuery({ queryKey: [vendor ? 'bills' : 'invoices'], queryFn: vendor ? api.bills : api.invoices })
  const title = vendor ? 'Your vendor bills' : 'Your invoices'
  return <><p>The server returns up to 100 recent documents. Search applies to that returned list.</p><QueryFeedback query={query}><LocalDirectory<PortalDocument> rows={query.data ?? []} caption={title} searchText={(row) => `${row.number} ${row.status} ${row.vendorBillNumber ?? ''}`} header={<tr><th>Document</th><th>Date</th><th>Due date</th><th>Status</th><th className="numeric-cell">Total</th><th className="numeric-cell">Balance due</th></tr>} renderRow={(row) => <tr key={row.id}><td className="table-code">{row.number}</td><td>{row.date}</td><td>{row.dueDate ?? '--'}</td><td><StatusChip status={row.status} /></td><td className="numeric-cell"><Money amount={row.total} /></td><td className="numeric-cell"><Money amount={row.balanceDue ?? 0} /></td></tr>} /></QueryFeedback></>
}

export function PortalOrders({ api }: { api: PortalApi }) {
  const query = useQuery({ queryKey: ['orders'], queryFn: api.orders })
  const [selected, setSelected] = useState<string | null>(null)
  return <><p>Up to 100 orders returned by the server. Opening an order does not confirm or dispatch it.</p><QueryFeedback query={query}><LocalDirectory rows={query.data ?? []} caption="Your orders" searchText={(row) => `${row.number} ${row.referenceNumber ?? ''} ${row.status}`} header={<tr><th>Order</th><th>Reference</th><th>Date</th><th>Status</th><th className="numeric-cell">Total</th></tr>} renderRow={(row) => <tr key={row.id}><td><Button variant="ghost" onClick={() => setSelected(row.id)}>{row.number}</Button></td><td>{row.referenceNumber ?? '--'}</td><td>{row.date}</td><td><StatusChip status={row.status} /></td><td className="numeric-cell"><Money amount={row.total} /></td></tr>} /></QueryFeedback>{selected && <OrderDetail api={api} id={selected} onClose={() => setSelected(null)} />}</>
}
function OrderDetail({ api, id, onClose }: { api: PortalApi; id: string; onClose: () => void }) {
  const query = useQuery({ queryKey: ['order', id], queryFn: () => api.order(id) })
  const order = query.data
  return <Modal isOpen size="xl" title={order?.number ?? 'Your order'} onClose={onClose}><QueryFeedback query={query}>{order && <><FactList><Fact label="Status" value={<StatusChip status={order.status} />} /><Fact label="Shipping" value={order.shippedStatus} /><Fact label="Invoicing" value={order.invoicedStatus} /><Fact label="Expected shipment" value={order.expectedShipmentDate} /><Fact label="Subtotal" value={<Money amount={order.subtotal} />} /><Fact label="Tax" value={<Money amount={order.taxAmount} />} /><Fact label="Total" value={<Money amount={order.total} />} /></FactList><DataTable caption="Order lines"><thead><tr><th>Item</th><th>Unit</th><th className="numeric-cell">Ordered</th><th className="numeric-cell">Shipped</th><th className="numeric-cell">Rate</th><th className="numeric-cell">Discount %</th><th className="numeric-cell">Amount</th></tr></thead><tbody>{order.lines?.map((line) => <tr key={line.id}><td>{line.description}</td><td>{line.unit}</td><td className="numeric-cell"><Quantity value={line.quantity} /></td><td className="numeric-cell"><Quantity value={line.quantityShipped} /></td><td className="numeric-cell"><Money amount={line.rate} /></td><td className="numeric-cell"><Quantity value={line.discountPct} /></td><td className="numeric-cell"><Money amount={line.amount} /></td></tr>)}</tbody></DataTable><p>{order.notes}</p></>}</QueryFeedback></Modal>
}

export function PortalLedger({ api }: { api: PortalApi }) {
  const [range, setRange] = useState({ from: '', to: '' })
  const [applied, setApplied] = useState<{ from: string; to: string } | null>(null)
  const query = useQuery({ queryKey: ['statement', applied], queryFn: () => api.statement(applied!.from, applied!.to), enabled: !!applied })
  const ledger = query.data
  return <><FormCard title="Account statement"><form onSubmit={(e) => { e.preventDefault(); if (range.from && range.to && range.from <= range.to) setApplied({ ...range }) }}><FormGrid><TextField label="From date" type="date" required value={range.from} onChange={(e) => setRange({ ...range, from: e.target.value })} /><TextField label="To date" type="date" required min={range.from} value={range.to} onChange={(e) => setRange({ ...range, to: e.target.value })} /></FormGrid><Button type="submit" disabled={!range.from || !range.to || range.from > range.to}>Load statement</Button></form></FormCard>{applied && <QueryFeedback query={query}>{ledger && <><FactList><Fact label="Opening balance" value={<Money amount={ledger.openingBalance} />} /><Fact label="Closing balance" value={<Money amount={ledger.closingBalance} />} /><Fact label="Invoiced" value={<Money amount={ledger.totalInvoiced} />} /><Fact label="Paid" value={<Money amount={ledger.totalPaid} />} /></FactList><LocalDirectory rows={ledger.entries.map((entry, index) => ({ ...entry, id: `${entry.referenceId}-${index}` }))} caption="Statement entries" searchText={(row) => `${row.number} ${row.description} ${row.type}`} header={<tr><th>Date</th><th>Type</th><th>Document</th><th>Description</th><th className="numeric-cell">Debit</th><th className="numeric-cell">Credit</th><th className="numeric-cell">Balance</th></tr>} renderRow={(row) => <tr key={row.id}><td>{row.date}</td><td>{row.type}</td><td className="table-code">{row.number}</td><td>{row.description}</td><td className="numeric-cell"><Money amount={row.debit} /></td><td className="numeric-cell"><Money amount={row.credit} /></td><td className="numeric-cell"><Money amount={row.runningBalance} /></td></tr>} /></>}</QueryFeedback>}</>
}
