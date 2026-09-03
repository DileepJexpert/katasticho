import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  FileCheck2,
  RefreshCw,
  ShoppingCart,
} from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { getShortbook, type ShortbookItem } from '@/features/items/items-api'
import { createPurchaseOrder } from '@/features/purchase-orders/purchase-orders-api'

export function ShortbookPage() {
  const queryClient = useQueryClient()
  const navigate = useNavigate()
  const [selectedItems, setSelectedItems] = useState<ShortbookItem[]>([])
  const [showPoModal, setShowPoModal] = useState(false)

  const shortbookQuery = useQuery({
    queryKey: ['shortbook'],
    queryFn: getShortbook,
  })

  const items = shortbookQuery.data ?? []

  function toggleItem(item: ShortbookItem) {
    if (selectedItems.some((i) => i.itemId === item.itemId)) {
      setSelectedItems(selectedItems.filter((i) => i.itemId !== item.itemId))
    } else {
      setSelectedItems([...selectedItems, item])
    }
  }

  function selectAll() {
    if (selectedItems.length === items.length) {
      setSelectedItems([])
    } else {
      setSelectedItems([...items])
    }
  }

  const totalReplenishCost = items.reduce(
    (acc, curr) =>
      acc +
      Number(curr.deficitQuantity ?? 0) * Number(curr.purchasePrice ?? 0),
    0
  )

  const selectedCost = selectedItems.reduce(
    (acc, curr) =>
      acc +
      Number(curr.deficitQuantity ?? 0) * Number(curr.purchasePrice ?? 0),
    0
  )

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
            <Button
              onClick={() =>
                queryClient.invalidateQueries({ queryKey: ['shortbook'] })
              }
              variant="secondary"
            >
              <RefreshCw className="icon" /> Refresh
            </Button>
            <Button
              disabled={selectedItems.length === 0}
              onClick={() => setShowPoModal(true)}
              variant="primary"
            >
              <ShoppingCart className="icon" /> Create Draft PO (
              {selectedItems.length})
            </Button>
          </div>
        }
        description="Live replenishment shortbook of items below minimum safety reorder thresholds. Convert deficit to Purchase Orders in 1-click."
        eyebrow="Inventory / Procurement"
        title="Replenishment Shortbook"
      />

      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
          gap: '1rem',
          marginBottom: '1rem',
        }}
      >
        <div className="card" style={{ padding: '1rem' }}>
          <div style={{ fontSize: '0.75rem', color: 'var(--color-text-muted)' }}>
            Deficit Items
          </div>
          <div style={{ fontSize: '1.5rem', fontWeight: 'bold' }}>
            {items.length}
          </div>
        </div>
        <div className="card" style={{ padding: '1rem' }}>
          <div style={{ fontSize: '0.75rem', color: 'var(--color-text-muted)' }}>
            Total Est. Replenishment Cost
          </div>
          <div style={{ fontSize: '1.5rem', fontWeight: 'bold' }}>
            <Money amount={totalReplenishCost} />
          </div>
        </div>
        <div className="card" style={{ padding: '1rem' }}>
          <div style={{ fontSize: '0.75rem', color: 'var(--color-text-muted)' }}>
            Selected for PO ({selectedItems.length})
          </div>
          <div
            style={{
              fontSize: '1.5rem',
              fontWeight: 'bold',
              color: 'var(--color-primary)',
            }}
          >
            <Money amount={selectedCost} />
          </div>
        </div>
      </div>

      {shortbookQuery.isLoading ? (
        <div className="directory-state">Loading shortbook...</div>
      ) : items.length > 0 ? (
        <DataTable caption="Replenishment Shortbook">
          <thead>
            <tr>
              <th scope="col">
                <input
                  checked={items.length > 0 && selectedItems.length === items.length}
                  onChange={selectAll}
                  type="checkbox"
                />
              </th>
              <th scope="col">Item</th>
              <th className="numeric-cell" scope="col">Current Stock</th>
              <th className="numeric-cell" scope="col">Reorder Level</th>
              <th className="numeric-cell" scope="col">Deficit Qty</th>
              <th className="numeric-cell" scope="col">Purchase Price</th>
              <th className="numeric-cell" scope="col">Est. Replenish Cost</th>
            </tr>
          </thead>
          <tbody>
            {items.map((row) => (
              <tr key={row.itemId}>
                <td>
                  <input
                    checked={selectedItems.some((i) => i.itemId === row.itemId)}
                    onChange={() => toggleItem(row)}
                    type="checkbox"
                  />
                </td>
                <td>
                  <div>
                    <strong>{row.itemName}</strong>
                    {row.itemSku && (
                      <div style={{ fontSize: '0.75rem', color: 'var(--color-text-muted)' }}>
                        SKU: {row.itemSku}
                      </div>
                    )}
                  </div>
                </td>
                <td className="numeric-cell">
                  <Quantity unit={row.unitOfMeasure ?? 'Units'} value={row.totalOnHand} />
                </td>
                <td className="numeric-cell">
                  <Quantity unit={row.unitOfMeasure ?? 'Units'} value={row.reorderLevel} />
                </td>
                <td className="numeric-cell">
                  <strong style={{ color: 'var(--color-danger, #BE3A34)' }}>
                    <Quantity unit={row.unitOfMeasure ?? 'Units'} value={row.deficitQuantity} />
                  </strong>
                </td>
                <td className="numeric-cell">
                  <Money amount={Number(row.purchasePrice ?? 0)} />
                </td>
                <td className="numeric-cell">
                  <Money
                    amount={
                      Number(row.deficitQuantity ?? 0) * Number(row.purchasePrice ?? 0)
                    }
                  />
                </td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      ) : (
        <div className="directory-state">
          No deficit items found. All stock balances meet or exceed reorder thresholds.
        </div>
      )}

      {showPoModal && (
        <CreatePoFromShortbookModal
          items={selectedItems}
          onClose={() => setShowPoModal(false)}
          onSuccess={(poId) => {
            setShowPoModal(false)
            setSelectedItems([])
            queryClient.invalidateQueries({ queryKey: ['shortbook'] })
            navigate(`${appRoutes.purchaseOrders}/${poId}`)
          }}
        />
      )}
    </section>
  )
}

function CreatePoFromShortbookModal({
  items,
  onClose,
  onSuccess,
}: {
  items: ShortbookItem[]
  onClose: () => void
  onSuccess: (poId: string) => void
}) {
  const [supplierId, setSupplierId] = useState('')
  const [warehouseId, setWarehouseId] = useState('MAIN')

  const mutation = useMutation({
    mutationFn: () =>
      createPurchaseOrder({
        supplierId: supplierId || 'VEND-DEFAULT',
        warehouseId,
        orderDate: new Date().toISOString().slice(0, 10),
        expectedDeliveryDate: new Date(Date.now() + 7 * 86400000).toISOString().slice(0, 10),
        notes: `Auto-generated from Shortbook replenishment console for ${items.length} deficit items.`,
        lines: items.map((item) => ({
          itemId: item.itemId,
          quantity: Number(item.reorderQuantity || item.deficitQuantity || 1),
          unitPrice: Number(item.purchasePrice || 0),
        })),
      }),
    onSuccess: (res) => onSuccess(res.id),
  })

  return (
    <div className="modal-backdrop" role="dialog">
      <div className="modal-dialog" style={{ maxWidth: '600px' }}>
        <header className="modal-header">
          <h3>Create Purchase Order from Shortbook</h3>
          <Button onClick={onClose} variant="ghost">âœ•</Button>
        </header>
        <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
            <label className="field-group">
              <span>Vendor / Supplier ID</span>
              <input onChange={(e) => setSupplierId(e.target.value)} placeholder="e.g. VEND-001" value={supplierId} />
            </label>
            <label className="field-group">
              <span>Destination Warehouse</span>
              <input onChange={(e) => setWarehouseId(e.target.value)} value={warehouseId} />
            </label>
          </div>

          <div>
            <h4>Included Items ({items.length})</h4>
            <ul style={{ maxHeight: '160px', overflowY: 'auto', fontSize: '0.875rem', paddingLeft: '1.25rem' }}>
              {items.map((i) => (
                <li key={i.itemId}>
                  {i.itemName}: Deficit {i.deficitQuantity} {i.unitOfMeasure} @ <Money amount={Number(i.purchasePrice || 0)} />
                </li>
              ))}
            </ul>
          </div>
        </div>
        <footer className="modal-footer">
          <Button onClick={onClose} variant="secondary">Cancel</Button>
          <Button disabled={mutation.isPending} onClick={() => mutation.mutate()} variant="primary">
            <FileCheck2 className="icon" /> {mutation.isPending ? 'Generating PO...' : 'Create Draft PO'}
          </Button>
        </footer>
      </div>
    </div>
  )
}
