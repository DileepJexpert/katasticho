import { useDeferredValue, useEffect, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Boxes, ChevronLeft, ChevronRight, Plus, Search, UploadCloud } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import {
  createItem,
  getNegativeStockCount,
  listItems,
  type CreateItemRequest,
  type Item,
} from '@/features/items/items-api'

type ItemFilter = 'ALL' | 'NEGATIVE_STOCK' | 'ACTIVE_ONLY'

export function ItemsPage() {
  const [filter, setFilter] = useState<ItemFilter>('ALL')
  const [page, setPage] = useState(0)
  const [search, setSearch] = useState('')
  const deferredSearch = useDeferredValue(search)
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  // Modals
  const [showCreateModal, setShowCreateModal] = useState(false)
  const [showImportModal, setShowImportModal] = useState(false)

  const negativeStockOnly = filter === 'NEGATIVE_STOCK'
  const activeOnly = filter === 'ACTIVE_ONLY'

  useEffect(() => {
    setPage(0)
  }, [deferredSearch, filter])

  const negativeStock = useQuery({
    queryKey: ['items', 'negative-stock-count'],
    queryFn: getNegativeStockCount,
  })

  const items = useQuery({
    queryKey: ['items', { negativeStockOnly, activeOnly, page, search: deferredSearch }],
    queryFn: () => listItems({ negativeStockOnly, activeOnly, page, search: deferredSearch }),
  })
  const itemPage = items.data

  function selectFilter(nextFilter: ItemFilter) {
    setFilter(nextFilter)
    if (nextFilter === 'NEGATIVE_STOCK') setSearch('')
  }

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Inventory"
        title="Items & Product Catalog"
        description="Master product catalog with on-hand stock, warehouse balances, ATP calculations, FEFO batches, serials, and multi-packaging barcodes."
        actions={
          <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
            <Button onClick={() => setShowImportModal(true)} variant="secondary">
              <UploadCloud size={16} /> Import CSV
            </Button>
            <Button onClick={() => setShowCreateModal(true)} variant="primary">
              <Plus size={16} /> Create Item
            </Button>
          </div>
        }
      />

      <section className="list-panel" aria-label="Item directory">
        <div className="list-toolbar">
          <div className="role-tabs" aria-label="Filter inventory items" role="tablist">
            <button
              aria-selected={filter === 'ALL'}
              className={filter === 'ALL' ? 'role-tab role-tab--active' : 'role-tab'}
              onClick={() => selectFilter('ALL')}
              role="tab"
              type="button"
            >
              All items
              <span>{filter === 'ALL' ? itemPage?.totalElements ?? 0 : '--'}</span>
            </button>
            <button
              aria-selected={negativeStockOnly}
              className={negativeStockOnly ? 'role-tab role-tab--active' : 'role-tab'}
              onClick={() => selectFilter('NEGATIVE_STOCK')}
              role="tab"
              type="button"
            >
              Negative stock
              <span>{negativeStock.isLoading ? '...' : negativeStock.data ?? 0}</span>
            </button>
            <button
              aria-selected={activeOnly}
              className={activeOnly ? 'role-tab role-tab--active' : 'role-tab'}
              onClick={() => selectFilter('ACTIVE_ONLY')}
              role="tab"
              type="button"
            >
              Active Only
            </button>
          </div>
          <label className="directory-search">
            <Search aria-hidden="true" size={18} />
            <span className="sr-only">Search items</span>
            <input
              disabled={negativeStockOnly}
              onChange={(event) => setSearch(event.target.value)}
              placeholder={negativeStockOnly ? 'Search is unavailable in negative-stock view' : 'Search name, SKU, barcode, HSN'}
              value={search}
            />
          </label>
        </div>

        {items.isError ? (
          <div className="directory-state directory-state--error" role="alert">
            <strong>Items could not be loaded.</strong>
            <p>Check your connection and permissions, then refresh the page.</p>
          </div>
        ) : items.isLoading ? (
          <div aria-live="polite" className="directory-state">Loading items...</div>
        ) : itemPage?.content.length ? (
          <>
            <DataTable caption="Items">
              <thead>
                <tr>
                  <th scope="col">Item</th>
                  <th scope="col">Type</th>
                  <th className="numeric-cell" scope="col">On hand</th>
                  <th className="numeric-cell" scope="col">Purchase price</th>
                  <th className="numeric-cell" scope="col">Sale price</th>
                  <th scope="col">GST and unit</th>
                  <th scope="col">Status</th>
                  <th scope="col">Actions</th>
                </tr>
              </thead>
              <tbody>
                {itemPage.content.map((item) => (
                  <ItemRow
                    item={item}
                    key={item.id}
                    onOpen={() => navigate(appRoutes.itemDetail ? appRoutes.itemDetail(item.id) : `/items/${item.id}`)}
                  />
                ))}
              </tbody>
            </DataTable>
            <footer className="table-footer">
              <span>{itemPage.totalElements} item{itemPage.totalElements === 1 ? '' : 's'} {deferredSearch ? 'matching this search' : negativeStockOnly ? 'with negative stock' : 'in this organisation'}</span>
              <div className="pagination-actions">
                <button aria-label="Previous page" disabled={itemPage.page === 0} onClick={() => setPage((current) => current - 1)} type="button"><ChevronLeft aria-hidden="true" size={16} /></button>
                <span>Page {itemPage.page + 1} of {Math.max(itemPage.totalPages, 1)}</span>
                <button aria-label="Next page" disabled={itemPage.last} onClick={() => setPage((current) => current + 1)} type="button"><ChevronRight aria-hidden="true" size={16} /></button>
              </div>
            </footer>
          </>
        ) : (
          <div className="directory-state">
            <Boxes aria-hidden="true" size={24} />
            <strong>{negativeStockOnly ? 'No items have negative stock.' : 'No items found.'}</strong>
            <p>{negativeStockOnly ? 'Every inventory-tracked item is at zero or above.' : deferredSearch ? 'Try a different name, SKU, barcode, or HSN.' : 'Create your first item to start tracking inventory and sales.'}</p>
          </div>
        )}
      </section>

      {/* Create Modal */}
      {showCreateModal && (
        <CreateItemModal
          onClose={() => setShowCreateModal(false)}
          onSuccess={() => {
            setShowCreateModal(false)
            queryClient.invalidateQueries({ queryKey: ['items'] })
          }}
        />
      )}

      {/* CSV Import Modal */}
      {showImportModal && (
        <ImportItemsModal
          onClose={() => setShowImportModal(false)}
          onSuccess={() => {
            setShowImportModal(false)
            queryClient.invalidateQueries({ queryKey: ['items'] })
          }}
        />
      )}
    </section>
  )
}

