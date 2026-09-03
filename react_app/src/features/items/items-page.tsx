import { useDeferredValue, useEffect, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Boxes, ChevronLeft, ChevronRight, Search } from 'lucide-react'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import { getNegativeStockCount, listItems, type Item } from '@/features/items/items-api'

type ItemFilter = 'ALL' | 'NEGATIVE_STOCK'

export function ItemsPage() {
  const [filter, setFilter] = useState<ItemFilter>('ALL')
  const [page, setPage] = useState(0)
  const [search, setSearch] = useState('')
  const deferredSearch = useDeferredValue(search)
  const negativeStockOnly = filter === 'NEGATIVE_STOCK'

  useEffect(() => {
    setPage(0)
  }, [deferredSearch, filter])

  const negativeStock = useQuery({
    queryKey: ['items', 'negative-stock-count'],
    queryFn: getNegativeStockCount,
  })
  const items = useQuery({
    queryKey: ['items', { negativeStockOnly, page, search: deferredSearch }],
    queryFn: () => listItems({ negativeStockOnly, page, search: deferredSearch }),
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
        title="Items"
        description="Master items with server-returned on-hand stock, pricing, and GST information."
        actions={<StatusChip status="Read-only pilot" />}
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
                </tr>
              </thead>
              <tbody>
                {itemPage.content.map((item) => <ItemRow item={item} key={item.id} />)}
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
            <p>{negativeStockOnly ? 'Every inventory-tracked item is at zero or above.' : deferredSearch ? 'Try a different name, SKU, barcode, or HSN.' : 'Create items in the existing Flutter workflow while this React directory is read-only.'}</p>
          </div>
        )}
      </section>

      <p className="directory-note">On-hand, price, GST, and item status come from the existing inventory API. Stock labels are presentation only and do not change the inventory ledger.</p>
    </section>
  )
}

function ItemRow({ item }: { item: Item }) {
  const itemCode = item.sku ?? item.barcode ?? '--'

  return (
    <tr>
      <td>
        <div className="item-primary"><span aria-hidden="true" className="item-avatar"><Boxes size={15} /></span><div className="cell-stack"><strong>{item.name}</strong><code>{itemCode}</code></div></div>
      </td>
      <td><span className="item-type">{formatItemType(item.itemType)}</span></td>
      <td className="numeric-cell"><ItemStock item={item} /></td>
      <td className="numeric-cell"><Money amount={item.purchasePrice} /></td>
      <td className="numeric-cell"><Money amount={item.salePrice} /></td>
      <td><div className="cell-stack"><code>{item.hsnCode ? `HSN ${item.hsnCode}` : '--'}</code><span>{formatGst(item.gstRate)} · {item.unitOfMeasure ?? '--'}</span></div></td>
      <td><StatusChip status={item.active ? 'Active' : 'Inactive'} /></td>
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
