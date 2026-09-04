import { useState } from 'react'
import type { ReactNode } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  ArrowLeft,
  Boxes,
  Layers,
  Plus,
  Snowflake,
} from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import {
  confirmPutawayLine,
  createWarehouseZone,
  getWarehouse,
  listPutawayTasks,
  listWarehouseZones,
  type PutawayTask,
} from '@/features/warehouses/warehouses-api'

export function WarehouseDetailPage() {
  const { warehouseId } = useParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [activeTab, setActiveTab] = useState<'zones' | 'putaway'>('zones')

  // Modals
  const [showAddZoneModal, setShowAddZoneModal] = useState(false)
  const [selectedPutawayLine, setSelectedPutawayLine] = useState<{ taskId: string; line: PutawayTask['lines'][number] } | null>(null)

  const warehouse = useQuery({
    queryKey: ['warehouses', warehouseId],
    queryFn: () => getWarehouse(warehouseId!),
    enabled: Boolean(warehouseId),
  })

  const zonesQuery = useQuery({
    queryKey: ['warehouses', warehouseId, 'zones'],
    queryFn: () => listWarehouseZones(warehouseId!),
    enabled: Boolean(warehouseId),
  })

  const putawayQuery = useQuery({
    queryKey: ['warehouses', warehouseId, 'putaway-tasks'],
    queryFn: () => listPutawayTasks(warehouseId!),
    enabled: Boolean(warehouseId) && activeTab === 'putaway',
  })

  if (!warehouseId) return <DocumentError onBack={() => navigate(appRoutes.warehouses)} />
  if (warehouse.isLoading) return <section className="workspace-page"><div aria-live="polite" className="directory-state">Loading warehouse details...</div></section>
  if (warehouse.isError || !warehouse.data) return <DocumentError onBack={() => navigate(appRoutes.warehouses)} />

  const doc = warehouse.data

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Inventory / Infrastructure / Warehouse"
        title={doc.name}
        description={`Code: ${doc.code} · Type: ${doc.warehouseType ?? 'CENTRAL'} · GSTIN: ${doc.gstin ?? '--'}`}
        actions={
          <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
            <StatusChip status={doc.isDefault ? 'Primary Hub' : 'Standard'} />
            <StatusChip status={doc.active ? 'Active' : 'Inactive'} />
          </div>
        }
      />

      <div className="document-actions">
        <Button onClick={() => navigate(appRoutes.warehouses)} variant="secondary">
          <ArrowLeft aria-hidden="true" size={16} /> Back to warehouses
        </Button>
      </div>

      <div className="document-layout">
        <section className="document-card">
          <h2>Facility Address & Info</h2>
          <dl className="document-facts">
            <Fact label="Address" value={doc.addressLine1 ?? '--'} />
            <Fact label="City, State" value={doc.city ? `${doc.city}, ${doc.state ?? ''} - ${doc.pincode ?? ''}` : '--'} />
            <Fact label="GSTIN" value={doc.gstin ?? '--'} />
            <Fact label="Facility Type" value={doc.warehouseType ?? 'CENTRAL'} />
          </dl>
        </section>

        <aside className="document-card document-card--summary">
          <h2>Topology Overview</h2>
          <div className="progress-row"><span>Defined Zones</span><strong>{zonesQuery.data?.length ?? 0}</strong></div>
          <div className="progress-row"><span>Status</span><StatusChip status={doc.active ? 'Active' : 'Inactive'} /></div>
        </aside>
      </div>

      {/* Tabs */}
      <div className="role-tabs" role="tablist" style={{ marginTop: '1.5rem', marginBottom: '1.5rem' }}>
        <button
          className={activeTab === 'zones' ? 'role-tab role-tab--active' : 'role-tab'}
          onClick={() => setActiveTab('zones')}
          role="tab"
          type="button"
        >
          <Layers size={16} style={{ marginRight: '0.5rem' }} />
          Storage Zones & Bins ({zonesQuery.data?.length ?? 0})
        </button>
        <button
          className={activeTab === 'putaway' ? 'role-tab role-tab--active' : 'role-tab'}
          onClick={() => setActiveTab('putaway')}
          role="tab"
          type="button"
        >
          <Boxes size={16} style={{ marginRight: '0.5rem' }} />
          Putaway Tasks ({putawayQuery.data?.length ?? 0})
        </button>
      </div>

      {activeTab === 'zones' && (
        <section className="document-card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
            <h3>Storage Zones</h3>
            <Button onClick={() => setShowAddZoneModal(true)} variant="primary">
              <Plus size={16} /> Add Zone
            </Button>
          </div>

          {zonesQuery.isLoading ? (
            <div className="directory-state">Loading warehouse zones...</div>
          ) : !zonesQuery.data?.length ? (
            <div className="directory-state">
              <Layers size={24} />
              <strong>No zones configured for this warehouse.</strong>
              <p>Add storage, receiving, pick-face, or cold-storage zones to enable bin-level putaway.</p>
            </div>
          ) : (
            <DataTable caption="Warehouse Zones">
              <thead>
                <tr>
                  <th scope="col">Zone Code</th>
                  <th scope="col">Zone Name</th>
                  <th scope="col">Zone Type</th>
                  <th className="numeric-cell" scope="col">Capacity</th>
                  <th scope="col">Temp Controlled</th>
                  <th scope="col">Notes</th>
                </tr>
              </thead>
              <tbody>
                {zonesQuery.data.map((z) => (
                  <tr key={z.id}>
                    <td><code>{z.code}</code></td>
                    <td><strong>{z.name}</strong></td>
                    <td><StatusChip status={z.zoneType} /></td>
                    <td className="numeric-cell">{z.capacity ?? 'Unlimited'}</td>
                    <td>
                      {z.temperatureControlled ? (
                        <span style={{ display: 'flex', alignItems: 'center', gap: '0.25rem', color: '#0284c7' }}>
                          <Snowflake size={14} /> Cold Storage (2-8Â°C)
                        </span>
                      ) : (
                        'Ambient'
                      )}
                    </td>
                    <td>{z.notes ?? '--'}</td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          )}
        </section>
      )}

      {activeTab === 'putaway' && (
        <section className="document-card">
          <h3>Active Putaway Recommendations</h3>
          {putawayQuery.isLoading ? (
            <div className="directory-state">Loading putaway tasks...</div>
          ) : !putawayQuery.data?.length ? (
            <div className="directory-state">
              <Boxes size={24} />
              <strong>No pending putaway tasks.</strong>
              <p>Putaway tasks generate automatically upon Goods Receipt to suggest optimal bin locations.</p>
            </div>
          ) : (
            putawayQuery.data.map((task) => (
              <div key={task.id} style={{ marginBottom: '1.5rem', border: '1px solid var(--color-border)', borderRadius: '6px', padding: '1rem' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '0.75rem' }}>
                  <strong>Putaway Task #{task.taskId}</strong>
                  <StatusChip status={task.status} />
                </div>
                <DataTable caption="Putaway Lines">
                  <thead>
                    <tr>
                      <th scope="col">Item</th>
                      <th className="numeric-cell" scope="col">Quantity</th>
                      <th scope="col">Suggested Zone</th>
                      <th scope="col">Confirmed Bin / Rack</th>
                      <th scope="col">Status</th>
                      <th scope="col">Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {task.lines.map((l) => (
                      <tr key={l.id}>
                        <td><strong>{l.itemName}</strong></td>
                        <td className="numeric-cell">{l.quantity}</td>
                        <td>{l.suggestedZoneName ?? l.suggestedZoneId ?? 'Storage'}</td>
                        <td>{l.confirmedRack ?? '--'}</td>
                        <td><StatusChip status={l.status} /></td>
                        <td>
                          {l.status === 'PENDING' && (
                            <Button onClick={() => setSelectedPutawayLine({ taskId: task.id, line: l })} variant="ghost">
                              Confirm Putaway
                            </Button>
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </DataTable>
              </div>
            ))
          )}
        </section>
      )}

      {/* Add Zone Modal */}
      {showAddZoneModal && (
        <AddZoneModal
          onClose={() => setShowAddZoneModal(false)}
          onSuccess={() => {
            setShowAddZoneModal(false)
            queryClient.invalidateQueries({ queryKey: ['warehouses', warehouseId, 'zones'] })
          }}
          warehouseId={warehouseId}
        />
      )}

      {/* Confirm Putaway Modal */}
      {selectedPutawayLine && (
        <ConfirmPutawayModal
          line={selectedPutawayLine.line}
          onClose={() => setSelectedPutawayLine(null)}
          onSuccess={() => {
            setSelectedPutawayLine(null)
            queryClient.invalidateQueries({ queryKey: ['warehouses', warehouseId, 'putaway-tasks'] })
          }}
          taskId={selectedPutawayLine.taskId}
        />
      )}
    </section>
  )
}

function AddZoneModal({
  warehouseId,
  onClose,
  onSuccess,
}: {
  warehouseId: string
  onClose: () => void
  onSuccess: () => void
}) {
  const [code, setCode] = useState('')
  const [name, setName] = useState('')
  const [zoneType, setZoneType] = useState('STORAGE')
  const [capacity, setCapacity] = useState('')
  const [temperatureControlled, setTemperatureControlled] = useState(false)
  const [notes, setNotes] = useState('')

  const mutation = useMutation({
    mutationFn: () =>
      createWarehouseZone(warehouseId, {
        code,
        name,
        zoneType,
        capacity: capacity ? Number(capacity) : undefined,
        temperatureControlled,
        notes: notes || undefined,
      }),
    onSuccess: () => onSuccess(),
  })

  return (
    <div className="modal-backdrop" role="dialog">
      <div className="modal-dialog">
        <header className="modal-header">
          <h3>Add Storage Zone</h3>
          <Button onClick={onClose} variant="ghost">✕</Button>
        </header>
        <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 2fr', gap: '1rem' }}>
            <label className="field-group">
              <span>Zone Code *</span>
              <input onChange={(e) => setCode(e.target.value)} placeholder="e.g. ZONE-A" value={code} />
            </label>
            <label className="field-group">
              <span>Zone Name *</span>
              <input onChange={(e) => setName(e.target.value)} placeholder="e.g. High-Bay Pallet Racks" value={name} />
            </label>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
            <label className="field-group">
              <span>Zone Type</span>
              <select onChange={(e) => setZoneType(e.target.value)} value={zoneType}>
                <option value="STORAGE">Bulk Storage</option>
                <option value="PICK_FACE">Pick Face</option>
                <option value="RECEIVING">Inbound Receiving</option>
                <option value="SHIPPING">Outbound Shipping</option>
                <option value="COLD_STORAGE">Cold Storage</option>
                <option value="QUARANTINE">Quarantine</option>
              </select>
            </label>
            <label className="field-group">
              <span>Capacity (Pallets/Units)</span>
              <input onChange={(e) => setCapacity(e.target.value)} placeholder="e.g. 500" type="number" value={capacity} />
            </label>
          </div>
          <label style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
            <input checked={temperatureControlled} onChange={(e) => setTemperatureControlled(e.target.checked)} type="checkbox" />
            <span>Temperature Controlled (Cold Storage)</span>
          </label>
          <label className="field-group">
            <span>Notes</span>
            <input onChange={(e) => setNotes(e.target.value)} placeholder="Aisle 1 through 6" value={notes} />
          </label>
        </div>
        <footer className="modal-footer">
          <Button onClick={onClose} variant="secondary">Cancel</Button>
          <Button disabled={!code || !name || mutation.isPending} onClick={() => mutation.mutate()} variant="primary">
            {mutation.isPending ? 'Saving...' : 'Add Zone'}
          </Button>
        </footer>
      </div>
    </div>
  )
}

function ConfirmPutawayModal({
  taskId,
  line,
  onClose,
  onSuccess,
}: {
  taskId: string
  line: PutawayTask['lines'][number]
  onClose: () => void
  onSuccess: () => void
}) {
  const [confirmedRack, setConfirmedRack] = useState(line.confirmedRack || 'RACK-A-01')

  const mutation = useMutation({
    mutationFn: () =>
      confirmPutawayLine(taskId, line.id, {
        confirmedZoneId: line.suggestedZoneId || 'ZONE-A',
        confirmedRack,
      }),
    onSuccess: () => onSuccess(),
  })

  return (
    <div className="modal-backdrop" role="dialog">
      <div className="modal-dialog">
        <header className="modal-header">
          <h3>Confirm Bin / Rack Putaway</h3>
          <Button onClick={onClose} variant="ghost">✕</Button>
        </header>
        <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <p>
            Item: <strong>{line.itemName}</strong> (Qty: {line.quantity})
          </p>
          <label className="field-group">
            <span>Allocated Rack / Bin Location *</span>
            <input onChange={(e) => setConfirmedRack(e.target.value)} placeholder="e.g. RACK-A-04-BIN-2" value={confirmedRack} />
          </label>
        </div>
        <footer className="modal-footer">
          <Button onClick={onClose} variant="secondary">Cancel</Button>
          <Button disabled={!confirmedRack || mutation.isPending} onClick={() => mutation.mutate()} variant="primary">
            {mutation.isPending ? 'Confirming...' : 'Confirm Putaway'}
          </Button>
        </footer>
      </div>
    </div>
  )
}

function Fact({ label, value }: { label: string; value: ReactNode }) {
  return (
    <div className="document-fact">
      <dt>{label}</dt>
      <dd>{value}</dd>
    </div>
  )
}

function DocumentError({ onBack }: { onBack: () => void }) {
  return (
    <section className="workspace-page">
      <div className="directory-state directory-state--error" role="alert">
        <strong>Warehouse not found.</strong>
        <p>The requested warehouse could not be loaded.</p>
        <Button onClick={onBack} variant="secondary">Back to warehouses</Button>
      </div>
    </section>
  )
}