function ItemRow({ item, onOpen }: { item: Item; onOpen: () => void }) {
  const itemCode = item.sku ?? item.barcode ?? '--'

  return (
    <tr onClick={onOpen} style={{ cursor: 'pointer' }}>
      <td>
        <div className="item-primary">
          <span aria-hidden="true" className="item-avatar"><Boxes size={15} /></span>
          <div className="cell-stack">
            <strong>{item.name}</strong>
            <code>{itemCode}</code>
          </div>
        </div>
      </td>
      <td><span className="item-type">{formatItemType(item.itemType)}</span></td>
      <td className="numeric-cell"><ItemStock item={item} /></td>
      <td className="numeric-cell"><Money amount={item.purchasePrice} /></td>
      <td className="numeric-cell"><Money amount={item.salePrice} /></td>
      <td>
        <div className="cell-stack">
          <code>{item.hsnCode ? `HSN ${item.hsnCode}` : '--'}</code>
          <span>{formatGst(item.gstRate)} Â· {item.unitOfMeasure ?? '--'}</span>
        </div>
      </td>
      <td><StatusChip status={item.active ? 'Active' : 'Inactive'} /></td>
      <td>
        <Button onClick={(e) => { e.stopPropagation(); onOpen() }} variant="ghost">
          View Detail
        </Button>
      </td>
    </tr>
  )
}

function ItemStock({ item }: { item: Item }) {
  if (!item.trackInventory) return <span className="cell-muted">Not tracked</span>

  return (
    <div className="item-stock">
      <Quantity unit={item.unitOfMeasure} value={item.totalOnHand} />
      <StatusChip status={stockStatus(item)} />
    </div>
  )
}

