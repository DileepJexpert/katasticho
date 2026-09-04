import { useQuery } from '@tanstack/react-query'
import { Building2 } from 'lucide-react'
import { Link } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { DataTable, EmptyState, PageHeader, StatusChip } from '@/design-system'
import { listWarehouses, type Warehouse } from '@/features/warehouses/warehouses-api'

export function WarehousesPage() {
  const warehouses = useQuery({
    queryKey: ['warehouses'],
    queryFn: listWarehouses,
  })

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Inventory / Facilities"
        title="Warehouses"
        description="Read-only facility and storage-zone review. Warehouse maintenance remains in Flutter during migration."
      />

      <section className="list-panel" aria-label="Warehouse directory">
        {warehouses.isError ? (
          <div className="directory-state directory-state--error" role="alert">
            <strong>Warehouses could not be loaded.</strong>
            <p>Check your connection and permissions, then refresh the page.</p>
          </div>
        ) : warehouses.isLoading ? (
          <div aria-live="polite" className="directory-state">Loading warehouses...</div>
        ) : warehouses.data?.length ? (
          <DataTable caption="Warehouses">
            <thead>
              <tr>
                <th scope="col">Warehouse</th>
                <th scope="col">Location</th>
                <th scope="col">State code</th>
                <th scope="col">Default</th>
                <th scope="col">Status</th>
              </tr>
            </thead>
            <tbody>{warehouses.data.map((warehouse) => <WarehouseRow key={warehouse.id} warehouse={warehouse} />)}</tbody>
          </DataTable>
        ) : (
          <EmptyState
            description="Facilities will appear here when they are configured in the organisation."
            icon={Building2}
            title="No warehouses are available."
          />
        )}
      </section>
    </section>
  )
}

function WarehouseRow({ warehouse }: { warehouse: Warehouse }) {
  const location = [warehouse.city, warehouse.state, warehouse.country].filter(Boolean).join(', ')

  return (
    <tr>
      <td>
        <div className="item-primary">
          <span aria-hidden="true" className="item-avatar"><Building2 size={15} /></span>
          <div className="cell-stack">
            <Link className="table-row-link" to={appRoutes.warehouseDetail(warehouse.id)}>{warehouse.name}</Link>
            <code>{warehouse.code}</code>
          </div>
        </div>
      </td>
      <td>{location || warehouse.addressLine1 || '--'}</td>
      <td><code>{warehouse.stateCode ?? '--'}</code></td>
      <td><StatusChip status={warehouse.isDefault ? 'Default' : 'Standard'} /></td>
      <td><StatusChip status={warehouse.active ? 'Active' : 'Inactive'} /></td>
    </tr>
  )
}
