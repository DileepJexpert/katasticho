import { useMemo, useState } from 'react'
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
  Money,
  NumberInput,
  PageHeader,
  SelectInput,
  TextAreaInput,
  TextInput,
} from '@/design-system'
import { listContacts } from '@/features/contacts/contacts-api'
import { listItems } from '@/features/items/items-api'
import {
  createPurchaseOrder,
  type CreatePurchaseOrderRequest,
} from '@/features/purchase-orders/purchase-orders-api'

interface PoLineItem {
  id: string
  itemId: string
  itemName: string
  description: string
  quantity: number
  unitPrice: number
  lineTotal: number
}

export function PurchaseOrderCreatePage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const [supplierId, setSupplierId] = useState('')
  const [orderDate, setOrderDate] = useState(() => new Date().toISOString().split('T')[0] || '')
  const [expectedDeliveryDate, setExpectedDeliveryDate] = useState(() => {
    const d = new Date()
    d.setDate(d.getDate() + 14)
    return d.toISOString().split('T')[0] || ''
  })
  const [notes, setNotes] = useState('')
  const [lines, setLines] = useState<PoLineItem[]>([])
  const [feedback, setFeedback] = useState<{ type: 'error' | 'success'; message: string } | null>(null)

  const suppliersQuery = useQuery({
    queryKey: ['vendors-for-po'],
    queryFn: () => listContacts({ filter: 'VENDOR', page: 0 }),
  })

  const itemsQuery = useQuery({
    queryKey: ['items-for-po'],
    queryFn: () => listItems({ page: 0 }),
  })

  const suppliers = suppliersQuery.data?.content ?? []
  const catalogItems = itemsQuery.data?.content ?? []

  const handleAddItem = (itemId: string) => {
    const item = catalogItems.find((i) => i.id === itemId)
    if (!item) return
    const price = Number(item.purchasePrice || item.salePrice || 0)
    const newLine: PoLineItem = {
      id: Math.random().toString(36).substring(2, 9),
      itemId: item.id,
      itemName: item.name,
      description: item.name,
      quantity: 1,
      unitPrice: price,
      lineTotal: price,
    }
    setLines((prev) => [...prev, newLine])
  }

  const handleUpdateLine = (id: string, updates: Partial<PoLineItem>) => {
    setLines((prev) =>
      prev.map((l) => {
        if (l.id !== id) return l
        const updated = { ...l, ...updates }
        updated.lineTotal = (updated.quantity || 0) * (updated.unitPrice || 0)
        return updated
      })
    )
  }

  const handleRemoveLine = (id: string) => {
    setLines((prev) => prev.filter((l) => l.id !== id))
  }

  const totalAmount = useMemo(() => {
    return lines.reduce((acc, l) => acc + (l.lineTotal || 0), 0)
  }, [lines])

  const createMutation = useMutation({
    mutationFn: (req: CreatePurchaseOrderRequest) => createPurchaseOrder(req),
    onSuccess: (created) => {
      queryClient.invalidateQueries({ queryKey: ['purchase-orders'] })
      navigate(appRoutes.purchaseOrderDetail(created.id))
    },
    onError: (err: unknown) => {
      const msg = err instanceof Error ? err.message : 'Failed to create purchase order.'
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
      setFeedback({ type: 'error', message: 'Please add at least one line item to the purchase order.' })
      return
    }

    createMutation.mutate({
      supplierId,
      orderDate,
      expectedDeliveryDate: expectedDeliveryDate || undefined,
      notes: notes.trim() || undefined,
      lines: lines.map((l) => ({
        itemId: l.itemId,
        quantity: l.quantity,
        unitPrice: l.unitPrice,
        description: l.description,
      })),
    })
  }

  return (
    <section className="workspace-page">
      <Link className="form-back-link" to={appRoutes.purchaseOrders}>
        <ArrowLeft size={16} /> Back to Purchase Orders
      </Link>

      <PageHeader
        eyebrow="Purchases / Procurement"
        title="New Purchase Order"
        description="Draft purchase commitments to suppliers with expected delivery timelines and items to procure."
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
          description="Select the vendor and set the purchase order date and expected delivery window."
          stepNumber={1}
          title="Supplier & Procurement Details"
        >
          <FormGrid columns={3}>
            <FormField label="Supplier / Vendor" required>
              <SelectInput
                onChange={(e) => setSupplierId(e.target.value)}
                options={suppliers.map((s) => ({
                  value: s.id,
                  label: `${s.displayName} ${s.companyName ? '(' + s.companyName + ')' : ''}`,
                }))}
                placeholderOption="-- Select Supplier --"
                required
                value={supplierId}
              />
            </FormField>

            <FormField label="Order Date" required>
              <TextInput
                onChange={(e) => setOrderDate(e.target.value)}
                required
                type="date"
                value={orderDate}
              />
            </FormField>

            <FormField label="Expected Delivery Date">
              <TextInput
                onChange={(e) => setExpectedDeliveryDate(e.target.value)}
                type="date"
                value={expectedDeliveryDate}
              />
            </FormField>
          </FormGrid>
        </FormCard>

        <FormCard
          description="Select goods, quantities, and negotiated purchase unit costs."
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
                placeholderOption="+ Add Item to Order..."
                value=""
              />
            </div>
          }
          stepNumber={2}
          title={`Line Items to Procure (${lines.length})`}
        >
          {lines.length === 0 ? (
            <div className="directory-state" style={{ padding: 'var(--space-6)' }}>
              <FileCheck size={28} />
              <p>No line items added yet. Select an item above to add it to this purchase order.</p>
            </div>
          ) : (
            <>
              <DataTable caption="Purchase Order Lines">
                <thead>
                  <tr>
                    <th scope="col">Item & Description</th>
                    <th className="numeric-cell" scope="col">Quantity</th>
                    <th className="numeric-cell" scope="col">Unit Cost (₹)</th>
                    <th className="numeric-cell" scope="col">Line Total</th>
                    <th style={{ width: '40px' }} />
                  </tr>
                </thead>
                <tbody>
                  {lines.map((line) => (
                    <tr key={line.id}>
                      <td>
                        <div className="cell-stack">
                          <strong>{line.itemName}</strong>
                          <TextInput
                            onChange={(e) => handleUpdateLine(line.id, { description: e.target.value })}
                            placeholder="Optional line notes"
                            style={{ marginTop: 'var(--space-1)', width: '100%' }}
                            value={line.description}
                          />
                        </div>
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
                      <td className="numeric-cell">
                        <strong>
                          <Money amount={line.lineTotal} />
                        </strong>
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

              <div className="form-summary-card">
                <div className="form-summary-row form-summary-row--total">
                  <span>Estimated PO Total:</span>
                  <Money amount={totalAmount} />
                </div>
              </div>
            </>
          )}
        </FormCard>

        <FormCard
          description="Include packaging guidelines, gate delivery instructions, and terms."
          stepNumber={3}
          title="Supplier Notes & Instructions"
        >
          <FormField label="Delivery Instructions & Remarks">
            <TextAreaInput
              onChange={(e) => setNotes(e.target.value)}
              placeholder="Delivery notes, packaging guidelines, quality terms..."
              rows={3}
              value={notes}
            />
          </FormField>
        </FormCard>

        <div className="form-actions-bar">
          <Button
            onClick={() => navigate(appRoutes.purchaseOrders)}
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
            {createMutation.isPending ? 'Saving...' : 'Create Purchase Order'}
          </Button>
        </div>
      </form>
    </section>
  )
}
