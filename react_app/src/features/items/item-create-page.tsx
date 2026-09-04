import { useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, Save } from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { PageHeader } from '@/design-system/page-header'
import { createItem, type CreateItemRequest } from '@/features/items/items-api'

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
        actions={
          <div style={{ display: 'flex', gap: 'var(--space-2)' }}>
            <Button onClick={() => navigate(appRoutes.items)} type="button" variant="secondary">
              Cancel
            </Button>
            <Button disabled={!name.trim() || mutation.isPending} form="item-form" type="submit" variant="primary">
              <Save size={16} />
              {mutation.isPending ? 'Saving...' : 'Create Item'}
            </Button>
          </div>
        }
      />

      {feedback && (
        <div
          className={`directory-state ${feedback.type === 'error' ? 'directory-state--error' : ''}`}
          role="alert"
          style={{ marginBottom: 'var(--space-4)', minHeight: 'auto', padding: 'var(--space-3)' }}
        >
          <strong>{feedback.message}</strong>
        </div>
      )}

      <form className="create-form-container" id="item-form" onSubmit={handleSubmit}>
        <div className="form-card">
          <div className="form-card-header">
            <div>
              <h2 className="form-card-title">1. Basic Identification</h2>
              <p className="form-card-description">Item naming, categorization, and identification codes</p>
            </div>
          </div>
          <div className="form-grid--2col">
            <label className="field-group">
              <span>Item Name *</span>
              <input
                onChange={(e) => setName(e.target.value)}
                placeholder="e.g. Paracetamol 500mg Tablet"
                required
                value={name}
              />
            </label>
            <label className="field-group">
              <span>Item Type *</span>
              <select onChange={(e) => setItemType(e.target.value)} value={itemType}>
                <option value="FINISHED_GOOD">Finished Good</option>
                <option value="RAW_MATERIAL">Raw Material</option>
                <option value="WORK_IN_PROGRESS">Work in Progress (WIP)</option>
                <option value="MERCHANDISE">Merchandise (Traded)</option>
                <option value="SERVICE">Service</option>
              </select>
            </label>
          </div>

          <div className="form-grid--2col">
            <label className="field-group">
              <span>SKU / Product Code</span>
              <input
                onChange={(e) => setSku(e.target.value)}
                placeholder="e.g. SKU-PARA-500"
                value={sku}
              />
            </label>
            <label className="field-group">
              <span>Barcode / EAN-13</span>
              <input
                onChange={(e) => setBarcode(e.target.value)}
                placeholder="e.g. 8901234567890"
                value={barcode}
              />
            </label>
          </div>

          <label className="field-group">
            <span>Description / Composition</span>
            <textarea
              onChange={(e) => setDescription(e.target.value)}
              placeholder="Detailed product specifications, formulation, or packaging notes..."
              rows={2}
              value={description}
            />
          </label>
        </div>

        <div className="form-card">
          <div className="form-card-header">
            <div>
              <h2 className="form-card-title">2. Taxation & Pricing</h2>
              <p className="form-card-description">HSN classification, GST tax slabs, and purchase/selling rates</p>
            </div>
          </div>
          <div className="form-grid--3col">
            <label className="field-group">
              <span>HSN Code</span>
              <input
                onChange={(e) => setHsnCode(e.target.value)}
                placeholder="e.g. 3004"
                value={hsnCode}
              />
            </label>
            <label className="field-group">
              <span>GST Rate (%)</span>
              <input
                min={0}
                onChange={(e) => setGstRate(Number(e.target.value))}
                step={0.1}
                type="number"
                value={gstRate}
              />
            </label>
            <label className="field-group">
              <span>Unit of Measure (UoM) *</span>
              <input
                onChange={(e) => setUnitOfMeasure(e.target.value)}
                placeholder="e.g. PCS, BOX, STRIP, KG"
                required
                value={unitOfMeasure}
              />
            </label>
          </div>

          <div className="form-grid--2col">
            <label className="field-group">
              <span>Purchase Price (₹)</span>
              <input
                min={0}
                onChange={(e) => setPurchasePrice(Number(e.target.value))}
                step={0.01}
                type="number"
                value={purchasePrice}
              />
            </label>
            <label className="field-group">
              <span>Sale Price / MRP (₹)</span>
              <input
                min={0}
                onChange={(e) => setSalePrice(Number(e.target.value))}
                step={0.01}
                type="number"
                value={salePrice}
              />
            </label>
          </div>
        </div>

        <div className="form-card">
          <div className="form-card-header">
            <div>
              <h2 className="form-card-title">3. Inventory & Stock Controls</h2>
              <p className="form-card-description">Tracking methods, lot valuation, and automated reorder triggers</p>
            </div>
          </div>
          <div className="form-grid--4col">
            <label className="field-group">
              <span>Reorder Level</span>
              <input
                min={0}
                onChange={(e) => setReorderLevel(Number(e.target.value))}
                type="number"
                value={reorderLevel}
              />
            </label>
            <label className="field-group">
              <span>Reorder Quantity</span>
              <input
                min={1}
                onChange={(e) => setReorderQuantity(Number(e.target.value))}
                type="number"
                value={reorderQuantity}
              />
            </label>
            <label className="field-group">
              <span>Min Stock Level</span>
              <input
                min={0}
                onChange={(e) => setMinStockLevel(Number(e.target.value))}
                type="number"
                value={minStockLevel}
              />
            </label>
            <label className="field-group">
              <span>Max Stock Level</span>
              <input
                min={0}
                onChange={(e) => setMaxStockLevel(Number(e.target.value))}
                type="number"
                value={maxStockLevel}
              />
            </label>
            <label className="field-group">
              <span>Costing Valuation Method</span>
              <select onChange={(e) => setCostingMethod(e.target.value)} value={costingMethod}>
                <option value="FIFO">FIFO (First In, First Out)</option>
                <option value="WEIGHTED_AVERAGE">Weighted Average Cost</option>
              </select>
            </label>
          </div>

          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 'var(--space-5)', marginTop: 'var(--space-2)' }}>
            <label className="form-checkbox-label">
              <input checked={trackInventory} onChange={(e) => setTrackInventory(e.target.checked)} type="checkbox" />
              <span>Track Inventory Balance</span>
            </label>
            <label className="form-checkbox-label">
              <input checked={trackBatches} onChange={(e) => setTrackBatches(e.target.checked)} type="checkbox" />
              <span>Track Batches & FEFO Expiry</span>
            </label>
            <label className="form-checkbox-label">
              <input checked={trackSerials} onChange={(e) => setTrackSerials(e.target.checked)} type="checkbox" />
              <span>Track Unique Serial Numbers</span>
            </label>
          </div>
        </div>

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
