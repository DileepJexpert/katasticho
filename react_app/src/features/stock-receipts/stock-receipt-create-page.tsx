import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, FileCheck, Save, Trash2 } from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  DataTable,
  FormCard,
  FormField,
  FormGrid,
  NumberInput,
  PageHeader,
  SelectInput,
  TextInput,
} from '@/design-system'
import { listContacts } from '@/features/contacts/contacts-api'
import { listItems } from '@/features/items/items-api'
import { listPurchaseOrders } from '@/features/purchase-orders/purchase-orders-api'
import {
  createStockReceipt,
  type CreateStockReceiptLineRequest,
  type CreateStockReceiptRequest,
} from '@/features/stock-receipts/stock-receipts-api'

interface GrnLineItem extends CreateStockReceiptLineRequest {
  id: string
  itemName: string
}

export function StockReceiptCreatePage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const [supplierId, setSupplierId] = useState('')
  const [purchaseOrderId, setPurchaseOrderId] = useState('')
  const [receiptDate, setReceiptDate] = useState(() => new Date().toISOString().split('T')[0] || '')
  const [supplierInvoiceNo, setSupplierInvoiceNo] = useState('')
  const [supplierInvoiceDate, setSupplierInvoiceDate] = useState('')
  const [notes, setNotes] = useState('')
  const [lines, setLines] = useState<GrnLineItem[]>([])
  const [feedback, setFeedback] = useState<{ type: 'error' | 'success'; message: string } | null>(null)

  const suppliersQuery = useQuery({
    queryKey: ['suppliers-for-grn'],
    queryFn: () => listContacts({ filter: 'VENDOR', page: 0 }),
  })

  const posQuery = useQuery({
    queryKey: ['pos-for-grn'],
    queryFn: () => listPurchaseOrders(),
  })

  const itemsQuery = useQuery({
    queryKey: ['items-for-grn'],
    queryFn: () => listItems({ page: 0 }),
  })

  const suppliers = suppliersQuery.data?.content ?? []
  const purchaseOrders = posQuery.data ?? []
  const catalogItems = itemsQuery.data?.content ?? []

  const handleAddItem = (itemId: string) => {
    const item = catalogItems.find((i) => i.id === itemId)
    if (!item) return
    const newLine: GrnLineItem = {
      id: Math.random().toString(36).substring(2, 9),
      itemId: item.id,
      itemName: item.name,
      description: item.name,
      quantity: 1,
      unitPrice: Number(item.purchasePrice || 0),
      batchNumber: '',
      expiryDate: '',
    }
    setLines((prev) => [...prev, newLine])
  }

  const handleUpdateLine = (id: string, updates: Partial<GrnLineItem>) => {
    setLines((prev) =>
      prev.map((l) => (l.id === id ? { ...l, ...updates } : l))
    )
  }

  const handleRemoveLine = (id: string) => {
    setLines((prev) => prev.filter((l) => l.id !== id))
  }

  const createMutation = useMutation({
    mutationFn: (req: CreateStockReceiptRequest) => createStockReceipt(req),
    onSuccess: (created) => {
      queryClient.invalidateQueries({ queryKey: ['stock-receipts'] })
      navigate(appRoutes.stockReceiptDetail(created.id))
    },
    onError: (err: unknown) => {
      const msg = err instanceof Error ? err.message : 'Failed to create stock receipt.'
      setFeedback({ type: 'error', message: msg })
    },
  })

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    setFeedback(null)

    if (!supplierId) {
      setFeedback({ type: 'error', message: 'Please select a supplier.' })
      return
    }

    if (lines.length === 0) {
      setFeedback({ type: 'error', message: 'Please add at least one item to receive into stock.' })
      return
    }

    createMutation.mutate({
      supplierId,
      receiptDate,
      purchaseOrderId: purchaseOrderId || undefined,
      supplierInvoiceNo: supplierInvoiceNo.trim() || undefined,
      supplierInvoiceDate: supplierInvoiceDate || undefined,
      notes: notes.trim() || undefined,
      lines: lines.map((l) => ({
        itemId: l.itemId,
        description: l.description,
        quantity: l.quantity,
        unitPrice: l.unitPrice,
        batchNumber: l.batchNumber || undefined,
        expiryDate: l.expiryDate || undefined,
      })),
    })
  }

  return (
    <section className="workspace-page">
      <Link className="form-back-link" to={appRoutes.stockReceipts}>
        <ArrowLeft size={16} /> Back to Stock Receipts
      </Link>

      <PageHeader
        eyebrow="Purchases / Warehouse"
        title="New Stock Receipt (GRN)"
        description="Receive incoming goods into warehouse inventory, capture supplier delivery batches, and verify against purchase orders."
      />

      {feedback && (
        <div
          className={`banner ${feedback.type === 'success' ? 'banner--success' : 'banner--error'}`}
          role="alert"
          style={{ marginBottom: 'var(--space-4)' }}
        >
          <span>{feedback.message}</span>
          <button className="banner-dismiss" onClick={() => setFeedback(null)} type="button">
            ✕
          </button>
        </div>
      )}

      <form className="create-form-container" onSubmit={handleSubmit}>
        <FormCard
          description="Supplier selection, receipt date, supplier invoice/challan number, and linked purchase order."
          stepNumber={1}
          title="Supplier & Receipt Info"
        >
          <FormGrid columns={3}>
            <FormField label="Supplier" required>
              <SelectInput
                onChange={(e) => setSupplierId(e.target.value)}
                options={suppliers.map((s) => ({
                  value: s.id,
                  label: s.displayName,
                }))}
                placeholderOption="-- Select Supplier --"
                required
                value={supplierId}
              />
            </FormField>

            <FormField label="Receipt Date" required>
              <TextInput
                onChange={(e) => setReceiptDate(e.target.value)}
                required
                type="date"
                value={receiptDate}
              />
            </FormField>

            <FormField label="Supplier DC / Invoice #">
              <TextInput
                onChange={(e) => setSupplierInvoiceNo(e.target.value)}
                placeholder="e.g. DC-987"
                value={supplierInvoiceNo}
              />
            </FormField>

            <FormField label="Linked Purchase Order">
              <SelectInput
                onChange={(e) => setPurchaseOrderId(e.target.value)}
                options={[
                  { value: '', label: '-- None / Direct GRN --' },
                  ...purchaseOrders.map((po) => ({
                    value: po.id,
                    label: `${po.poNumber} - ${po.supplierName}`,
                  })),
                ]}
                value={purchaseOrderId}
              />
            </FormField>

            <FormField label="Supplier Invoice Date">
              <TextInput
                onChange={(e) => setSupplierInvoiceDate(e.target.value)}
                type="date"
                value={supplierInvoiceDate}
              />
            </FormField>

            <FormField label="Receiving Notes">
              <TextInput
                onChange={(e) => setNotes(e.target.value)}
                placeholder="e.g. Gate pass #, condition..."
                value={notes}
              />
            </FormField>
          </FormGrid>
        </FormCard>

        <FormCard
          description="Select catalog products, quantities, batches, and shelf life expiry dates."
          headerAction={
            <div style={{ minWidth: 260 }}>
              <SelectInput
                onChange={(e) => {
                  if (e.target.value) {
                    handleAddItem(e.target.value)
                    e.target.value = ''
                  }
                }}
                options={catalogItems.map((item) => ({
                  value: item.id,
                  label: `${item.name} (${item.sku || 'No SKU'})`,
                }))}
                placeholderOption="+ Add Item to GRN..."
                value=""
              />
            </div>
          }
          stepNumber={2}
          title={`Items Received (${lines.length})`}
        >
          {lines.length === 0 ? (
            <div className="directory-state" style={{ padding: 'var(--space-6)' }}>
              <FileCheck size={28} />
              <p>No line items added yet. Select an item above to record inward receipt.</p>
            </div>
          ) : (
            <DataTable caption="Received items">
              <thead>
                <tr>
                  <th scope="col">Item</th>
                  <th className="numeric-cell" scope="col">Received Qty</th>
                  <th className="numeric-cell" scope="col">Unit Cost (₹)</th>
                  <th scope="col">Batch #</th>
                  <th scope="col">Expiry Date</th>
                  <th style={{ width: '40px' }} />
                </tr>
              </thead>
              <tbody>
                {lines.map((line) => (
                  <tr key={line.id}>
                    <td>
                      <strong>{line.itemName}</strong>
                    </td>
                    <td className="numeric-cell">
                      <NumberInput
                        min={1}
                        onChange={(e) => handleUpdateLine(line.id, { quantity: parseFloat(e.target.value) || 0 })}
                        step="1"
                        style={{ width: 85 }}
                        value={line.quantity}
                      />
                    </td>
                    <td className="numeric-cell">
                      <NumberInput
                        currencyPrefix="₹"
                        min={0}
                        onChange={(e) => handleUpdateLine(line.id, { unitPrice: parseFloat(e.target.value) || 0 })}
                        step="0.01"
                        style={{ width: 110 }}
                        value={line.unitPrice}
                      />
                    </td>
                    <td>
                      <TextInput
                        onChange={(e) => handleUpdateLine(line.id, { batchNumber: e.target.value })}
                        placeholder="e.g. BATCH-01"
                        style={{ width: 120 }}
                        value={line.batchNumber}
                      />
                    </td>
                    <td>
                      <TextInput
                        onChange={(e) => handleUpdateLine(line.id, { expiryDate: e.target.value })}
                        style={{ width: 140 }}
                        type="date"
                        value={line.expiryDate}
                      />
                    </td>
                    <td>
                      <Button
                        aria-label="Remove item"
                        onClick={() => handleRemoveLine(line.id)}
                        type="button"
                        variant="ghost"
                      >
                        <Trash2 color="var(--color-danger)" size={14} />
                      </Button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          )}
        </FormCard>

        <div className="form-actions-bar">
          <Button
            onClick={() => navigate(appRoutes.stockReceipts)}
            type="button"
            variant="secondary"
          >
            Cancel
          </Button>
          <Button
            disabled={createMutation.isPending || !supplierId || lines.length === 0}
            type="submit"
            variant="primary"
          >
            <Save size={16} />
            {createMutation.isPending ? 'Saving...' : 'Create Stock Receipt'}
          </Button>
        </div>
      </form>
    </section>
  )
}
