import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Button, EntityPicker, FormField, FormGrid, Modal, PageHeader, StatusChip } from '@/design-system'
import { TextField } from '@/design-system/text-field'
import { listOrgUsers } from '@/features/settings/settings-api'
import { useSessionStore } from '@/shared/session/session-store'
import { ConfirmedAction } from '@/shared/workflows/confirmed-action'
import { LocalDirectory } from '@/shared/workflows/local-directory'
import { QueryFeedback } from '@/shared/workflows/query-feedback'
import { WorkspaceBoundary } from '@/shared/workflows/workspace-boundary'
import { createAssignment, deleteAssignment, endAssignment, listAssignments, updateFieldAssignment, type FieldSalesAssignment } from './field-sales-api'
import { planningRoutes, planningVans } from './field-planning-lookups'

function today() { const now = new Date(); return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}` }
function enabled(row: FieldSalesAssignment) { return row.active ?? row.isActive }
export function TeamAssignmentsPage() { return <WorkspaceBoundary roles={['OWNER', 'ADMIN']}><Assignments /></WorkspaceBoundary> }
function Assignments() {
  const orgId = useSessionStore((s) => s.user!.orgId)
  const client = useQueryClient()
  const [editor, setEditor] = useState<FieldSalesAssignment | 'new' | null>(null)
  const [action, setAction] = useState<{ row: FieldSalesAssignment; type: 'end' | 'deactivate' } | null>(null)
  const query = useQuery({ queryKey: ['field-sales', orgId, 'assignments', 'all'], queryFn: () => listAssignments(true) })
  const users = useQuery({ queryKey: ['field-sales', orgId, 'users', 'picker'], queryFn: listOrgUsers })
  const routes = useQuery({ queryKey: ['field-sales', orgId, 'routes', 'picker'], queryFn: planningRoutes })
  const vans = useQuery({ queryKey: ['field-sales', orgId, 'vans', 'picker'], queryFn: planningVans })
  const refresh = () => { setEditor(null); setAction(null); void client.invalidateQueries({ queryKey: ['field-sales'] }) }
  const names = (row: FieldSalesAssignment) => ({ person: users.data?.find((u) => u.id === row.salespersonId)?.fullName || users.data?.find((u) => u.id === row.salespersonId)?.email || row.salespersonName || 'User unavailable', route: routes.data?.find((r) => r.id === row.routeId)?.name || row.routeName || 'No route', van: vans.data?.find((v) => v.id === row.vanId)?.vehicleNumber || row.vanPlateNumber || 'No van' })
  return <section className="workspace-page"><PageHeader eyebrow="Field sales / Planning" title="Team Assignments" description="Assign organisation users to routes and vans for an effective date range. Beats belong to the route, not the assignment." actions={<Button onClick={() => setEditor('new')}>New Assignment</Button>} />{(users.error || routes.error || vans.error) && <p role="alert" className="form-error">Reference names could not be loaded. {users.error?.message ?? routes.error?.message ?? vans.error?.message}</p>}<QueryFeedback query={query}><LocalDirectory rows={query.data ?? []} caption="Team route assignments" searchText={(row) => `${Object.values(names(row)).join(' ')} ${row.territory ?? ''}`} header={<tr><th>Salesperson</th><th>Route</th><th>Van</th><th>Territory</th><th>Effective dates</th><th>Status</th><th>Actions</th></tr>} renderRow={(row) => { const name = names(row); const status = !enabled(row) ? 'INACTIVE' : row.effectiveTo && row.effectiveTo < today() ? 'ENDED' : row.effectiveFrom > today() ? 'SCHEDULED' : 'ACTIVE'; return <tr key={row.id}><td>{name.person}</td><td>{name.route}</td><td>{name.van}</td><td>{row.territory ?? '--'}</td><td>{row.effectiveFrom} to {row.effectiveTo ?? 'Open-ended'}</td><td><StatusChip status={status} /></td><td><div className="table-actions">{enabled(row) && <><Button variant="ghost" onClick={() => setEditor(row)}>Edit</Button><Button variant="secondary" onClick={() => setAction({ row, type: 'end' })}>End</Button><Button variant="destructive" onClick={() => setAction({ row, type: 'deactivate' })}>Deactivate</Button></>}</div></td></tr> }} /></QueryFeedback>
    {editor && <AssignmentEditor row={editor === 'new' ? undefined : editor} onClose={() => setEditor(null)} onDone={refresh} />}
    {action?.type === 'deactivate' && <ConfirmedAction title="Deactivate assignment" description={`Deactivate ${names(action.row).person}'s assignment? This removes it from active route eligibility.`} destructive run={() => deleteAssignment(action.row.id)} onClose={() => setAction(null)} onDone={refresh} />}
    {action?.type === 'end' && <EndAssignment row={action.row} onClose={() => setAction(null)} onDone={refresh} />}
  </section>
}
function AssignmentEditor({ row, onClose, onDone }: { row?: FieldSalesAssignment; onClose: () => void; onDone: () => void }) {
  const orgId = useSessionStore((s) => s.user!.orgId)
  const users = useQuery({ queryKey: ['field-sales', orgId, 'users', 'picker'], queryFn: listOrgUsers })
  const routes = useQuery({ queryKey: ['field-sales', orgId, 'routes', 'picker'], queryFn: planningRoutes })
  const vans = useQuery({ queryKey: ['field-sales', orgId, 'vans', 'picker'], queryFn: planningVans })
  const [person, setPerson] = useState(row?.salespersonId ?? '')
  const [route, setRoute] = useState(row?.routeId ?? '')
  const [van, setVan] = useState(row?.vanId ?? '')
  const [territory, setTerritory] = useState(row?.territory ?? '')
  const [from, setFrom] = useState(row?.effectiveFrom ?? today())
  const [to, setTo] = useState(row?.effectiveTo ?? '')
  const valid = !!person && !!route && !!from && (!to || to >= from) && (!row?.vanId || !!van) && users.data?.some((u) => u.id === person && u.active)
  const save = useMutation({ mutationFn: () => { const body = { salespersonId: person, routeId: route, vanId: van || null, territory, effectiveFrom: from, effectiveTo: to || null }; return row ? updateFieldAssignment(row.id, body) : createAssignment(body) }, onSuccess: onDone })
  return <Modal isOpen title={row ? 'Edit team assignment' : 'New team assignment'} onClose={() => { if (!save.isPending) onClose() }} error={save.error?.message ?? users.error?.message ?? routes.error?.message ?? vans.error?.message} footer={<><Button variant="secondary" disabled={save.isPending} onClick={onClose}>Cancel</Button><Button disabled={!valid || save.isPending} loading={save.isPending} onClick={() => save.mutate()}>Save assignment</Button></>}><FormGrid><FormField label="Salesperson"><EntityPicker ariaLabel="Assignment salesperson" value={person} onChange={(id) => setPerson(id ?? '')} options={(users.data ?? []).filter((u) => u.active)} getOptionId={(u) => u.id} getOptionLabel={(u) => u.fullName || u.email} getOptionDescription={(u) => `${u.email} / ${u.role}`} /></FormField><FormField label="Route"><EntityPicker ariaLabel="Assignment route" value={route} onChange={(id) => setRoute(id ?? '')} options={routes.data ?? []} getOptionId={(r) => r.id} getOptionLabel={(r) => r.name} getOptionDescription={(r) => r.code} /></FormField><FormField label="Van (optional)"><EntityPicker ariaLabel="Assignment van" value={van || null} onChange={(id) => setVan(id ?? '')} options={vans.data ?? []} getOptionId={(v) => v.id} getOptionLabel={(v) => v.vehicleNumber || v.code} /></FormField><TextField label="Territory" value={territory} onChange={(e) => setTerritory(e.target.value)} /><TextField label="Effective from" type="date" required value={from} onChange={(e) => setFrom(e.target.value)} /><TextField label="Effective to (optional)" type="date" min={from} value={to} onChange={(e) => setTo(e.target.value)} /></FormGrid>{row?.vanId && <p>The existing update API cannot clear a van. Select a replacement, or end this assignment and create a new one without a van.</p>}</Modal>
}
function EndAssignment({ row, onClose, onDone }: { row: FieldSalesAssignment; onClose: () => void; onDone: () => void }) {
  const [date, setDate] = useState(today() < row.effectiveFrom ? row.effectiveFrom : today())
  const save = useMutation({ mutationFn: () => endAssignment(row.id, date), onSuccess: onDone })
  return <Modal isOpen title="End assignment" onClose={() => { if (!save.isPending) onClose() }} error={save.error?.message} footer={<><Button variant="secondary" disabled={save.isPending} onClick={onClose}>Cancel</Button><Button disabled={!date || date < row.effectiveFrom || save.isPending} onClick={() => save.mutate()}>Confirm end date</Button></>}><TextField label="End date" type="date" min={row.effectiveFrom} value={date} onChange={(e) => setDate(e.target.value)} /><p>The backend applies the effective end date to this assignment.</p></Modal>
}
