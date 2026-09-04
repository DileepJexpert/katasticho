import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  ArrowLeft,
  ArrowRight,
  Plus,
  Trash2,
} from 'lucide-react'
import {
  Button,
  DataTable,
  DocumentCard,
  PageHeader,
} from '@/design-system'
import {
  createTransferOrder,
  listCatalogItems,
  listWarehouses,
  type CreateTransferOrderRequest,
} from '@/features/inventory/transfer-orders-api'

interface LineDraft {
  itemId: string
  batchId?: string
  quantity: number
  notes?: string
}

function getTodayIso(): string {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

export function TransferOrderCreatePage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const [fromWarehouseId, setFromWarehouseId] = useState('')
  const [toWarehouseId, setToWarehouseId] = useState('')
  const [transferDate, setTransferDate] = useState(getTodayIso())
  const [notes, setNotes] = useState('')
  const [formError, setFormError] = useState<string | null>(null)

  const [lines, setLines] = useState<LineDraft[]>([
    { itemId: '', quantity: 1, notes: '' },
  ])

  const warehousesQuery = useQuery({
    queryKey: ['warehouses'],
    queryFn: () => listWarehouses(),
  })

  const catalogQuery = useQuery({
    queryKey: ['catalog-items'],
    queryFn: () => listCatalogItems(),
  })

  const warehouses = warehousesQuery.data ?? []
  const catalogItems = catalogQuery.data ?? []

  const createMutation = useMutation({
    mutationFn: (req: CreateTransferOrderRequest) => createTransferOrder(req),
    onSuccess: (res) => {
      queryClient.invalidateQueries({ queryKey: ['inventory', 'transfer-orders'] })
      navigate(`/transfer-orders/${res.id}`)
    },
    onError: (err: Error) => {
      setFormError(err.message || 'Failed to create transfer order')
    },
  })

  function handleAddLine() {
    setLines([...lines, { itemId: '', quantity: 1, notes: '' }])
  }

  function handleRemoveLine(index: number) {
    if (lines.length === 1) return
    setLines(lines.filter((_, i) => i !== index))
  }

  function handleLineChange(index: number, field: keyof LineDraft, value: string | number) {
    setLines((prev) => {
      const next = [...prev]
      next[index] = { ...next[index], [field]: value }
      return next
    })
  }

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setFormError(null)

    if (!fromWarehouseId) {
      setFormError('Source warehouse is required.')
      return
    }
    if (!toWarehouseId) {
      setFormError('Destination warehouse is required.')
      return
    }
    if (fromWarehouseId === toWarehouseId) {
      setFormError('Source and destination warehouses cannot be the same.')
      return
    }

    const validLines = lines.filter((l) => l.itemId && l.quantity > 0)
    if (validLines.length === 0) {
      setFormError('Please add at least one line item with a quantity greater than zero.')
      return
    }

    createMutation.mutate({
      fromWarehouseId,
      toWarehouseId,
      transferDate,
      notes: notes.trim() || undefined,
      lines: validLines.map((l) => ({
        itemId: l.itemId,
        quantity: Number(l.quantity),
        notes: l.notes?.trim() || undefined,
      })),
    })
  }

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <Button onClick={() => navigate('/transfer-orders')} variant="secondary">
            <ArrowLeft size={15} aria-hidden="true" />
            <span>Back to Transfers</span>
          </Button>
        }
        eyebrow="Inventory Movement • Stock Relocation"
        title="New Stock Transfer Order"
        description="Initiate an inter-warehouse shipment transfer. Stock is deducted from the source upon dispatch and added to the destination upon receipt."
      />

      <form onSubmit={handleSubmit} className="dashboard-workspace">
        {formError && (
          <div className="compact-zero-state text-neg bg-neg p-3 rounded">
            <span>{formError}</span>
          </div>
        )}

        {/* ── Route & Location Selection Card ── */}
        <DocumentCard title="Transfer Route & Logistics">
          <div className="p-4 grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="flex flex-col gap-1">
              <label htmlFor="from-warehouse-select" className="text-secondary text-xs font-medium">
                Source Warehouse (From) *
              </label>
              <select
                id="from-warehouse-select"
                className="dashboard-branch-select"
                value={fromWarehouseId}
                onChange={(e) => setFromWarehouseId(e.target.value)}
                required
              >
                <option value="">Select source warehouse...</option>
                {warehouses.map((w) => (
                  <option key={w.id} value={w.id}>
                    {w.name} ({w.code})
                  </option>
                ))}
              </select>
            </div>

            <div className="flex flex-col gap-1">
              <label htmlFor="to-warehouse-select" className="text-secondary text-xs font-medium flex items-center gap-1">
                <span>Destination Warehouse (To) *</span>
                <ArrowRight size={13} className="text-muted" />
              </label>
              <select
                id="to-warehouse-select"
                className="dashboard-branch-select"
                value={toWarehouseId}
                onChange={(e) => setToWarehouseId(e.target.value)}
                required
              >
                <option value="">Select destination warehouse...</option>
                {warehouses.map((w) => (
                  <option key={w.id} value={w.id}>
                    {w.name} ({w.code})
                  </option>
                ))}
              </select>
            </div>

            <div className="flex flex-col gap-1">
              <label htmlFor="transfer-date-input" className="text-secondary text-xs font-medium">
                Transfer Date *
              </label>
              <input
                id="transfer-date-input"
                type="date"
                className="dashboard-branch-select"
                value={transferDate}
                onChange={(e) => setTransferDate(e.target.value)}
                required
              />
            </div>

            <div className="flex flex-col gap-1 md:col-span-3">
              <label htmlFor="transfer-notes-input" className="text-secondary text-xs font-medium">
                Transfer Notes & Instructions (Optional)
              </label>
              <input
                id="transfer-notes-input"
                type="text"
                placeholder="e.g. Regular monthly replenishment for City Branch"
                className="dashboard-branch-select"
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
              />
            </div>
          </div>
        </DocumentCard>

        {/* ── Line Items Table Card ── */}
        <DocumentCard
          headerAction={
            <Button onClick={handleAddLine} type="button" variant="secondary">
              <Plus size={14} />
              <span>Add Item</span>
            </Button>
          }
          title="Line Items to Transfer"
        >
          <DataTable caption="Transfer line items">
            <thead>
              <tr>
                <th scope="col" style={{ width: '45%' }}>Product Item *</th>
                <th scope="col">SKU</th>
                <th scope="col" style={{ width: '15%' }}>Quantity *</th>
                <th scope="col" style={{ width: '25%' }}>Line Notes</th>
                <th scope="col" style={{ width: '5%' }}>Remove</th>
              </tr>
            </thead>
            <tbody>
              {lines.map((line, idx) => {
                const selectedItem = catalogItems.find((i) => i.id === line.itemId)
                return (
                  <tr key={idx}>
                    <td>
                      <select
                        aria-label={`Select item for line ${idx + 1}`}
                        className="dashboard-branch-select"
                        style={{ width: '100%' }}
                        value={line.itemId}
                        onChange={(e) => handleLineChange(idx, 'itemId', e.target.value)}
                        required
                      >
                        <option value="">Select item from catalog...</option>
                        {catalogItems.map((item) => (
                          <option key={item.id} value={item.id}>
                            {item.name} ({item.sku})
                          </option>
                        ))}
                      </select>
                    </td>
                    <td>
                      <span className="code-pill font-mono text-xs">
                        {selectedItem?.sku || '—'}
                      </span>
                    </td>
                    <td>
                      <input
                        aria-label={`Quantity for line ${idx + 1}`}
                        type="number"
                        min="1"
                        step="1"
                        className="dashboard-branch-select"
                        style={{ width: '100%' }}
                        value={line.quantity}
                        onChange={(e) => handleLineChange(idx, 'quantity', Number(e.target.value))}
                        required
                      />
                    </td>
                    <td>
                      <input
                        aria-label={`Notes for line ${idx + 1}`}
                        type="text"
                        placeholder="Lot / batch remarks..."
                        className="dashboard-branch-select"
                        style={{ width: '100%' }}
                        value={line.notes || ''}
                        onChange={(e) => handleLineChange(idx, 'notes', e.target.value)}
                      />
                    </td>
                    <td>
                      <button
                        aria-label={`Remove line ${idx + 1}`}
                        type="button"
                        onClick={() => handleRemoveLine(idx)}
                        disabled={lines.length === 1}
                        className="p-1.5 text-muted hover:text-neg transition-colors disabled:opacity-40"
                      >
                        <Trash2 size={16} />
                      </button>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </DataTable>

          <div className="p-4 flex items-center justify-between border-t border-border">
            <Button onClick={handleAddLine} type="button" variant="secondary">
              <Plus size={14} />
              <span>Add Another Item</span>
            </Button>
            <div className="flex items-center gap-3">
              <Button onClick={() => navigate('/transfer-orders')} type="button" variant="secondary">
                Cancel
              </Button>
              <Button type="submit" variant="primary" disabled={createMutation.isPending}>
                <span>{createMutation.isPending ? 'Creating...' : 'Create Transfer Order'}</span>
              </Button>
            </div>
          </div>
        </DocumentCard>
      </form>
    </section>
  )
}
