import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  ArrowLeft,
  Boxes,
  Layers,
  History,
  Barcode,
  Hash,
  AlertTriangle,
  RotateCcw,
  Plus,
  Trash2,
  Package,
} from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button, Fact, FactList, FormField, FormGrid, Modal, NumberInput, SelectInput, TextInput } from '@/design-system'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatDateTime } from '@/shared/format/format'
import {
  getItem,
  getItemBalances,
  getItemMovements,
  getItemBatches,
  getAvailableSerials,
  listPackagingBarcodes,
  computeAtp,
  adjustStock,
  reverseStockMovement,
  markSerialDamaged,
  addPackagingBarcode,
  deletePackagingBarcode,
  type Item,
  type StockBalance,
  type StockMovement,
  type StockBatch,
  type SerialNumber,
  type PackagingBarcode,
} from '@/features/items/items-api'

export function ItemDetailPage() {
  const { itemId } = useParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [activeTab, setActiveTab] = useState<'overview' | 'balances' | 'movements' | 'batches' | 'serials' | 'packaging'>('overview')

  // Modals
  const [showAdjustModal, setShowAdjustModal] = useState(false)
  const [showAddBarcodeModal, setShowAddBarcodeModal] = useState(false)
  const [showAtpModal, setShowAtpModal] = useState(false)

  // Query item
  const itemQuery = useQuery({
    queryKey: ['items', itemId],
    queryFn: () => getItem(itemId!),
    enabled: Boolean(itemId),
  })

  // Balances
  const balancesQuery = useQuery({
    queryKey: ['items', itemId, 'balances'],
    queryFn: () => getItemBalances(itemId!),
    enabled: Boolean(itemId),
  })

  // Movements
  const movementsQuery = useQuery({
    queryKey: ['items', itemId, 'movements'],
    queryFn: () => getItemMovements(itemId!),
    enabled: Boolean(itemId) && activeTab === 'movements',
  })

  // Batches
  const batchesQuery = useQuery({
    queryKey: ['items', itemId, 'batches'],
    queryFn: () => getItemBatches(itemId!),
    enabled: Boolean(itemId) && activeTab === 'batches',
  })

  // Serials
  const serialsQuery = useQuery({
    queryKey: ['items', itemId, 'serials'],
    queryFn: () => getAvailableSerials(itemId!),
    enabled: Boolean(itemId) && activeTab === 'serials',
  })

  // Packaging Barcodes
  const barcodesQuery = useQuery({
    queryKey: ['items', itemId, 'packaging-barcodes'],
    queryFn: () => listPackagingBarcodes(itemId!),
    enabled: Boolean(itemId) && activeTab === 'packaging',
  })

  // Reverse Movement Mutation
  const reverseMutation = useMutation({
    mutationFn: (movementId: string) => reverseStockMovement(movementId, 'User requested reversal from web workbench'),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['items', itemId] })
    },
  })

  // Mark Serial Damaged Mutation
  const damageSerialMutation = useMutation({
    mutationFn: (serialId: string) => markSerialDamaged(serialId, 'Marked damaged from web catalog'),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['items', itemId, 'serials'] })
    },
  })

  // Delete Packaging Barcode Mutation
  const deleteBarcodeMutation = useMutation({
    mutationFn: (barcodeId: string) => deletePackagingBarcode(barcodeId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['items', itemId, 'packaging-barcodes'] })
    },
  })

  if (!itemId) return <section className="workspace-page"><div className="directory-state">No item ID specified.</div></section>
  if (itemQuery.isLoading) return <section className="workspace-page"><div className="directory-state">Loading item details...</div></section>
  if (itemQuery.isError || !itemQuery.data) {
    return (
      <section className="workspace-page">
        <div className="directory-state directory-state--error">
          <AlertTriangle size={24} />
          <strong>Item not found or failed to load.</strong>
          <Button onClick={() => navigate(appRoutes.items)} variant="secondary">Back to items</Button>
        </div>
      </section>
    )
  }

  const item = itemQuery.data

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Inventory / Product Catalog"
        title={item.name}
        description={`SKU: ${item.sku ?? '--'} · Barcode: ${item.barcode ?? '--'} · Type: ${item.itemType}`}
        actions={
          <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
            <Button onClick={() => setShowAdjustModal(true)} variant="secondary">
              <RotateCcw size={16} /> Adjust Stock
            </Button>
            <Button onClick={() => setShowAtpModal(true)} variant="secondary">
              <Boxes size={16} /> Check ATP
            </Button>
            <StatusChip status={item.active ? 'Active' : 'Inactive'} />
          </div>
        }
      />

      <div style={{ marginBottom: '1rem' }}>
        <Button onClick={() => navigate(appRoutes.items)} variant="ghost">
          <ArrowLeft size={16} /> Back to item catalog
        </Button>
      </div>

      {/* Tabs */}
      <div className="role-tabs" role="tablist" style={{ marginBottom: '1.5rem' }}>
        <button
          className={activeTab === 'overview' ? 'role-tab role-tab--active' : 'role-tab'}
          onClick={() => setActiveTab('overview')}
          role="tab"
          type="button"
        >
          <Boxes size={16} style={{ marginRight: '0.5rem' }} />
          Overview & Stats
        </button>
        <button
          className={activeTab === 'balances' ? 'role-tab role-tab--active' : 'role-tab'}
          onClick={() => setActiveTab('balances')}
          role="tab"
          type="button"
        >
          <Layers size={16} style={{ marginRight: '0.5rem' }} />
          Warehouse Balances ({balancesQuery.data?.length ?? 0})
        </button>
        <button
          className={activeTab === 'movements' ? 'role-tab role-tab--active' : 'role-tab'}
          onClick={() => setActiveTab('movements')}
          role="tab"
          type="button"
        >
          <History size={16} style={{ marginRight: '0.5rem' }} />
          Stock Ledger
        </button>
        {item.trackBatches && (
          <button
            className={activeTab === 'batches' ? 'role-tab role-tab--active' : 'role-tab'}
            onClick={() => setActiveTab('batches')}
            role="tab"
            type="button"
          >
            <Package size={16} style={{ marginRight: '0.5rem' }} />
            Batches & FEFO
          </button>
        )}
        {item.trackSerials && (
          <button
            className={activeTab === 'serials' ? 'role-tab role-tab--active' : 'role-tab'}
            onClick={() => setActiveTab('serials')}
            role="tab"
            type="button"
          >
            <Hash size={16} style={{ marginRight: '0.5rem' }} />
            Serial Numbers
          </button>
        )}
        <button
          className={activeTab === 'packaging' ? 'role-tab role-tab--active' : 'role-tab'}
          onClick={() => setActiveTab('packaging')}
          role="tab"
          type="button"
        >
          <Barcode size={16} style={{ marginRight: '0.5rem' }} />
          Packaging Barcodes
        </button>
      </div>

      {/* Tab Contents */}
      {activeTab === 'overview' && (
        <OverviewTab item={item} />
      )}

      {activeTab === 'balances' && (
        <BalancesTab balances={balancesQuery.data ?? []} isLoading={balancesQuery.isLoading} />
      )}

      {activeTab === 'movements' && (
        <MovementsTab
          isLoading={movementsQuery.isLoading}
          movements={movementsQuery.data ?? []}
          onReverse={(id) => reverseMutation.mutate(id)}
        />
      )}

      {activeTab === 'batches' && item.trackBatches && (
        <BatchesTab batches={batchesQuery.data ?? []} isLoading={batchesQuery.isLoading} />
      )}

      {activeTab === 'serials' && item.trackSerials && (
        <SerialsTab
          isLoading={serialsQuery.isLoading}
          onMarkDamaged={(id) => damageSerialMutation.mutate(id)}
          serials={serialsQuery.data ?? []}
        />
      )}

      {activeTab === 'packaging' && (
        <PackagingTab
          barcodes={barcodesQuery.data ?? []}
          isLoading={barcodesQuery.isLoading}
          onAdd={() => setShowAddBarcodeModal(true)}
          onDelete={(id) => deleteBarcodeMutation.mutate(id)}
        />
      )}

      {/* Modals */}
      {showAdjustModal && (
        <StockAdjustmentModal
          itemId={item.id}
          onClose={() => setShowAdjustModal(false)}
          onSuccess={() => {
            setShowAdjustModal(false)
            queryClient.invalidateQueries({ queryKey: ['items', itemId] })
          }}
        />
      )}

      {showAtpModal && (
        <AtpModal itemId={item.id} onClose={() => setShowAtpModal(false)} />
      )}

      {showAddBarcodeModal && (
        <AddPackagingBarcodeModal
          itemId={item.id}
          onClose={() => setShowAddBarcodeModal(false)}
          onSuccess={() => {
            setShowAddBarcodeModal(false)
            queryClient.invalidateQueries({ queryKey: ['items', itemId, 'packaging-barcodes'] })
          }}
        />
      )}
    </section>
  )
}

