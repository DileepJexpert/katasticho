import { useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, Save, Trash2 } from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { listContacts } from '@/features/contacts/contacts-api'
import { listItems } from '@/features/items/items-api'
import {
  createSalesOrder,
  type CreateSalesOrderLineRequest,
  type CreateSalesOrderRequest,
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
  const [expectedShipmentDate, setExpectedShipmentDate] = useState(() => {
    const d = new Date()
    d.setDate(d.getDate() + 7)
    return d.toISOString().split('T')[0] || ''
  })
  const [referenceNumber, setReferenceNumber] = useState('')
  const [deliveryMethod, setDeliveryMethod] = useState('Standard Courier')
  const [placeOfSupply, setPlaceOfSupply] = useState('')
  const [allowBackorder, setAllowBackorder] = useState(false)
  const [notes, setNotes] = useState('Thank you for your business.')
  const [terms, setTerms] = useState('Net 30 days from dispatch.')
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
    const rate = Number(item.salePrice || item.purchasePrice || 0)
    const newLine: OrderLineFormItem = {
      id: Math.random().toString(36).substring(2, 9),
      itemId: item.id,
      itemName: item.name,
      description: item.name,
      hsnCode: item.hsnCode || '',
      quantity: 1,
      rate: rate,
      unit: item.unitOfMeasure || 'pcs',
      discountPct: 0,
      lineTotal: rate,
    }
    setLines((prev) => [...prev, newLine])
  }

  const handleUpdateLine = (id: string, updates: Partial<OrderLineFormItem>) => {
    setLines((prev) =>
      prev.map((l) => {
        if (l.id !== id) return l
        const updated = { ...l, ...updates }
        const raw = (updated.quantity || 0) * (updated.rate || 0)
        const disc = ((updated.discountPct || 0) / 100) * raw
        updated.lineTotal = Math.max(0, raw - disc)
        return updated
      })
    )
  }

  const handleRemoveLine = (id: string) => {
    setLines((prev) => prev.filter((l) => l.id !== id))
  }

  const subtotal = useMemo(() => {
    return lines.reduce((acc, l) => acc + (l.lineTotal || 0), 0)
  }, [lines])

  const estimatedTax = useMemo(() => {
    return subtotal * 0.18
  }, [subtotal])

  const totalAmount = useMemo(() => {
    return subtotal + estimatedTax
  }, [subtotal, estimatedTax])

  const createMutation = useMutation({
    mutationFn: (req: CreateSalesOrderRequest) => createSalesOrder(req),
    onSuccess: (created) => {
      queryClient.invalidateQueries({ queryKey: ['sales-orders'] })
      navigate(appRoutes.salesOrderDetail(created.id))
    },
    onError: (err: unknown) => {
      const msg = err instanceof Error ? err.message : 'Failed to create sales order.'
      setFeedback({ type: 'error', message: msg })
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
      setFeedback({ type: 'error', message: 'Please add at least one line item to the order.' })
      return
    }

    createMutation.mutate({
      contactId,
      orderDate,
      expectedShipmentDate,
      referenceNumber: referenceNumber.trim() || undefined,
      deliveryMethod: deliveryMethod.trim() || undefined,
      placeOfSupply: placeOfSupply.trim() || undefined,
      allowBackorder,
      notes: notes.trim() || undefined,
      terms: terms.trim() || undefined,
      lines: lines.map((l) => ({
        itemId: l.itemId,
        description: l.description,
        hsnCode: l.hsnCode || undefined,
        quantity: l.quantity,
        rate: l.rate,
        unit: l.unit,
        discountPct: l.discountPct,
      })),
    })
  }

  return (
    <section className="workspace-page">
      <div style={{ marginBottom: 'var(--space-3)' }}>
        <Link
          to={appRoutes.salesOrders}
          style={{
            alignItems: 'center',
            color: 'var(--text-secondary)',
            display: 'inline-flex',
            fontSize: 'var(--text-sm)',
            gap: 'var(--space-1)',
            textDecoration: 'none',
          }}
        >
          <ArrowLeft size={16} /> Back to Sales Orders
        </Link>
      </div>

      <PageHeader
        eyebrow="Sales"
        title="New Sales Order"
        description="Book customer orders, allocate stock commitments, and initiate delivery workflows."
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

      <form id="so-form" onSubmit={handleSubmit}>
        <div style={{ display: 'grid', gap: 'var(--space-4)', marginBottom: 'var(--space-6)' }}>
          <div className="document-card">
            <h2 style={{ marginBottom: 'var(--space-3)' }}>1. Customer & Order Specifics</h2>
            <div style={{ display: 'grid', gap: 'var(--space-4)', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))' }}>
              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Customer *
                </label>
                <select
                  onChange={(e) => setContactId(e.target.value)}
                  required
                  style={{
                    background: 'var(--bg-surface)',
                    border: '1px solid var(--border-strong)',
                    borderRadius: 'var(--radius)',
                    color: 'var(--text-primary)',
                    height: 'var(--control-h)',
                    padding: '0 var(--space-2)',
                    width: '100%',
                  }}
                  value={contactId}
                >
                  <option value="">-- Select Customer --</option>
                  {customers.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.displayName} {c.companyName ? `(${c.companyName})` : ''}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Order Date *
                </label>
                <input
                  onChange={(e) => setOrderDate(e.target.value)}
                  required
                  style={{
                    background: 'var(--bg-surface)',
                    border: '1px solid var(--border-strong)',
                    borderRadius: 'var(--radius)',
                    color: 'var(--text-primary)',
                    height: 'var(--control-h)',
                    padding: '0 var(--space-2)',
                    width: '100%',
                  }}
                  type="date"
                  value={orderDate}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Expected Shipment Date
                </label>
                <input
                  onChange={(e) => setExpectedShipmentDate(e.target.value)}
                  style={{
                    background: 'var(--bg-surface)',
                    border: '1px solid var(--border-strong)',
                    borderRadius: 'var(--radius)',
                    color: 'var(--text-primary)',
                    height: 'var(--control-h)',
                    padding: '0 var(--space-2)',
                    width: '100%',
                  }}
                  type="date"
                  value={expectedShipmentDate}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  PO / Ref Number
                </label>
                <input
                  onChange={(e) => setReferenceNumber(e.target.value)}
                  placeholder="e.g. PO-89012"
                  style={{
                    background: 'var(--bg-surface)',
                    border: '1px solid var(--border-strong)',
                    borderRadius: 'var(--radius)',
                    color: 'var(--text-primary)',
                    height: 'var(--control-h)',
                    padding: '0 var(--space-2)',
                    width: '100%',
                  }}
                  type="text"
                  value={referenceNumber}
                />
              </div>
            </div>
          </div>

          <div className="document-card document-card--lines">
            <div style={{ alignItems: 'center', display: 'flex', justifyContent: 'space-between', marginBottom: 'var(--space-3)' }}>
              <h2>2. Line Items</h2>
              <div style={{ display: 'flex', gap: 'var(--space-2)' }}>
                <select
                  onChange={(e) => {
                    if (e.target.value) {
                      handleAddItem(e.target.value)
                      e.target.value = ''
                    }
                  }}
                  style={{
                    background: 'var(--bg-surface)',
                    border: '1px solid var(--border-strong)',
                    borderRadius: 'var(--radius)',
                    color: 'var(--text-primary)',
                    height: '32px',
                    padding: '0 var(--space-2)',
                  }}
                  value=""
                >
                  <option value="">+ Add Item from Catalog...</option>
                  {catalogItems.map((item) => (
                    <option key={item.id} value={item.id}>
                      {item.name} ({item.sku || 'No SKU'})
                    </option>
                  ))}
                </select>
              </div>
            </div>

            {lines.length === 0 ? (
              <div className="directory-state" style={{ minHeight: '120px' }}>
                No line items added yet. Select an item above to add it to this sales order.
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
                          style={{
                            background: 'transparent',
                            border: '0',
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
                          onChange={(e) => handleUpdateLine(line.id, { quantity: parseFloat(e.target.value) || 0 })}
                          step="any"
                          style={{
                            background: 'var(--bg-surface)',
                            border: '1px solid var(--border-strong)',
                            borderRadius: 'var(--radius)',
                            color: 'var(--text-primary)',
                            height: '28px',
                            padding: '0 var(--space-2)',
                            textAlign: 'right',
                            width: '80px',
                          }}
                          type="number"
                          value={line.quantity}
                        />
                      </td>
                      <td className="numeric-cell">
                        <input
                          min="0"
                          onChange={(e) => handleUpdateLine(line.id, { rate: parseFloat(e.target.value) || 0 })}
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
                          value={line.rate}
                        />
                      </td>
                      <td className="numeric-cell">
                        <input
                          max="100"
                          min="0"
                          onChange={(e) => handleUpdateLine(line.id, { discountPct: parseFloat(e.target.value) || 0 })}
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
                          value={line.discountPct}
                        />
                      </td>
                      <td className="numeric-cell">
                        <Money amount={line.lineTotal} />
                      </td>
                      <td>
                        <button
                          aria-label="Remove item"
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
                <div style={{ minWidth: '260px' }}>
                  <div className="progress-row">
                    <span>Subtotal</span>
                    <Money amount={subtotal} />
                  </div>
                  <div className="progress-row">
                    <span>Estimated GST (18%)</span>
                    <Money amount={estimatedTax} />
                  </div>
                  <div className="progress-row progress-row--total">
                    <span>Grand Total</span>
                    <Money amount={totalAmount} />
                  </div>
                </div>
              </div>
            )}
          </div>

          <div className="document-card">
            <h2 style={{ marginBottom: 'var(--space-3)' }}>3. Fulfilment & Commercial Terms</h2>
            <div style={{ display: 'grid', gap: 'var(--space-4)', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))' }}>
              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Delivery Method
                </label>
                <input
                  onChange={(e) => setDeliveryMethod(e.target.value)}
                  placeholder="e.g. Courier / Hand Delivery / Road"
                  style={{
                    background: 'var(--bg-surface)',
                    border: '1px solid var(--border-strong)',
                    borderRadius: 'var(--radius)',
                    color: 'var(--text-primary)',
                    height: 'var(--control-h)',
                    padding: '0 var(--space-2)',
                    width: '100%',
                  }}
                  type="text"
                  value={deliveryMethod}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Place of Supply
                </label>
                <input
                  onChange={(e) => setPlaceOfSupply(e.target.value)}
                  placeholder="e.g. 27-Maharashtra"
                  style={{
                    background: 'var(--bg-surface)',
                    border: '1px solid var(--border-strong)',
                    borderRadius: 'var(--radius)',
                    color: 'var(--text-primary)',
                    height: 'var(--control-h)',
                    padding: '0 var(--space-2)',
                    width: '100%',
                  }}
                  type="text"
                  value={placeOfSupply}
                />
              </div>

              <div style={{ display: 'flex', alignItems: 'center', marginTop: '20px' }}>
                <label style={{ display: 'inline-flex', alignItems: 'center', gap: '8px', cursor: 'pointer' }}>
                  <input
                    checked={allowBackorder}
                    onChange={(e) => setAllowBackorder(e.target.checked)}
                    type="checkbox"
                  />
                  <span style={{ fontSize: 'var(--text-sm)', fontWeight: 'var(--fw-medium)' }}>
                    Allow Backorder if stock is insufficient
                  </span>
                </label>
              </div>
            </div>

            <div style={{ display: 'grid', gap: 'var(--space-4)', gridTemplateColumns: '1fr 1fr', marginTop: 'var(--space-4)' }}>
              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Customer Notes
                </label>
                <textarea
                  onChange={(e) => setNotes(e.target.value)}
                  rows={3}
                  style={{
                    background: 'var(--bg-surface)',
                    border: '1px solid var(--border-strong)',
                    borderRadius: 'var(--radius)',
                    color: 'var(--text-primary)',
                    padding: 'var(--space-2)',
                    width: '100%',
                  }}
                  value={notes}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Terms & Conditions
                </label>
                <textarea
                  onChange={(e) => setTerms(e.target.value)}
                  rows={3}
                  style={{
                    background: 'var(--bg-surface)',
                    border: '1px solid var(--border-strong)',
                    borderRadius: 'var(--radius)',
                    color: 'var(--text-primary)',
                    padding: 'var(--space-2)',
                    width: '100%',
                  }}
                  value={terms}
                />
              </div>
            </div>
          </div>
        </div>
      </form>
    </section>
  )
}
