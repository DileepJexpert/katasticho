import { useQuery } from '@tanstack/react-query'
import { Button, EntityPicker } from '@/design-system'
import { listItems, type Item } from '@/features/items/items-api'
import { listSelectableSuppliers, type Supplier } from '@/features/suppliers/suppliers-api'
import { listWarehouses, type Warehouse } from '@/features/warehouses/warehouses-api'

async function searchItems(search: string) { return (await listItems({ search, activeOnly: true, size: 25 })).content }
async function searchAllItems(search: string) { return (await listItems({ search, activeOnly: false, size: 25 })).content }
async function searchSuppliers(search: string) { return (await listSelectableSuppliers(search, 0, 25)).content }
const id = (entry: { id: string }) => entry.id
const name = (entry: { name: string }) => entry.name
const sku = (entry: Item) => entry.sku ?? undefined
const supplierDescription = (entry: Supplier) => [entry.gstin, entry.phone, entry.city].filter(Boolean).join(' | ')

export function InventoryItemPicker({ value, onChange, disabled, id: inputId, includeInactive = false }: { value: Item | null; onChange: (item: Item | null) => void; disabled?: boolean; id?: string; includeInactive?: boolean }) {
  return <EntityPicker<Item> id={inputId} ariaLabel="Search inventory item" value={value?.id ?? null} selectedEntity={value} onChange={(_id, item) => onChange(item ?? null)} onSearch={includeInactive ? searchAllItems : searchItems} getOptionId={id} getOptionLabel={name} getOptionDescription={sku} disabled={disabled} />
}
export function InventorySupplierPicker({ value, onChange, disabled, id: inputId }: { value: Supplier | null; onChange: (supplier: Supplier | null) => void; disabled?: boolean; id?: string }) {
  return <EntityPicker<Supplier> id={inputId} ariaLabel="Search inventory supplier" value={value?.id ?? null} selectedEntity={value} onChange={(_id, supplier) => onChange(supplier ?? null)} onSearch={searchSuppliers} getOptionId={id} getOptionLabel={name} getOptionDescription={supplierDescription} disabled={disabled} />
}
export function InventoryWarehousePicker({ value, onChange, disabled, id: inputId }: { value: Warehouse | null; onChange: (warehouse: Warehouse | null) => void; disabled?: boolean; id?: string }) {
  const query = useQuery({ queryKey: ['warehouses'], queryFn: listWarehouses })
  return <><EntityPicker<Warehouse> id={inputId} ariaLabel="Select inventory warehouse" value={value?.id ?? null} selectedEntity={value} onChange={(_id, warehouse) => onChange(warehouse ?? null)} options={(query.data ?? []).filter((entry) => entry.active)} getOptionId={id} getOptionLabel={name} getOptionDescription={(entry) => entry.code} disabled={disabled || query.isPending || query.isError} />{query.isError && <div role="alert">{query.error.message}<Button variant="secondary" disabled={disabled} onClick={() => void query.refetch()}>Retry warehouses</Button></div>}</>
}
