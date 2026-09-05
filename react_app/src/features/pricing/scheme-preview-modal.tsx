import { useState, type FormEvent } from 'react'
import { useMutation, useQuery } from '@tanstack/react-query'
import { Button, EntityPicker, Fact, FactList, FormField, FormGrid, Modal, Money, NumberInput, Quantity, SelectInput } from '@/design-system'
import type { Item } from '@/features/items/items-api'
import { entityId, itemDescription, itemLabel, pricingError, searchPricingItems } from '@/features/price-lists/pricing-shared'
import { evaluateScheme, listApplicableSchemes } from './schemes-api'

export function SchemePreviewModal({ onClose }: { onClose: () => void }) {
  const [item, setItem] = useState<Item | null>(null)
  const [quantity, setQuantity] = useState('1')
  const [price, setPrice] = useState('')
  const [schemeId, setSchemeId] = useState('')
  const valid = Boolean(item && quantity.trim() && price.trim() && Number.isFinite(Number(quantity)) && Number(quantity) > 0 && Number.isFinite(Number(price)) && Number(price) >= 0)
  const applicable = useQuery({ queryKey: ['schemes', 'applicable', item?.id, quantity], queryFn: () => listApplicableSchemes(item!.id, Number(quantity)), enabled: Boolean(item && Number.isFinite(Number(quantity)) && Number(quantity) > 0) })
  const evaluation = useMutation({ mutationFn: (request: Parameters<typeof evaluateScheme>[0]) => evaluateScheme(request) })
  const signature = `${item?.id}|${quantity}|${price}|${schemeId}`
  const [evaluatedSignature, setEvaluatedSignature] = useState('')
  const result = signature === evaluatedSignature ? evaluation.data : undefined
  function submit(event: FormEvent) {
    event.preventDefault()
    if (!valid || !item || evaluation.isPending || !applicable.isSuccess) return
    if (schemeId && !applicable.data.some((scheme) => scheme.id === schemeId)) return
    setEvaluatedSignature(signature)
    evaluation.mutate({ itemId: item.id, quantity: Number(quantity), unitPrice: Number(price), schemeId: schemeId || null })
  }
  return <Modal isOpen size="lg" title="Preview trade scheme" description="Calculate the benefit for an item and quantity. This preview does not create an order or reserve stock." onClose={onClose} error={evaluation.isError ? pricingError(evaluation.error) : applicable.isError ? pricingError(applicable.error) : null}
    footer={<><Button onClick={onClose} variant="secondary">Close</Button><Button type="submit" form="scheme-preview" disabled={!valid || !applicable.isSuccess || Boolean(schemeId && !applicable.data?.some((scheme) => scheme.id === schemeId))} loading={evaluation.isPending}>Calculate preview</Button></>}>
    <form id="scheme-preview" onSubmit={submit} className="create-form-container">
      <FormField label="Item" required><EntityPicker<Item> ariaLabel="Search preview item" value={item?.id ?? null} selectedEntity={item} onChange={(_id, value) => { setItem(value ?? null); setSchemeId(''); if (value) setPrice(String(value.salePrice ?? '')) }} onSearch={searchPricingItems} getOptionId={entityId} getOptionLabel={itemLabel} getOptionDescription={itemDescription} /></FormField>
      <FormGrid columns={2}>
        <FormField label="Quantity" required><NumberInput min={0.0001} step="any" required value={quantity} onChange={(event) => { setQuantity(event.target.value); setSchemeId('') }} /></FormField>
        <FormField label="Base unit price" required><NumberInput min={0} step="any" required value={price} onChange={(event) => setPrice(event.target.value)} /></FormField>
        <FormField label="Applicable scheme" span="full" hint="Eligibility uses today's date and the selected quantity."><SelectInput value={schemeId} onChange={(event) => setSchemeId(event.target.value)} disabled={!applicable.isSuccess}><option value="">Automatic selection</option>{applicable.data?.map((scheme) => <option key={scheme.id} value={scheme.id}>{scheme.name}</option>)}</SelectInput></FormField>
      </FormGrid>
    </form>
    {result && !evaluation.isPending && <div className="pricing-preview-result" aria-live="polite">
      <p>{result.explanation}</p>
      <FactList>
        <Fact label="Applied scheme" value={result.schemeName ?? 'None'} />
        <Fact label="Ordered quantity" value={<Quantity value={result.orderedQuantity} />} />
        <Fact label="Free quantity" value={<Quantity value={result.freeQuantity} />} />
        <Fact label="Discount" value={<Money amount={result.discountAmount} />} />
        <Fact label="Effective unit rate" value={<Money amount={result.effectiveUnitPrice} />} />
        <Fact label="Line amount before tax" value={<Money amount={result.totalLineAmount} />} />
        <Fact label="Company funded" value={<Money amount={result.companyFundedAmount} />} />
        <Fact label="Distributor funded" value={<Money amount={result.distributorFundedAmount} />} />
        <Fact label="Half-scheme applied" value={result.isHalfSchemeApplied ? 'Yes' : 'No'} />
      </FactList>
    </div>}
  </Modal>
}
