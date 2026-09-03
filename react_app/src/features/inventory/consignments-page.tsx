import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  Handshake,
  Plus,
  RotateCcw,
  ShoppingCart,
} from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate } from '@/shared/format/format'
import {
  getConsignmentStock,
  receiveConsignment,
  recordConsignmentSale,
  settleConsignment,
  type ConsignmentStock,
} from '@/features/inventory/consignment-api'

export function ConsignmentsPage() {
  const queryClient = useQueryClient()
  const [showReceiveModal, setShowReceiveModal] = useState(false)
  const [selectedStockForSale, setSelectedStockForSale] = useState<ConsignmentStock | null>(null)

  const consignmentQuery = useQuery({
    queryKey: ['consignments'],
    queryFn: getConsignmentStock,
  })

  const settleMutation = useMutation({
    mutationFn: (id: string) => settleConsignment(id),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['consignments'] }),
  })

  const stocks = consignmentQuery.data ?? []

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Inventory / Vendor-Managed Inventory"
        title="Consignment Stock & VMI Hub"
        description="Manage supplier-owned consignment inventory, record consumer sales, and settle vendor liabilities upon consumption."
        actions={
          <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
            <Button onClick={() => setShowReceiveModal(true)} variant="primary">
              <Plus size={16} /> Receive Consignment
            </Button>
          </div>
        }
      />

      {consignmentQuery.isLoading ? (
        <div className="directory-state">Loading consignment stock inventory...</div>
      ) : !stocks.length ? (
        <div className="directory-state">
          <Handshake size={32} />
          <strong>No active consignment stock recorded.</strong>
          <p>Receive goods on consignment to track supplier inventory without immediate AP liability.</p>
        </div>
      ) : (
        <DataTable caption="Consignment Stock">
          <thead>
            <tr>
              <th scope="col">Item</th>
              <th scope="col">Supplier</th>
              <th scope="col">Warehouse</th>
              <th className="numeric-cell" scope="col">Received Qty</th>
              <th className="numeric-cell" scope="col">Remaining Qty</th>
              <th className="numeric-cell" scope="col">Unit Cost</th>
              <th scope="col">Consignment Date</th>
              <th scope="col">Status</th>
              <th scope="col">Actions</th>
            </tr>
          </thead>
          <tbody>
            {stocks.map((stock) => (
              <tr key={stock.id}>
                <td>
                  <div className="cell-stack">
                    <strong>{stock.itemName}</strong>
                    <code>{stock.itemSku ?? stock.itemId}</code>
                  </div>
                </td>
                <td>{stock.supplierName ?? stock.supplierId}</td>
                <td>{stock.warehouseName}</td>
                <td className="numeric-cell"><strong>{stock.receivedQuantity}</strong></td>
                <td className="numeric-cell">
                  <strong style={{ color: Number(stock.remainingQuantity) > 0 ? 'var(--color-success, #2e7d32)' : 'inherit' }}>
                    {stock.remainingQuantity}
                  </strong>
                </td>
                <td className="numeric-cell"><Money amount={stock.unitCost} /></td>
                <td>{formatDate(stock.consignmentDate)}</td>
                <td><StatusChip status={stock.status} /></td>
                <td>
                  <div style={{ display: 'flex', gap: '0.5rem' }}>
                    {stock.status === 'ACTIVE' && (
                      <>
                        <Button onClick={() => setSelectedStockForSale(stock)} variant="ghost">
                          <ShoppingCart size={14} /> Record Sale
                        </Button>
                        <Button onClick={() => settleMutation.mutate(stock.id)} variant="ghost">
                          <RotateCcw size={14} /> Settle
                        </Button>
                      </>
                    )}
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      )}

      {/* Receive Modal */}
      {showReceiveModal && (
        <ReceiveConsignmentModal
          onClose={() => setShowReceiveModal(false)}
          onSuccess={() => {
            setShowReceiveModal(false)
            queryClient.invalidateQueries({ queryKey: ['consignments'] })
          }}
        />
      )}

      {/* Record Sale Modal */}
      {selectedStockForSale && (
        <RecordSaleModal
          onClose={() => setSelectedStockForSale(null)}
          onSuccess={() => {
            setSelectedStockForSale(null)
            queryClient.invalidateQueries({ queryKey: ['consignments'] })
          }}
          stock={selectedStockForSale}
        />
      )}
    </section>
  )
}

function ReceiveConsignmentModal({ onClose, onSuccess }: { onClose: () => void; onSuccess: () => void }) {
  const [itemId, setItemId] = useState('')
  const [supplierId, setSupplierId] = useState('')
  const [warehouseId, setWarehouseId] = useState('WH-MAIN')
  const [quantity, setQuantity] = useState(100)
  const [unitCost, setUnitCost] = useState(50)
  const [agreementRef, setAgreementRef] = useState('')

  const mutation = useMutation({
    mutationFn: () =>
      receiveConsignment({
        itemId,
        supplierId,
        warehouseId,
        quantity,
        unitCost,
        agreementRef: agreementRef || undefined,
      }),
    onSuccess: () => onSuccess(),
  })

  return (
    <div className="modal-backdrop" role="dialog">
      <div className="modal-dialog">
        <header className="modal-header">
          <h3>Receive Consignment Stock</h3>
          <Button onClick={onClose} variant="ghost">âœ•</Button>
        </header>
        <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <label className="field-group">
            <span>Item ID / SKU</span>
            <input onChange={(e) => setItemId(e.target.value)} placeholder="e.g. ITEM-001" value={itemId} />
          </label>
          <label className="field-group">
            <span>Supplier ID</span>
            <input onChange={(e) => setSupplierId(e.target.value)} placeholder="e.g. SUPP-001" value={supplierId} />
          </label>
          <label className="field-group">
            <span>Destination Warehouse</span>
            <input onChange={(e) => setWarehouseId(e.target.value)} value={warehouseId} />
          </label>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
            <label className="field-group">
              <span>Quantity</span>
              <input onChange={(e) => setQuantity(Number(e.target.value))} type="number" value={quantity} />
            </label>
            <label className="field-group">
              <span>Agreed Unit Cost (â‚¹)</span>
              <input onChange={(e) => setUnitCost(Number(e.target.value))} type="number" value={unitCost} />
            </label>
          </div>
          <label className="field-group">
            <span>Agreement Reference</span>
            <input onChange={(e) => setAgreementRef(e.target.value)} placeholder="e.g. VMI-AGR-2026" value={agreementRef} />
          </label>
        </div>
        <footer className="modal-footer">
          <Button onClick={onClose} variant="secondary">Cancel</Button>
          <Button disabled={!itemId || !supplierId || quantity <= 0 || mutation.isPending} onClick={() => mutation.mutate()} variant="primary">
            {mutation.isPending ? 'Receiving...' : 'Receive Stock'}
          </Button>
        </footer>
      </div>
    </div>
  )
}

function RecordSaleModal({
  stock,
  onClose,
  onSuccess,
}: {
  stock: ConsignmentStock
  onClose: () => void
  onSuccess: () => void
}) {
  const [quantitySold, setQuantitySold] = useState(1)

  const mutation = useMutation({
    mutationFn: () =>
      recordConsignmentSale({
        consignmentStockId: stock.id,
        quantitySold,
      }),
    onSuccess: () => onSuccess(),
  })

  return (
    <div className="modal-backdrop" role="dialog">
      <div className="modal-dialog">
        <header className="modal-header">
          <h3>Record Consignment Sale / Consumption</h3>
          <Button onClick={onClose} variant="ghost">âœ•</Button>
        </header>
        <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <p>
            Recording sale for <strong>{stock.itemName}</strong> (Available remaining: {stock.remainingQuantity}).
          </p>
          <label className="field-group">
            <span>Quantity Sold / Consumed</span>
            <input
              max={Number(stock.remainingQuantity)}
              min={1}
              onChange={(e) => setQuantitySold(Number(e.target.value))}
              type="number"
              value={quantitySold}
            />
          </label>
          <p style={{ fontSize: '0.875rem', color: 'var(--color-muted)' }}>
            This will reduce available consignment stock and accrue a payable bill to supplier {stock.supplierName ?? stock.supplierId}.
          </p>
        </div>
        <footer className="modal-footer">
          <Button onClick={onClose} variant="secondary">Cancel</Button>
          <Button disabled={quantitySold <= 0 || quantitySold > Number(stock.remainingQuantity) || mutation.isPending} onClick={() => mutation.mutate()} variant="primary">
            {mutation.isPending ? 'Recording...' : 'Confirm Sale'}
          </Button>
        </footer>
      </div>
    </div>
  )
}