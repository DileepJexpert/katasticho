import { useState, type FormEvent } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { Button, CheckboxInput, FormField, FormGrid, Modal, TextAreaInput, TextInput } from '@/design-system'
import { createPriceList } from './price-lists-api'
import { pricingError, useCanManagePricing } from './pricing-shared'

export function PriceListCreateModal({ onClose, onCreated }: { onClose: () => void; onCreated: (id: string) => void }) {
  const canManage = useCanManagePricing()
  const queryClient = useQueryClient()
  const [name, setName] = useState('')
  const [description, setDescription] = useState('')
  const [currency, setCurrency] = useState('INR')
  const [isDefault, setIsDefault] = useState(false)
  const [validation, setValidation] = useState('')
  const save = useMutation({
    mutationFn: (request: Parameters<typeof createPriceList>[0]) => createPriceList(request),
    onSuccess: (list) => {
      void queryClient.invalidateQueries({ queryKey: ['price-lists'] })
      onCreated(list.id)
    },
  })
  function submit(event: FormEvent) {
    event.preventDefault()
    if (!canManage || save.isPending) return
    if (!name.trim() || !/^[A-Z]{3}$/.test(currency.trim().toUpperCase())) {
      setValidation('Enter a name and a three-letter currency code.')
      return
    }
    setValidation('')
    save.mutate({ name: name.trim(), description: description.trim() || null, currency: currency.trim().toUpperCase(), isDefault })
  }
  return <Modal isOpen onClose={() => { if (!save.isPending) onClose() }} title="New price list" error={validation || (save.isError ? pricingError(save.error) : null)}
    footer={<><Button disabled={save.isPending} onClick={onClose} variant="secondary">Cancel</Button><Button form="create-price-list" type="submit" loading={save.isPending} disabled={!canManage}>Create price list</Button></>}>
    <form id="create-price-list" onSubmit={submit} className="create-form-container">
      <FormGrid columns={2}>
        <FormField label="Name" required><TextInput required maxLength={100} value={name} onChange={(event) => setName(event.target.value)} disabled={save.isPending} /></FormField>
        <FormField label="Currency" required><TextInput required minLength={3} maxLength={3} value={currency} onChange={(event) => setCurrency(event.target.value.toUpperCase())} disabled={save.isPending} /></FormField>
        <FormField label="Description" span="full"><TextAreaInput rows={2} value={description} onChange={(event) => setDescription(event.target.value)} disabled={save.isPending} /></FormField>
      </FormGrid>
      <CheckboxInput label="Use as organisation default" description="Replaces the current default list. Customers with a pinned list keep that assignment." checked={isDefault} onChange={(event) => setIsDefault(event.target.checked)} disabled={save.isPending} />
    </form>
  </Modal>
}
