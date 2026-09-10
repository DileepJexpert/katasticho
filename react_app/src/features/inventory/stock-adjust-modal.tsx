import { useState, type FormEvent } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  Button,
  FormField,
  FormGrid,
  Modal,
  NumberInput,
  SelectInput,
  TextAreaInput,
  TextInput,
} from '@/design-system'
import { adjustStock, type StockAdjustmentRequest } from '@/features/items/items-api'
import { listWarehouses } from '@/features/warehouses/warehouses-api'

const directionOptions = [
  { label: 'Add stock (+) — Surplus / Found / Count adjustment', value: 'INCREASE' },
  { label: 'Remove stock (-) — Loss / Damage / Scrap / Expiry', value: 'DECREASE' },
]

export function StockAdjustModal({
  itemId,
  itemName,
  unit,
  initialUnitCost,
  isOpen,
  onClose,
  onSaved,
}: {
  itemId: string
  itemName: string
  unit?: string | null
  initialUnitCost?: number | null
  isOpen: boolean
  onClose: () => void
  onSaved?: () => void
}) {
  const queryClient = useQueryClient()
  const today = new Date().toISOString().split('T')[0]

  const [direction, setDirection] = useState<'INCREASE' | 'DECREASE'>('INCREASE')
  const [warehouseId, setWarehouseId] = useState('')
  const [quantity, setQuantity] = useState<number>(1)
  const [unitCost, setUnitCost] = useState<number>(initialUnitCost ?? 0)
  const [adjustmentDate, setAdjustmentDate] = useState(today)
  const [reason, setReason] = useState('')
  const [error, setError] = useState<string | null>(null)

  const warehousesQuery = useQuery({
    queryKey: ['warehouses'],
    queryFn: listWarehouses,
  })

  const mutation = useMutation({
    mutationFn: async () => {
      if (!quantity || quantity <= 0) {
        throw new Error('Quantity must be greater than zero.')
      }

      const signedQuantity = direction === 'INCREASE' ? quantity : -quantity
      const payload: StockAdjustmentRequest = {
        itemId,
        warehouseId: warehouseId || undefined,
        quantity: signedQuantity,
        unitCost: unitCost > 0 ? unitCost : undefined,
        adjustmentDate: adjustmentDate || undefined,
        reason: reason.trim() || 'Manual stock adjustment',
      }

      return adjustStock(payload)
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['items', itemId] })
      queryClient.invalidateQueries({ queryKey: ['items', itemId, 'balances'] })
      queryClient.invalidateQueries({ queryKey: ['items', itemId, 'movements'] })
      queryClient.invalidateQueries({ queryKey: ['stock-summary'] })
      onSaved?.()
      onClose()
    },
    onError: (err: unknown) => {
      const msg =
        err instanceof Error
          ? err.message
          : typeof err === 'object' && err !== null && 'message' in err
          ? String((err as { message: unknown }).message)
          : 'Stock adjustment failed.'
      setError(msg)
    },
  })

  function handleSubmit(e: FormEvent) {
    e.preventDefault()
    setError(null)
    mutation.mutate()
  }

  const warehouseOptions = (warehousesQuery.data ?? []).map((w) => ({
    label: `${w.name} (${w.code})`,
    value: w.id,
  }))

  return (
    <Modal
      isOpen={isOpen}
      onClose={() => !mutation.isPending && onClose()}
      size="md"
      title={`Adjust stock — ${itemName}`}
      description="Record a manual inventory adjustment (gain, loss, recount, damage). Adjustments record immutable inventory movements."
      footer={
        <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end', width: '100%' }}>
          <Button disabled={mutation.isPending} onClick={onClose} variant="ghost">
            Cancel
          </Button>
          <Button
            loading={mutation.isPending}
            onClick={handleSubmit}
            variant={direction === 'DECREASE' ? 'destructive' : 'primary'}
          >
            {direction === 'INCREASE' ? 'Record stock increase' : 'Record stock reduction'}
          </Button>
        </div>
      }
    >
      <form onSubmit={handleSubmit}>
        {error && (
          <div
            className="directory-state directory-state--error"
            role="alert"
            style={{ marginBottom: '16px' }}
          >
            <strong>Adjustment error</strong>
            <p>{error}</p>
          </div>
        )}

        <FormGrid columns={1}>
          <FormField label="Adjustment type" required>
            <SelectInput
              aria-label="Adjustment type"
              onChange={(e) => setDirection(e.target.value as 'INCREASE' | 'DECREASE')}
              options={directionOptions}
              value={direction}
            />
          </FormField>
        </FormGrid>

        <FormGrid columns={2}>
          <FormField label="Warehouse" hint="Leave unselected to use the organization's default warehouse.">
            <SelectInput
              aria-label="Warehouse"
              onChange={(e) => setWarehouseId(e.target.value)}
              options={warehouseOptions}
              placeholderOption="Default warehouse"
              value={warehouseId}
            />
          </FormField>

          <FormField label="Adjustment date">
            <TextInput
              aria-label="Adjustment date"
              onChange={(e) => setAdjustmentDate(e.target.value)}
              type="date"
              value={adjustmentDate}
            />
          </FormField>
        </FormGrid>

        <FormGrid columns={2}>
          <FormField label={`Quantity ${unit ? `(${unit})` : ''}`} required>
            <NumberInput
              aria-label="Quantity"
              min={0.001}
              onChange={(e) => setQuantity(parseFloat(e.target.value) || 0)}
              step="any"
              value={quantity}
            />
          </FormField>

          <FormField label="Unit cost (₹)" hint="Defaults to current weighted average cost if left zero.">
            <NumberInput
              aria-label="Unit cost"
              min={0}
              onChange={(e) => setUnitCost(parseFloat(e.target.value) || 0)}
              step="any"
              value={unitCost}
            />
          </FormField>
        </FormGrid>

        <FormGrid columns={1}>
          <FormField label="Reason / notes" hint="e.g. Broken packaging, Found during physical stock count, Sample issue">
            <TextAreaInput
              aria-label="Reason / notes"
              onChange={(e) => setReason(e.target.value)}
              placeholder="Reason for adjustment..."
              rows={3}
              value={reason}
            />
          </FormField>
        </FormGrid>
      </form>
    </Modal>
  )
}
