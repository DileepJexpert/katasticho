import { useSessionStore } from '@/shared/session/session-store'
import { listItems, type Item } from '@/features/items/items-api'
import { listContacts, type Contact } from '@/features/contacts/contacts-api'
import { listSelectableSuppliers, type Supplier } from '@/features/suppliers/suppliers-api'

export function useCanManagePricing() {
  return useSessionStore((state) => ['OWNER', 'ADMIN', 'ACCOUNTANT'].includes(state.user?.role ?? ''))
}

export async function searchPricingItems(search: string) {
  return (await listItems({ search, activeOnly: true, size: 25 })).content
}
export async function searchPricingCustomers(search: string) {
  return (await listContacts({ search, filter: 'CUSTOMER', size: 25 })).content.filter((contact) => contact.active)
}
export async function searchPricingSuppliers(search: string) {
  return (await listSelectableSuppliers(search)).content
}
export const entityId = (entity: { id: string }) => entity.id
export const itemLabel = (item: Item) => item.name
export const itemDescription = (item: Item) => item.sku ?? undefined
export const customerLabel = (contact: Contact) => contact.displayName
export const customerDescription = (contact: Contact) => [contact.companyName, contact.phone, contact.gstin].filter(Boolean).join(' / ')
export const supplierLabel = (supplier: Supplier) => supplier.name
export const supplierDescription = (supplier: Supplier) => [supplier.phone, supplier.gstin].filter(Boolean).join(' / ')
export const pricingError = (error: unknown) => error instanceof Error ? error.message : 'The request could not be completed.'
