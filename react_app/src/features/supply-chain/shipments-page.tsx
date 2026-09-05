import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { Button, DataTable, Fact, FactList, FormCard, FormField, FormGrid, Modal, Money, PageHeader, Quantity, SelectInput, StatusChip } from '@/design-system'
import { TextField } from '@/design-system/text-field'
import type { Item } from '@/features/items/items-api'
import type { Warehouse } from '@/features/warehouses/warehouses-api'
import { useSessionStore } from '@/shared/session/session-store'
import { WorkspaceBoundary } from '@/shared/workflows/workspace-boundary'
import { QueryFeedback } from '@/shared/workflows/query-feedback'
import { ConfirmedAction } from '@/shared/workflows/confirmed-action'
import { LocalDirectory } from '@/shared/workflows/local-directory'
import { createShipment, getShipment, listShipments, planningReadRoles, planningRoles, shipmentAction } from './supply-chain-api'
import { PlanningItemName, PlanningItemPicker, PlanningWarehousePicker, validNumber } from './planning-pickers'
import { shipmentSchedule } from './shipment-schedule'

const trackingNotice = 'Shipment actions update logistics tracking only. They do not reserve, issue, receive or transfer stock, and do not post freight to the ledger. Use the corresponding inventory and accounting documents for those operations.'
export function SupplyShipmentsPage() { return <WorkspaceBoundary roles={planningReadRoles}><Shipments /></WorkspaceBoundary> }
function Shipments() {
  const user = useSessionStore((s) => s.user!)
  const client = useQueryClient()
  const navigate = useNavigate()
  const [create, setCreate] = useState(false)
  const query = useQuery({ queryKey: ['supply', user.orgId, 'shipments'], queryFn: listShipments })
  return <section className="workspace-page"><PageHeader eyebrow="Supply planning" title="Shipment tracking" description="Track planned, in-transit and delivered loads." actions={planningRoles.some((r) => r === user.role) && <Button onClick={() => setCreate(true)}>New tracking record</Button>} /><p className="banner">{trackingNotice}</p>
    <QueryFeedback query={query}><LocalDirectory rows={query.data ?? []} caption="Shipment tracking" searchText={(s) => `${s.shipmentNumber} ${s.carrier ?? ''} ${s.vehicleNumber ?? ''} ${s.status}`} header={<tr><th>Shipment</th><th>Type</th><th>Carrier</th><th>Vehicle</th><th>Status</th><th className="numeric-cell">Freight reference</th></tr>} renderRow={(s) => <tr key={s.id}><td><Link className="table-row-link table-code" to={`/supply-chain/shipments/${s.id}`}>{s.shipmentNumber}</Link></td><td>{s.shipmentType}</td><td>{s.carrier ?? '--'}</td><td>{s.vehicleNumber ?? '--'}</td><td><StatusChip status={s.status} /></td><td className="numeric-cell"><Money amount={s.freightCost} /></td></tr>} /></QueryFeedback>
    {create && <ShipmentEditor onClose={() => setCreate(false)} onDone={(id) => { void client.invalidateQueries({ queryKey: ['supply', user.orgId] }); if (useSessionStore.getState().user?.orgId === user.orgId) navigate(`/supply-chain/shipments/${id}`) }} />}
  </section>
}
function ShipmentEditor({ onClose, onDone }: { onClose: () => void; onDone: (id: string) => void }) {
  const [type, setType] = useState('OUTBOUND')
  const [origin, setOrigin] = useState<Warehouse | null>(null)
  const [destination, setDestination] = useState<Warehouse | null>(null)
  const [carrier, setCarrier] = useState('')
  const [vehicle, setVehicle] = useState('')
  const [freight, setFreight] = useState('0')
  const [notes, setNotes] = useState('')
  const [departure, setDeparture] = useState('')
  const [arrival, setArrival] = useState('')
  const schedule = shipmentSchedule(departure, arrival)
  const [lines, setLines] = useState<{ key: string; item: Item | null; qty: string; packages: string; weight: string; notes: string }[]>([{ key: crypto.randomUUID(), item: null, qty: '1', packages: '1', weight: '', notes: '' }])
  const valid = schedule.valid && validNumber(freight) && lines.length > 0 && lines.every((l) => l.item && validNumber(l.qty) && +l.qty > 0 && (!l.weight || validNumber(l.weight)) && validNumber(l.packages, 1) && Number.isInteger(+l.packages)) && (type !== 'TRANSFER' || (origin && destination && origin.id !== destination.id))
  const save = useMutation({ mutationFn: () => createShipment({ shipmentType: type, originWarehouseId: origin?.id, destinationWarehouseId: destination?.id, carrier, vehicleNumber: vehicle, freightCost: +freight, estimatedDeparture: schedule.estimatedDeparture, estimatedArrival: schedule.estimatedArrival, notes, lines: lines.map((l) => ({ itemId: l.item!.id, quantity: +l.qty, packages: +l.packages, ...(l.weight ? { weight: +l.weight } : {}), notes: l.notes })) }), onSuccess: (s) => onDone(s.id) })
  return <Modal isOpen size="lg" title="New shipment tracking record" error={save.error?.message} onClose={() => { if (!save.isPending) onClose() }} footer={<><Button variant="secondary" disabled={save.isPending} onClick={onClose}>Cancel</Button><Button disabled={!valid || save.isPending} onClick={() => save.mutate()}>Create tracking draft</Button></>}><p>{trackingNotice}</p>
    <FormGrid><FormField label="Shipment type"><SelectInput value={type} onChange={(e) => setType(e.target.value)}>{['OUTBOUND', 'INBOUND', 'TRANSFER'].map((v) => <option key={v}>{v}</option>)}</SelectInput></FormField><PlanningWarehousePicker label="Origin warehouse" value={origin} onChange={setOrigin} /><PlanningWarehousePicker label="Destination warehouse" value={destination} onChange={setDestination} /><TextField label="Carrier" value={carrier} onChange={(e) => setCarrier(e.target.value)} /><TextField label="Vehicle number" value={vehicle} onChange={(e) => setVehicle(e.target.value)} /><TextField label="Freight reference amount" type="number" min="0" step="any" value={freight} onChange={(e) => setFreight(e.target.value)} /><TextField label="Notes" value={notes} onChange={(e) => setNotes(e.target.value)} /></FormGrid>
    <FormGrid><TextField label="Estimated departure (local time)" type="datetime-local" value={departure} onChange={(e) => setDeparture(e.target.value)} /><TextField label="Estimated arrival (local time)" type="datetime-local" min={departure || undefined} value={arrival} onChange={(e) => setArrival(e.target.value)} error={!schedule.valid ? 'Arrival must not precede departure; use valid dates.' : undefined} /></FormGrid>
    {lines.map((line, index) => <FormCard key={line.key} title={`Line ${index + 1}`} headerAction={<Button variant="ghost" onClick={() => setLines(lines.filter((l) => l.key !== line.key))}>Remove line {index + 1}</Button>}><FormGrid><PlanningItemPicker label={`Shipment item ${index + 1}`} value={line.item} onChange={(item) => setLines(lines.map((l) => l.key === line.key ? { ...l, item } : l))} /><TextField label={`Quantity ${index + 1}`} type="number" min="0" step="any" value={line.qty} onChange={(e) => setLines(lines.map((l) => l.key === line.key ? { ...l, qty: e.target.value } : l))} /><TextField label={`Packages ${index + 1}`} type="number" min="1" step="1" value={line.packages} onChange={(e) => setLines(lines.map((l) => l.key === line.key ? { ...l, packages: e.target.value } : l))} /><TextField label={`Weight ${index + 1} (agreed carrier unit)`} type="number" min="0" step="any" value={line.weight} onChange={(e) => setLines(lines.map((l) => l.key === line.key ? { ...l, weight: e.target.value } : l))} /><TextField label={`Line notes ${index + 1}`} value={line.notes} onChange={(e) => setLines(lines.map((l) => l.key === line.key ? { ...l, notes: e.target.value } : l))} /></FormGrid></FormCard>)}
    <p>Weight has no unit field in the existing service; record the agreed unit in line notes. Document linking remains unavailable until the service validates reference ownership.</p>
    <Button variant="secondary" onClick={() => setLines([...lines, { key: crypto.randomUUID(), item: null, qty: '1', packages: '1', weight: '', notes: '' }])}>Add line</Button>
  </Modal>
}
export function SupplyShipmentDetailPage() {
  const { shipmentId = '' } = useParams()
  return <WorkspaceBoundary roles={planningReadRoles}><ShipmentDetail key={shipmentId} id={shipmentId} /></WorkspaceBoundary>
}
function ShipmentDetail({ id }: { id: string }) {
  const user = useSessionStore((s) => s.user!)
  const client = useQueryClient()
  const query = useQuery({ queryKey: ['supply', user.orgId, 'shipment', id], queryFn: () => getShipment(id) })
  const [action, setAction] = useState<'dispatch' | 'deliver' | 'cancel' | null>(null)
  const shipment = query.data
  const canWrite = planningRoles.some((r) => r === user.role)
  return <section className="workspace-page"><Link to="/supply-chain/shipments">Back to shipments</Link><PageHeader eyebrow="Supply planning" title={shipment?.shipmentNumber ?? 'Shipment'} /><p className="banner">{trackingNotice}</p>
    <QueryFeedback query={query}>{shipment && <><FormCard title="Tracking details" headerAction={<StatusChip status={shipment.status} />}><FactList><Fact label="Carrier" value={shipment.carrier} /><Fact label="Vehicle" value={shipment.vehicleNumber} /><Fact label="Actual departure" value={shipment.actualDeparture} /><Fact label="Actual arrival" value={shipment.actualArrival} /><Fact label="Notes" value={shipment.notes} /><Fact label="Freight reference" value={<Money amount={shipment.freightCost} />} /></FactList>
      {canWrite && <>{['DRAFT', 'READY'].includes(shipment.status) && <Button onClick={() => setAction('dispatch')}>Mark in transit</Button>}{shipment.status === 'IN_TRANSIT' && <Button onClick={() => setAction('deliver')}>Mark delivered</Button>}{!['DELIVERED', 'CANCELLED'].includes(shipment.status) && <Button variant="secondary" onClick={() => setAction('cancel')}>Cancel tracking record</Button>}</>}
    </FormCard><FactList><Fact label="Estimated departure" value={shipment.estimatedDeparture ? new Date(shipment.estimatedDeparture).toLocaleString() : '--'} /><Fact label="Estimated arrival" value={shipment.estimatedArrival ? new Date(shipment.estimatedArrival).toLocaleString() : '--'} /></FactList><DataTable caption="Shipment contents"><thead><tr><th>Item</th><th className="numeric-cell">Quantity</th><th>Packages</th><th className="numeric-cell">Weight (see notes for unit)</th><th>Notes</th></tr></thead><tbody>{shipment.lines.map((line) => <tr key={line.id}><td><PlanningItemName id={line.itemId} /></td><td className="numeric-cell"><Quantity value={line.quantity} /></td><td>{line.packages}</td><td className="numeric-cell">{line.weight == null ? '--' : <Quantity value={line.weight} />}</td><td>{line.notes ?? '--'}</td></tr>)}</tbody></DataTable></>}</QueryFeedback>
    {action && <ConfirmedAction title={`${action} shipment tracking`} description={trackingNotice} destructive={action === 'cancel'} run={() => shipmentAction(id, action)} onClose={() => setAction(null)} onDone={() => { setAction(null); void client.invalidateQueries({ queryKey: ['supply', user.orgId] }) }} />}
  </section>
}
