import { useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, Save, Trash2 } from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import {
  createBill,
  type CreatePurchaseBillRequest,
} from '@/features/bills/bills-api'
import { listContacts } from '@/features/contacts/contacts-api'
import { listItems } from '@/features/items/items-api'

interface BillLineFormItem {
  id: string
  lineType: 'GOODS' | 'SERVICE'
  itemId?: string
  itemName: string
  description: string
  hsnCode?: string
  quantity: number
  unitPrice: number
  gstRate: number
  lineTax: number
  lineTotal: number
}

export function BillCreatePage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const [contactId, setContactId] = useState('')
  const [vendorBillNumber, setVendorBillNumber] = useState('')
  const [billDate, setBillDate] = useState(() => new Date().toISOString().split('T')[0] || '')
  const [dueDate, setDueDate] = useState(() => {
    const d = new Date()
    d.setDate(d.getDate() + 30)
    return d.toISOString().split('T')[0] || ''
  })
  const [placeOfSupply, setPlaceOfSupply] = useState('')
  const [reverseCharge, setReverseCharge] = useState(false)
  const [notes, setNotes] = useState('')
  const [lines, setLines] = useState<BillLineFormItem[]>([])
  const [feedback, setFeedback] = useState<{ type: 'error' | 'success'; message: string } | null>(null)

  const vendorsQuery = useQuery({
    queryKey: ['vendors-for-bill'],
    queryFn: () => listContacts({ filter: 'VENDOR', page: 0 }),
  })

  const itemsQuery = useQuery({
    queryKey: ['items-for-bill'],
    queryFn: () => listItems({ page: 0 }),
  })

  const vendors = vendorsQuery.data?.content ?? []
  const catalogItems = itemsQuery.data?.content ?? []

  const handleAddItem = (itemId: string) => {
    const item = catalogItems.find((i) => i.id === itemId)
    if (!item) return
    const price = Number(item.purchasePrice || 0)
    const gst = Number(item.gstRate || 18)
    const tax = (price * gst) / 100
    const newLine: BillLineFormItem = {
      id: Math.random().toString(36).substring(2, 9),
      lineType: 'GOODS',
      itemId: item.id,
      itemName: item.name,
      description: item.name,
      hsnCode: item.hsnCode || '',
      quantity: 1,
      unitPrice: price,
      gstRate: gst,
      lineTax: tax,
      lineTotal: price + tax,
    }
    setLines((prev) => [...prev, newLine])
  }

  const handleUpdateLine = (id: string, updates: Partial<BillLineFormItem>) => {
    setLines((prev) =>
      prev.map((l) => {
        if (l.id !== id) return l
        const updated = { ...l, ...updates }
        const taxable = (updated.quantity || 0) * (updated.unitPrice || 0)
        const tax = ((updated.gstRate || 0) / 100) * taxable
        updated.lineTax = tax
        updated.lineTotal = taxable + tax
        return updated
      })
    )
  }

  const handleRemoveLine = (id: string) => {
    setLines((prev) => prev.filter((l) => l.id !== id))
  }

  const subtotal = useMemo(() => {
    return lines.reduce((acc, l) => acc + (l.quantity || 0) * (l.unitPrice || 0), 0)
  }, [lines])

  const totalGst = useMemo(() => {
    return lines.reduce((acc, l) => acc + (l.lineTax || 0), 0)
  }, [lines])

  const grandTotal = useMemo(() => {
    return subtotal + totalGst
  }, [subtotal, totalGst])

  const createMutation = useMutation({
    mutationFn: (req: CreatePurchaseBillRequest) => createBill(req),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['bills'] })
      navigate(appRoutes.bills)
    },
    onError: (err: unknown) => {
      const msg = err instanceof Error ? err.message : 'Failed to create vendor bill.'
      setFeedback({ type: 'error', message: msg })
    },
  })

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    setFeedback(null)

    if (!contactId) {
      setFeedback({ type: 'error', message: 'Please select a vendor.' })
      return
    }

    if (lines.length === 0) {
      setFeedback({ type: 'error', message: 'Please add at least one line item to the bill.' })
      return
    }

    createMutation.mutate({
      contactId,
      vendorBillNumber: vendorBillNumber.trim() || undefined,
      billDate,
      dueDate,
      placeOfSupply: placeOfSupply.trim() || undefined,
      reverseCharge,
      notes: notes.trim() || undefined,
      lines: lines.map((l) => ({
        lineType: l.lineType,
        description: l.description,
        hsnCode: l.hsnCode || undefined,
        itemId: l.itemId,
        quantity: l.quantity,
        unitPrice: l.unitPrice,
        gstRate: l.gstRate,
      })),
    })
  }

  return (
    <section className="workspace-page">
      <div style={{ marginBottom: 'var(--space-3)' }}>
        <Link
          to={appRoutes.bills}
          style={{
            alignItems: 'center',
            color: 'var(--text-secondary)',
            display: 'inline-flex',
            fontSize: 'var(--text-sm)',
            gap: 'var(--space-1)',
            textDecoration: 'none',
          }}
        >
          <ArrowLeft size={16} /> Back to Bills
        </Link>
      </div>

      <PageHeader
        eyebrow="Purchases / Payables"
        title="New Vendor Bill"
        description="Book vendor invoices against accounts payable, input tax credits, and purchase ledgers."
        actions={
          <div style={{ display: 'flex', gap: 'var(--space-2)' }}>
            <Button
              onClick={() => navigate(appRoutes.bills)}
              type="button"
              variant="secondary"
            >
              Cancel
            </Button>
            <Button
              disabled={createMutation.isPending || !contactId || lines.length === 0}
              form="bill-form"
              type="submit"
              variant="primary"
            >
              <Save size={16} />
              {createMutation.isPending ? 'Saving...' : 'Save Bill'}
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

      <form id="bill-form" onSubmit={handleSubmit}>
        <div style={{ display: 'grid', gap: 'var(--space-4)', marginBottom: 'var(--space-6)' }}>
          <div className="document-card">
            <h2 style={{ marginBottom: 'var(--space-3)' }}>1. Vendor & Invoice Reference</h2>
            <div style={{ display: 'grid', gap: 'var(--space-4)', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))' }}>
              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Vendor / Supplier *
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
                  <option value="">-- Select Vendor --</option>
                  {vendors.map((v) => (
                    <option key={v.id} value={v.id}>
                      {v.displayName} {v.companyName ? `(${v.companyName})` : ''}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Vendor Invoice #
                </label>
                <input
                  onChange={(e) => setVendorBillNumber(e.target.value)}
                  placeholder="e.g. INV-2026-908"
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
                  value={vendorBillNumber}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Bill Date *
                </label>
                <input
                  onChange={(e) => setBillDate(e.target.value)}
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
                  value={billDate}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Due Date
                </label>
                <input
                  onChange={(e) => setDueDate(e.target.value)}
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
                  value={dueDate}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Place of Supply
                </label>
                <input
                  onChange={(e) => setPlaceOfSupply(e.target.value)}
                  placeholder="e.g. 29-Karnataka"
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

              <div style={{ display: 'flex', alignItems: 'center', gap: '8px', paddingTop: '22px' }}>
                <label style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: 'var(--text-xs)', cursor: 'pointer' }}>
                  <input
                    checked={reverseCharge}
                    onChange={(e) => setReverseCharge(e.target.checked)}
                    type="checkbox"
                  />
                  <span>Reverse Charge (RCM)</span>
                </label>
              </div>
            </div>
          </div>

          <div className="document-card document-card--lines">
            <div style={{ alignItems: 'center', display: 'flex', justifyContent: 'space-between', marginBottom: 'var(--space-3)' }}>
              <h2>2. Billed Items & Services</h2>
              <div>
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
                  <option value="">+ Add Item to Bill...</option>
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
                No line items added yet. Select an item above to add it to this bill.
              </div>
            ) : (
              <DataTable caption="Bill Lines">
                <thead>
                  <tr>
                    <th scope="col">Description</th>
                    <th scope="col">HSN</th>
                    <th className="numeric-cell" scope="col">Qty</th>
                    <th className="numeric-cell" scope="col">Unit Cost (₹)</th>
                    <th className="numeric-cell" scope="col">GST %</th>
                    <th className="numeric-cell" scope="col">Tax</th>
                    <th className="numeric-cell" scope="col">Total</th>
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
                            width: '70px',
                          }}
                          type="number"
                          value={line.quantity}
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
                          max="28"
                          min="0"
                          onChange={(e) => handleUpdateLine(line.id, { gstRate: parseFloat(e.target.value) || 0 })}
                          step="any"
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
                          value={line.gstRate}
                        />
                      </td>
                      <td className="numeric-cell">
                        <Money amount={line.lineTax} />
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
                    <span>Taxable Subtotal</span>
                    <Money amount={subtotal} />
                  </div>
                  <div className="progress-row">
                    <span>Input GST (ITC)</span>
                    <Money amount={totalGst} />
                  </div>
                  <div className="progress-row progress-row--total">
                    <span>Bill Amount</span>
                    <Money amount={grandTotal} />
                  </div>
                </div>
              </div>
            )}
          </div>

          <div className="document-card">
            <h2 style={{ marginBottom: 'var(--space-3)' }}>3. Notes & References</h2>
            <textarea
              onChange={(e) => setNotes(e.target.value)}
              placeholder="Vendor notes, verification comments..."
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
        </div>
      </form>
    </section>
  )
}