function OverviewTab({ item }: { item: Item }) {
  return (
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: '1.5rem' }}>
      <section className="document-card">
        <h3>Master Attributes</h3>
        <dl className="document-facts">
          <div className="fact-item">
            <dt>Item Type</dt>
            <dd>{item.itemType}</dd>
          </div>
          <div className="fact-item">
            <dt>HSN Code</dt>
            <dd><code>{item.hsnCode ?? '--'}</code></dd>
          </div>
          <div className="fact-item">
            <dt>GST Rate</dt>
            <dd>{item.gstRate !== null && item.gstRate !== undefined ? `${item.gstRate}%` : '--'}</dd>
          </div>
          <div className="fact-item">
            <dt>Unit of Measure</dt>
            <dd>{item.unitOfMeasure ?? '--'}</dd>
          </div>
          <div className="fact-item">
            <dt>Costing Method</dt>
            <dd>{item.costingMethod ?? 'FIFO'}</dd>
          </div>
          <div className="fact-item">
            <dt>Description</dt>
            <dd>{item.description ?? '--'}</dd>
          </div>
        </dl>
      </section>

      <section className="document-card">
        <h3>Pricing & Inventory Controls</h3>
        <dl className="document-facts">
          <div className="fact-item">
            <dt>Purchase Price</dt>
            <dd><Money amount={item.purchasePrice} /></dd>
          </div>
          <div className="fact-item">
            <dt>Sale Price (MRP/Base)</dt>
            <dd><Money amount={item.salePrice} /></dd>
          </div>
          <div className="fact-item">
            <dt>Total On Hand</dt>
            <dd><Quantity unit={item.unitOfMeasure} value={item.totalOnHand} /></dd>
          </div>
          <div className="fact-item">
            <dt>Min Stock Level</dt>
            <dd><Quantity unit={item.unitOfMeasure} value={item.minStockLevel} /></dd>
          </div>
          <div className="fact-item">
            <dt>Max Stock Level</dt>
            <dd><Quantity unit={item.unitOfMeasure} value={item.maxStockLevel} /></dd>
          </div>
          <div className="fact-item">
            <dt>Reorder Point / Qty</dt>
            <dd>
              <Quantity unit={item.unitOfMeasure} value={item.reorderLevel} /> / <Quantity unit={item.unitOfMeasure} value={item.reorderQuantity} />
            </dd>
          </div>
        </dl>
      </section>

      <section className="document-card">
        <h3>Tracking Configuration</h3>
        <dl className="document-facts">
          <div className="fact-item">
            <dt>Track Inventory</dt>
            <dd><StatusChip status={item.trackInventory ? 'Active' : 'Inactive'} /></dd>
          </div>
          <div className="fact-item">
            <dt>Batch Tracking & FEFO</dt>
            <dd><StatusChip status={item.trackBatches ? 'Active' : 'Inactive'} /></dd>
          </div>
          <div className="fact-item">
            <dt>Serial Tracking</dt>
            <dd><StatusChip status={item.trackSerials ? 'Active' : 'Inactive'} /></dd>
          </div>
        </dl>
      </section>
    </div>
  )
}

