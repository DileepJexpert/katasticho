import { useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, Save } from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  CheckboxInput,
  FormCard,
  FormField,
  FormGrid,
  NumberInput,
  PageHeader,
  SelectInput,
  TextAreaInput,
  TextInput,
} from '@/design-system'
import { createItem, type CreateItemRequest } from '@/features/items/items-api'

const ITEM_TYPES = [
  { value: 'FINISHED_GOOD', label: 'Finished Good' },
  { value: 'RAW_MATERIAL', label: 'Raw Material' },
  { value: 'WORK_IN_PROGRESS', label: 'Work in Progress (WIP)' },
  { value: 'MERCHANDISE', label: 'Merchandise (Traded)' },
  { value: 'SERVICE', label: 'Service' },
]

export function ItemCreatePage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const [name, setName] = useState('')
  const [sku, setSku] = useState('')
  const [barcode, setBarcode] = useState('')
  const [itemType, setItemType] = useState('FINISHED_GOOD')
  const [description, setDescription] = useState('')
  const [hsnCode, setHsnCode] = useState('')
  const [gstRate, setGstRate] = useState(18)
  const [unitOfMeasure, setUnitOfMeasure] = useState('PCS')
  const [purchasePrice, setPurchasePrice] = useState(0)
  const [salePrice, setSalePrice] = useState(0)
  const [reorderLevel, setReorderLevel] = useState(10)
  const [reorderQuantity, setReorderQuantity] = useState(50)
  const [minStockLevel, setMinStockLevel] = useState(0)
  const [maxStockLevel, setMaxStockLevel] = useState(1000)
  const [trackInventory, setTrackInventory] = useState(true)
  const [trackBatches, setTrackBatches] = useState(false)
  const [trackSerials, setTrackSerials] = useState(false)
  const [costingMethod, setCostingMethod] = useState('FIFO')
  const [feedback, setFeedback] = useState<{ type: 'error' | 'success'; message: string } | null>(null)

  const mutation = useMutation({
    mutationFn: () => {
      const payload: CreateItemRequest = {
        name: name.trim(),
        sku: sku.trim() || undefined,
        barcode: barcode.trim() || undefined,
        itemType,
        description: description.trim() || undefined,
        hsnCode: hsnCode.trim() || undefined,
        gstRate,
        unitOfMeasure: unitOfMeasure.trim() || 'PCS',
        purchasePrice,
        salePrice,
        reorderLevel,
        reorderQuantity,
        minStockLevel: minStockLevel || undefined,
        maxStockLevel: maxStockLevel || undefined,
        trackInventory,
        trackBatches,
        trackSerials,
        costingMethod,
      }
      return createItem(payload)
    },
    onSuccess: (item) => {
      queryClient.invalidateQueries({ queryKey: ['items'] })
      navigate(appRoutes.itemDetail(item.id))
    },
    onError: (err) => {
      setFeedback({
        type: 'error',
        message: err instanceof Error ? err.message : 'Failed to create item',
      })
    },
  })

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (!name.trim()) {
      setFeedback({ type: 'error', message: 'Item name is required.' })
      return
    }
    mutation.mutate()
  }

  return (
    <section className="workspace-page">
      <Link className="form-back-link" to={appRoutes.items}>
        <ArrowLeft size={16} /> Back to Items
      </Link>

      <PageHeader
        eyebrow="Inventory & Catalog"
        title="New Item"
        description="Register a new inventory, manufactured, or traded product with HSN tax code, barcode, valuation, and stock controls."
      />

      {feedback && (
        <div
          className={`banner ${feedback.type === 'success' ? 'banner--success' : 'banner--error'}`}
          role="alert"
          style={{ marginBottom: 'var(--space-4)' }}
        >
          <span>{feedback.message}</span>
          <button className="banner-dismiss" onClick={() => setFeedback(null)} type="button">
            ✕
          </button>
        </div>
      )}

      <form className="create-form-container" onSubmit={handleSubmit}>
        <FormCard
          description="Item naming, categorization, and identification codes."
          stepNumber={1}
          title="Basic Identification"
        >
          <FormGrid columns={2}>
            <FormField label="Item Name" required>
              <TextInput
                onChange={(e) => setName(e.target.value)}
                placeholder="e.g. Paracetamol 500mg Tablet"
                required
                value={name}
              />
            </FormField>

            <FormField label="Item Type" required>
              <SelectInput
                onChange={(e) => setItemType(e.target.value)}
                options={ITEM_TYPES}
                required
                value={itemType}
              />
            </FormField>

            <FormField label="SKU / Product Code">
              <TextInput
                onChange={(e) => setSku(e.target.value)}
                placeholder="e.g. SKU-PARA-500"
                value={sku}
              />
            </FormField>

            <FormField label="Barcode / EAN-13">
              <TextInput
                onChange={(e) => setBarcode(e.target.value)}
                placeholder="e.g. 8901234567890"
                value={barcode}
              />
            </FormField>
          </FormGrid>

          <div style={{ marginTop: 'var(--space-4)' }}>
            <FormField label="Description / Composition">
              <TextAreaInput
                onChange={(e) => setDescription(e.target.value)}
                placeholder="Detailed product specifications, formulation, or packaging notes..."
                rows={2}
                value={description}
              />
            </FormField>
          </div>
        </FormCard>

        <FormCard
          description="HSN classification, GST tax slabs, and purchase/selling rates."
          stepNumber={2}
          title="Taxation & Pricing"
        >
          <FormGrid columns={3}>
            <FormField label="HSN Code">
              <TextInput
                onChange={(e) => setHsnCode(e.target.value)}
                placeholder="e.g. 3004"
                value={hsnCode}
              />
            </FormField>

            <FormField label="GST Rate" required>
              <NumberInput
                min={0}
                onChange={(e) => setGstRate(Number(e.target.value))}
                step={0.1}
                unitSuffix="%"
                value={gstRate}
              />
            </FormField>

            <FormField label="Unit of Measure (UoM)" required>
              <TextInput
                onChange={(e) => setUnitOfMeasure(e.target.value)}
                placeholder="e.g. PCS, BOX, STRIP, KG"
                required
                value={unitOfMeasure}
              />
            </FormField>

            <FormField label="Purchase Price">
              <NumberInput
                currencyPrefix="₹"
                min={0}
                onChange={(e) => setPurchasePrice(Number(e.target.value))}
                step={0.01}
                value={purchasePrice}
              />
            </FormField>

            <FormField label="Sale Price / MRP">
              <NumberInput
                currencyPrefix="₹"
                min={0}
                onChange={(e) => setSalePrice(Number(e.target.value))}
                step={0.01}
                value={salePrice}
              />
            </FormField>
          </FormGrid>
        </FormCard>

        <FormCard
          description="Tracking methods, lot valuation, and automated reorder triggers."
          stepNumber={3}
          title="Inventory & Stock Controls"
        >
          <FormGrid columns={4}>
            <FormField label="Reorder Level">
              <NumberInput
                min={0}
                onChange={(e) => setReorderLevel(Number(e.target.value))}
                value={reorderLevel}
              />
            </FormField>

            <FormField label="Reorder Quantity">
              <NumberInput
                min={1}
                onChange={(e) => setReorderQuantity(Number(e.target.value))}
                value={reorderQuantity}
              />
            </FormField>

            <FormField label="Min Stock Level">
              <NumberInput
                min={0}
                onChange={(e) => setMinStockLevel(Number(e.target.value))}
                value={minStockLevel}
              />
            </FormField>

            <FormField label="Max Stock Level">
              <NumberInput
                min={0}
                onChange={(e) => setMaxStockLevel(Number(e.target.value))}
                value={maxStockLevel}
              />
            </FormField>

            <FormField label="Costing Valuation Method">
              <SelectInput
                onChange={(e) => setCostingMethod(e.target.value)}
                options={[
                  { value: 'FIFO', label: 'FIFO (First In, First Out)' },
                  { value: 'WEIGHTED_AVERAGE', label: 'Weighted Average Cost' },
                ]}
                value={costingMethod}
              />
            </FormField>
          </FormGrid>

          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 'var(--space-5)', marginTop: 'var(--space-4)' }}>
            <CheckboxInput
              checked={trackInventory}
              description="Maintain stock ledger balance"
              onChange={(e) => setTrackInventory(e.target.checked)}
              title="Track Inventory Balance"
            />
            <CheckboxInput
              checked={trackBatches}
              description="Capture lot number & expiration"
              onChange={(e) => setTrackBatches(e.target.checked)}
              title="Track Batches & FEFO Expiry"
            />
            <CheckboxInput
              checked={trackSerials}
              description="Unique serial number per unit"
              onChange={(e) => setTrackSerials(e.target.checked)}
              title="Track Unique Serial Numbers"
            />
          </div>
        </FormCard>

        <div className="form-actions-bar">
          <Button onClick={() => navigate(appRoutes.items)} type="button" variant="secondary">
            Cancel
          </Button>
          <Button disabled={!name.trim() || mutation.isPending} type="submit" variant="primary">
            <Save size={16} />
            {mutation.isPending ? 'Saving...' : 'Create Item'}
          </Button>
        </div>
      </form>
    </section>
  )
}
