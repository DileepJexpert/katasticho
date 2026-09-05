import { useQuery } from '@tanstack/react-query'
import { EntityPicker } from '@/design-system'
import { getItem, listItems, type Item } from '@/features/items/items-api'
import { getSupplier, listSelectableSuppliers, type Supplier } from '@/features/suppliers/suppliers-api'
import { listWarehouses, type Warehouse } from '@/features/warehouses/warehouses-api'
import { useSessionStore } from '@/shared/session/session-store'

export function PlanningItemPicker({ value, onChange, label = 'Item' }: { value: Item | null; onChange: (item: Item | null) => void; label?: string }) {
  return <EntityPicker<Item> ariaLabel={label} value={value?.id ?? null} selectedEntity={value} onSearch={async (search) => (await listItems({ search, activeOnly: true })).content} getOptionId={(i) => i.id} getOptionLabel={(i) => i.name} getOptionDescription={(i) => i.sku ?? ''} onChange={(_id, item) => onChange(item ?? null)} />
}
export function PlanningSupplierPicker({ value, onChange }: { value: Supplier | null; onChange: (supplier: Supplier | null) => void }) {
  return <EntityPicker<Supplier> ariaLabel="Supplier" value={value?.id ?? null} selectedEntity={value} onSearch={async (search) => (await listSelectableSuppliers(search)).content} getOptionId={(s) => s.id} getOptionLabel={(s) => s.name} getOptionDescription={(s) => [s.gstin, s.city].filter(Boolean).join(' / ')} onChange={(_id, supplier) => onChange(supplier ?? null)} />
}
export function PlanningWarehousePicker({ value, onChange, label = 'Warehouse' }: { value: Warehouse | null; onChange: (warehouse: Warehouse | null) => void; label?: string }) {
  return <EntityPicker<Warehouse> ariaLabel={label} value={value?.id ?? null} selectedEntity={value} onSearch={async (search) => (await listWarehouses()).filter((w) => w.active && `${w.name} ${w.code}`.toLowerCase().includes(search.toLowerCase()))} getOptionId={(w) => w.id} getOptionLabel={(w) => w.name} getOptionDescription={(w) => w.code} onChange={(_id, warehouse) => onChange(warehouse ?? null)} />
}
export function PlanningItemName({ id }: { id: string }) {
  const orgId = useSessionStore((s) => s.user?.orgId)
  const query = useQuery({ queryKey: ['planning-item-name', orgId, id], queryFn: () => getItem(id), staleTime: 60_000 })
  return <span>{query.data?.name ?? (query.isError ? 'Item name unavailable' : 'Loading item...')}</span>
}
export function PlanningSupplierName({ id }: { id: string }) {
  const orgId = useSessionStore((s) => s.user?.orgId)
  const query = useQuery({ queryKey: ['planning-supplier-name', orgId, id], queryFn: () => getSupplier(id), staleTime: 60_000 })
  return <span>{query.data?.name ?? (query.isError ? 'Supplier name unavailable' : 'Loading supplier...')}</span>
}
export function validNumber(value: string, minimum = 0) { return value.trim() !== '' && Number.isFinite(Number(value)) && Number(value) >= minimum }