function stockStatus(item: Item) {
  const onHand = Number(item.totalOnHand) || 0
  const reorderLevel = Number(item.reorderLevel) || 0
  if (onHand < 0) return 'Negative stock'
  if (onHand === 0) return 'Out of stock'
  if (reorderLevel > 0 && onHand <= reorderLevel) return 'Low stock'
  return 'In stock'
}

function formatItemType(itemType: Item['itemType']) {
  return itemType.toLocaleLowerCase().replaceAll('_', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function formatGst(rate: Item['gstRate']) {
  if (rate === null || rate === undefined || rate === '') return 'GST --'
  return `GST ${Number(rate)}%`
}

function CreateItemModal({ onClose, onSuccess }: { onClose: () => void; onSuccess: () => void }) {
  const [name, setName] = useState('')
  const [sku, setSku] = useState('')
  const [barcode, setBarcode] = useState('')
  const [itemType, setItemType] = useState('FINISHED_GOOD')
  const [hsnCode, setHsnCode] = useState('')
  const [gstRate, setGstRate] = useState(18)
  const [unitOfMeasure, setUnitOfMeasure] = useState('PCS')
  const [purchasePrice, setPurchasePrice] = useState(0)
  const [salePrice, setSalePrice] = useState(0)
  const [reorderLevel, setReorderLevel] = useState(10)
  const [reorderQuantity, setReorderQuantity] = useState(50)
  const [trackInventory, setTrackInventory] = useState(true)
  const [trackBatches, setTrackBatches] = useState(false)
  const [trackSerials, setTrackSerials] = useState(false)
  const [costingMethod, setCostingMethod] = useState('FIFO')

  const mutation = useMutation({
    mutationFn: () => {
      const payload: CreateItemRequest = {
        name,
        sku: sku || undefined,
        barcode: barcode || undefined,
        itemType,
        hsnCode: hsnCode || undefined,
        gstRate,
        unitOfMeasure,
        purchasePrice,
        salePrice,
        reorderLevel,
        reorderQuantity,
        trackInventory,
        trackBatches,
        trackSerials,
        costingMethod,
      }
      return createItem(payload)
    },
    onSuccess: () => onSuccess(),
  })

  return (
    <div className="modal-backdrop" role="dialog">
      <div className="modal-dialog" style={{ maxWidth: '640px' }}>
        <header className="modal-header">
          <h3>Create Inventory Item</h3>
          <Button onClick={onClose} variant="ghost">âœ•</Button>
        </header>
        <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '1rem', maxHeight: '70vh', overflowY: 'auto' }}>
          <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: '1rem' }}>
            <label className="field-group">
              <span>Item Name *</span>
              <input onChange={(e) => setName(e.target.value)} placeholder="e.g. Paracetamol 500mg" value={name} />
            </label>
            <label className="field-group">
              <span>Item Type</span>
              <select onChange={(e) => setItemType(e.target.value)} value={itemType}>
                <option value="FINISHED_GOOD">Finished Good</option>
                <option value="RAW_MATERIAL">Raw Material</option>
                <option value="WORK_IN_PROGRESS">WIP</option>
                <option value="MERCHANDISE">Merchandise</option>
                <option value="SERVICE">Service</option>
              </select>
            </label>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
            <label className="field-group">
              <span>SKU</span>
              <input onChange={(e) => setSku(e.target.value)} placeholder="e.g. SKU-PARA-500" value={sku} />
            </label>
            <label className="field-group">
              <span>Barcode / EAN</span>
              <input onChange={(e) => setBarcode(e.target.value)} placeholder="e.g. 890123456789" value={barcode} />
            </label>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '1rem' }}>
            <label className="field-group">
              <span>HSN Code</span>
              <input onChange={(e) => setHsnCode(e.target.value)} placeholder="e.g. 3004" value={hsnCode} />
            </label>
            <label className="field-group">
              <span>GST Rate (%)</span>
              <input onChange={(e) => setGstRate(Number(e.target.value))} type="number" value={gstRate} />
            </label>
            <label className="field-group">
              <span>Unit of Measure</span>
              <input onChange={(e) => setUnitOfMeasure(e.target.value)} placeholder="e.g. PCS, BOX, KG" value={unitOfMeasure} />
            </label>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
            <label className="field-group">
              <span>Purchase Price (â‚¹)</span>
              <input onChange={(e) => setPurchasePrice(Number(e.target.value))} type="number" value={purchasePrice} />
            </label>
            <label className="field-group">
              <span>Sale Price / MRP (â‚¹)</span>
              <input onChange={(e) => setSalePrice(Number(e.target.value))} type="number" value={salePrice} />
            </label>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '1rem' }}>
            <label className="field-group">
              <span>Reorder Level</span>
              <input onChange={(e) => setReorderLevel(Number(e.target.value))} type="number" value={reorderLevel} />
            </label>
            <label className="field-group">
              <span>Reorder Quantity</span>
              <input onChange={(e) => setReorderQuantity(Number(e.target.value))} type="number" value={reorderQuantity} />
            </label>
            <label className="field-group">
              <span>Costing Method</span>
              <select onChange={(e) => setCostingMethod(e.target.value)} value={costingMethod}>
                <option value="FIFO">FIFO</option>
                <option value="WEIGHTED_AVERAGE">Weighted Avg</option>
              </select>
            </label>
          </div>

          <div style={{ display: 'flex', gap: '1.5rem', marginTop: '0.5rem' }}>
            <label style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
              <input checked={trackInventory} onChange={(e) => setTrackInventory(e.target.checked)} type="checkbox" />
              <span>Track Inventory</span>
            </label>
            <label style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
              <input checked={trackBatches} onChange={(e) => setTrackBatches(e.target.checked)} type="checkbox" />
              <span>Track Batches & FEFO</span>
            </label>
            <label style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
              <input checked={trackSerials} onChange={(e) => setTrackSerials(e.target.checked)} type="checkbox" />
              <span>Track Serial Numbers</span>
            </label>
          </div>
        </div>
        <footer className="modal-footer">
          <Button onClick={onClose} variant="secondary">Cancel</Button>
          <Button disabled={!name || mutation.isPending} onClick={() => mutation.mutate()} variant="primary">
            {mutation.isPending ? 'Creating...' : 'Create Item'}
          </Button>
        </footer>
      </div>
    </div>
  )
}

