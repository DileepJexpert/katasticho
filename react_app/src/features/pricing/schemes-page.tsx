import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Tag } from 'lucide-react'
import { Button, DataTable, DirectoryToolbar, EmptyState, FilterTabs, Modal, Money, PageHeader, Quantity, SearchInput, StatusChip } from '@/design-system'
import { pricingError, useCanManagePricing } from '@/features/price-lists/pricing-shared'
import { formatDate } from '@/shared/format/format'
import { deleteScheme, listSchemes, schemeLabels, type Scheme } from './schemes-api'
import { SchemeFormModal } from './scheme-form-modal'
import { SchemePreviewModal } from './scheme-preview-modal'

export function SchemesPage() {
  const client = useQueryClient()
  const canManage = useCanManagePricing()
  const [search, setSearch] = useState('')
  const [status, setStatus] = useState('all')
  const [editor, setEditor] = useState<Scheme | 'new' | null>(null)
  const [removing, setRemoving] = useState<Scheme | null>(null)
  const [preview, setPreview] = useState(false)
  const schemes = useQuery({ queryKey: ['schemes', 'list'], queryFn: listSchemes })
  const remove = useMutation({ mutationFn: deleteScheme, onSuccess: () => { void client.invalidateQueries({ queryKey: ['schemes'] }); setRemoving(null) } })
  const rows = (schemes.data ?? []).filter((scheme) => (status === 'all' || scheme.active === (status === 'active')) && `${scheme.name} ${scheme.itemName ?? ''} ${scheme.supplierName ?? ''}`.toLowerCase().includes(search.toLowerCase()))
  return <section className="workspace-page">
    <PageHeader title="Trade schemes" eyebrow="Sales / Pricing" description="Manage promotional rates, free quantities, and company funding."
      actions={<><Button variant="secondary" onClick={() => setPreview(true)}>Preview scheme</Button>{canManage && <Button onClick={() => setEditor('new')}>New scheme</Button>}</>} />
    <section className="list-panel">
      <DirectoryToolbar actions={<Button onClick={() => void schemes.refetch()} variant="ghost">Refresh</Button>}>
        <SearchInput ariaLabel="Search schemes" value={search} onChange={setSearch} placeholder="Search scheme, item, or supplier" />
        <FilterTabs ariaLabel="Scheme status" activeValue={status} onChange={setStatus} items={[{ value: 'all', label: 'All' }, { value: 'active', label: 'Active' }, { value: 'inactive', label: 'Inactive' }]} />
      </DirectoryToolbar>
      {schemes.isPending ? <div className="directory-state" role="status">Loading trade schemes...</div> : schemes.isError ? <div className="directory-state directory-state--error" role="alert">{pricingError(schemes.error)}</div> : rows.length ?
        <DataTable caption="Trade schemes"><thead><tr><th scope="col">Scheme</th><th scope="col">Item / supplier</th><th scope="col">Benefit</th><th className="numeric-cell" scope="col">Minimum order</th><th scope="col">Validity</th><th scope="col">Status</th>{canManage && <th scope="col">Actions</th>}</tr></thead>
          <tbody>{rows.map((scheme) => <tr key={scheme.id}>
            <td><div className="cell-stack"><strong>{scheme.name}</strong><span className="cell-muted">{schemeLabels[scheme.schemeType] ?? scheme.schemeType}</span></div></td>
            <td><div className="cell-stack"><span>{scheme.itemName ?? (scheme.itemId || 'All items')}</span><span className="cell-muted">{scheme.supplierName ?? (scheme.supplierId || 'No funding supplier')}</span></div></td>
            <td>{scheme.schemeType === 'PERCENT_DISCOUNT' ? `${scheme.discountPercent ?? 0}%` : scheme.schemeType === 'SPECIAL_NET_RATE' ? <Money amount={scheme.specialNetRate} /> : <><Quantity value={scheme.buyQuantity} /> + <Quantity value={scheme.freeQuantity} /> free</>}</td>
            <td className="numeric-cell"><Quantity value={scheme.minOrderQuantity} /></td>
            <td><div className="cell-stack"><span>{scheme.validFrom ? formatDate(scheme.validFrom) : 'No start limit'}</span><span className="cell-muted">{scheme.validTo ? formatDate(scheme.validTo) : 'No end limit'}</span></div></td>
            <td><StatusChip status={scheme.active ? 'Active' : 'Inactive'} /></td>
            {canManage && <td><div className="table-row-actions"><Button variant="ghost" onClick={() => setEditor(scheme)}>Edit</Button><Button variant="ghost" onClick={() => { remove.reset(); setRemoving(scheme) }}>Delete</Button></div></td>}
          </tr>)}</tbody>
        </DataTable> : <EmptyState icon={Tag} title="No matching schemes" description="Create a scheme or adjust the filters to see existing promotions." />}
    </section>
    {editor && <SchemeFormModal scheme={editor === 'new' ? undefined : editor} onClose={() => setEditor(null)} />}
    {preview && <SchemePreviewModal onClose={() => setPreview(false)} />}
    {removing && <Modal isOpen title="Delete trade scheme" onClose={() => { if (!remove.isPending) setRemoving(null) }} error={remove.isError ? pricingError(remove.error) : null}
      footer={<><Button onClick={() => setRemoving(null)} disabled={remove.isPending} variant="secondary">Cancel</Button><Button disabled={!canManage} loading={remove.isPending} variant="destructive" onClick={() => remove.mutate(removing.id)}>Delete scheme</Button></>}><p>Delete <strong>{removing.name}</strong>? It will be excluded from future scheme selection. Existing documents keep their recorded amounts.</p></Modal>}
  </section>
}