function BalancesTab({ balances, isLoading }: { balances: StockBalance[]; isLoading: boolean }) {
  if (isLoading) return <div className="directory-state">Loading warehouse balances...</div>
  if (!balances.length) {
    return (
      <div className="directory-state">
        <Boxes size={24} />
        <strong>No stock balances recorded yet.</strong>
        <p>Stock will appear here upon Purchase Goods Receipt, Opening Stock entry, or Transfer In.</p>
      </div>
    )
  }

  return (
    <DataTable caption="Warehouse Balances">
      <thead>
        <tr>
          <th scope="col">Warehouse</th>
          <th className="numeric-cell" scope="col">On Hand</th>
          <th className="numeric-cell" scope="col">Allocated</th>
          <th className="numeric-cell" scope="col">Available</th>
          <th className="numeric-cell" scope="col">Reorder Level</th>
        </tr>
      </thead>
      <tbody>
        {balances.map((b) => (
          <tr key={b.id || b.warehouseId}>
            <td>
              <div className="cell-stack">
                <strong>{b.warehouseName}</strong>
                <code>{b.warehouseCode ?? b.warehouseId}</code>
              </div>
            </td>
            <td className="numeric-cell">
              <strong>{b.currentBalance}</strong>
            </td>
            <td className="numeric-cell">{b.allocatedQuantity ?? 0}</td>
            <td className="numeric-cell">
              <span style={{ color: Number(b.availableQuantity) <= 0 ? 'var(--color-danger, #d32f2f)' : 'inherit' }}>
                {b.availableQuantity ?? b.currentBalance}
              </span>
            </td>
            <td className="numeric-cell">{b.reorderLevel ?? '--'}</td>
          </tr>
        ))}
      </tbody>
    </DataTable>
  )
}

