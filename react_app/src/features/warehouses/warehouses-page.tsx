import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Building2, Plus } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import {
  createWarehouse,
  listWarehouses,
  type CreateWarehouseRequest,
  type Warehouse,
} from '@/features/warehouses/warehouses-api'

export function WarehousesPage() {
  const [showCreateModal, setShowCreateModal] = useState(false)
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const warehouses = useQuery({
    queryKey: ['warehouses'],
    queryFn: listWarehouses,
  })

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Inventory / Infrastructure"
        title="Warehouses & Depots"
        description="Multi-warehouse facilities, multi-zone bin topologies, and automated putaway allocation tasks."
        actions={
          <Button onClick={() => setShowCreateModal(true)} variant="primary">
            <Plus size={16} /> Add Warehouse
          </Button>
        }
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
                <th scope="col">Type</th>
                <th scope="col">Location / City</th>
                <th scope="col">GSTIN</th>
                <th scope="col">Default</th>
                <th scope="col">Status</th>
                <th scope="col">Actions</th>
              </tr>
            </thead>
            <tbody>
              {warehouses.data.map((wh) => (
                <WarehouseRow
                  key={wh.id}
                  onOpen={() => navigate(appRoutes.warehouseDetail ? appRoutes.warehouseDetail(wh.id) : `/warehouses/${wh.id}`)}
                  warehouse={wh}
                />
              ))}
            </tbody>
          </DataTable>
        ) : (
          <div className="directory-state">
            <Building2 aria-hidden="true" size={24} />
            <strong>No warehouses defined.</strong>
            <p>Create central warehouses, regional distribution centers, or transit stock depots.</p>
          </div>
        )}
      </section>

      {/* Create Modal */}
      {showCreateModal && (
        <CreateWarehouseModal
          onClose={() => setShowCreateModal(false)}
          onSuccess={(id) => {
            setShowCreateModal(false)
            queryClient.invalidateQueries({ queryKey: ['warehouses'] })
            navigate(appRoutes.warehouseDetail ? appRoutes.warehouseDetail(id) : `/warehouses/${id}`)
          }}
        />
      )}
    </section>
  )
}

function WarehouseRow({ onOpen, warehouse }: { onOpen: () => void; warehouse: Warehouse }) {
  return (
    <tr onClick={onOpen} style={{ cursor: 'pointer' }}>
      <td>
        <div className="item-primary">
          <span aria-hidden="true" className="item-avatar"><Building2 size={15} /></span>
          <div className="cell-stack">
            <strong>{warehouse.name}</strong>
            <code>{warehouse.code}</code>
          </div>
        </div>
      </td>
      <td>{warehouse.warehouseType ?? 'CENTRAL'}</td>
      <td>
        <div className="cell-stack">
          <span>{warehouse.city ? `${warehouse.city}, ${warehouse.state ?? ''}` : warehouse.addressLine1 ?? '--'}</span>
          <code>{warehouse.pincode ?? ''}</code>
        </div>
      </td>
      <td><code>{warehouse.gstin ?? '--'}</code></td>
      <td><StatusChip status={warehouse.isDefault ? 'Primary Hub' : 'Standard'} /></td>
      <td><StatusChip status={warehouse.active ? 'Active' : 'Inactive'} /></td>
      <td>
        <Button onClick={(e) => { e.stopPropagation(); onOpen() }} variant="ghost">
          Manage Zones
        </Button>
      </td>
    </tr>
  )
}

function CreateWarehouseModal({ onClose, onSuccess }: { onClose: () => void; onSuccess: (id: string) => void }) {
  const [code, setCode] = useState('')
  const [name, setName] = useState('')
  const [warehouseType, setWarehouseType] = useState('CENTRAL')
  const [addressLine1, setAddressLine1] = useState('')
  const [city, setCity] = useState('')
  const [state, setState] = useState('')
  const [pincode, setPincode] = useState('')
  const [gstin, setGstin] = useState('')
  const [isDefault, setIsDefault] = useState(false)

  const mutation = useMutation({
    mutationFn: () => {
      const payload: CreateWarehouseRequest = {
        code,
        name,
        warehouseType,
        addressLine1: addressLine1 || undefined,
        city: city || undefined,
        state: state || undefined,
        pincode: pincode || undefined,
        gstin: gstin || undefined,
        isDefault,
      }
      return createWarehouse(payload)
    },
    onSuccess: (res) => onSuccess(res.id),
  })

  return (
    <div className="modal-backdrop" role="dialog">
      <div className="modal-dialog" style={{ maxWidth: '600px' }}>
        <header className="modal-header">
          <h3>Create Warehouse Facility</h3>
          <Button onClick={onClose} variant="ghost">✕</Button>
        </header>
        <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 2fr', gap: '1rem' }}>
            <label className="field-group">
              <span>Warehouse Code *</span>
              <input onChange={(e) => setCode(e.target.value)} placeholder="e.g. WH-BOM" value={code} />
            </label>
            <label className="field-group">
              <span>Facility Name *</span>
              <input onChange={(e) => setName(e.target.value)} placeholder="e.g. Mumbai Central Depot" value={name} />
            </label>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
            <label className="field-group">
              <span>Facility Type</span>
              <select onChange={(e) => setWarehouseType(e.target.value)} value={warehouseType}>
                <option value="CENTRAL">Central Distribution Center</option>
                <option value="REGIONAL">Regional Depot</option>
                <option value="RETAIL">Retail Store Stockroom</option>
                <option value="TRANSIT">Transit Hub</option>
              </select>
            </label>
            <label className="field-group">
              <span>State GSTIN</span>
              <input onChange={(e) => setGstin(e.target.value)} placeholder="e.g. 27AAAAA0000A1Z5" value={gstin} />
            </label>
          </div>

          <label className="field-group">
            <span>Address</span>
            <input onChange={(e) => setAddressLine1(e.target.value)} placeholder="Building, Street, Industrial Area" value={addressLine1} />
          </label>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '1rem' }}>
            <label className="field-group">
              <span>City</span>
              <input onChange={(e) => setCity(e.target.value)} placeholder="e.g. Mumbai" value={city} />
            </label>
            <label className="field-group">
              <span>State</span>
              <input onChange={(e) => setState(e.target.value)} placeholder="e.g. Maharashtra" value={state} />
            </label>
            <label className="field-group">
              <span>Pincode</span>
              <input onChange={(e) => setPincode(e.target.value)} placeholder="400001" value={pincode} />
            </label>
          </div>

          <label style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
            <input checked={isDefault} onChange={(e) => setIsDefault(e.target.checked)} type="checkbox" />
            <span>Set as Default Primary Warehouse</span>
          </label>
        </div>
        <footer className="modal-footer">
          <Button onClick={onClose} variant="secondary">Cancel</Button>
          <Button disabled={!code || !name || mutation.isPending} onClick={() => mutation.mutate()} variant="primary">
            {mutation.isPending ? 'Creating...' : 'Create Facility'}
          </Button>
        </footer>
      </div>
    </div>
  )
}