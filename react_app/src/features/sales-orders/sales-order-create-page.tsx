import { useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, Save, Trash2 } from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  CheckboxInput,
  DataTable,
  FormCard,
  FormField,
  FormGrid,
  Money,
  PageHeader,
  SelectInput,
  TextAreaInput,
  TextInput,
} from '@/design-system'
import { listContacts } from '@/features/contacts/contacts-api'
import { listItems } from '@/features/items/items-api'
import {
  createSalesOrder,
  type CreateSalesOrderLineRequest,
} from '@/features/sales-orders/sales-orders-api'

interface OrderLineFormItem extends CreateSalesOrderLineRequest {
  id: string
  itemName: string
  lineTotal: number
}

export function SalesOrderCreatePage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const [contactId, setContactId] = useState('')
  const [orderDate, setOrderDate] = useState(() => new Date().toISOString().split('T')[0] || '')
  const [expectedDeliveryDate, setExpectedDeliveryDate] = useState(() => {
    const d = new Date()
    d.setDate(d.getDate() + 7)
    return d.toISOString().split('T')[0] || ''
  })
  const [referenceNumber, setReferenceNumber] = useState('')
  const [allowBackorder, setAllowBackorder] = useState(false)
  const [notes, setNotes] = useState('Thank you for your order.')
  const [terms, setTerms] = useState('Payment within 30 days. Subject to local jurisdiction.')
  const [lines, setLines] = useState<OrderLineFormItem[]>([])
  const [feedback, setFeedback] = useState<{ type: 'error' | 'success'; message: string } | null>(null)

  const contactsQuery = useQuery({
    queryKey: ['contacts-for-so'],
    queryFn: () => listContacts({ filter: 'CUSTOMER', page: 0 }),
  })

  const itemsQuery = useQuery({
    queryKey: ['items-for-so'],
    queryFn: () => listItems({ page: 0 }),
  })

  const customers = contactsQuery.data?.content ?? []
  const catalogItems = itemsQuery.data?.content ?? []

  const handleAddItem = (itemId: string) => {
    const item = catalogItems.find((i) => i.id === itemId)
    if (!item) return
    const price = Number(item.salePrice || item.purchasePrice || 0)
    const newLine: OrderLineFormItem = {
      id: Math.random().toString(36).substring(2, 9),
      itemId: item.id,
      itemName: item.name,
      description: item.name,
      hsnCode: item.hsnCode || '',
      orderedQuantity: 1,
      unitPrice: price,
      discountPercent: 0,
      lineTotal: price,
    }
    setLines((prev) => [...prev, newLine])
  }

  const handleUpdateLine = (id: string, updates: Partial<OrderLineFormItem>) => {
    setLines((prev) =>
      prev.map((l) => {
        if (l.id !== id) return l
        const updated = { ...l, ...updates }
        const rawTotal = (updated.orderedQuantity || 0) * (updated.unitPrice || 0)
        const disc = (rawTotal * (updated.discountPercent || 0)) / 100
        updated.lineTotal = Math.max(0, rawTotal - disc)
        return updated
      })
    )
  }

  const handleRemoveLine = (id: string) => {
    setLines((prev) => prev.filter((l) => l.id !== id))
  }

  const grandTotal = useMemo(() => {
    return lines.reduce((acc, l) => acc + (l.lineTotal || 0), 0)
  }, [lines])

  const totalQuantity = useMemo(() => {
    return lines.reduce((acc, l) => acc + (l.orderedQuantity || 0), 0)
  }, [lines])

  const createMutation = useMutation({
    mutationFn: createSalesOrder,
    onSuccess: (created) => {
      queryClient.invalidateQueries({ queryKey: ['sales-orders'] })
      navigate(appRoutes.salesOrderDetail(created.id))
    },
    onError: (err) => {
      setFeedback({
        type: 'error',
        message: err instanceof Error ? err.message : 'Failed to create sales order',
      })
    },
  })

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    setFeedback(null)

    if (!contactId) {
      setFeedback({ type: 'error', message: 'Please select a customer.' })
      return
    }

    if (lines.length === 0) {
      setFeedback({ type: 'error', message: 'At least one line item is required.' })
      return
    }

    createMutation.mutate({
      contactId,
      orderDate,
      expectedDeliveryDate: expectedDeliveryDate || undefined,
      referenceNumber: referenceNumber.trim() || undefined,
      notes: notes.trim() || undefined,
      termsAndConditions: terms.trim() || undefined,
      lines: lines.map((l) => ({
        itemId: l.itemId,
        description: l.description,
        hsnCode: l.hsnCode || undefined,
        orderedQuantity: l.orderedQuantity,
        unitPrice: l.unitPrice,
        discountPercent: l.discountPercent,
      })),
    })
  }

  return (
    <section className="workspace-page">
      <Link className="form-back-link" to={appRoutes.salesOrders}>
        <ArrowLeft size={16} /> Back to Sales Orders
      </Link>

      <PageHeader
        eyebrow="Sales"
        title="New Sales Order"
        description="Book customer commitments, track order fulfillment, and allocate stock against confirmed demands."
        actions={
          <div style={{ display: 'flex', gap: 'var(--space-2)' }}>
            <Button
              onClick={() => navigate(appRoutes.salesOrders)}
              type="button"
              variant="secondary"
            >
              Cancel
            </Button>
            <Button
              disabled={createMutation.isPending || !contactId || lines.length === 0}
              form="so-form"
              type="submit"
              variant="primary"
            >
              <Save size={16} />
              {createMutation.isPending ? 'Saving...' : 'Save Sales Order'}
            </Button>
          </div>
        }
      />

      {feedback && (
        <div
          className={`directory-state ${feedback.type === 'error' ? 'directory-state--error' : ''}`}
          role="alert"
          style={{ marginBottom: 'var(--space-4)', minHeight: 'auto', padding: 'var(--space-3)' }}
        >
          <strong>{feedback.message}</strong>
        </div>
      )}

      <form className="create-form-container" id="so-form" onSubmit={handleSubmit}>
        <FormCard
          description="Specify buyer identity, order dates, and reference numbers"
          stepNumber={1}
          title="Customer & Order Specifics"
        >
          <FormGrid columns={4}>
            <FormField label="Customer" required>
              <SelectInput
                onChange={(e) => setContactId(e.target.value)}
                placeholderOption="-- Select Customer --"
                required
                value={contactId}
              >
                {customers.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.displayName} {c.companyName ? `(${c.companyName})` : ''}
                  </option>
                ))}
              </SelectInput>
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

            <FormField label="Customer PO / Reference">
              <TextInput
                onChange={(e) => setReferenceNumber(e.target.value)}
                placeholder="e.g. PO-89012"
                type="text"
                value={referenceNumber}
              />
            </FormField>
          </FormGrid>

          <div style={{ marginTop: 'var(--space-2)' }}>
            <CheckboxInput
              checked={allowBackorder}
              description="Allow order booking even if on-hand warehouse stock is currently insufficient"
              label="Allow Backorder for out-of-stock items"
              onChange={(e) => setAllowBackorder(e.target.checked)}
            />
          </div>
        </FormCard>

        <FormCard
          description="Add items from the catalog, specify quantities, and configure custom pricing"
          headerAction={
            <SelectInput
              onChange={(e) => {
                if (e.target.value) {
                  handleAddItem(e.target.value)
                  e.target.value = ''
                }
              }}
              placeholderOption="+ Add Item from Catalog..."
              style={{ minWidth: '240px' }}
              value=""
            >
              {catalogItems.map((item) => (
                <option key={item.id} value={item.id}>
                  {item.name} ({item.sku || 'No SKU'})
                </option>
              ))}
            </SelectInput>
          }
          stepNumber={2}
          title="Line Items"
        >
          {lines.length === 0 ? (
            <div className="directory-state" style={{ minHeight: '120px' }}>
              No line items added yet. Select an item from the dropdown above to add it to this order.
            </div>
          ) : (
            <DataTable caption="Sales Order Lines">
              <thead>
                <tr>
                  <th scope="col">Item & Description</th>
                  <th scope="col">HSN</th>
                  <th className="numeric-cell" scope="col">Quantity</th>
                  <th className="numeric-cell" scope="col">Unit Rate (₹)</th>
                  <th className="numeric-cell" scope="col">Disc %</th>
                  <th className="numeric-cell" scope="col">Line Total</th>
                  <th style={{ width: '40px' }} />
                </tr>
              </thead>
              <tbody>
                {lines.map((line) => (
                  <tr key={line.id}>
                    <td>
                      <strong>{line.itemName}</strong>
                      <input
                        onChange={(e) => handleUpdateLine(line.id, { description: e.target.value })}
                        placeholder="Line description or remarks"
                        style={{
                          background: 'transparent',
                          border: 0,
                          borderBottom: '1px solid var(--border)',
                          color: 'var(--text-secondary)',
                          display: 'block',
                          fontSize: '12px',
                          marginTop: '2px',
                          width: '100%',
                        }}
                        value={line.description}
                      />
                    </td>
                    <td>
                      <input
                        onChange={(e) => handleUpdateLine(line.id, { hsnCode: e.target.value })}
                        placeholder="HSN"
                        style={{
                          background: 'var(--bg-surface)',
                          border: '1px solid var(--border)',
                          borderRadius: 'var(--radius)',
                          color: 'var(--text-primary)',
                          height: '28px',
                          padding: '0 4px',
                          width: '80px',
                        }}
                        value={line.hsnCode}
                      />
                    </td>
                    <td className="numeric-cell">
                      <input
                        min="1"
                        onChange={(e) => handleUpdateLine(line.id, { orderedQuantity: parseFloat(e.target.value) || 0 })}
                        step="any"
                        style={{
                          background: 'var(--bg-surface)',
                          border: '1px solid var(--border-strong)',
                          borderRadius: 'var(--radius)',
                          color: 'var(--text-primary)',
                          height: '28px',
                          padding: '0 var(--space-2)',
                          textAlign: 'right',
                          width: '70px',
                        }}
                        type="number"
                        value={line.orderedQuantity}
                      />
                    </td>
                    <td className="numeric-cell">
                      <input
                        min="0"
                        onChange={(e) => handleUpdateLine(line.id, { unitPrice: parseFloat(e.target.value) || 0 })}
                        step="0.01"
                        style={{
                          background: 'var(--bg-surface)',
                          border: '1px solid var(--border-strong)',
                          borderRadius: 'var(--radius)',
                          color: 'var(--text-primary)',
                          height: '28px',
                          padding: '0 var(--space-2)',
                          textAlign: 'right',
                          width: '90px',
                        }}
                        type="number"
                        value={line.unitPrice}
                      />
                    </td>
                    <td className="numeric-cell">
                      <input
                        max="100"
                        min="0"
                        onChange={(e) => handleUpdateLine(line.id, { discountPercent: parseFloat(e.target.value) || 0 })}
                        step="0.1"
                        style={{
                          background: 'var(--bg-surface)',
                          border: '1px solid var(--border)',
                          borderRadius: 'var(--radius)',
                          color: 'var(--text-primary)',
                          height: '28px',
                          padding: '0 var(--space-2)',
                          textAlign: 'right',
                          width: '60px',
                        }}
                        type="number"
                        value={line.discountPercent}
                      />
                    </td>
                    <td className="numeric-cell">
                      <Money amount={line.lineTotal} />
                    </td>
                    <td>
                      <button
                        aria-label="Remove line"
                        onClick={() => handleRemoveLine(line.id)}
                        style={{
                          background: 'transparent',
                          border: 0,
                          color: 'var(--neg-text)',
                          cursor: 'pointer',
                          padding: '4px',
                        }}
                        type="button"
                      >
                        <Trash2 size={16} />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          )}

          {lines.length > 0 && (
            <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: 'var(--space-4)' }}>
              <div className="form-summary-card">
                <div className="form-summary-row">
                  <span>Total Units</span>
                  <strong>{totalQuantity}</strong>
                </div>
                <div className="form-summary-row form-summary-row--total">
                  <span>Order Total</span>
                  <span className="amount"><Money amount={grandTotal} /></span>
                </div>
              </div>
            </div>
          )}
        </FormCard>

        <FormCard
          description="Customer-facing notes and supply agreements"
          stepNumber={3}
          title="Terms & Notes"
        >
          <FormGrid columns={2}>
            <FormField label="Customer Notes">
              <TextAreaInput
                onChange={(e) => setNotes(e.target.value)}
                placeholder="Notes visible to customer..."
                rows={3}
                value={notes}
              />
            </FormField>

            <FormField label="Terms & Conditions">
              <TextAreaInput
                onChange={(e) => setTerms(e.target.value)}
                placeholder="Payment and delivery conditions..."
                rows={3}
                value={terms}
              />
            </FormField>
          </FormGrid>
        </FormCard>

        <div className="form-actions-bar">
          <Button
            onClick={() => navigate(appRoutes.salesOrders)}
            type="button"
            variant="secondary"
          >
            Cancel
          </Button>
          <Button
            disabled={createMutation.isPending || !contactId || lines.length === 0}
            type="submit"
            variant="primary"
          >
            <Save size={16} />
            {createMutation.isPending ? 'Saving...' : 'Save Sales Order'}
          </Button>
        </div>
      </form>
    </section>
  )
}
