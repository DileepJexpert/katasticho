import { useEffect, useState, type FormEvent } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, ArrowLeftRight, Trash2 } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  DataTable,
  EmptyState,
  EntityPicker,
  FormCard,
  FormField,
  FormGrid,
  NumberInput,
  PageHeader,
  SelectInput,
  TextAreaInput,
  TextInput,
} from '@/design-system'
import { listItems, type Item } from '@/features/items/items-api'
import { listWarehouses } from '@/features/warehouses/warehouses-api'
import { createTransferOrder, type CreateTransferOrderRequest } from './transfer-orders-api'

type TransferLineDraft = {
  item: Item
  quantity: string
  notes: string
}

function todayIso() {
  const date = new Date()
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`
}

function errorMessage(error: unknown, fallback: string) {
  return error instanceof Error && error.message ? error.message : fallback
}

export function TransferOrderCreatePage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [fromWarehouseId, setFromWarehouseId] = useState('')
  const [toWarehouseId, setToWarehouseId] = useState('')
  const [transferDate, setTransferDate] = useState(todayIso)
  const [notes, setNotes] = useState('')
  const [lines, setLines] = useState<TransferLineDraft[]>([])
  const [formError, setFormError] = useState<string | null>(null)
  const [itemPickerKey, setItemPickerKey] = useState(0)
  const warehouses = useQuery({ queryKey: ['warehouses'], queryFn: listWarehouses })

  const selectableWarehouses = (warehouses.data ?? []).filter((warehouse) => warehouse.active)

  useEffect(() => {
    if (!fromWarehouseId && selectableWarehouses.length === 1 && selectableWarehouses[0]) {
      setFromWarehouseId(selectableWarehouses[0].id)
    }
  }, [fromWarehouseId, selectableWarehouses])

  const createMutation = useMutation({
    mutationFn: (request: CreateTransferOrderRequest) => createTransferOrder(request),
    onSuccess: (transfer) => {
      queryClient.invalidateQueries({ queryKey: ['transfer-orders'] })
      navigate(appRoutes.transferOrderDetail(transfer.id))
    },
    onError: (error) => setFormError(errorMessage(error, 'The transfer order could not be created.')),
  })

  function updateWarehouse(kind: 'from' | 'to', id: string) {
    setFormError(null)
    if (kind === 'from') {
      setFromWarehouseId(id)
      if (id === toWarehouseId) setToWarehouseId('')
      return
    }
    setToWarehouseId(id)
    if (id === fromWarehouseId) setFromWarehouseId('')
  }

  function addItem(item: Item | null | undefined) {
    if (!item) return
    if (lines.some((line) => line.item.id === item.id)) {
      setFormError(`${item.name} is already included in this transfer.`)
      setItemPickerKey((current) => current + 1)
      return
    }

    setLines((previous) => [...previous, { item, quantity: '1', notes: '' }])
    setFormError(null)
    setItemPickerKey((current) => current + 1)
  }

  function updateLine(itemId: string, updates: Partial<TransferLineDraft>) {
    setLines((previous) => previous.map((line) => line.item.id === itemId ? { ...line, ...updates } : line))
  }

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setFormError(null)

    if (!fromWarehouseId || !toWarehouseId) {
      setFormError('Select both the source and destination warehouses.')
      return
    }
    if (fromWarehouseId === toWarehouseId) {
      setFormError('Source and destination warehouses must be different.')
      return
    }
    if (!transferDate) {
      setFormError('Enter the date for this transfer.')
      return
    }
    if (lines.length === 0) {
      setFormError('Add at least one item to transfer.')
      return
    }

    const invalidLine = lines.find((line) => {
      const quantity = Number(line.quantity)
      return line.quantity.trim() === '' || !Number.isFinite(quantity) || quantity <= 0
    })
    if (invalidLine) {
      setFormError(`Enter a positive quantity for ${invalidLine.item.name}.`)
      return
    }

    createMutation.mutate({
      fromWarehouseId,
      toWarehouseId,
      transferDate,
      notes: notes.trim() || undefined,
      lines: lines.map((line) => ({
        itemId: line.item.id,
        quantity: Number(line.quantity),
        notes: line.notes.trim() || undefined,
      })),
    })
  }

  return (
    <section className="workspace-page">
      <PageHeader
        actions={<Button onClick={() => navigate(appRoutes.transferOrders)} variant="secondary"><ArrowLeft aria-hidden="true" size={16} /> Back to transfers</Button>}
        description="Prepare the exact stock quantities to move. Dispatch validates source stock and receipt records the same quantities at the destination."
        eyebrow="Inventory / Warehouse Transfers"
        title="New Transfer Order"
      />

      <form className="dashboard-workspace" onSubmit={submit}>
        {formError && <div className="form-error" role="alert">{formError}</div>}

        <FormCard description="Choose the warehouses and the operational date for this transfer." stepNumber={1} title="Transfer route">
          <FormGrid columns={3}>
            <FormField error={warehouses.isError ? 'Warehouses could not be loaded.' : undefined} label="Source warehouse" required>
              <SelectInput
                disabled={warehouses.isLoading || warehouses.isError}
                onChange={(event) => updateWarehouse('from', event.target.value)}
                options={selectableWarehouses.map((warehouse) => ({ value: warehouse.id, label: `${warehouse.code} / ${warehouse.name}` }))}
                placeholderOption={warehouses.isLoading ? 'Loading warehouses...' : 'Select source warehouse'}
                value={fromWarehouseId}
              />
            </FormField>
            <FormField label="Destination warehouse" required>
              <SelectInput
                disabled={warehouses.isLoading || warehouses.isError}
                onChange={(event) => updateWarehouse('to', event.target.value)}
                options={selectableWarehouses.map((warehouse) => ({ value: warehouse.id, label: `${warehouse.code} / ${warehouse.name}`, disabled: warehouse.id === fromWarehouseId }))}
                placeholderOption={warehouses.isLoading ? 'Loading warehouses...' : 'Select destination warehouse'}
                value={toWarehouseId}
              />
            </FormField>
            <FormField label="Transfer date" required>
              <TextInput onChange={(event) => setTransferDate(event.target.value)} required type="date" value={transferDate} />
            </FormField>
            <FormField label="Transfer notes" optional span="full">
              <TextAreaInput onChange={(event) => setNotes(event.target.value)} placeholder="e.g. Weekly branch replenishment" rows={2} value={notes} />
            </FormField>
          </FormGrid>
        </FormCard>

        <FormCard
          description="Add the requested quantities. This creates a DRAFT only; source stock is validated and deducted when an authorised user dispatches it."
          stepNumber={2}
          title={`Transfer lines (${lines.length})`}
        >
          <FormField label="Search catalogue item">
            <EntityPicker<Item>
              ariaLabel="Search items to add to transfer"
              getOptionDescription={(item) => [item.sku, item.unitOfMeasure, item.trackBatches ? 'Batch tracked' : 'Standard'].filter(Boolean).join(' / ')}
              getOptionId={(item) => item.id}
              getOptionLabel={(item) => item.name}
              key={itemPickerKey}
              onChange={(_id, item) => addItem(item)}
              onSearch={async (search) => (await listItems({ activeOnly: true, search, size: 20 })).content}
              placeholder="Search item name, SKU, or HSN"
              value={null}
            />
          </FormField>

          {lines.length ? (
            <DataTable caption="Transfer order line items">
              <thead>
                <tr>
                  <th scope="col">Item</th>
                  <th className="numeric-cell" scope="col">Quantity</th>
                  <th scope="col">Line note</th>
                  <th scope="col"><span className="visually-hidden">Remove</span></th>
                </tr>
              </thead>
              <tbody>
                {lines.map((line) => (
                  <tr key={line.item.id}>
                    <td>
                      <div className="item-primary">
                        <span aria-hidden="true" className="item-avatar"><ArrowLeftRight size={15} /></span>
                        <div className="cell-stack"><strong>{line.item.name}</strong><code>{[line.item.sku, line.item.unitOfMeasure].filter(Boolean).join(' / ') || 'No SKU or unit recorded'}</code></div>
                      </div>
                    </td>
                    <td className="numeric-cell">
                      <NumberInput
                        aria-label={`Quantity for ${line.item.name}`}
                        min="0.001"
                        onChange={(event) => updateLine(line.item.id, { quantity: event.target.value })}
                        step="0.001"
                        value={line.quantity}
                      />
                    </td>
                    <td><TextInput aria-label={`Line note for ${line.item.name}`} onChange={(event) => updateLine(line.item.id, { notes: event.target.value })} placeholder="Optional handling note" value={line.notes} /></td>
                    <td><Button aria-label={`Remove ${line.item.name}`} onClick={() => setLines((previous) => previous.filter((entry) => entry.item.id !== line.item.id))} variant="ghost"><Trash2 aria-hidden="true" size={16} /></Button></td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          ) : (
            <EmptyState description="Search the item catalogue to add the first line." icon={ArrowLeftRight} title="No items selected" />
          )}
        </FormCard>

        <div className="document-actions">
          <Button onClick={() => navigate(appRoutes.transferOrders)} type="button" variant="secondary">Cancel</Button>
          <Button loading={createMutation.isPending} type="submit" variant="primary">Create draft transfer</Button>
        </div>
      </form>
    </section>
  )
}
