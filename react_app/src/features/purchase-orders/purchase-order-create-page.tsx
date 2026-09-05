import { useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, FileCheck, Save, Trash2 } from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  DataTable,
  EntityPicker,
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
import { listItems, type Item } from '@/features/items/items-api'
import {
  createPurchaseOrder,
  type CreatePurchaseOrderRequest,
} from '@/features/purchase-orders/purchase-orders-api'
import { listSelectableSuppliers, type Supplier } from '@/features/suppliers/suppliers-api'
import { listWarehouses } from '@/features/warehouses/warehouses-api'

type PoLineItem = {
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
  const [supplier, setSupplier] = useState<Supplier | null>(null)
  const [warehouseId, setWarehouseId] = useState('')
  const [orderDate, setOrderDate] = useState(() => new Date().toISOString().split('T')[0] || '')
  const [expectedDeliveryDate, setExpectedDeliveryDate] = useState(() => {
    const date = new Date()
    date.setDate(date.getDate() + 14)
    return date.toISOString().split('T')[0] || ''
  })
  const [notes, setNotes] = useState('')
  const [lines, setLines] = useState<PoLineItem[]>([])
  const [feedback, setFeedback] = useState<string | null>(null)

  const warehouses = useQuery({ queryKey: ['warehouses'], queryFn: listWarehouses })

  const handleAddItem = (item: Item | null | undefined) => {
    if (!item) return
    const price = Number(item.purchasePrice || item.salePrice || 0)
    setLines((previous) => [
      ...previous,
      {
        id: crypto.randomUUID(),
        itemId: item.id,
        itemName: item.name,
        description: item.name,
        quantity: 1,
        unitPrice: price,
        lineTotal: price,
      },
    ])
  }

  const handleUpdateLine = (id: string, updates: Partial<PoLineItem>) => {
    setLines((previous) => previous.map((line) => {
      if (line.id !== id) return line
      const updated = { ...line, ...updates }
      return { ...updated, lineTotal: updated.quantity * updated.unitPrice }
    }))
  }

  const totalAmount = useMemo(
    () => lines.reduce((total, line) => total + line.lineTotal, 0),
    [lines],
  )

  const createMutation = useMutation({
    mutationFn: (request: CreatePurchaseOrderRequest) => createPurchaseOrder(request),
    onSuccess: (created) => {
      queryClient.invalidateQueries({ queryKey: ['purchase-orders'] })
      navigate(appRoutes.purchaseOrderDetail(created.id))
    },
    onError: (error: Error) => setFeedback(error.message),
  })

  const handleSubmit = (event: React.FormEvent) => {
    event.preventDefault()
    setFeedback(null)
    if (!supplier) {
      setFeedback('Select an active supplier before creating the purchase order.')
      return
    }
    if (!lines.length) {
      setFeedback('Add at least one item before creating the purchase order.')
      return
    }
    createMutation.mutate({
      supplierId: supplier.id,
      orderDate,
      expectedDeliveryDate: expectedDeliveryDate || undefined,
      warehouseId: warehouseId || undefined,
      notes: notes.trim() || undefined,
      lines: lines.map(({ itemId, quantity, unitPrice, description }) => ({
        itemId,
        quantity,
        unitPrice,
        description: description.trim() || undefined,
      })),
    })
  }

  return (
    <section className="workspace-page">
      <Link className="form-back-link" to={appRoutes.purchaseOrders}>
        <ArrowLeft size={16} /> Back to purchase orders
      </Link>
      <PageHeader
        eyebrow="Purchases / Procurement"
        title="New Purchase Order"
        description="Create a supplier commitment. A purchase order does not move stock or post a journal."
      />

      {feedback ? <div className="banner banner--error" role="alert">{feedback}</div> : null}

      <form className="create-form-container" onSubmit={handleSubmit}>
        <FormCard
          description="Choose the eligible supplier projection, delivery warehouse, and dates for this commitment."
          stepNumber={1}
          title="Supplier and delivery"
        >
          <FormGrid columns={3}>
            <FormField label="Supplier" required>
              <EntityPicker
                ariaLabel="Search active suppliers"
                getOptionDescription={(item) => [item.gstin, item.phone, item.city].filter(Boolean).join(' / ')}
                getOptionId={(item) => item.id}
                getOptionLabel={(item) => item.name}
                onChange={(_id, item) => setSupplier(item ?? null)}
                onSearch={async (search) => (await listSelectableSuppliers(search)).content}
                placeholder="Search supplier name, GSTIN, or phone"
                renderEmpty={() => (
                  <div className="entity-picker__empty">No eligible suppliers found. Enable the supplier role for a vendor contact first.</div>
                )}
                selectedEntity={supplier}
                value={supplier?.id ?? null}
              />
            </FormField>
            <FormField label="Receiving warehouse">
              <SelectInput
                onChange={(event) => setWarehouseId(event.target.value)}
                options={(warehouses.data ?? []).filter((warehouse) => warehouse.active).map((warehouse) => ({
                  value: warehouse.id,
                  label: `${warehouse.code} / ${warehouse.name}${warehouse.isDefault ? ' (default)' : ''}`,
                }))}
                placeholderOption="Use organisation default warehouse"
                value={warehouseId}
              />
            </FormField>
            <FormField label="Order date" required>
              <TextInput onChange={(event) => setOrderDate(event.target.value)} required type="date" value={orderDate} />
            </FormField>
            <FormField label="Expected delivery date">
              <TextInput onChange={(event) => setExpectedDeliveryDate(event.target.value)} type="date" value={expectedDeliveryDate} />
            </FormField>
          </FormGrid>
        </FormCard>

        <FormCard
          description="Search the catalog and enter agreed pre-tax unit costs. GST is recorded on the vendor bill, not the PO."
          stepNumber={2}
          title={`Line items (${lines.length})`}
        >
          <FormField label="Add catalog item">
            <EntityPicker<Item>
              ariaLabel="Search items to add to purchase order"
              getOptionDescription={(item) => [item.sku, item.hsnCode, item.unitOfMeasure].filter(Boolean).join(' / ')}
              getOptionId={(item) => item.id}
              getOptionLabel={(item) => item.name}
              onChange={(_id, item) => handleAddItem(item)}
              onSearch={async (search) => (await listItems({ activeOnly: true, search, size: 20 })).content}
              placeholder="Search item name, SKU, or HSN"
              value={null}
            />
          </FormField>

          {lines.length ? (
            <DataTable caption="Purchase order lines">
              <thead>
                <tr>
                  <th scope="col">Item and description</th>
                  <th className="numeric-cell" scope="col">Quantity</th>
                  <th className="numeric-cell" scope="col">Unit cost</th>
                  <th className="numeric-cell" scope="col">Line total</th>
                  <th scope="col"><span className="visually-hidden">Remove</span></th>
                </tr>
              </thead>
              <tbody>
                {lines.map((line) => (
                  <tr key={line.id}>
                    <td>
                      <div className="cell-stack">
                        <strong>{line.itemName}</strong>
                        <TextInput onChange={(event) => handleUpdateLine(line.id, { description: event.target.value })} placeholder="Optional line notes" value={line.description} />
                      </div>
                    </td>
                    <td className="numeric-cell"><NumberInput min={0.0001} onChange={(event) => handleUpdateLine(line.id, { quantity: Number(event.target.value) || 0 })} step="0.0001" value={line.quantity} /></td>
                    <td className="numeric-cell"><NumberInput currencyPrefix="INR" min={0} onChange={(event) => handleUpdateLine(line.id, { unitPrice: Number(event.target.value) || 0 })} step="0.01" value={line.unitPrice} /></td>
                    <td className="numeric-cell"><Money amount={line.lineTotal} /></td>
                    <td><Button aria-label={`Remove ${line.itemName}`} onClick={() => setLines((previous) => previous.filter((entry) => entry.id !== line.id))} type="button" variant="ghost"><Trash2 size={14} /></Button></td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          ) : (
            <div className="directory-state"><FileCheck size={28} /><p>Search for an item to start this purchase order.</p></div>
          )}

          <div className="form-summary-card"><div className="form-summary-row form-summary-row--total"><span>Estimated PO total</span><Money amount={totalAmount} /></div></div>
        </FormCard>

        <FormCard description="These notes travel with the draft and remain part of the procurement audit trail." stepNumber={3} title="Supplier instructions">
          <FormField label="Delivery instructions and remarks">
            <TextAreaInput onChange={(event) => setNotes(event.target.value)} placeholder="Delivery notes, packaging instructions, quality terms" rows={3} value={notes} />
          </FormField>
        </FormCard>

        <div className="form-actions-bar">
          <Button onClick={() => navigate(appRoutes.purchaseOrders)} type="button" variant="secondary">Cancel</Button>
          <Button disabled={createMutation.isPending || !supplier || !lines.length} type="submit" variant="primary"><Save size={16} />{createMutation.isPending ? 'Creating...' : 'Create purchase order'}</Button>
        </div>
      </form>
    </section>
  )
}
