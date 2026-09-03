import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  ArrowRightLeft,
  Plus,
  Truck,
} from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDateTime } from '@/shared/format/format'
import {
  createTransferOrder,
  listTransferOrders,
} from '@/features/transfer-orders/transfer-orders-api'
import { listWarehouses } from '@/features/warehouses/warehouses-api'
import { listItems, type Item } from '@/features/items/items-api'

export function TransferOrdersPage() {
  const [page] = useState(0)
  const [showCreateModal, setShowCreateModal] = useState(false)
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const transferOrdersQuery = useQuery({
    queryKey: ['transfer-orders', page],
    queryFn: () => listTransferOrders({ page }),
  })

  const orders = transferOrdersQuery.data?.content ?? []

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
            <Button onClick={() => setShowCreateModal(true)} variant="primary">
              <Plus className="icon" /> New Transfer Order
            </Button>
          </div>
        }
        description="Inter-warehouse stock movements, in-transit telemetry tracking, and destination receipt reconciliations."
        eyebrow="Inventory / Logistics"
        title="Transfer Orders"
      />

      {transferOrdersQuery.isLoading ? (
        <div className="directory-state">Loading transfer orders...</div>
      ) : orders.length > 0 ? (
        <DataTable caption="Transfer Orders">
          <thead>
            <tr>
              <th scope="col">Transfer Order</th>
              <th scope="col">Route</th>
              <th scope="col">Status</th>
              <th className="numeric-cell" scope="col">Items Count</th>
              <th scope="col">Date Created</th>
              <th scope="col">Actions</th>
            </tr>
          </thead>
          <tbody>
            {orders.map((row) => (
              <tr key={row.id}>
                <td>
                  <Link to={`${appRoutes.transferOrders}/${row.id}`}>
                    <strong>{row.orderNumber}</strong>
                  </Link>
                </td>
                <td>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                    <span>{row.sourceWarehouseName ?? 'Source'}</span>
                    <ArrowRightLeft className="icon" style={{ opacity: 0.5, width: 14, height: 14 }} />
                    <span>{row.destinationWarehouseName ?? 'Destination'}</span>
                  </div>
                </td>
                <td>
                  <StatusChip status={row.status} />
                </td>
                <td className="numeric-cell">{row.lines?.length ?? 0}</td>
                <td>{formatDateTime(row.createdAt)}</td>
                <td>
                  <Button onClick={() => navigate(`${appRoutes.transferOrders}/${row.id}`)} variant="secondary">
                    View Detail
                  </Button>
                </td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      ) : (
        <div className="directory-state">
          No transfer orders created yet. Initiate an inter-warehouse shipment above.
        </div>
      )}

      {showCreateModal && (
        <CreateTransferOrderModal
          onClose={() => setShowCreateModal(false)}
          onSuccess={(orderId) => {
            setShowCreateModal(false)
            queryClient.invalidateQueries({ queryKey: ['transfer-orders'] })
            navigate(`${appRoutes.transferOrders}/${orderId}`)
          }}
        />
      )}
    </section>
  )
}

function CreateTransferOrderModal({
  onClose,
  onSuccess,
}: {
  onClose: () => void
  onSuccess: (orderId: string) => void
}) {
  const [sourceWarehouseId, setSourceWarehouseId] = useState('')
  const [destinationWarehouseId, setDestinationWarehouseId] = useState('')
  const [notes, setNotes] = useState('')
  const [lines, setLines] = useState<{ itemId: string; requestedQuantity: number; batchNumber?: string }[]>([
    { itemId: '', requestedQuantity: 1 },
  ])

  const warehousesQuery = useQuery({
    queryKey: ['warehouses-dropdown'],
    queryFn: listWarehouses,
  })

  const itemsQuery = useQuery({
    queryKey: ['items-dropdown'],
    queryFn: () => listItems(),
  })

  const mutation = useMutation({
    mutationFn: () =>
      createTransferOrder({
        sourceWarehouseId,
        destinationWarehouseId,
        notes,
        lines: lines
          .filter((l) => Boolean(l.itemId))
          .map((l) => ({
            itemId: l.itemId,
            requestedQuantity: Number(l.requestedQuantity || 1),
            batchNumber: l.batchNumber || undefined,
          })),
      }),
    onSuccess: (res) => onSuccess(res.id),
  })

  function addLine() {
    setLines([...lines, { itemId: '', requestedQuantity: 1 }])
  }

  function updateLine(idx: number, patch: Partial<{ itemId: string; requestedQuantity: number; batchNumber?: string }>) {
    setLines((prev) =>
      prev.map((item, i) => (i === idx ? { ...item, ...patch } : item))
    )
  }

  function removeLine(idx: number) {
    setLines(lines.filter((_, i) => i !== idx))
  }

  return (
    <div className="modal-backdrop" role="dialog">
      <div className="modal-dialog" style={{ maxWidth: '650px' }}>
        <header className="modal-header">
          <h3>Create Inter-Warehouse Transfer Order</h3>
          <Button onClick={onClose} variant="ghost">âœ•</Button>
        </header>
        <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
            <label className="field-group">
              <span>Source Warehouse</span>
              <select onChange={(e) => setSourceWarehouseId(e.target.value)} value={sourceWarehouseId}>
                <option value="">-- Select Source --</option>
                {warehousesQuery.data?.map((w) => (
                  <option key={w.id} value={w.id}>
                    {w.name} ({w.code})
                  </option>
                ))}
              </select>
            </label>
            <label className="field-group">
              <span>Destination Warehouse</span>
              <select onChange={(e) => setDestinationWarehouseId(e.target.value)} value={destinationWarehouseId}>
                <option value="">-- Select Destination --</option>
                {warehousesQuery.data?.map((w) => (
                  <option key={w.id} value={w.id}>
                    {w.name} ({w.code})
                  </option>
                ))}
              </select>
            </label>
          </div>

          <div>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.5rem' }}>
              <h4>Transfer Items</h4>
              <Button onClick={addLine} variant="secondary"><Plus className="icon" /> Add Item</Button>
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
              {lines.map((line, idx) => (
                <div key={idx} style={{ display: 'grid', gridTemplateColumns: '2fr 1fr 1fr auto', gap: '0.5rem', alignItems: 'center' }}>
                  <select onChange={(e) => updateLine(idx, { itemId: e.target.value })} value={line.itemId}>
                    <option value="">-- Select Item --</option>
                    {itemsQuery.data?.content?.map((item: Item) => (
                      <option key={item.id} value={item.id}>
                        {item.name} ({item.sku ?? 'No SKU'})
                      </option>
                    ))}
                  </select>
                  <input
                    min={1}
                    onChange={(e) => updateLine(idx, { requestedQuantity: Number(e.target.value) })}
                    placeholder="Qty"
                    type="number"
                    value={line.requestedQuantity}
                  />
                  <input
                    onChange={(e) => updateLine(idx, { batchNumber: e.target.value })}
                    placeholder="Batch (Opt)"
                    value={line.batchNumber ?? ''}
                  />
                  <Button disabled={lines.length === 1} onClick={() => removeLine(idx)} variant="ghost">âœ•</Button>
                </div>
              ))}
            </div>
          </div>

          <label className="field-group">
            <span>Transfer Notes / Reason</span>
            <input onChange={(e) => setNotes(e.target.value)} placeholder="e.g. Stock balancing, seasonal demand" value={notes} />
          </label>
        </div>
        <footer className="modal-footer">
          <Button onClick={onClose} variant="secondary">Cancel</Button>
          <Button
            disabled={!sourceWarehouseId || !destinationWarehouseId || lines.some((l) => !l.itemId) || mutation.isPending}
            onClick={() => mutation.mutate()}
            variant="primary"
          >
            <Truck className="icon" /> {mutation.isPending ? 'Creating Order...' : 'Create Transfer Order'}
          </Button>
        </footer>
      </div>
    </div>
  )
}
