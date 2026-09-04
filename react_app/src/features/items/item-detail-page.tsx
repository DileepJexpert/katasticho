import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { AlertTriangle, ArrowLeft, Barcode, History, Layers, Package, type LucideIcon } from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button, DataTable, DocumentCard, Fact, FactList, FilterTabs, Money, PageHeader, Quantity, StatusChip } from '@/design-system'
import {
  getItem,
  getItemBalances,
  getItemBatches,
  getItemMovements,
  listPackagingBarcodes,
  type Item,
  type PackagingBarcode,
  type StockBalance,
  type StockBatch,
  type StockMovement,
} from '@/features/items/items-api'
import { formatDate, formatDateTime, formatPercent, formatStatusLabel } from '@/shared/format/format'

type DetailTab = 'overview' | 'balances' | 'movements' | 'batches' | 'packaging'

export function ItemDetailPage() {
  const { itemId } = useParams()
  const navigate = useNavigate()
  const [activeTab, setActiveTab] = useState<DetailTab>('overview')
  const itemQuery = useQuery({
    queryKey: ['items', itemId],
    queryFn: () => getItem(itemId!),
    enabled: Boolean(itemId),
  })
  const balancesQuery = useQuery({
    queryKey: ['items', itemId, 'balances'],
    queryFn: () => getItemBalances(itemId!),
    enabled: Boolean(itemId) && activeTab === 'balances',
  })
  const movementsQuery = useQuery({
    queryKey: ['items', itemId, 'movements'],
    queryFn: () => getItemMovements(itemId!),
    enabled: Boolean(itemId) && activeTab === 'movements',
  })
  const batchesQuery = useQuery({
    queryKey: ['items', itemId, 'batches'],
    queryFn: () => getItemBatches(itemId!),
    enabled: Boolean(itemId) && activeTab === 'batches',
  })
  const barcodesQuery = useQuery({
    queryKey: ['items', itemId, 'packaging-barcodes'],
    queryFn: () => listPackagingBarcodes(itemId!),
    enabled: Boolean(itemId) && activeTab === 'packaging',
  })

  if (!itemId) return <ItemState message="No item ID was specified." />
  if (itemQuery.isLoading) return <ItemState message="Loading item details..." />
  if (itemQuery.isError || !itemQuery.data) {
    return (
      <section className="workspace-page">
        <div className="directory-state directory-state--error" role="alert">
          <AlertTriangle aria-hidden="true" size={24} />
          <strong>Item details could not be loaded.</strong>
          <Button onClick={() => navigate(appRoutes.items)} variant="secondary">Back to items</Button>
        </div>
      </section>
    )
  }

  const item = itemQuery.data
  const tabs = [
    { value: 'overview', label: 'Overview' },
    { value: 'balances', label: 'Warehouse balances' },
    { value: 'movements', label: 'Stock ledger' },
    ...(item.trackBatches ? [{ value: 'batches', label: 'Batches' }] : []),
    { value: 'packaging', label: 'Packaging barcodes' },
  ]

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Inventory / Item review"
        title={item.name}
        description={`${item.sku ?? 'No SKU'} · ${formatStatusLabel(item.itemType)} · ${item.unitOfMeasure ?? 'No unit'}`}
        actions={<StatusChip status={item.active ? 'Active' : 'Inactive'} />}
      />

      <div className="document-actions">
        <Button onClick={() => navigate(appRoutes.items)} variant="ghost">
          <ArrowLeft aria-hidden="true" size={16} />
          Back to items
        </Button>
        <span className="cell-muted">Read-only review. Stock and master-data changes remain in Flutter during migration.</span>
      </div>

      <FilterTabs
        activeValue={activeTab}
        ariaLabel="Item review sections"
        items={tabs}
        onChange={(value) => setActiveTab(value as DetailTab)}
      />

      {activeTab === 'overview' && <OverviewTab item={item} />}
      {activeTab === 'balances' && <BalancesTab balances={balancesQuery.data ?? []} isLoading={balancesQuery.isLoading} />}
      {activeTab === 'movements' && <MovementsTab isLoading={movementsQuery.isLoading} movements={movementsQuery.data ?? []} unit={item.unitOfMeasure} />}
      {activeTab === 'batches' && <BatchesTab batches={batchesQuery.data ?? []} isLoading={batchesQuery.isLoading} />}
      {activeTab === 'packaging' && <PackagingTab barcodes={barcodesQuery.data ?? []} isLoading={barcodesQuery.isLoading} />}
    </section>
  )
}

function ItemState({ message }: { message: string }) {
  return <section className="workspace-page"><div aria-live="polite" className="directory-state">{message}</div></section>
}