function MovementsTab({
  movements,
  isLoading,
  onReverse,
}: {
  movements: StockMovement[]
  isLoading: boolean
  onReverse: (id: string) => void
}) {
  if (isLoading) return <div className="directory-state">Loading stock movement ledger...</div>
  if (!movements.length) {
    return (
      <div className="directory-state">
        <History size={24} />
        <strong>No stock movements recorded.</strong>
      </div>
    )
  }

  return (
    <DataTable caption="Stock Movements Ledger">
      <thead>
        <tr>
          <th scope="col">Date & Time</th>
          <th scope="col">Movement Type</th>
          <th className="numeric-cell" scope="col">Quantity</th>
          <th className="numeric-cell" scope="col">Unit Cost</th>
          <th className="numeric-cell" scope="col">Total Cost</th>
          <th scope="col">Reference</th>
          <th scope="col">Notes</th>
          <th scope="col">Actions</th>
        </tr>
      </thead>
      <tbody>
        {movements.map((m) => (
          <tr key={m.id}>
            <td>{formatDateTime(m.movementDate || m.createdAt)}</td>
            <td>
              <StatusChip status={m.movementType} />
            </td>
            <td className="numeric-cell">
              <strong style={{ color: Number(m.quantity) < 0 ? 'var(--color-danger, #d32f2f)' : 'var(--color-success, #2e7d32)' }}>
                {Number(m.quantity) > 0 ? `+${m.quantity}` : m.quantity}
              </strong>
            </td>
            <td className="numeric-cell"><Money amount={m.unitCost} /></td>
            <td className="numeric-cell"><Money amount={m.totalCost} /></td>
            <td>
              <div className="cell-stack">
                <span>{m.referenceType ?? '--'}</span>
                <code>{m.referenceNumber ?? m.referenceId ?? '--'}</code>
              </div>
            </td>
            <td>{m.notes ?? '--'}</td>
            <td>
              {m.movementType !== 'REVERSAL' && (
                <Button onClick={() => onReverse(m.id)} variant="ghost">
                  <RotateCcw size={14} /> Reverse
                </Button>
              )}
            </td>
          </tr>
        ))}
      </tbody>
    </DataTable>
  )
}

