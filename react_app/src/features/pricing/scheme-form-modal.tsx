import { useState, type FormEvent } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { Button, CheckboxInput, EntityPicker, FormField, FormGrid, Modal, NumberInput, SelectInput, TextInput } from '@/design-system'
import type { Item } from '@/features/items/items-api'
import type { Supplier } from '@/features/suppliers/suppliers-api'
import { entityId, itemDescription, itemLabel, pricingError, searchPricingItems, searchPricingSuppliers, supplierDescription, supplierLabel, useCanManagePricing } from '@/features/price-lists/pricing-shared'
import { createScheme, schemeLabels, updateScheme, validateScheme, type Scheme, type SchemeRequest, type SchemeType } from './schemes-api'

export function SchemeFormModal({ scheme, onClose }: { scheme?: Scheme; onClose: () => void }) {
  const client = useQueryClient()
  const canManage = useCanManagePricing()
  const [name, setName] = useState(scheme?.name ?? '')
  const [type, setType] = useState<SchemeType>(scheme?.schemeType ?? 'BUY_X_GET_Y')
  const [itemId, setItemId] = useState(scheme?.itemId ?? null)
  const [item, setItem] = useState<Item | null>(null)
  const [supplierId, setSupplierId] = useState(scheme?.supplierId ?? null)
  const [supplier, setSupplier] = useState<Supplier | null>(null)
  const [validFrom, setValidFrom] = useState(scheme?.validFrom ?? '')
  const [validTo, setValidTo] = useState(scheme?.validTo ?? '')
  const [active, setActive] = useState(scheme?.active ?? true)
  const [allowHalf, setAllowHalf] = useState(scheme?.allowHalfScheme ?? true)
  const [values, setValues] = useState({
    buyQuantity: String(scheme?.buyQuantity ?? ''), freeQuantity: String(scheme?.freeQuantity ?? ''),
    discountPercent: String(scheme?.discountPercent ?? ''), minOrderQuantity: String(scheme?.minOrderQuantity ?? 0),
    halfSchemeMinQty: String(scheme?.halfSchemeMinQty ?? ''), companySubsidyPercent: String(scheme?.companySubsidyPercent ?? 100),
    specialNetRate: String(scheme?.specialNetRate ?? ''), maxFreeQuantityCap: String(scheme?.maxFreeQuantityCap ?? ''),
  })
  const [validation, setValidation] = useState<string | null>(null)
  const isQuantity = type === 'BUY_X_GET_Y' || type === 'HALF_FULL_SCHEME'
  const save = useMutation({
    mutationFn: (request: SchemeRequest) => scheme ? updateScheme(scheme.id, request) : createScheme(request),
    onSuccess: () => { void client.invalidateQueries({ queryKey: ['schemes'] }); onClose() },
  })
  const number = (key: keyof typeof values) => values[key].trim() ? Number(values[key]) : null
  function submit(event: FormEvent) {
    event.preventDefault()
    if (!canManage || save.isPending) return
    const request: SchemeRequest = {
      name: name.trim(), schemeType: type, itemId, supplierId, active,
      validFrom: validFrom || null, validTo: validTo || null,
      buyQuantity: isQuantity ? number('buyQuantity') : null,
      freeQuantity: isQuantity ? number('freeQuantity') : null,
      discountPercent: type === 'PERCENT_DISCOUNT' ? number('discountPercent') : null,
      specialNetRate: type === 'SPECIAL_NET_RATE' ? number('specialNetRate') : null,
      minOrderQuantity: number('minOrderQuantity') ?? 0,
      allowHalfScheme: isQuantity && allowHalf,
      halfSchemeMinQty: isQuantity ? number('halfSchemeMinQty') : null,
      maxFreeQuantityCap: isQuantity ? number('maxFreeQuantityCap') : null,
      companySubsidyPercent: number('companySubsidyPercent') ?? 100,
    }
    const error = validateScheme(request)
    setValidation(error)
    if (!error) save.mutate(request)
  }
  function numeric(key: keyof typeof values, label: string, options: { required?: boolean; max?: number; min?: number; hint?: string } = {}) {
    return <FormField label={label} required={options.required} hint={options.hint}><NumberInput value={values[key]} onChange={(event) => setValues((current) => ({ ...current, [key]: event.target.value }))} min={options.min ?? 0} max={options.max} step="any" required={options.required} disabled={save.isPending} /></FormField>
  }
  return <Modal isOpen size="lg" title={scheme ? 'Edit trade scheme' : 'New trade scheme'} onClose={() => { if (!save.isPending) onClose() }} error={validation || (save.isError ? pricingError(save.error) : null)}
    footer={<><Button onClick={onClose} disabled={save.isPending} variant="secondary">Cancel</Button><Button form="scheme-form" type="submit" loading={save.isPending} disabled={!canManage}>Save scheme</Button></>}>
    <form id="scheme-form" onSubmit={submit} className="create-form-container">
      <FormGrid columns={2}>
        <FormField label="Scheme name" required><TextInput required maxLength={200} value={name} onChange={(event) => setName(event.target.value)} disabled={save.isPending} /></FormField>
        <FormField label="Scheme type" required><SelectInput value={type} onChange={(event) => setType(event.target.value as SchemeType)} disabled={save.isPending}>{Object.entries(schemeLabels).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</SelectInput></FormField>
        <FormField label="Item" hint="Leave empty to apply across items."><EntityPicker<Item> ariaLabel="Search scheme item" value={itemId} selectedEntity={item} selectedLabel={itemId === scheme?.itemId ? scheme?.itemName ?? itemId : undefined} onChange={(id, entity) => { setItemId(id); setItem(entity ?? null) }} onSearch={searchPricingItems} getOptionId={entityId} getOptionLabel={itemLabel} getOptionDescription={itemDescription} disabled={save.isPending} /></FormField>
        <FormField label="Funding supplier" optional><EntityPicker<Supplier> ariaLabel="Search scheme supplier" value={supplierId} selectedEntity={supplier} selectedLabel={supplierId === scheme?.supplierId ? scheme?.supplierName ?? supplierId : undefined} onChange={(id, entity) => { setSupplierId(id); setSupplier(entity ?? null) }} onSearch={searchPricingSuppliers} getOptionId={entityId} getOptionLabel={supplierLabel} getOptionDescription={supplierDescription} disabled={save.isPending} /></FormField>
        {isQuantity && numeric('buyQuantity', 'Buy quantity', { required: true, min: 0.0001 })}
        {isQuantity && numeric('freeQuantity', 'Free quantity', { required: true, min: 0.0001 })}
        {type === 'PERCENT_DISCOUNT' && numeric('discountPercent', 'Discount (%)', { required: true, max: 100 })}
        {type === 'SPECIAL_NET_RATE' && numeric('specialNetRate', 'Special net unit rate', { required: true })}
        {numeric('minOrderQuantity', 'Minimum order quantity')}
        {numeric('companySubsidyPercent', 'Company funding (%)', { required: true, max: 100 })}
        {isQuantity && numeric('maxFreeQuantityCap', 'Maximum free quantity', { hint: 'Leave empty for no cap.' })}
        {isQuantity && allowHalf && numeric('halfSchemeMinQty', 'Minimum half-scheme quantity', { hint: 'Leave empty to use half the buy quantity.' })}
        <FormField label="Valid from" optional><TextInput type="date" value={validFrom} onChange={(event) => setValidFrom(event.target.value)} disabled={save.isPending} /></FormField>
        <FormField label="Valid until" optional><TextInput type="date" min={validFrom || undefined} value={validTo} onChange={(event) => setValidTo(event.target.value)} disabled={save.isPending} /></FormField>
      </FormGrid>
      {isQuantity && <CheckboxInput checked={allowHalf} onChange={(event) => setAllowHalf(event.target.checked)} label="Allow half-scheme cash discount" disabled={save.isPending} />}
      <CheckboxInput checked={active} onChange={(event) => setActive(event.target.checked)} label="Active" disabled={save.isPending} />
    </form>
  </Modal>
}
