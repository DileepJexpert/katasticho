import { useState } from 'react'
import { Link } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { Button, CheckboxInput, FilterTabs, FormField, FormGrid, SelectInput, DataTable, Modal, Money, PageHeader, StatusChip } from '@/design-system'
import { TextField } from '@/design-system/text-field'
import { useSessionStore } from '@/shared/session/session-store'
import { createFranchiseNode, updateFranchiseNode, deleteFranchiseNode, listFranchiseNodes, getFranchisePolicy, saveFranchisePolicy, listRoyaltySettlements, franchiseIntegrationNotice, type FranchiseNode, type FranchiseNodeRequest, type FranchiseCatalogPolicy } from './franchise-api'

const emptyNode: FranchiseNodeRequest = { nodeCode: '', nodeName: '', nodeType: 'FOFO', contactEmail: '', phone: '', city: '', stateCode: '', royaltyRatePercent: 5, fixedMonthlyFee: 0, active: true }

export function FranchisePage() {
  const user = useSessionStore((s) => s.user)
  return <FranchisePageWorkspace key={`${user?.orgId}:${user?.id}:${user?.role}`} />
}

function FranchisePageWorkspace() {
  const user = useSessionStore((s) => s.user)
  const canWrite = ['OWNER', 'ADMIN'].includes(user?.role ?? '')
  const canReadSettlements = ['OWNER', 'ADMIN', 'ACCOUNTANT', 'VIEWER'].includes(user?.role ?? '')
  const [tab, setTab] = useState('nodes')
  const [search, setSearch] = useState('')
  const [editing, setEditing] = useState<FranchiseNode | 'new' | null>(null)
  const [deleting, setDeleting] = useState<FranchiseNode | null>(null)
  const client = useQueryClient()
  const nodes = useQuery({ queryKey: ['franchise-nodes', user?.orgId], queryFn: listFranchiseNodes })
  const policy = useQuery({ queryKey: ['franchise-policy', user?.orgId], queryFn: getFranchisePolicy, enabled: tab === 'policy' })
  const settlements = useQuery({ queryKey: ['franchise-settlements', user?.orgId], queryFn: () => listRoyaltySettlements(), enabled: tab === 'royalties' && canReadSettlements })
  const remove = useMutation({ mutationFn: deleteFranchiseNode, onSuccess: () => { client.invalidateQueries({ queryKey: ['franchise-nodes'] }); setDeleting(null) } })
  const visible = (nodes.data ?? []).filter((n) => `${n.nodeCode} ${n.nodeName} ${n.city ?? ''}`.toLowerCase().includes(search.toLowerCase()))
  return <section className="workspace-page">
    <PageHeader eyebrow="Partner network" title="Franchise Operations & Multi-Store Network" description="Manage store records and governance policies. Integration availability is shown explicitly."
      actions={canWrite && <Button onClick={() => setEditing('new')}>Add Franchise Store</Button>} />
    <div className="banner" role="status">{franchiseIntegrationNotice}</div>
    <FilterTabs ariaLabel="Franchise sections" activeValue={tab} onChange={setTab} items={[{ value: 'nodes', label: 'Stores' }, { value: 'policy', label: 'Catalog policy' }, ...(canReadSettlements ? [{ value: 'royalties', label: 'Royalty Settlements' }] : [])]} />
    {tab === 'nodes' && <>
      <TextField label="Search stores" value={search} onChange={(e) => setSearch(e.target.value)} />
      {nodes.isError ? <div role="alert">{nodes.error.message}<Button onClick={() => nodes.refetch()}>Retry</Button></div> : nodes.isPending ? <p role="status">Loading stores...</p> : <DataTable caption="Franchise stores"><thead><tr><th>Code</th><th>Store</th><th>Type</th><th>City</th><th>Royalty rate</th><th className="numeric-cell">Monthly fee</th><th>Status</th><th>Actions</th></tr></thead><tbody>{visible.map((n) => <tr key={n.id}><td className="table-code">{n.nodeCode}</td><td><Link to={appRoutes.franchiseDetail(n.id)}>{n.nodeName}</Link></td><td>{n.nodeType}</td><td>{n.city || '-'}</td><td>{n.royaltyRatePercent}%</td><td className="numeric-cell"><Money amount={n.fixedMonthlyFee} /></td><td><StatusChip status={n.active ? 'ACTIVE' : 'INACTIVE'} /></td><td>{canWrite && <><Button variant="ghost" onClick={() => setEditing(n)}>Edit {n.nodeCode}</Button><Button variant="ghost" onClick={() => { remove.reset(); setDeleting(n) }}>Delete {n.nodeCode}</Button></>}</td></tr>)}</tbody></DataTable>}
    </>}
    {tab === 'policy' && (policy.isError ? <p role="alert">{policy.error.message}</p> : policy.data ? <PolicyEditor key={policy.data.id ?? 'default'} initial={policy.data} canWrite={canWrite} /> : <p role="status">Loading policy...</p>)}
    {tab === 'royalties' && canReadSettlements && <>
      <p>Existing settlements are read-only. Creation and invoice generation await the backend integration.</p>
      {settlements.isError ? <p role="alert">{settlements.error.message}</p> : settlements.isPending ? <p role="status">Loading settlements...</p> : <DataTable caption="Royalty history"><thead><tr><th>Store</th><th>Period</th><th className="numeric-cell">Royalty</th><th className="numeric-cell">Fixed fee</th><th className="numeric-cell">Total</th><th>Status</th></tr></thead><tbody>{settlements.data.map((r) => <tr key={r.id}><td>{r.nodeCode} - {r.nodeName}</td><td>{r.periodStart} to {r.periodEnd}</td><td className="numeric-cell"><Money amount={r.royaltyAmount} /></td><td className="numeric-cell"><Money amount={r.fixedFeeAmount} /></td><td className="numeric-cell"><Money amount={r.totalSettlementAmount} /></td><td><StatusChip status={r.status} /></td></tr>)}</tbody></DataTable>}
    </>}
    {editing && <NodeEditor key={editing === 'new' ? 'new' : editing.id} node={editing} onClose={() => setEditing(null)} />}
    <Modal isOpen={!!deleting} title="Delete franchise store" description={`Delete ${deleting?.nodeName ?? ''}? This removes the store record; it is not a deactivation.`} onClose={() => { if (!remove.isPending) setDeleting(null) }} error={remove.error?.message}
      footer={<><Button variant="secondary" disabled={remove.isPending} onClick={() => setDeleting(null)}>Cancel</Button><Button variant="destructive" disabled={remove.isPending} onClick={() => { if (deleting && canWrite) remove.mutate(deleting.id) }}>Delete store</Button></>}><p>Use Edit and clear Active if you only want to deactivate the store.</p></Modal>
  </section>
}