function BatchesTab({ batches, isLoading }: { batches: StockBatch[]; isLoading: boolean }) {
  if (isLoading) return <div className="directory-state">Loading batch records...</div>
  if (!batches.length) {
    return (
      <div className="directory-state">
        <Package size={24} />
        <strong>No active batches found for this item.</strong>
      </div>
    )
  }

  return (
    <DataTable caption="Item Batches & FEFO Expiry">
      <thead>
        <tr>
          <th scope="col">Batch Number</th>
          <th scope="col">Mfg Date</th>
          <th scope="col">Expiry Date</th>
          <th className="numeric-cell" scope="col">MRP</th>
          <th className="numeric-cell" scope="col">Purchase Cost</th>
          <th className="numeric-cell" scope="col">Available Qty</th>
          <th scope="col">Expiry Status</th>
        </tr>
      </thead>
      <tbody>
        {batches.map((b) => (
          <tr key={b.id}>
            <td>
              <strong>{b.batchNumber}</strong>
            </td>
            <td>{formatDate(b.mfgDate)}</td>
            <td>{formatDate(b.expiryDate)}</td>
            <td className="numeric-cell"><Money amount={b.mrp} /></td>
            <td className="numeric-cell"><Money amount={b.purchaseRate} /></td>
            <td className="numeric-cell">
              <strong>{b.quantityAvailable ?? b.currentBalance ?? 0}</strong>
            </td>
            <td>
              {b.isExpired ? (
                <StatusChip status="Expired" />
              ) : b.isNearExpiry ? (
                <StatusChip status="Near Expiry" />
              ) : (
                <StatusChip status="Valid" />
              )}
            </td>
          </tr>
        ))}
      </tbody>
    </DataTable>
  )
}

function SerialsTab({
  serials,
  isLoading,
  onMarkDamaged,
}: {
  serials: SerialNumber[]
  isLoading: boolean
  onMarkDamaged: (id: string) => void
}) {
  if (isLoading) return <div className="directory-state">Loading serial numbers...</div>
  if (!serials.length) {
    return (
      <div className="directory-state">
        <Hash size={24} />
        <strong>No serial numbers found for this item.</strong>
      </div>
    )
  }

  return (
    <DataTable caption="Serial Numbers Inventory">
      <thead>
        <tr>
          <th scope="col">Serial Number</th>
          <th scope="col">Status</th>
          <th scope="col">Warranty End</th>
          <th scope="col">Received At</th>
          <th scope="col">Sold At</th>
          <th scope="col">Actions</th>
        </tr>
      </thead>
      <tbody>
        {serials.map((s) => (
          <tr key={s.id}>
            <td>
              <code>{s.serialNumber}</code>
            </td>
            <td><StatusChip status={s.status} /></td>
            <td>{formatDate(s.warrantyEndDate)}</td>
            <td>{formatDateTime(s.receivedAt)}</td>
            <td>{formatDateTime(s.soldAt)}</td>
            <td>
              {s.status === 'AVAILABLE' && (
                <Button onClick={() => onMarkDamaged(s.id)} variant="ghost">
                  <AlertTriangle size={14} /> Mark Damaged
                </Button>
              )}
            </td>
          </tr>
        ))}
      </tbody>
    </DataTable>
  )
}

