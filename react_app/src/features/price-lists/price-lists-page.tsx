import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Tag } from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button, DataTable, DirectoryToolbar, EmptyState, PageHeader, SearchInput, StatusChip } from '@/design-system'
import { listPriceLists, type PriceList } from '@/features/price-lists/price-lists-api'
import { PriceListCreateModal } from './price-list-create-modal'
import { useCanManagePricing } from './pricing-shared'

export function PriceListsPage() {
  const navigate = useNavigate()
  const canManage = useCanManagePricing()
  const [creating, setCreating] = useState(false)
  const [search, setSearch] = useState('')
  const priceLists = useQuery({
    queryKey: ['price-lists'],
    queryFn: listPriceLists,
  })
  const lists = (priceLists.data ?? []).filter((list) => `${list.name} ${list.description ?? ''}`.toLowerCase().includes(search.toLowerCase()))

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Sales / Pricing"
        title="Price lists"
        description="Maintain quantity-based rates and customer pricing assignments."
        actions={canManage ? <Button onClick={() => setCreating(true)}>New price list</Button> : undefined}
      />

      <section className="list-panel" aria-label="Price list directory">
        <DirectoryToolbar actions={<Button variant="ghost" onClick={() => void priceLists.refetch()}>Refresh</Button>}><SearchInput ariaLabel="Search price lists" value={search} onChange={setSearch} placeholder="Search name or description" /></DirectoryToolbar>
        {priceLists.isError ? (
          <div className="directory-state directory-state--error" role="alert">
            <strong>Price lists could not be loaded.</strong>
            <p>Check your connection and permissions, then refresh the page.</p>
          </div>
        ) : priceLists.isLoading ? (
          <div aria-live="polite" className="directory-state">Loading price lists...</div>
        ) : lists.length ? (
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
            <tbody>{lists.map((priceList) => <PriceListRow key={priceList.id} priceList={priceList} />)}</tbody>
          </DataTable>
        ) : (
          <EmptyState
            description="Price lists will appear here when they are configured for the organisation."
            icon={Tag}
            title="No price lists are available."
          />
        )}
      </section>
      {creating && <PriceListCreateModal onClose={() => setCreating(false)} onCreated={(id) => navigate(appRoutes.priceListDetail(id))} />}
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
