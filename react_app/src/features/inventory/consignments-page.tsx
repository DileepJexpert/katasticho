import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  Handshake,
  Plus,
  RotateCcw,
  ShoppingCart,
} from 'lucide-react'
import {
  Button,
  DataTable,
  FormField,
  FormGrid,
  Modal,
  Money,
  NumberInput,
  PageHeader,
  StatusChip,
  TextInput,
} from '@/design-system'
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
  const [quantity, setQuantity] = useState(10)
  const [unitCost, setUnitCost] = useState(100)
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
    <Modal
      footer={
        <>
          <Button onClick={onClose} variant="secondary">Cancel</Button>
          <Button disabled={!itemId || !supplierId || quantity <= 0 || mutation.isPending} onClick={() => mutation.mutate()} variant="primary">
            {mutation.isPending ? 'Receiving...' : 'Receive Stock'}
          </Button>
        </>
      }
      isOpen
      onClose={onClose}
      size="lg"
      title="Receive Consignment Stock"
    >
      <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
        <FormField label="Item ID / SKU" required>
          <TextInput onChange={(e) => setItemId(e.target.value)} placeholder="e.g. ITEM-001" value={itemId} />
        </FormField>
        <FormField label="Supplier ID" required>
          <TextInput onChange={(e) => setSupplierId(e.target.value)} placeholder="e.g. SUPP-001" value={supplierId} />
        </FormField>
        <FormField label="Destination Warehouse">
          <TextInput onChange={(e) => setWarehouseId(e.target.value)} value={warehouseId} />
        </FormField>
        <FormGrid columns={2}>
          <FormField label="Quantity" required>
            <NumberInput min={1} onChange={(e) => setQuantity(Number(e.target.value))} value={quantity} />
          </FormField>
          <FormField label="Agreed Unit Cost (₹)" required>
            <NumberInput min={0} onChange={(e) => setUnitCost(Number(e.target.value))} step="0.01" value={unitCost} />
          </FormField>
        </FormGrid>
        <FormField label="Agreement Reference">
          <TextInput onChange={(e) => setAgreementRef(e.target.value)} placeholder="e.g. VMI-AGR-2026" value={agreementRef} />
        </FormField>
      </div>
    </Modal>
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
    <Modal
      footer={
        <>
          <Button onClick={onClose} variant="secondary">Cancel</Button>
          <Button disabled={quantitySold <= 0 || quantitySold > Number(stock.remainingQuantity) || mutation.isPending} onClick={() => mutation.mutate()} variant="primary">
            {mutation.isPending ? 'Recording...' : 'Confirm Sale'}
          </Button>
        </>
      }
      isOpen
      onClose={onClose}
      size="md"
      title="Record Consignment Sale / Consumption"
    >
      <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
        <p style={{ margin: 0 }}>
          Recording sale for <strong>{stock.itemName}</strong> (Available remaining: {stock.remainingQuantity}).
        </p>
        <FormField label="Quantity Sold / Consumed" required>
          <NumberInput
            max={Number(stock.remainingQuantity)}
            min={1}
            onChange={(e) => setQuantitySold(Number(e.target.value))}
            value={quantitySold}
          />
        </FormField>
        <p style={{ margin: 0, fontSize: '0.875rem', color: 'var(--color-text-muted)' }}>
          This will reduce available consignment stock and accrue a payable bill to supplier {stock.supplierName ?? stock.supplierId}.
        </p>
      </div>
    </Modal>
  )
}