function NodeEditor({ node, onClose }: { node: FranchiseNode | 'new'; onClose: () => void }) {
  const [draft, setDraft] = useState<FranchiseNodeRequest>(() => node === 'new' ? { ...emptyNode } : { nodeCode: node.nodeCode, nodeName: node.nodeName, nodeType: node.nodeType, branchId: node.branchId, contactEmail: node.contactEmail ?? '', phone: node.phone ?? '', city: node.city ?? '', stateCode: node.stateCode ?? '', royaltyRatePercent: node.royaltyRatePercent, fixedMonthlyFee: node.fixedMonthlyFee, active: node.active })
  const client = useQueryClient()
  const save = useMutation({ mutationFn: () => node === 'new' ? createFranchiseNode(draft) : updateFranchiseNode(node.id, draft), onSuccess: () => { client.invalidateQueries({ queryKey: ['franchise-nodes'] }); onClose() } })
  const valid = !!draft.nodeCode.trim() && !!draft.nodeName.trim() && Number.isFinite(+draft.royaltyRatePercent) && +draft.royaltyRatePercent >= 0 && +draft.royaltyRatePercent <= 100 && Number.isFinite(+draft.fixedMonthlyFee) && +draft.fixedMonthlyFee >= 0
  return <Modal isOpen title={node === 'new' ? 'Add Franchise Store Branch' : 'Edit franchise store'} onClose={() => { if (!save.isPending) onClose() }} error={save.error?.message}
    footer={<><Button variant="secondary" disabled={save.isPending} onClick={onClose}>Cancel</Button><Button disabled={!valid || save.isPending} onClick={() => save.mutate()}>{node === 'new' ? 'Create Store' : 'Save store'}</Button></>}>
    <FormGrid>
      <TextField label="Store code" value={draft.nodeCode} disabled={node !== 'new'} onChange={(e) => setDraft({ ...draft, nodeCode: e.target.value.trim().toUpperCase() })} required />
      <TextField label="Store name" value={draft.nodeName} onChange={(e) => setDraft({ ...draft, nodeName: e.target.value })} required />
      <FormField label="Ownership model"><SelectInput value={draft.nodeType} onChange={(e) => setDraft({ ...draft, nodeType: e.target.value })}>{['FOFO', 'COCO', 'FICO'].map((type) => <option key={type}>{type}</option>)}</SelectInput></FormField>
      <TextField label="Contact email" type="email" value={draft.contactEmail ?? ''} onChange={(e) => setDraft({ ...draft, contactEmail: e.target.value })} />
      <TextField label="Phone" value={draft.phone ?? ''} onChange={(e) => setDraft({ ...draft, phone: e.target.value })} />
      <TextField label="City" value={draft.city ?? ''} onChange={(e) => setDraft({ ...draft, city: e.target.value })} />
      <TextField label="State code" value={draft.stateCode ?? ''} onChange={(e) => setDraft({ ...draft, stateCode: e.target.value })} />
      <TextField label="Royalty rate (%)" type="number" min="0" max="100" step="0.01" value={draft.royaltyRatePercent} onChange={(e) => setDraft({ ...draft, royaltyRatePercent: e.target.value })} />
      <TextField label="Fixed monthly fee" type="number" min="0" step="0.01" value={draft.fixedMonthlyFee} onChange={(e) => setDraft({ ...draft, fixedMonthlyFee: e.target.value })} />
      <CheckboxInput label="Active" checked={draft.active} onChange={(e) => setDraft({ ...draft, active: e.target.checked })} />
    </FormGrid>
  </Modal>
}