function ImportItemsModal({ onClose, onSuccess }: { onClose: () => void; onSuccess: () => void }) {
  const [csvContent, setCsvContent] = useState('')
  const [previewRows, setPreviewRows] = useState<string[][]>([])

  function handleFileChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    if (file) {
      const reader = new FileReader()
      reader.onload = (event) => {
        const text = (event.target?.result as string) || ''
        setCsvContent(text)
        const rows = text
          .split('\n')
          .filter(Boolean)
          .map((r) => r.split(',').map((c) => c.trim()))
        setPreviewRows(rows.slice(0, 5))
      }
      reader.readAsText(file)
    }
  }

  return (
    <div className="modal-backdrop" role="dialog">
      <div className="modal-dialog" style={{ maxWidth: '600px' }}>
        <header className="modal-header">
          <h3>Bulk Import Items CSV</h3>
          <Button onClick={onClose} variant="ghost">âœ•</Button>
        </header>
        <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <p style={{ fontSize: '0.875rem', color: 'var(--color-muted)' }}>
            Upload CSV with columns: <code>name, sku, barcode, itemType, hsnCode, gstRate, uom, purchasePrice, salePrice</code>
          </p>
          <input accept=".csv" onChange={handleFileChange} type="file" />

          {previewRows.length > 0 && (
            <div style={{ marginTop: '0.5rem' }}>
              <h4>Preview (First {previewRows.length} rows)</h4>
              <table style={{ width: '100%', fontSize: '0.75rem', borderCollapse: 'collapse' }}>
                <tbody>
                  {previewRows.map((row, i) => (
                    <tr key={i} style={{ borderBottom: '1px solid var(--color-border)' }}>
                      {row.map((col, j) => (
                        <td key={j} style={{ padding: '0.25rem 0.5rem' }}>{col}</td>
                      ))}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
        <footer className="modal-footer">
          <Button onClick={onClose} variant="secondary">Cancel</Button>
          <Button
            disabled={!csvContent}
            onClick={() => {
              onSuccess()
            }}
            variant="primary"
          >
            Commit Import
          </Button>
        </footer>
      </div>
    </div>
  )
}