function OverviewTab({ item }: { item: Item }) {
  const dimensions = [item.length, item.width, item.height].every((value) => value !== null)
    ? `${item.length} × ${item.width} × ${item.height} ${item.dimensionUnit ?? ''}`.trim()
    : null
  const attributes = Object.entries(item.variantAttributes ?? {})

  return (
    <>
      <div className="document-layout">
        <DocumentCard title="Catalog identity">
          <FactList>
            <Fact label="SKU" mono value={item.sku} />
            <Fact label="Barcode" mono value={item.barcode} />
            <Fact label="Item type" value={formatStatusLabel(item.itemType)} />
            <Fact label="Category" value={item.category} />
            <Fact label="Brand" value={item.brand} />
            <Fact label="Manufacturer" value={item.manufacturer} />
            <Fact label="HSN" mono value={item.hsnCode} />
            <Fact label="GST rate" value={formatPercent(item.gstRate)} />
          </FactList>
        </DocumentCard>
        <DocumentCard title="Pricing and stock controls" variant="summary">
          <FactList>
            <Fact label="Purchase price" value={<Money amount={item.purchasePrice} />} />
            <Fact label="Sale price" value={<Money amount={item.salePrice} />} />
            <Fact label="MRP" value={<Money amount={item.mrp} />} />
            <Fact label="On hand" value={<Quantity unit={item.unitOfMeasure} value={item.totalOnHand} />} />
            <Fact label="Reorder level" value={<Quantity unit={item.unitOfMeasure} value={item.reorderLevel} />} />
            <Fact label="Reorder quantity" value={<Quantity unit={item.unitOfMeasure} value={item.reorderQuantity} />} />
            <Fact label="Inventory tracking" value={item.trackInventory ? 'Enabled' : 'Not tracked'} />
            <Fact label="Batch tracking" value={item.trackBatches ? 'Enabled' : 'Not enabled'} />
          </FactList>
        </DocumentCard>
      </div>

      <div className="document-layout">
        <DocumentCard title="Fulfilment and purchasing">
          <FactList>
            <Fact label="Preferred vendor" value={item.preferredVendorName} />
            <Fact label="Rack location" mono value={item.rackLocationCode} />
            <Fact label="Rack name" value={item.rackLocationName} />
            <Fact label="Purchase unit" value={item.purchaseUom} />
            <Fact label="Purchase conversion" value={item.purchaseUomConversion} />
            <Fact label="Purchase price per unit" value={<Money amount={item.purchasePricePerUom} />} />
          </FactList>
        </DocumentCard>
        <DocumentCard title="Product attributes" variant="summary">
          <FactList>
            <Fact label="Weight" value={item.weight === null ? null : `${item.weight} ${item.weightUnit ?? ''}`.trim()} />
            <Fact label="Dimensions" value={dimensions} />
            <Fact label="Pack size" value={item.packSize} />
            <Fact label="Storage" value={item.storageCondition} />
            <Fact label="Created" value={formatDateTime(item.createdAt)} />
            <Fact label="Variant group" value={item.groupName} />
          </FactList>
        </DocumentCard>
      </div>

      {attributes.length > 0 && (
        <DocumentCard title="Variant attributes">
          <FactList>{attributes.map(([label, value]) => <Fact key={label} label={label} value={value} />)}</FactList>
        </DocumentCard>
      )}
    </>
  )
}

function BalancesTab({ balances, isLoading }: { balances: StockBalance[]; isLoading: boolean }) {
  if (isLoading) return <ItemState message="Loading warehouse balances..." />
  if (!balances.length) return <EmptyReview icon={Layers} message="No warehouse stock balances have been recorded for this item." />

  return (
    <DocumentCard title="Warehouse balances" variant="lines">
      <DataTable caption="Warehouse balances">
        <thead><tr><th scope="col">Warehouse</th><th className="numeric-cell" scope="col">On hand</th><th className="numeric-cell" scope="col">Average cost</th><th className="numeric-cell" scope="col">Reorder level</th><th scope="col">Last movement</th><th scope="col">Status</th></tr></thead>
        <tbody>{balances.map((balance) => (
          <tr key={balance.warehouseId}>
            <td><div className="cell-stack"><strong>{balance.warehouseName}</strong><code>{balance.warehouseId}</code></div></td>
            <td className="numeric-cell"><Quantity value={balance.quantityOnHand} /></td>
            <td className="numeric-cell"><Money amount={balance.averageCost} /></td>
            <td className="numeric-cell"><Quantity value={balance.reorderLevel} /></td>
            <td>{formatDateTime(balance.lastMovementAt)}</td>
            <td><StatusChip status={balance.lowStock ? 'Low stock' : 'In stock'} /></td>
          </tr>
        ))}</tbody>
      </DataTable>
    </DocumentCard>
  )
}

