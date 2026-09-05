import { useState, type FormEvent } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { Button, CheckboxInput, FormField, FormGrid, Modal, NumberInput, SelectInput, TextAreaInput, TextInput } from '@/design-system'
import { useInventoryAccess } from '@/features/inventory/inventory-access'
import { createWarehouseZone, deleteWarehouseZone, updateWarehouseZone, type WarehouseZone, type WarehouseZoneUpdate } from './warehouses-api'

const zoneTypes = ['STORAGE', 'QUARANTINE', 'STAGING', 'CROSS_DOCK', 'RETURNS']

export function WarehouseZoneModal({ warehouseId, zone, onClose }: { warehouseId: string; zone?: WarehouseZone; onClose: () => void }) {
  const access = useInventoryAccess()
  const client = useQueryClient()
  const [code, setCode] = useState(zone?.code ?? '')
  const [name, setName] = useState(zone?.name ?? '')
  const [type, setType] = useState(zone?.zoneType ?? 'STORAGE')
  const [capacity, setCapacity] = useState(String(zone?.capacity ?? ''))
  const [controlled, setControlled] = useState(zone?.temperatureControlled ?? false)
  const [notes, setNotes] = useState(zone?.notes ?? '')
  const [error, setError] = useState('')
  const mutation = useMutation({
    mutationFn: (request: WarehouseZoneUpdate) => zone ? updateWarehouseZone(zone.id, request) : createWarehouseZone({ ...request, warehouseId, code: code.trim() }),
    onSuccess: () => { void client.invalidateQueries({ queryKey: ['warehouses', warehouseId, 'zones'] }); onClose() },
  })
  function submit(event: FormEvent) {
    event.preventDefault()
    if (mutation.isPending || !access.administer) return
    if (!code.trim() || !name.trim() || !zoneTypes.includes(type) || (capacity.trim() && (!Number.isFinite(Number(capacity)) || Number(capacity) < 0))) {
      setError('Enter a zone code, name, valid type, and a nonnegative capacity.'); return
    }
    if (zone?.capacity != null && !capacity.trim()) { setError('The existing API cannot clear a saved capacity. Enter a replacement value.'); return }
    setError('')
    mutation.mutate({ name: name.trim(), zoneType: type, capacity: capacity.trim() ? Number(capacity) : undefined, temperatureControlled: controlled, notes: notes.trim() })
  }
  return <Modal isOpen title={zone ? 'Edit storage zone' : 'Add storage zone'} onClose={() => { if (!mutation.isPending) onClose() }} error={error || mutation.error?.message} footer={<><Button variant="secondary" disabled={mutation.isPending} onClick={onClose}>Cancel</Button><Button form="warehouse-zone" type="submit" loading={mutation.isPending} disabled={!access.administer}>Save zone</Button></>}>
    <form id="warehouse-zone" className="create-form-container" onSubmit={submit}>
      <FormGrid columns={2}>
        <FormField label="Zone code" required><TextInput value={code} maxLength={20} required disabled={mutation.isPending || Boolean(zone)} onChange={(event) => setCode(event.target.value)} /></FormField>
        <FormField label="Zone name" required><TextInput value={name} maxLength={255} required disabled={mutation.isPending} onChange={(event) => setName(event.target.value)} /></FormField>
        <FormField label="Zone type" required><SelectInput value={type} disabled={mutation.isPending} onChange={(event) => setType(event.target.value)} options={zoneTypes.map((value) => ({ value, label: value.replaceAll('_', ' ') }))} /></FormField>
        <FormField label="Capacity"><NumberInput value={capacity} min={0} step="any" disabled={mutation.isPending} onChange={(event) => setCapacity(event.target.value)} /></FormField>
      </FormGrid>
      <CheckboxInput label="Temperature controlled" checked={controlled} disabled={mutation.isPending} onChange={(event) => setControlled(event.target.checked)} />
      <FormField label="Zone notes"><TextAreaInput value={notes} disabled={mutation.isPending} onChange={(event) => setNotes(event.target.value)} /></FormField>
      <p className="cell-muted">This changes zone configuration only. Current utilisation is read-only; stock movement and putaway are separate workflows.</p>
    </form>
  </Modal>
}

export function WarehouseZoneDeleteModal({ zone, onClose }: { zone: WarehouseZone; onClose: () => void }) {
  const access = useInventoryAccess()
  const client = useQueryClient()
  const mutation = useMutation({ mutationFn: () => deleteWarehouseZone(zone.id), onSuccess: () => { void client.invalidateQueries({ queryKey: ['warehouses', zone.warehouseId, 'zones'] }); onClose() } })
  return <Modal isOpen title="Remove storage zone" onClose={() => { if (!mutation.isPending) onClose() }} error={mutation.error?.message} footer={<><Button variant="secondary" disabled={mutation.isPending} onClick={onClose}>Keep zone</Button><Button variant="destructive" disabled={!access.administer} loading={mutation.isPending} onClick={() => { if (access.administer && !mutation.isPending) mutation.mutate() }}>Remove zone</Button></>}>
    <p>Remove <strong>{zone.name}</strong> ({zone.code}) from this warehouse's zone configuration? This does not move or reconcile stock. Check dependent storage and putaway work before continuing.</p>
  </Modal>
}
