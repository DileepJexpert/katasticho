import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Building2 } from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button, DataTable, DirectoryToolbar, EmptyState, PageHeader, SearchInput, StatusChip } from '@/design-system'
import { useInventoryAccess } from '@/features/inventory/inventory-access'
import { WarehouseFormModal } from './warehouse-form-modal'
import { listWarehouses, type Warehouse } from '@/features/warehouses/warehouses-api'

export function WarehousesPage() {
  const [creating, setCreating] = useState(false)
  const [search, setSearch] = useState('')
  const access = useInventoryAccess()
  const navigate = useNavigate()
  const warehouses = useQuery({
    queryKey: ['warehouses'],
    queryFn: listWarehouses,
  })
  const rows = (warehouses.data ?? []).filter((warehouse) => `${warehouse.code} ${warehouse.name} ${warehouse.city ?? ''}`.toLowerCase().includes(search.toLowerCase()))

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Inventory / Facilities"
        title="Warehouses"
        description="Maintain facilities, addresses, and the organisation default warehouse."
        actions={<><Button variant="secondary" onClick={() => void warehouses.refetch()}>Refresh</Button>{access.manage && <Button onClick={() => setCreating(true)}>Create warehouse</Button>}</>}
      />

      <section className="list-panel" aria-label="Warehouse directory">
        <DirectoryToolbar><SearchInput ariaLabel="Search warehouses" value={search} onChange={setSearch} placeholder="Search code, name, or city" /></DirectoryToolbar>
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
            <tbody>{rows.map((warehouse) => <WarehouseRow key={warehouse.id} warehouse={warehouse} />)}{!rows.length && <tr><td colSpan={5}>No warehouses match your search.</td></tr>}</tbody>
          </DataTable>
        ) : (
          <EmptyState
            description="Facilities will appear here when they are configured in the organisation."
            icon={Building2}
            title="No warehouses are available."
          />
        )}
      </section>
      {creating && <WarehouseFormModal onClose={() => setCreating(false)} onSaved={(id) => { setCreating(false); navigate(appRoutes.warehouseDetail(id)) }} />}
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
