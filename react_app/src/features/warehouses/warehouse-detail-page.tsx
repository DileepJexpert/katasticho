import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { AlertTriangle, ArrowLeft, Layers } from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button, DataTable, DocumentCard, Fact, FactList, FilterTabs, PageHeader, StatusChip } from '@/design-system'
import { getWarehouse, listWarehouseZones, type Warehouse, type WarehouseZone } from '@/features/warehouses/warehouses-api'
import { formatDateTime, formatStatusLabel } from '@/shared/format/format'

type WarehouseTab = 'overview' | 'zones'

export function WarehouseDetailPage() {
  const { warehouseId } = useParams()
  const navigate = useNavigate()
  const [activeTab, setActiveTab] = useState<WarehouseTab>('overview')
  const warehouseQuery = useQuery({
    queryKey: ['warehouses', warehouseId],
    queryFn: () => getWarehouse(warehouseId!),
    enabled: Boolean(warehouseId),
  })
  const zonesQuery = useQuery({
    queryKey: ['warehouses', warehouseId, 'zones'],
    queryFn: () => listWarehouseZones(warehouseId!),
    enabled: Boolean(warehouseId) && activeTab === 'zones',
  })

  if (!warehouseId) return <WarehouseState message="No warehouse ID was specified." />
  if (warehouseQuery.isLoading) return <WarehouseState message="Loading warehouse details..." />
  if (warehouseQuery.isError || !warehouseQuery.data) {
    return (
      <section className="workspace-page">
        <div className="directory-state directory-state--error" role="alert">
          <AlertTriangle aria-hidden="true" size={24} />
          <strong>Warehouse details could not be loaded.</strong>
          <Button onClick={() => navigate(appRoutes.warehouses)} variant="secondary">Back to warehouses</Button>
        </div>
      </section>
    )
  }

  const warehouse = warehouseQuery.data

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Inventory / Facility review"
        title={warehouse.name}
        description={`${warehouse.code} · ${warehouse.city ?? warehouse.state ?? warehouse.country ?? 'No location'}`}
        actions={<StatusChip status={warehouse.active ? 'Active' : 'Inactive'} />}
      />

      <div className="document-actions">
        <Button onClick={() => navigate(appRoutes.warehouses)} variant="ghost">
          <ArrowLeft aria-hidden="true" size={16} />
          Back to warehouses
        </Button>
        <span className="cell-muted">Read-only review. Warehouse and zone changes remain in Flutter during migration.</span>
      </div>

      <FilterTabs
        activeValue={activeTab}
        ariaLabel="Warehouse review sections"
        items={[
          { value: 'overview', label: 'Overview' },
          { value: 'zones', label: 'Storage zones' },
        ]}
        onChange={(value) => setActiveTab(value as WarehouseTab)}
      />

      {activeTab === 'overview' && <WarehouseOverview warehouse={warehouse} />}
      {activeTab === 'zones' && <ZonesTab isError={zonesQuery.isError} isLoading={zonesQuery.isLoading} zones={zonesQuery.data ?? []} />}
    </section>
  )
}

function WarehouseState({ message }: { message: string }) {
  return <section className="workspace-page"><div aria-live="polite" className="directory-state">{message}</div></section>
}

function WarehouseOverview({ warehouse }: { warehouse: Warehouse }) {
  return (
    <div className="document-layout">
      <DocumentCard title="Facility details">
        <FactList>
          <Fact label="Warehouse code" mono value={warehouse.code} />
          <Fact label="Address line 1" value={warehouse.addressLine1} />
          <Fact label="Address line 2" value={warehouse.addressLine2} />
          <Fact label="City" value={warehouse.city} />
          <Fact label="State" value={warehouse.state} />
          <Fact label="State code" mono value={warehouse.stateCode} />
          <Fact label="Postal code" mono value={warehouse.postalCode} />
          <Fact label="Country" value={warehouse.country} />
        </FactList>
      </DocumentCard>
      <DocumentCard title="Record status" variant="summary">
        <FactList>
          <Fact label="Default warehouse" value={warehouse.isDefault ? 'Yes' : 'No'} />
          <Fact label="Operational status" value={<StatusChip status={warehouse.active ? 'Active' : 'Inactive'} />} />
          <Fact label="Created" value={formatDateTime(warehouse.createdAt)} />
        </FactList>
      </DocumentCard>
    </div>
  )
}

function ZonesTab({ isError, isLoading, zones }: { isError: boolean; isLoading: boolean; zones: WarehouseZone[] }) {
  if (isLoading) return <WarehouseState message="Loading storage zones..." />
  if (isError) return <div className="directory-state directory-state--error" role="alert">Storage zones could not be loaded.</div>
  if (!zones.length) return <div className="directory-state"><Layers aria-hidden="true" size={24} /><span>No storage zones are configured for this warehouse.</span></div>

  return (
    <DocumentCard title="Storage zones" variant="lines">
      <DataTable caption="Warehouse storage zones">
        <thead>
          <tr>
            <th scope="col">Zone</th>
            <th scope="col">Type</th>
            <th className="numeric-cell" scope="col">Capacity</th>
            <th className="numeric-cell" scope="col">Utilisation</th>
            <th scope="col">Temperature</th>
            <th scope="col">Notes</th>
          </tr>
        </thead>
        <tbody>{zones.map((zone) => (
          <tr key={zone.id}>
            <td><div className="cell-stack"><strong>{zone.name}</strong><code>{zone.code}</code></div></td>
            <td><StatusChip status={formatStatusLabel(zone.zoneType)} /></td>
            <td className="numeric-cell">{zone.capacity ?? '--'}</td>
            <td className="numeric-cell">{zone.currentUtilization ?? '--'}</td>
            <td>{zone.temperatureControlled ? 'Temperature controlled' : 'Ambient'}</td>
            <td>{zone.notes ?? '--'}</td>
          </tr>
        ))}</tbody>
      </DataTable>
    </DocumentCard>
  )
}
