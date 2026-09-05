import { useDeferredValue, useEffect, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Boxes, Plus } from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button, DataTable, DirectoryToolbar, EmptyState, FilterTabs, Money, PageHeader, Quantity, SearchInput, StatusChip, TablePagination } from '@/design-system'
import { getNegativeStockCount, listItems, type Item } from '@/features/items/items-api'
import { useInventoryAccess } from '@/features/inventory/inventory-access'
import { formatPercent, formatStatusLabel } from '@/shared/format/format'

type ItemFilter = 'ALL' | 'NEGATIVE_STOCK' | 'ACTIVE_ONLY'

export function ItemsPage() {
  const navigate = useNavigate()
  const access = useInventoryAccess()
  const [filter, setFilter] = useState<ItemFilter>('ALL')
  const [page, setPage] = useState(0)
  const [search, setSearch] = useState('')
  const deferredSearch = useDeferredValue(search)
  const negativeStockOnly = filter === 'NEGATIVE_STOCK'
  const activeOnly = filter === 'ACTIVE_ONLY'

  useEffect(() => {
    setPage(0)
  }, [deferredSearch, filter])

  const negativeStock = useQuery({ queryKey: ['items', 'negative-stock-count'], queryFn: getNegativeStockCount })
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
        title="Items"
        description="Manage your product catalog, pricing, tax, measurement units, and inventory controls."
        actions={access.operate && <>
          <Link className="button button--secondary" to={appRoutes.itemImport}>Import items</Link>
          <Button onClick={() => navigate(appRoutes.itemCreate)}>
            <Plus aria-hidden="true" size={16} />
            New item
          </Button>
        </>}
      />

      <section className="list-panel" aria-label="Item directory">
        <DirectoryToolbar ariaLabel="Filter inventory items by status and search">
          <FilterTabs
            activeValue={filter}
            ariaLabel="Filter inventory items"
            items={[
              { value: 'ALL', label: 'All items', count: filter === 'ALL' ? itemPage?.totalElements : undefined },
              { value: 'NEGATIVE_STOCK', label: 'Negative stock', count: negativeStock.isLoading ? undefined : negativeStock.data },
              { value: 'ACTIVE_ONLY', label: 'Active only' },
            ]}
            onChange={(value) => selectFilter(value as ItemFilter)}
          />
          <SearchInput
            ariaLabel="Search items"
            disabled={negativeStockOnly}
            onChange={setSearch}
            onClear={() => setSearch('')}
            placeholder={negativeStockOnly ? 'Search is unavailable in negative-stock view' : 'Search name, SKU, barcode, or HSN'}
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
                  <th scope="col">Item</th><th scope="col">Type</th><th className="numeric-cell" scope="col">On hand</th>
                  <th className="numeric-cell" scope="col">Purchase price</th><th className="numeric-cell" scope="col">Sale price</th>
                  <th scope="col">GST and unit</th><th scope="col">Status</th>
                </tr>
              </thead>
              <tbody>{itemPage.content.map((item) => <ItemRow item={item} key={item.id} />)}</tbody>
            </DataTable>
            <TablePagination
              filterDescription={deferredSearch ? 'matching this search' : negativeStockOnly ? 'with negative stock' : activeOnly ? 'that are active' : 'in this organisation'}
              isFiltered={Boolean(deferredSearch || negativeStockOnly || activeOnly)}
              itemLabel="item"
              onPageChange={setPage}
              page={itemPage.page}
              totalElements={itemPage.totalElements}
              totalPages={itemPage.totalPages}
            />
          </>
        ) : (
          <EmptyState
            action={
              access.operate && !negativeStockOnly && !deferredSearch ? (
                <Button onClick={() => navigate(appRoutes.itemCreate)}>
                  <Plus aria-hidden="true" size={16} />
                  New item
                </Button>
              ) : undefined
            }
            description={negativeStockOnly ? 'Every inventory-tracked item is at zero or above.' : deferredSearch ? 'Try a different name, SKU, barcode, or HSN.' : 'No catalog items are available in this organisation.'}
            icon={Boxes}
            title={negativeStockOnly ? 'No items have negative stock.' : 'No items found.'}
          />
        )}
      </section>
    </section>
  )
}

function ItemRow({ item }: { item: Item }) {
  const stock = Number(item.totalOnHand) || 0
  const reorderLevel = Number(item.reorderLevel) || 0
  const stockStatus = stock < 0
    ? 'Negative stock'
    : stock === 0
      ? 'Out of stock'
      : reorderLevel > 0 && stock <= reorderLevel
        ? 'Low stock'
        : 'In stock'

  return (
    <tr>
      <td>
        <div className="item-primary">
          <span aria-hidden="true" className="item-avatar"><Boxes size={15} /></span>
          <div className="cell-stack">
            <Link className="table-row-link" to={appRoutes.itemDetail(item.id)}>{item.name}</Link>
            <code>{item.sku ?? item.barcode ?? '--'}</code>
          </div>
        </div>
      </td>
      <td><span className="item-type">{formatStatusLabel(item.itemType)}</span></td>
      <td className="numeric-cell">{item.trackInventory ? <Quantity unit={item.unitOfMeasure} value={item.totalOnHand} /> : <span className="cell-muted">Not tracked</span>}</td>
      <td className="numeric-cell"><Money amount={item.purchasePrice} /></td>
      <td className="numeric-cell"><Money amount={item.salePrice} /></td>
      <td><div className="cell-stack"><code>{item.hsnCode ? `HSN ${item.hsnCode}` : '--'}</code><span>{formatPercent(item.gstRate)} · {item.unitOfMeasure ?? '--'}</span></div></td>
      <td><StatusChip status={item.active ? (item.trackInventory ? stockStatus : 'Active') : 'Inactive'} /></td>
    </tr>
  )
}