function PolicyEditor({ initial, canWrite }: { initial: FranchiseCatalogPolicy; canWrite: boolean }) {
  const [draft, setDraft] = useState(initial)
  const client = useQueryClient()
  const save = useMutation({ mutationFn: () => saveFranchisePolicy(draft), onSuccess: (data) => { setDraft(data); client.invalidateQueries({ queryKey: ['franchise-policy'] }) } })
  const valid = [draft.minMarginPercent, draft.maxDiscountFromMrpPercent].every((n) => Number.isFinite(+n) && +n >= 0 && +n <= 100)
  return <div className="document-card"><h2>Catalog policy</h2><p>These are stored preferences only; the unavailable integrations above will not execute.</p>
    {save.isError && <p role="alert">{save.error.message}</p>}{save.isSuccess && <p role="status">Policy saved.</p>}
    <FormGrid><TextField label="Maximum discount from MRP (%)" type="number" min="0" max="100" value={draft.maxDiscountFromMrpPercent} onChange={(e) => setDraft({ ...draft, maxDiscountFromMrpPercent: e.target.value })} disabled={!canWrite} />
      <TextField label="Minimum margin (%)" type="number" min="0" max="100" value={draft.minMarginPercent} onChange={(e) => setDraft({ ...draft, minMarginPercent: e.target.value })} disabled={!canWrite} />
      <CheckboxInput label="Auto-sync new items preference" checked={draft.autoSyncNewItems} onChange={(e) => setDraft({ ...draft, autoSyncNewItems: e.target.checked })} disabled={!canWrite} />
      <CheckboxInput label="Allow branch price override preference" checked={draft.allowBranchPriceOverride} onChange={(e) => setDraft({ ...draft, allowBranchPriceOverride: e.target.checked })} disabled={!canWrite} />
    </FormGrid><Button disabled={!canWrite || !valid || save.isPending} onClick={() => save.mutate()}>Save policy</Button>
  </div>
}