function PackagingTab({
  barcodes,
  isLoading,
  onAdd,
  onDelete,
}: {
  barcodes: PackagingBarcode[]
  isLoading: boolean
  onAdd: () => void
  onDelete: (id: string) => void
}) {
  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: '1rem' }}>
        <Button onClick={onAdd} variant="primary">
          <Plus size={16} /> Add Packaging Barcode
        </Button>
      </div>

      {isLoading ? (
        <div className="directory-state">Loading packaging barcodes...</div>
      ) : !barcodes.length ? (
        <div className="directory-state">
          <Barcode size={24} />
          <strong>No packaging hierarchy barcodes registered.</strong>
          <p>Register Inner-pack, Master Carton, or Pallet GS1/EAN barcodes with conversion factors.</p>
        </div>
      ) : (
        <DataTable caption="Multi-Packaging Hierarchy Barcodes">
          <thead>
            <tr>
              <th scope="col">Packaging Level</th>
              <th scope="col">Barcode</th>
              <th className="numeric-cell" scope="col">Conversion Factor (Each)</th>
              <th className="numeric-cell" scope="col">Gross Wt (kg)</th>
              <th scope="col">Dimensions (cm)</th>
              <th scope="col">Default</th>
              <th scope="col">Actions</th>
            </tr>
          </thead>
          <tbody>
            {barcodes.map((b) => (
              <tr key={b.id}>
                <td><strong>{b.packagingLevel}</strong></td>
                <td><code>{b.barcode}</code></td>
                <td className="numeric-cell"><strong>{b.conversionFactor}x</strong></td>
                <td className="numeric-cell">{b.grossWeightKg ?? '--'}</td>
                <td>{b.dimensionsCm ?? '--'}</td>
                <td><StatusChip status={b.isDefault ? 'Yes' : 'No'} /></td>
                <td>
                  <Button onClick={() => onDelete(b.id)} variant="ghost">
                    <Trash2 size={14} />
                  </Button>
                </td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      )}
    </div>
  )
}

function StockAdjustmentModal({
  itemId,
  onClose,
  onSuccess,
}: {
  itemId: string
  onClose: () => void
  onSuccess: () => void
}) {
  const [warehouseId, setWarehouseId] = useState('')
  const [quantityDelta, setQuantityDelta] = useState(0)
  const [unitCost, setUnitCost] = useState(0)
  const [reason, setReason] = useState('')
  const [batchNumber, setBatchNumber] = useState('')
  const [expiryDate, setExpiryDate] = useState('')

  const mutation = useMutation({
    mutationFn: () =>
      adjustStock({
        itemId,
        warehouseId: warehouseId || 'default-wh',
        quantityDelta,
        unitCost: unitCost || undefined,
        reason: reason || 'Manual stock adjustment',
        batchNumber: batchNumber || undefined,
        expiryDate: expiryDate || undefined,
      }),
    onSuccess: () => onSuccess(),
  })

  return (
    <Modal
      footer={
        <>
          <Button onClick={onClose} variant="secondary">Cancel</Button>
          <Button disabled={quantityDelta === 0 || mutation.isPending} onClick={() => mutation.mutate()} variant="primary">
            {mutation.isPending ? 'Posting...' : 'Post Stock Adjustment'}
          </Button>
        </>
      }
      isOpen
      onClose={onClose}
      size="md"
      title="Manual Stock Adjustment"
    >
      <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-4)' }}>
        <FormGrid columns={2}>
          <FormField label="Warehouse ID">
            <TextInput onChange={(e) => setWarehouseId(e.target.value)} placeholder="e.g. WH-MAIN" value={warehouseId} />
          </FormField>
          <FormField label="Quantity Delta (+/-)" required>
            <NumberInput onChange={(e) => setQuantityDelta(Number(e.target.value))} placeholder="e.g. 10 or -5" value={quantityDelta} />
          </FormField>
          <FormField label="Unit Cost (₹)">
            <NumberInput currencyPrefix="₹" min={0} onChange={(e) => setUnitCost(Number(e.target.value))} step="0.01" value={unitCost} />
          </FormField>
          <FormField label="Batch Number (optional)">
            <TextInput onChange={(e) => setBatchNumber(e.target.value)} placeholder="BATCH-001" value={batchNumber} />
          </FormField>
        </FormGrid>

        <FormGrid columns={2}>
          <FormField label="Expiry Date (optional)">
            <TextInput onChange={(e) => setExpiryDate(e.target.value)} type="date" value={expiryDate} />
          </FormField>
          <FormField label="Adjustment Reason">
            <TextInput onChange={(e) => setReason(e.target.value)} placeholder="e.g. Physical count variance, damaged item" value={reason} />
          </FormField>
        </FormGrid>
      </div>
    </Modal>
  )
}

