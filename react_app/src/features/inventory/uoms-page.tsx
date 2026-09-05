import { useMemo, useState } from 'react'
import type { FormEvent } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Scale } from 'lucide-react'
import { Button, CheckboxInput, DataTable, DirectoryToolbar, EmptyState, FilterTabs, FormField, FormGrid, Modal, PageHeader, SearchInput, SelectInput, StatusChip, TextInput } from '@/design-system'
import { createUom, deleteUom, getUoms, updateUom, UOM_CATEGORIES, type UomCategory, type UomRequest, type UomResponse } from '@/features/inventory/uoms-api'
import { useInventoryAccess } from './inventory-access'

type CategoryFilter = 'ALL' | UomCategory

const CATEGORY_LABELS: Record<UomCategory, string> = {
  COUNT: 'Count',
  WEIGHT: 'Weight',
  VOLUME: 'Volume',
  LENGTH: 'Length',
  PACKAGING: 'Packaging',
}

export function UomsPage() {
  const access = useInventoryAccess()
  const [editing, setEditing] = useState<UomResponse | 'new' | null>(null)
  const [filter, setFilter] = useState<CategoryFilter>('ALL')
  const [search, setSearch] = useState('')

  const uomsQuery = useQuery({
    queryKey: ['uoms'],
    queryFn: () => getUoms(),
  })

  const uoms = uomsQuery.data ?? []

  const filteredUoms = useMemo(() => {
    const query = search.trim().toLowerCase()
    return uoms.filter((uom) => {
      const matchesCategory = filter === 'ALL' || uom.category === filter
      if (!matchesCategory) return false

      if (!query) return true

      const matchesName = uom.name.toLowerCase().includes(query)
      const matchesAbbreviation = uom.abbreviation.toLowerCase().includes(query)
      return matchesName || matchesAbbreviation
    })
  }, [uoms, filter, search])

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Inventory / Measurement"
        title="Units of measure"
        description="Maintain measurement units and baseline flags. Unit metadata does not define conversion ratios or recalculate existing stock."
        actions={access.manage && <Button onClick={() => setEditing('new')}>New unit</Button>}
      />

      <section className="list-panel" aria-label="Units of measure directory">
        <DirectoryToolbar ariaLabel="Filter units of measure by category and search">
          <SearchInput
            onChange={setSearch}
            onClear={() => setSearch('')}
            placeholder="Search unit name or symbol..."
            value={search}
          />
          <FilterTabs
            activeValue={filter}
            ariaLabel="Filter units by category"
            items={[
              { value: 'ALL', label: 'All units', count: uoms.length },
              { value: 'COUNT', label: 'Count', count: uoms.filter((u) => u.category === 'COUNT').length },
              { value: 'WEIGHT', label: 'Weight', count: uoms.filter((u) => u.category === 'WEIGHT').length },
              { value: 'VOLUME', label: 'Volume', count: uoms.filter((u) => u.category === 'VOLUME').length },
              { value: 'LENGTH', label: 'Length', count: uoms.filter((u) => u.category === 'LENGTH').length },
              { value: 'PACKAGING', label: 'Packaging', count: uoms.filter((u) => u.category === 'PACKAGING').length },
            ]}
            onChange={(value) => setFilter(value as CategoryFilter)}
          />
        </DirectoryToolbar>

        {uomsQuery.isError ? (
          <div className="directory-state directory-state--error" role="alert">
            <strong>Units of measure could not be loaded.</strong>
            <p>Check your connection and permissions, then refresh the page.</p>
            <Button variant="secondary" onClick={() => void uomsQuery.refetch()}>Retry units</Button>
          </div>
        ) : uomsQuery.isLoading ? (
          <div aria-live="polite" className="directory-state">Loading units of measure...</div>
        ) : filteredUoms.length ? (
          <DataTable caption="Units of measure">
            <thead>
              <tr>
                <th scope="col">Unit name</th>
                <th scope="col">Abbreviation</th>
                <th scope="col">Category</th>
                <th scope="col">Baseline</th>
                <th scope="col">Status</th>
                {access.manage && <th scope="col">Actions</th>}
              </tr>
            </thead>
            <tbody>
              {filteredUoms.map((uom) => (
                <tr key={uom.id}>
                  <td><strong>{uom.name}</strong></td>
                  <td><code className="fact-value--mono">{uom.abbreviation}</code></td>
                  <td>
                    <span className="entity-picker__option-badge">
                      {CATEGORY_LABELS[uom.category] ?? uom.category}
                    </span>
                  </td>
                  <td>
                    <StatusChip status={uom.base ? 'Base unit' : 'Derived'} />
                  </td>
                  <td>
                    <StatusChip status={uom.active ? 'Active' : 'Inactive'} />
                  </td>
                  {access.manage && <td><Button variant="ghost" onClick={() => setEditing(uom)}>Edit {uom.abbreviation}</Button></td>}
                </tr>
              ))}
            </tbody>
          </DataTable>
        ) : (
          <EmptyState
            description={
              filter === 'ALL' && !search
                ? 'Units of measure will appear here when configured.'
                : 'No units of measure match the selected category or search query.'
            }
            icon={Scale}
            title={
              filter === 'ALL' && !search
                ? 'No units of measure available.'
                : 'No matching units.'
            }
          />
        )}
      </section>
      {editing && access.manage && <UomFormModal unit={editing === 'new' ? null : editing} onClose={() => setEditing(null)} />}
    </section>
  )
}

