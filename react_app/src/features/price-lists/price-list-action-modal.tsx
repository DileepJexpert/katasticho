import { useState, type FormEvent } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { Button, EntityPicker, FormField, FormGrid, Modal, NumberInput } from '@/design-system'
import type { Item } from '@/features/items/items-api'
import type { Contact } from '@/features/contacts/contacts-api'
import { addPriceListTier, assignPriceListCustomer, deletePriceList, deletePriceListTier, unassignPriceListCustomer, type PriceList, type PriceListCustomer, type PriceListItem } from './price-lists-api'
import { customerDescription, customerLabel, entityId, itemDescription, itemLabel, pricingError, searchPricingCustomers, searchPricingItems, useCanManagePricing } from './pricing-shared'

export type PriceListAction = { kind: 'tier' | 'customer' | 'delete' } | { kind: 'remove-tier'; tier: PriceListItem } | { kind: 'remove-customer'; customer: PriceListCustomer }

export function PriceListActionModal({ list, action, onClose, onDeleted }: { list: PriceList; action: PriceListAction; onClose: () => void; onDeleted: () => void }) {
  const client = useQueryClient()
  const canManage = useCanManagePricing()
  const [item, setItem] = useState<Item | null>(null)
  const [customer, setCustomer] = useState<Contact | null>(null)
  const [quantity, setQuantity] = useState('1')
  const [price, setPrice] = useState('')
  const [validation, setValidation] = useState('')
  const labels = { tier: 'Add item tier', customer: 'Assign customer', delete: 'Retire price list', 'remove-tier': 'Remove item tier', 'remove-customer': 'Remove customer assignment' }
  const save = useMutation({
    mutationFn: async (): Promise<void> => {
      if (!canManage) throw new Error('Your role cannot maintain pricing.')
      switch (action.kind) {
        case 'tier': await addPriceListTier(list.id, { itemId: item!.id, minQuantity: Number(quantity), price: Number(price) }); return
        case 'customer': await assignPriceListCustomer(list.id, customer!.id); return
        case 'delete': return deletePriceList(list.id)
        case 'remove-tier': return deletePriceListTier(action.tier.id)
        case 'remove-customer': return unassignPriceListCustomer(list.id, action.customer.id)
      }
    },
    onSuccess: () => {
      void client.invalidateQueries({ queryKey: ['price-lists'] })
      void client.invalidateQueries({ queryKey: ['contacts'] })
      if (action.kind === 'delete') onDeleted()
      else onClose()
    },
  })
  function submit(event: FormEvent) {
    event.preventDefault()
    if (save.isPending || !canManage) return
    if (action.kind === 'tier' && (!item || !quantity.trim() || !price.trim() || !Number.isFinite(Number(quantity)) || Number(quantity) < 0.0001 || !Number.isFinite(Number(price)) || Number(price) < 0)) {
      setValidation('Select an item, enter a positive minimum quantity, and a price of zero or more.')
      return
    }
    if (action.kind === 'customer' && !customer) { setValidation('Select a customer.'); return }
    setValidation('')
    save.mutate()
  }
  return <Modal isOpen title={labels[action.kind]} onClose={() => { if (!save.isPending) onClose() }} error={validation || (save.isError ? pricingError(save.error) : null)}
    footer={<><Button variant="secondary" disabled={save.isPending} onClick={onClose}>Cancel</Button><Button form="price-list-action" type="submit" loading={save.isPending} disabled={!canManage} variant={['delete', 'remove-tier', 'remove-customer'].includes(action.kind) ? 'destructive' : 'primary'}>{labels[action.kind]}</Button></>}>
    <form id="price-list-action" onSubmit={submit} className="create-form-container">
      {action.kind === 'tier' && <>
        <FormField label="Item" required><EntityPicker<Item> ariaLabel="Search tier item" value={item?.id ?? null} selectedEntity={item} onChange={(_id, value) => setItem(value ?? null)} onSearch={searchPricingItems} getOptionId={entityId} getOptionLabel={itemLabel} getOptionDescription={itemDescription} disabled={save.isPending} /></FormField>
        <FormGrid columns={2}>
          <FormField label="Minimum quantity" required><NumberInput value={quantity} onChange={(event) => setQuantity(event.target.value)} min={0.0001} step="any" required disabled={save.isPending} /></FormField>
          <FormField label="Unit price" required><NumberInput currencyPrefix={list.currency ?? undefined} value={price} onChange={(event) => setPrice(event.target.value)} min={0} step="any" required disabled={save.isPending} /></FormField>
        </FormGrid>
        <p className="cell-muted">The highest eligible quantity tier determines the rate. An item cannot have two tiers at the same minimum quantity.</p>
      </>}
      {action.kind === 'customer' && <>
        <FormField label="Customer" required><EntityPicker<Contact> ariaLabel="Search customer assignment" value={customer?.id ?? null} selectedEntity={customer} onChange={(_id, value) => setCustomer(value ?? null)} onSearch={searchPricingCustomers} getOptionId={entityId} getOptionLabel={customerLabel} getOptionDescription={customerDescription} disabled={save.isPending} /></FormField>
        <p className="cell-muted">Assigning a customer replaces their current pinned price list with {list.name}.</p>
      </>}
      {action.kind === 'delete' && <p>Retire <strong>{list.name}</strong>? It will no longer supply prices for future documents. Existing documents retain their recorded rates. {list.isDefault ? 'This is the current organisation default.' : ''}</p>}
      {action.kind === 'remove-tier' && <p>Remove the {action.tier.minQuantity} quantity tier for <strong>{action.tier.itemName ?? action.tier.itemId}</strong>? Future pricing will use the next eligible tier or fallback rate.</p>}
      {action.kind === 'remove-customer' && <p>Clear the pinned price list for <strong>{action.customer.displayName}</strong>? Future pricing will fall back to the organisation default or document rate.</p>}
    </form>
  </Modal>
}
