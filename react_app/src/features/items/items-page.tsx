import { useDeferredValue, useEffect, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Boxes, Plus, UploadCloud } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  DataTable,
  DirectoryToolbar,
  EmptyState,
  FilterTabs,
  Money,
  PageHeader,
  Quantity,
  SearchInput,
  StatusChip,
  TablePagination,
} from '@/design-system'
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
            <Button onClick={() => navigate(appRoutes.itemCreate)} variant="primary">
              <Plus size={16} /> Create Item
            </Button>
          </div>
        }
      />

      <section className="list-panel" aria-label="Item directory">
        <DirectoryToolbar ariaLabel="Filter inventory items by status and search">
          <FilterTabs
            activeValue={negativeStockOnly ? 'NEGATIVE_STOCK' : activeOnly ? 'ACTIVE_ONLY' : 'ALL'}
            ariaLabel="Filter inventory items"
            items={[
              {
                value: 'ALL',
                label: 'All items',
                count: filter === 'ALL' ? itemPage?.totalElements ?? 0 : undefined,
              },
              {
                value: 'NEGATIVE_STOCK',
                label: 'Negative stock',
                count: negativeStock.isLoading ? undefined : (negativeStock.data ?? 0),
              },
              {
                value: 'ACTIVE_ONLY',
                label: 'Active Only',
              },
            ]}
            onChange={(val) => selectFilter(val as 'ALL' | 'NEGATIVE_STOCK' | 'ACTIVE_ONLY')}
          />
          <SearchInput
            ariaLabel="Search items"
            disabled={negativeStockOnly}
            onChange={setSearch}
            onClear={() => setSearch('')}
            placeholder={negativeStockOnly ? 'Search is unavailable in negative-stock view' : 'Search name, SKU, barcode, HSN'}
            value={search}
          />
        </DirectoryToolbar>

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
            <TablePagination
              filterDescription={deferredSearch ? 'matching this search' : negativeStockOnly ? 'with negative stock' : 'in this organisation'}
              isFiltered={Boolean(deferredSearch || negativeStockOnly)}
              itemLabel="item"
              onPageChange={(p) => setPage(p)}
              page={itemPage.page}
              totalElements={itemPage.totalElements}
              totalPages={itemPage.totalPages}
            />
          </>
        ) : (
          <EmptyState
            action={
              !negativeStockOnly ? (
                <Button onClick={() => navigate(appRoutes.itemCreate)} variant="primary">
                  <Plus aria-hidden="true" size={16} />
                  <span>New Item</span>
                </Button>
              ) : null
            }
            description={negativeStockOnly ? 'Every inventory-tracked item is at zero or above.' : deferredSearch ? 'Try a different name, SKU, barcode, or HSN.' : 'Create your first item to start tracking inventory and sales.'}
            icon={Boxes}
            title={negativeStockOnly ? 'No items have negative stock.' : 'No items found.'}
          />
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
          <span>{formatGst(item.gstRate)} · {item.unitOfMeasure ?? '--'}</span>
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
    onSuccess: () => {
      onSuccess()
      onClose()
    },
  })

  return (
    <Modal
      footer={
        <>
          <Button onClick={onClose} variant="secondary">Cancel</Button>
          <Button disabled={!name || mutation.isPending} onClick={() => mutation.mutate()} variant="primary">
            {mutation.isPending ? 'Creating...' : 'Create Item'}
          </Button>
        </>
      }
      isOpen
      onClose={onClose}
      size="lg"
      title="Create Inventory Item"
    >
      <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-4)' }}>
        <FormGrid columns={2}>
          <FormField label="Item Name" required>
            <TextInput onChange={(e) => setName(e.target.value)} placeholder="e.g. Paracetamol 500mg" required value={name} />
          </FormField>
          <FormField label="Item Type" required>
            <SelectInput
              onChange={(e) => setItemType(e.target.value)}
              options={[
                { value: 'FINISHED_GOOD', label: 'Finished Good' },
                { value: 'RAW_MATERIAL', label: 'Raw Material' },
                { value: 'WORK_IN_PROGRESS', label: 'WIP' },
                { value: 'MERCHANDISE', label: 'Merchandise' },
                { value: 'SERVICE', label: 'Service' },
              ]}
              value={itemType}
            />
          </FormField>
          <FormField label="SKU">
            <TextInput onChange={(e) => setSku(e.target.value)} placeholder="e.g. SKU-PARA-500" value={sku} />
          </FormField>
          <FormField label="Barcode / EAN">
            <TextInput onChange={(e) => setBarcode(e.target.value)} placeholder="e.g. 890123456789" value={barcode} />
          </FormField>
        </FormGrid>

        <FormGrid columns={3}>
          <FormField label="HSN Code">
            <TextInput onChange={(e) => setHsnCode(e.target.value)} placeholder="e.g. 3004" value={hsnCode} />
          </FormField>
          <FormField label="GST Rate (%)">
            <NumberInput min={0} onChange={(e) => setGstRate(Number(e.target.value))} unitSuffix="%" value={gstRate} />
          </FormField>
          <FormField label="Unit of Measure">
            <TextInput onChange={(e) => setUnitOfMeasure(e.target.value)} placeholder="e.g. PCS, BOX, KG" value={unitOfMeasure} />
          </FormField>
          <FormField label="Purchase Price">
            <NumberInput currencyPrefix="₹" min={0} onChange={(e) => setPurchasePrice(Number(e.target.value))} value={purchasePrice} />
          </FormField>
          <FormField label="Sale Price / MRP">
            <NumberInput currencyPrefix="₹" min={0} onChange={(e) => setSalePrice(Number(e.target.value))} value={salePrice} />
          </FormField>
          <FormField label="Costing Method">
            <SelectInput
              onChange={(e) => setCostingMethod(e.target.value)}
              options={[
                { value: 'FIFO', label: 'FIFO' },
                { value: 'WEIGHTED_AVERAGE', label: 'Weighted Avg' },
              ]}
              value={costingMethod}
            />
          </FormField>
          <FormField label="Reorder Level">
            <NumberInput min={0} onChange={(e) => setReorderLevel(Number(e.target.value))} value={reorderLevel} />
          </FormField>
          <FormField label="Reorder Quantity">
            <NumberInput min={1} onChange={(e) => setReorderQuantity(Number(e.target.value))} value={reorderQuantity} />
          </FormField>
        </FormGrid>

        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 'var(--space-4)', marginTop: 'var(--space-1)' }}>
          <CheckboxInput checked={trackInventory} description="Maintain stock ledger" onChange={(e) => setTrackInventory(e.target.checked)} title="Track Inventory" />
          <CheckboxInput checked={trackBatches} description="FEFO batch expiration" onChange={(e) => setTrackBatches(e.target.checked)} title="Track Batches" />
          <CheckboxInput checked={trackSerials} description="Individual unit serials" onChange={(e) => setTrackSerials(e.target.checked)} title="Track Serials" />
        </div>
      </div>
    </Modal>
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
    <Modal
      footer={
        <>
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
        </>
      }
      isOpen
      onClose={onClose}
      size="md"
      title="Bulk Import Items CSV"
    >
      <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-3)' }}>
        <p style={{ fontSize: 'var(--text-sm)', color: 'var(--text-secondary)' }}>
          Upload CSV with columns: <code>name, sku, barcode, itemType, hsnCode, gstRate, uom, purchasePrice, salePrice</code>
        </p>
        <input accept=".csv" onChange={handleFileChange} type="file" />

        {previewRows.length > 0 && (
          <div style={{ marginTop: 'var(--space-2)' }}>
            <h4 style={{ fontSize: 'var(--text-sm)', marginBottom: 'var(--space-2)' }}>Preview (First {previewRows.length} rows)</h4>
            <table style={{ width: '100%', fontSize: 'var(--text-xs)', borderCollapse: 'collapse' }}>
              <tbody>
                {previewRows.map((row, i) => (
                  <tr key={i} style={{ borderBottom: '1px solid var(--border)' }}>
                    {row.map((col, j) => (
                      <td key={j} style={{ padding: 'var(--space-1) var(--space-2)' }}>{col}</td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </Modal>
  )
}