function AtpModal({ itemId, onClose }: { itemId: string; onClose: () => void }) {
  const [warehouseId, setWarehouseId] = useState('default-wh')
  const [qty, setQty] = useState(10)

  const atpQuery = useQuery({
    queryKey: ['items', itemId, 'atp', warehouseId, qty],
    queryFn: () => computeAtp(itemId, warehouseId, qty),
  })

  const atp = atpQuery.data

  return (
    <Modal
      footer={
        <Button onClick={onClose} variant="secondary">Close</Button>
      }
      isOpen
      onClose={onClose}
      size="md"
      title="Available-to-Promise (ATP) Calculator"
    >
      <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-4)' }}>
        <FormGrid columns={2}>
          <FormField label="Warehouse ID">
            <TextInput onChange={(e) => setWarehouseId(e.target.value)} value={warehouseId} />
          </FormField>
          <FormField label="Requested Order Qty" required>
            <NumberInput min={1} onChange={(e) => setQty(Number(e.target.value))} value={qty} />
          </FormField>
        </FormGrid>

        {atpQuery.isLoading ? (
          <div className="directory-state">Computing ATP promise...</div>
        ) : atp ? (
          <div className="document-card" style={{ marginTop: 'var(--space-2)' }}>
            <h4 style={{ margin: '0 0 var(--space-3) 0', fontSize: 'var(--text-sm)' }}>ATP Fulfillment Promise</h4>
            <FactList columns={2}>
              <Fact label="On Hand Stock" value={<strong>{atp.onHandQuantity}</strong>} />
              <Fact label="Reserved / Committed" value={atp.reservedQuantity} />
              <Fact label="Inbound PO Stock" value={atp.inboundPoQuantity} />
              <Fact label="Net Available (ATP)" value={<strong>{atp.netAvailableQuantity}</strong>} />
              <Fact label="Fulfillment Status" value={<StatusChip status={atp.isFulfillable ? 'Fulfillable Now' : 'Stock Shortage'} />} />
              <Fact label="Earliest Promise Date" value={atp.earliestFulfillmentDate ? formatDate(atp.earliestFulfillmentDate) : 'Immediate'} />
            </FactList>
          </div>
        ) : null}
      </div>
    </Modal>
  )
}

function AddPackagingBarcodeModal({
  itemId,
  onClose,
  onSuccess,
}: {
  itemId: string
  onClose: () => void
  onSuccess: () => void
}) {
  const [packagingLevel, setPackagingLevel] = useState('INNER_PACK')
  const [barcode, setBarcode] = useState('')
  const [conversionFactor, setConversionFactor] = useState(10)
  const [grossWeightKg, setGrossWeightKg] = useState('')
  const [dimensionsCm, setDimensionsCm] = useState('')

  const mutation = useMutation({
    mutationFn: () =>
      addPackagingBarcode(itemId, {
        packagingLevel,
        barcode,
        conversionFactor,
        grossWeightKg: grossWeightKg ? Number(grossWeightKg) : null,
        dimensionsCm: dimensionsCm || null,
        isDefault: false,
      }),
    onSuccess: () => onSuccess(),
  })

  return (
    <Modal
      footer={
        <>
          <Button onClick={onClose} variant="secondary">Cancel</Button>
          <Button disabled={!barcode || conversionFactor <= 0 || mutation.isPending} onClick={() => mutation.mutate()} variant="primary">
            {mutation.isPending ? 'Saving...' : 'Add Barcode'}
          </Button>
        </>
      }
      isOpen
      onClose={onClose}
      size="md"
      title="Add Packaging Barcode"
    >
      <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-4)' }}>
        <FormField label="Packaging Level" required>
          <SelectInput
            onChange={(e) => setPackagingLevel(e.target.value)}
            options={[
              { value: 'EACH', label: 'EACH (1x)' },
              { value: 'INNER_PACK', label: 'INNER PACK (Box)' },
              { value: 'MASTER_CARTON', label: 'MASTER CARTON (Case)' },
              { value: 'PALLET', label: 'PALLET' },
            ]}
            value={packagingLevel}
          />
        </FormField>
        <FormField label="Barcode (EAN / GS1 / UPC)" required>
          <TextInput onChange={(e) => setBarcode(e.target.value)} placeholder="e.g. 8901234567890" value={barcode} />
        </FormField>
        <FormGrid columns={3}>
          <FormField label="Conversion Factor" required>
            <NumberInput min={1} onChange={(e) => setConversionFactor(Number(e.target.value))} placeholder="e.g. 12" value={conversionFactor} />
          </FormField>
          <FormField label="Gross Weight (kg)">
            <TextInput onChange={(e) => setGrossWeightKg(e.target.value)} placeholder="e.g. 1.25" value={grossWeightKg} />
          </FormField>
          <FormField label="Dimensions (cm)">
            <TextInput onChange={(e) => setDimensionsCm(e.target.value)} placeholder="e.g. 30x20x15" value={dimensionsCm} />
          </FormField>
        </FormGrid>
      </div>
    </Modal>
  )
}