function UomFormModal({ unit, onClose }: { unit: UomResponse | null; onClose: () => void }) {
  const access = useInventoryAccess()
  const client = useQueryClient()
  const [form, setForm] = useState<UomRequest>({ name: unit?.name ?? '', abbreviation: unit?.abbreviation ?? '', category: unit?.category ?? 'COUNT', base: unit?.base ?? false, active: unit?.active ?? true })
  const [error, setError] = useState('')
  const [removing, setRemoving] = useState(false)
  const save = useMutation({
    mutationFn: async (action: 'save' | 'delete'): Promise<UomResponse | void> => action === 'delete' && unit ? deleteUom(unit.id) : unit ? updateUom(unit.id, form) : createUom(form),
    onSuccess: () => { void client.invalidateQueries({ queryKey: ['uoms'] }); void client.invalidateQueries({ queryKey: ['items'] }); onClose() },
  })
  function submit(event: FormEvent) {
    event.preventDefault()
    if (!access.manage || save.isPending || removing) return
    if (!form.name.trim() || !form.abbreviation.trim() || !UOM_CATEGORIES.includes(form.category)) { setError('Enter a unit name, abbreviation and supported category.'); return }
    setError(''); save.mutate('save')
  }
  return <Modal isOpen title={unit ? `Edit unit ${unit.abbreviation}` : 'New unit'} onClose={() => { if (!save.isPending) onClose() }} error={error || save.error?.message}>
    <form onSubmit={submit} className="create-form-container">
      <FormGrid columns={2}>
        <FormField label="Unit name" required><TextInput required maxLength={50} value={form.name} disabled={save.isPending || removing} onChange={(event) => setForm({ ...form, name: event.target.value })} /></FormField>
        <FormField label="Abbreviation" required><TextInput required maxLength={20} value={form.abbreviation} disabled={save.isPending || removing} onChange={(event) => setForm({ ...form, abbreviation: event.target.value })} /></FormField>
        <FormField label="Category" required><SelectInput value={form.category} disabled={save.isPending || removing} options={UOM_CATEGORIES.map((category) => ({ value: category, label: CATEGORY_LABELS[category] }))} onChange={(event) => setForm({ ...form, category: event.target.value as UomCategory })} /></FormField>
        <FormField label="Base unit"><CheckboxInput checked={form.base} disabled={save.isPending || removing} onChange={(event) => setForm({ ...form, base: event.target.checked })} /></FormField>
        <FormField label="Active"><CheckboxInput checked={form.active} disabled={save.isPending || removing} onChange={(event) => setForm({ ...form, active: event.target.checked })} /></FormField>
      </FormGrid>
      <p className="cell-muted">Changing a unit does not convert saved document quantities. This API has no conversion-ratio maintenance endpoint.</p>
      {removing && <div role="alert" className="banner banner--warning">Remove this unit from the directory? Existing references are not remapped. Deactivate it instead if it may still be in use.</div>}
      <div className="document-actions">
        <Button variant="secondary" disabled={save.isPending} onClick={onClose}>Cancel</Button>
        {unit && !removing && <Button variant="destructive" disabled={save.isPending} onClick={() => setRemoving(true)}>Remove unit</Button>}
        {removing ? <><Button variant="secondary" disabled={save.isPending} onClick={() => setRemoving(false)}>Keep unit</Button><Button variant="destructive" loading={save.isPending} onClick={() => { if (access.manage && !save.isPending) save.mutate('delete') }}>Confirm removal</Button></> : <Button type="submit" loading={save.isPending}>Save unit</Button>}
      </div>
    </form>
  </Modal>
}