function MovementsTab({ movements, isLoading, unit }: { movements: StockMovement[]; isLoading: boolean; unit: string | null }) {
  if (isLoading) return <ItemState message="Loading stock ledger..." />
  if (!movements.length) return <EmptyReview icon={History} message="No stock movements have been recorded for this item." />

  return (
    <DocumentCard title="Stock ledger" variant="lines">
      <DataTable caption="Item stock ledger">
        <thead><tr><th scope="col">Date</th><th scope="col">Movement</th><th scope="col">Warehouse</th><th scope="col">Reference</th><th scope="col">Batch</th><th className="numeric-cell" scope="col">Quantity</th><th className="numeric-cell" scope="col">Unit cost</th><th scope="col">State</th></tr></thead>
        <tbody>{movements.map((movement) => (
          <tr key={movement.id}>
            <td>{formatDate(movement.movementDate)}</td>
            <td>{formatStatusLabel(movement.movementType)}</td>
            <td>{movement.warehouseName}</td>
            <td><code>{movement.referenceNumber ?? movement.referenceType ?? '--'}</code></td>
            <td><code>{movement.batchNumber ?? '--'}</code></td>
            <td className="numeric-cell"><Quantity unit={unit} value={movement.quantity} /></td>
            <td className="numeric-cell"><Money amount={movement.unitCost} /></td>
            <td><StatusChip status={movement.reversed ? 'Reversed' : movement.reversal ? 'Reversal' : 'Posted'} /></td>
          </tr>
        ))}</tbody>
      </DataTable>
    </DocumentCard>
  )
}

function BatchesTab({ batches, isLoading }: { batches: StockBatch[]; isLoading: boolean }) {
  if (isLoading) return <ItemState message="Loading batch history..." />
  if (!batches.length) return <EmptyReview icon={Package} message="No batches have been received for this item." />

  return (
    <DocumentCard title="Batch history" variant="lines">
      <DataTable caption="Item batches">
        <thead><tr><th scope="col">Batch</th><th scope="col">Manufactured</th><th scope="col">Expiry</th><th className="numeric-cell" scope="col">Unit cost</th><th scope="col">Status</th></tr></thead>
        <tbody>{batches.map((batch) => (
          <tr key={batch.id}>
            <td><code>{batch.batchNumber}</code></td>
            <td>{formatDate(batch.manufacturingDate)}</td>
            <td>{formatDate(batch.expiryDate)}</td>
            <td className="numeric-cell"><Money amount={batch.unitCost} /></td>
            <td><StatusChip status={batch.active ? 'Active' : 'Inactive'} /></td>
          </tr>
        ))}</tbody>
      </DataTable>
    </DocumentCard>
  )
}

function PackagingTab({ barcodes, isLoading }: { barcodes: PackagingBarcode[]; isLoading: boolean }) {
  if (isLoading) return <ItemState message="Loading packaging barcodes..." />
  if (!barcodes.length) return <EmptyReview icon={Barcode} message="No packaging barcodes are configured for this item." />

  return (
    <DocumentCard title="Packaging barcodes" variant="lines">
      <DataTable caption="Item packaging barcodes">
        <thead><tr><th scope="col">Barcode</th><th scope="col">Level</th><th scope="col">Packaging</th><th className="numeric-cell" scope="col">Conversion</th><th className="numeric-cell" scope="col">MRP</th><th className="numeric-cell" scope="col">Sale price</th><th scope="col">Primary</th></tr></thead>
        <tbody>{barcodes.map((barcode) => (
          <tr key={barcode.id}>
            <td><code>{barcode.barcode}</code></td>
            <td>{formatStatusLabel(barcode.packagingLevel)}</td>
            <td>{barcode.packagingName ?? barcode.uomName ?? '--'}</td>
            <td className="numeric-cell"><Quantity unit={barcode.uomName} value={barcode.conversionFactor} /></td>
            <td className="numeric-cell"><Money amount={barcode.mrp} /></td>
            <td className="numeric-cell"><Money amount={barcode.salePrice} /></td>
            <td><StatusChip status={barcode.isPrimary ? 'Primary' : 'Alternate'} /></td>
          </tr>
        ))}</tbody>
      </DataTable>
    </DocumentCard>
  )
}

function EmptyReview({ icon: Icon, message }: { icon: LucideIcon; message: string }) {
  return <div className="directory-state"><Icon aria-hidden="true" size={24} /><span>{message}</span></div>
}
