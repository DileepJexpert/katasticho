import { useState, type FormEvent } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { Button, CheckboxInput, FormField, FormGrid, Modal, TextInput } from '@/design-system'
import { useInventoryAccess } from '@/features/inventory/inventory-access'
import { createWarehouse, updateWarehouse, deleteWarehouse, type Warehouse, type WarehouseRequest } from './warehouses-api'

const addressFields = [
  ['addressLine1', 'Address line 1', 255], ['addressLine2', 'Address line 2', 255],
  ['city', 'City', 100], ['state', 'State', 100], ['stateCode', 'State code', 5],
  ['postalCode', 'Postal code', 20], ['country', 'Country code', 2],
] as const

export function WarehouseFormModal({ warehouse, onClose, onSaved }: { warehouse?: Warehouse; onClose: () => void; onSaved: (id: string) => void }) {
  const access = useInventoryAccess()
  const client = useQueryClient()
  const [form, setForm] = useState<WarehouseRequest>(() => ({ code: warehouse?.code ?? '', name: warehouse?.name ?? '', addressLine1: warehouse?.addressLine1 ?? '', addressLine2: warehouse?.addressLine2 ?? '', city: warehouse?.city ?? '', state: warehouse?.state ?? '', stateCode: warehouse?.stateCode ?? '', postalCode: warehouse?.postalCode ?? '', country: warehouse?.country ?? 'IN', isDefault: warehouse?.isDefault ?? false, active: warehouse?.active ?? true }))
  const [error, setError] = useState('')
  const mutation = useMutation({ mutationFn: (request: WarehouseRequest) => warehouse ? updateWarehouse(warehouse.id, request) : createWarehouse(request), onSuccess: (saved) => { void client.invalidateQueries({ queryKey: ['warehouses'] }); onSaved(saved.id) } })
  function submit(event: FormEvent) {
    event.preventDefault()
    if (!access.manage || mutation.isPending) return
    if (!form.code.trim() || !form.name.trim() || (form.country && !/^[a-z]{2}$/i.test(form.country)) || (form.isDefault && !form.active)) { setError('Enter a code, name, two-letter country code, and keep the default warehouse active.'); return }
    setError('')
    mutation.mutate({ ...form, code: form.code.trim(), name: form.name.trim(), country: form.country?.toUpperCase() || null })
  }
  return <Modal isOpen size="lg" title={warehouse ? 'Edit warehouse' : 'Create warehouse'} onClose={() => { if (!mutation.isPending) onClose() }} error={error || mutation.error?.message} footer={<><Button variant="secondary" disabled={mutation.isPending} onClick={onClose}>Cancel</Button><Button type="submit" form="warehouse-form" loading={mutation.isPending} disabled={!access.manage}>Save warehouse</Button></>}>
    <form id="warehouse-form" onSubmit={submit} className="create-form-container"><FormGrid columns={2}>
      <FormField label="Code" required><TextInput required maxLength={20} value={form.code} onChange={(event) => setForm({ ...form, code: event.target.value })} disabled={mutation.isPending} /></FormField>
      <FormField label="Name" required><TextInput required maxLength={255} value={form.name} onChange={(event) => setForm({ ...form, name: event.target.value })} disabled={mutation.isPending} /></FormField>
      {addressFields.map(([key, label, max]) => <FormField key={key} label={label}><TextInput value={form[key] ?? ''} maxLength={max} onChange={(event) => setForm({ ...form, [key]: event.target.value })} disabled={mutation.isPending} /></FormField>)}
    </FormGrid>
    <CheckboxInput label="Default warehouse" checked={form.isDefault} disabled={mutation.isPending || warehouse?.isDefault} onChange={(event) => setForm({ ...form, isDefault: event.target.checked, active: event.target.checked ? true : form.active })} />
    {warehouse && <CheckboxInput label="Active" checked={form.active} disabled={mutation.isPending || form.isDefault} onChange={(event) => setForm({ ...form, active: event.target.checked })} />}
    <p className="cell-muted">Promoting a warehouse replaces the current default. To clear an existing default, promote another warehouse. The server assigns the default branch.</p>
    </form>
  </Modal>
}

export function WarehouseDeleteModal({ warehouse, onClose, onDeleted }: { warehouse: Warehouse; onClose: () => void; onDeleted: () => void }) {
  const access = useInventoryAccess()
  const client = useQueryClient()
  const mutation = useMutation({ mutationFn: () => deleteWarehouse(warehouse.id), onSuccess: () => { void client.invalidateQueries({ queryKey: ['warehouses'] }); onDeleted() } })
  return <Modal isOpen title="Remove warehouse" onClose={() => { if (!mutation.isPending) onClose() }} error={mutation.error?.message} footer={<><Button variant="secondary" disabled={mutation.isPending} onClick={onClose}>Keep warehouse</Button><Button variant="destructive" loading={mutation.isPending} disabled={!access.administer || warehouse.isDefault} onClick={() => { if (!mutation.isPending && access.administer && !warehouse.isDefault) mutation.mutate() }}>Remove warehouse</Button></>}>
    <p>Remove <strong>{warehouse.name}</strong>? The server rejects removal if this is the default warehouse or if it still holds stock. Existing records are retained through soft deletion.</p>
  </Modal>
}
