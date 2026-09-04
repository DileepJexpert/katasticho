import { useQuery } from '@tanstack/react-query'
import { Tag } from 'lucide-react'
import { Link } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { DataTable, EmptyState, PageHeader, StatusChip } from '@/design-system'
import { listPriceLists, type PriceList } from '@/features/price-lists/price-lists-api'

export function PriceListsPage() {
  const priceLists = useQuery({
    queryKey: ['price-lists'],
    queryFn: listPriceLists,
  })

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Sales / Pricing"
        title="Price lists"
        description="Read-only tier-pricing review. Price-list maintenance remains in Flutter during migration."
      />

      <section className="list-panel" aria-label="Price list directory">
        {priceLists.isError ? (
          <div className="directory-state directory-state--error" role="alert">
            <strong>Price lists could not be loaded.</strong>
            <p>Check your connection and permissions, then refresh the page.</p>
          </div>
        ) : priceLists.isLoading ? (
          <div aria-live="polite" className="directory-state">Loading price lists...</div>
        ) : priceLists.data?.length ? (
          <DataTable caption="Price lists">
            <thead>
              <tr>
                <th scope="col">Price list</th>
                <th scope="col">Description</th>
                <th scope="col">Currency</th>
                <th scope="col">Default</th>
                <th scope="col">Status</th>
              </tr>
            </thead>
            <tbody>{priceLists.data.map((priceList) => <PriceListRow key={priceList.id} priceList={priceList} />)}</tbody>
          </DataTable>
        ) : (
          <EmptyState
            description="Price lists will appear here when they are configured for the organisation."
            icon={Tag}
            title="No price lists are available."
          />
        )}
      </section>
    </section>
  )
}

function PriceListRow({ priceList }: { priceList: PriceList }) {
  return (
    <tr>
      <td>
        <div className="item-primary">
          <span aria-hidden="true" className="item-avatar"><Tag size={15} /></span>
          <Link className="table-row-link" to={appRoutes.priceListDetail(priceList.id)}>{priceList.name}</Link>
        </div>
      </td>
      <td>{priceList.description ?? '--'}</td>
      <td><code>{priceList.currency ?? '--'}</code></td>
      <td><StatusChip status={priceList.isDefault ? 'Default' : 'Standard'} /></td>
      <td><StatusChip status={priceList.active ? 'Active' : 'Inactive'} /></td>
    </tr>
  )
}
