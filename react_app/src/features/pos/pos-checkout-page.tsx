import { useEffect, useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  Banknote,
  CheckCircle2,
  CreditCard,
  Lock,
  Minus,
  Plus,
  QrCode,
  Receipt,
  RotateCcw,
  Search,
  ShoppingBag,
  Trash2,
  Unlock,
  User,
} from 'lucide-react'
import { Link } from 'react-router-dom'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { listContacts } from '@/features/contacts/contacts-api'
import {
  addRegisterExpense,
  closeRegister,
  createSalesReceipt,
  getTodayRegister,
  openRegister,
  searchPosItems,
  type CreateSalesReceiptRequest,
  type PosSearchResult,
  type SalesReceipt,
} from '@/features/pos/pos-api'

type CartItem = {
  id: string
  itemId: string
  name: string
  sku: string | null
  rate: number
  mrp: number | null
  quantity: number
  unit: string | null
  hsnCode: string | null
  batchId: string | null
  batchNumber: string | null
  rackLocationCode: string | null
}

export function PosCheckoutPage() {
  const queryClient = useQueryClient()

  // State
  const [itemQuery, setItemQuery] = useState('')
  const [cart, setCart] = useState<CartItem[]>([])
  const [selectedContactId, setSelectedContactId] = useState<string>('')
  const [paymentMode, setPaymentMode] = useState<'CASH' | 'UPI' | 'CARD' | 'CREDIT'>('CASH')
  const [tenderedAmount, setTenderedAmount] = useState<string>('')
  const [upiRef, setUpiRef] = useState<string>('')
  const [receiptNotes, setReceiptNotes] = useState<string>('')
  const [lastReceipt, setLastReceipt] = useState<SalesReceipt | null>(null)

  // Modals
  const [isOpenRegisterOpen, setIsOpenRegisterOpen] = useState(false)
  const [openingCashInput, setOpeningCashInput] = useState('1000')
  const [isCloseRegisterOpen, setIsCloseRegisterOpen] = useState(false)
  const [closingCashInput, setClosingCashInput] = useState('')
  const [isExpenseOpen, setIsExpenseOpen] = useState(false)
  const [expenseAmount, setExpenseAmount] = useState('')
  const [expenseReason, setExpenseReason] = useState('')

  // Queries
  const registerQuery = useQuery({
    queryKey: ['pos-today-register'],
    queryFn: () => getTodayRegister(),
  })

  const contactsQuery = useQuery({
    queryKey: ['contacts-pos-list'],
    queryFn: () => listContacts({ filter: 'CUSTOMER', page: 0, search: '' }),
  })

  const itemSearchQuery = useQuery({
    queryKey: ['pos-search-items', itemQuery],
    queryFn: () => searchPosItems(itemQuery, 12),
    enabled: itemQuery.trim().length >= 1,
  })

  const register = registerQuery.data
  const contacts = contactsQuery.data?.content ?? []
  const searchResults = itemSearchQuery.data ?? []

  // Mutations
  const openRegisterMutation = useMutation({
    mutationFn: ({ amount, notes }: { amount: number; notes?: string }) => openRegister(amount, notes),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['pos-today-register'] })
      setIsOpenRegisterOpen(false)
    },
  })

  const closeRegisterMutation = useMutation({
    mutationFn: ({ actual, notes }: { actual: number; notes?: string }) => closeRegister(actual, notes),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['pos-today-register'] })
      setIsCloseRegisterOpen(false)
    },
  })

  const addExpenseMutation = useMutation({
    mutationFn: ({ amount, description }: { amount: number; description: string }) =>
      addRegisterExpense(amount, description),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['pos-today-register'] })
      setIsExpenseOpen(false)
      setExpenseAmount('')
      setExpenseReason('')
    },
  })

  const saleCheckoutMutation = useMutation({
    mutationFn: (req: CreateSalesReceiptRequest) => createSalesReceipt(req),
    onSuccess: (receipt) => {
      setLastReceipt(receipt)
      setCart([])
      setTenderedAmount('')
      setUpiRef('')
      setReceiptNotes('')
      queryClient.invalidateQueries({ queryKey: ['pos-today-register'] })
    },
  })

  // Cart Calculations
  const subtotal = useMemo(() => {
    return cart.reduce((sum, item) => sum + item.rate * item.quantity, 0)
  }, [cart])

  // Approx GST 5% inclusive for pharma/kirana items unless mapped
  const taxAmount = useMemo(() => {
    return Math.round(subtotal * 0.05 * 100) / 100
  }, [subtotal])

  const grandTotal = useMemo(() => {
    return subtotal
  }, [subtotal])

  const changeDue = useMemo(() => {
    const tendered = Number(tenderedAmount || 0)
    return Math.max(0, tendered - grandTotal)
  }, [tenderedAmount, grandTotal])

  // Default tendered amount to grand total if cash
  useEffect(() => {
    if (paymentMode === 'CASH' && grandTotal > 0 && !tenderedAmount) {
      setTenderedAmount(String(Math.ceil(grandTotal)))
    }
  }, [grandTotal, paymentMode, tenderedAmount])

  const addToCart = (product: PosSearchResult) => {
    setCart((prev) => {
      const existing = prev.find((i) => i.itemId === product.id)
      if (existing) {
        return prev.map((i) =>
          i.itemId === product.id ? { ...i, quantity: i.quantity + 1 } : i
        )
      }
      return [
        ...prev,
        {
          id: `${product.id}-${Date.now()}`,
          itemId: product.id,
          name: product.name,
          sku: product.sku,
          rate: product.rate,
          mrp: product.mrp,
          quantity: 1,
          unit: product.unit || 'pcs',
          hsnCode: product.hsnCode,
          batchId: product.batchId,
          batchNumber: product.batchNumber,
          rackLocationCode: product.rackLocationCode,
        },
      ]
    })
    setItemQuery('')
  }

  const updateQuantity = (id: string, delta: number) => {
    setCart((prev) =>
      prev
        .map((item) => {
          if (item.id === id) {
            const nextQty = Math.max(1, item.quantity + delta)
            return { ...item, quantity: nextQty }
          }
          return item
        })
        .filter((item) => item.quantity > 0)
    )
  }

  const removeFromCart = (id: string) => {
    setCart((prev) => prev.filter((i) => i.id !== id))
  }

  const handleCheckout = () => {
    if (cart.length === 0) return
    const todayStr = new Date().toISOString().split('T')[0] || ''
    const req: CreateSalesReceiptRequest = {
      contactId: selectedContactId || undefined,
      receiptDate: todayStr,
      paymentMode,
      amountReceived: paymentMode === 'CASH' ? Number(tenderedAmount || grandTotal) : grandTotal,
      upiReference: upiRef.trim() || undefined,
      notes: receiptNotes.trim() || undefined,
      gstInvoice: true,
      lines: cart.map((item) => ({
        itemId: item.itemId,
        quantity: item.quantity,
        rate: item.rate,
        unit: item.unit || undefined,
        hsnCode: item.hsnCode || undefined,
        batchId: item.batchId || undefined,
      })),
    }
    saleCheckoutMutation.mutate(req)
  }

  const isRegisterOpen = register?.status === 'OPEN'

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Retail POS / Fast Checkout"
        title="POS Counter & Cash Register"
        description="High-speed barcode scanning, cash drawer management, and instant thermal receipt printing."
        actions={
          <div style={{ display: 'flex', gap: 'var(--space-sm)' }}>
            <Link className="btn btn--secondary" to="/sales-receipts">
              <Receipt aria-hidden="true" size={14} style={{ marginRight: 6 }} />
              Receipts History
            </Link>
          </div>
        }
      />

      {/* Cash Register Shift Header */}
      <div className="summary-strip">
        <div className="summary-card">
          <span className="summary-card__label">Register Status</span>
          <strong className="summary-card__value">
            <StatusChip status={isRegisterOpen ? 'Register Open' : 'Register Closed'} />
          </strong>
          <span className="summary-card__hint">
            {isRegisterOpen ? 'Accepting counter sales' : 'Open register to begin'}
          </span>
        </div>

        <div className="summary-card">
          <span className="summary-card__label">Cash in Drawer</span>
          <strong className="summary-card__value">
            <Money amount={register?.expectedClosing || register?.openingBalance || 0} />
          </strong>
          <span className="summary-card__hint">
            Opening: <Money amount={register?.openingBalance || 0} />
          </span>
        </div>

        <div className="summary-card">
          <span className="summary-card__label">Today's Sales Total</span>
          <strong className="summary-card__value">
            <Money amount={register?.totalSales || 0} />
          </strong>
          <span className="summary-card__hint">
            {register?.transactionCount || 0} transactions (Cash + UPI + Card)
          </span>
        </div>

        <div className="summary-card summary-card--accent">
          <span className="summary-card__label">Register Actions</span>
          <div style={{ display: 'flex', gap: 6, marginTop: 4, flexWrap: 'wrap' }}>
            {!isRegisterOpen ? (
              <Button onClick={() => setIsOpenRegisterOpen(true)} variant="primary">
                <Unlock aria-hidden="true" size={12} style={{ marginRight: 4 }} />
                Open Shift
              </Button>
            ) : (
              <>
                <Button onClick={() => setIsExpenseOpen(true)} variant="secondary">
                  <Minus aria-hidden="true" size={12} style={{ marginRight: 4 }} />
                  Cash Payout
                </Button>
                <Button onClick={() => setIsCloseRegisterOpen(true)} variant="secondary">
                  <Lock aria-hidden="true" size={12} style={{ marginRight: 4 }} />
                  Close Shift
                </Button>
              </>
            )}
          </div>
        </div>
      </div>

      {/* Main Two-Column POS Layout */}
      <div className="pos-checkout-grid">
        {/* LEFT: Item Search & Cart Lines */}
        <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
          <div style={{ position: 'relative', marginBottom: 'var(--space-md)' }}>
            <div className="search-field" style={{ width: '100%' }}>
              <Search aria-hidden="true" size={18} />
              <input
                aria-label="Scan barcode or type item name"
                autoFocus
                onChange={(e) => setItemQuery(e.target.value)}
                placeholder="Scan barcode or type medicine / product name..."
                type="search"
                value={itemQuery}
              />
            </div>

            {/* Live Search Suggestions Dropdown */}
            {itemQuery.trim().length >= 1 && (
              <div
                style={{
                  position: 'absolute',
                  top: '100%',
                  left: 0,
                  right: 0,
                  zIndex: 20,
                  marginTop: 4,
                  maxHeight: 280,
                  overflowY: 'auto',
                  backgroundColor: 'var(--color-surface)',
                  border: '1px solid var(--color-border)',
                  borderRadius: 'var(--radius-md)',
                  boxShadow: '0 4px 12px rgba(0,0,0,0.12)',
                }}
              >
                {itemSearchQuery.isLoading ? (
                  <p className="cell-muted" style={{ padding: 12 }}>
                    Searching items...
                  </p>
                ) : searchResults.length === 0 ? (
                  <p className="cell-muted" style={{ padding: 12 }}>
                    No items match "{itemQuery}"
                  </p>
                ) : (
                  searchResults.map((prod) => (
                    <div
                      key={prod.id}
                      onClick={() => addToCart(prod)}
                      style={{
                        padding: '10px 14px',
                        display: 'flex',
                        justifyContent: 'space-between',
                        alignItems: 'center',
                        cursor: 'pointer',
                        borderBottom: '1px solid var(--color-border)',
                      }}
                    >
                      <div>
                        <strong>{prod.name}</strong>
                        <div style={{ display: 'flex', gap: 8, fontSize: '0.8rem', color: 'var(--color-text-secondary)' }}>
                          {prod.rackLocationCode && (
                            <span className="table-code">ðŸ“ {prod.rackLocationCode}</span>
                          )}
                          {prod.batchNumber && <span>Batch: {prod.batchNumber}</span>}
                          <span>Stock: {prod.currentStock || 0} {prod.unit || 'pcs'}</span>
                        </div>
                      </div>
                      <div style={{ textAlign: 'right' }}>
                        <strong style={{ color: 'var(--color-primary)' }}>
                          <Money amount={prod.rate} />
                        </strong>
                        {prod.mrp ? (
                          <div style={{ fontSize: '0.75rem', color: 'var(--color-text-secondary)', textDecoration: 'line-through' }}>
                            <Money amount={prod.mrp} />
                          </div>
                        ) : null}
                      </div>
                    </div>
                  ))
                )}
              </div>
            )}
          </div>

          {/* Cart Table */}
          {cart.length === 0 ? (
            <div className="directory-state" style={{ minHeight: 240 }}>
              <ShoppingBag aria-hidden="true" size={32} />
              <strong>POS cart is empty.</strong>
              <p>Scan an item barcode or search above to ring up items.</p>
            </div>
          ) : (
            <DataTable caption="Current customer cart items">
              <thead>
                <tr>
                  <th scope="col">Item & Location</th>
                  <th className="numeric-cell" scope="col">Rate</th>
                  <th className="numeric-cell" scope="col" style={{ width: 120 }}>
                    Qty
                  </th>
                  <th className="numeric-cell" scope="col">Total</th>
                  <th scope="col" style={{ width: 40 }} />
                </tr>
              </thead>
              <tbody>
                {cart.map((item) => (
                  <tr key={item.id}>
                    <td>
                      <div className="cell-stack">
                        <strong>{item.name}</strong>
                        <div style={{ display: 'flex', gap: 6, fontSize: '0.75rem', color: 'var(--color-text-secondary)' }}>
                          {item.rackLocationCode && <span>Rack: {item.rackLocationCode}</span>}
                          {item.batchNumber && <span>Batch: {item.batchNumber}</span>}
                        </div>
                      </div>
                    </td>
                    <td className="numeric-cell">
                      <Money amount={item.rate} />
                    </td>
                    <td className="numeric-cell">
                      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'flex-end', gap: 4 }}>
                        <button
                          className="icon-button"
                          onClick={() => updateQuantity(item.id, -1)}
                          style={{ padding: 4 }}
                          type="button"
                        >
                          <Minus aria-hidden="true" size={12} />
                        </button>
                        <span style={{ fontWeight: 600, minWidth: 24, textAlign: 'center' }}>
                          {item.quantity}
                        </span>
                        <button
                          className="icon-button"
                          onClick={() => updateQuantity(item.id, 1)}
                          style={{ padding: 4 }}
                          type="button"
                        >
                          <Plus aria-hidden="true" size={12} />
                        </button>
                      </div>
                    </td>
                    <td className="numeric-cell">
                      <strong>
                        <Money amount={item.rate * item.quantity} />
                      </strong>
                    </td>
                    <td>
                      <button
                        aria-label="Remove item from cart"
                        className="icon-button"
                        onClick={() => removeFromCart(item.id)}
                        style={{ color: 'var(--color-error)', padding: 4 }}
                        type="button"
                      >
                        <Trash2 aria-hidden="true" size={14} />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          )}

          {cart.length > 0 && (
            <div style={{ marginTop: 'var(--space-sm)', textAlign: 'right' }}>
              <Button onClick={() => setCart([])} variant="secondary">
                <RotateCcw aria-hidden="true" size={12} style={{ marginRight: 4 }} />
                Clear Cart
              </Button>
            </div>
          )}
        </div>

        {/* RIGHT: Customer, Payment, Tender, and Complete Checkout */}
        <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
          <h3 style={{ fontSize: '1.1rem', fontWeight: 600, marginBottom: 'var(--space-sm)' }}>
            Checkout & Tender
          </h3>

          {/* Customer selection */}
          <div style={{ marginBottom: 'var(--space-md)' }}>
            <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
              Customer / Account
            </label>
            <select
              className="select-field"
              onChange={(e) => setSelectedContactId(e.target.value)}
              style={{
                width: '100%',
                padding: '8px 12px',
                borderRadius: 'var(--radius-md)',
                border: '1px solid var(--color-border)',
                background: 'var(--color-surface)',
                color: 'var(--color-text-primary)',
              }}
              value={selectedContactId}
            >
              <option value="">Walk-in Cash Customer</option>
              {contacts.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.displayName} {c.phone ? `(${c.phone})` : ''}
                </option>
              ))}
            </select>
          </div>

          {/* Payment Mode Selection */}
          <div style={{ marginBottom: 'var(--space-md)' }}>
            <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 6 }}>
              Payment Mode
            </label>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 6 }}>
              <button
                className={`filter-chip ${paymentMode === 'CASH' ? 'filter-chip--active' : ''}`}
                onClick={() => setPaymentMode('CASH')}
                style={{ justifyContent: 'center', padding: '8px 12px' }}
                type="button"
              >
                <Banknote aria-hidden="true" size={14} style={{ marginRight: 6 }} />
                Cash
              </button>
              <button
                className={`filter-chip ${paymentMode === 'UPI' ? 'filter-chip--active' : ''}`}
                onClick={() => setPaymentMode('UPI')}
                style={{ justifyContent: 'center', padding: '8px 12px' }}
                type="button"
              >
                <QrCode aria-hidden="true" size={14} style={{ marginRight: 6 }} />
                UPI / QR
              </button>
              <button
                className={`filter-chip ${paymentMode === 'CARD' ? 'filter-chip--active' : ''}`}
                onClick={() => setPaymentMode('CARD')}
                style={{ justifyContent: 'center', padding: '8px 12px' }}
                type="button"
              >
                <CreditCard aria-hidden="true" size={14} style={{ marginRight: 6 }} />
                Card POS
              </button>
              <button
                className={`filter-chip ${paymentMode === 'CREDIT' ? 'filter-chip--active' : ''}`}
                onClick={() => setPaymentMode('CREDIT')}
                style={{ justifyContent: 'center', padding: '8px 12px' }}
                type="button"
              >
                <User aria-hidden="true" size={14} style={{ marginRight: 6 }} />
                Customer Ledger
              </button>
            </div>
          </div>

          {/* Tendered Amount & Change (for Cash) */}
          {paymentMode === 'CASH' && (
            <div style={{ marginBottom: 'var(--space-md)', padding: 12, background: 'var(--color-bg-subtle)', borderRadius: 'var(--radius-md)' }}>
              <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                Cash Tendered (₹)
              </label>
              <input
                style={{
                  width: '100%',
                  padding: '8px 12px',
                  borderRadius: 'var(--radius-md)',
                  border: '1px solid var(--color-border)',
                  fontSize: '1.1rem',
                  fontWeight: 600,
                  marginBottom: 8,
                }}
                onChange={(e) => setTenderedAmount(e.target.value)}
                placeholder="Amount given by customer"
                type="number"
                value={tenderedAmount}
              />
              <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginBottom: 8 }}>
                {[100, 200, 500, 2000].map((denom) => (
                  <button
                    key={denom}
                    className="filter-chip"
                    onClick={() => setTenderedAmount(String(denom))}
                    style={{ fontSize: '0.8rem', padding: '4px 8px' }}
                    type="button"
                  >
                    ₹{denom}
                  </button>
                ))}
                <button
                  className="filter-chip"
                  onClick={() => setTenderedAmount(String(Math.ceil(grandTotal)))}
                  style={{ fontSize: '0.8rem', padding: '4px 8px' }}
                  type="button"
                >
                  Exact (₹{Math.ceil(grandTotal)})
                </button>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span style={{ fontSize: '0.9rem', color: 'var(--color-text-secondary)' }}>Change Return:</span>
                <strong style={{ fontSize: '1.1rem', color: changeDue > 0 ? 'var(--color-primary)' : 'var(--color-text-primary)' }}>
                  <Money amount={changeDue} />
                </strong>
              </div>
            </div>
          )}

          {/* UPI Reference (for UPI) */}
          {paymentMode === 'UPI' && (
            <div style={{ marginBottom: 'var(--space-md)' }}>
              <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                UPI Reference / UTR Number
              </label>
              <input
                style={{
                  width: '100%',
                  padding: '8px 12px',
                  borderRadius: 'var(--radius-md)',
                  border: '1px solid var(--color-border)',
                }}
                onChange={(e) => setUpiRef(e.target.value)}
                placeholder="e.g. 423985729103"
                type="text"
                value={upiRef}
              />
            </div>
          )}

          {/* Order Summary breakdown */}
          <div
            style={{
              padding: '12px 14px',
              borderRadius: 'var(--radius-md)',
              border: '1px solid var(--color-border)',
              marginBottom: 'var(--space-md)',
            }}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 6 }}>
              <span className="cell-muted">Items Subtotal</span>
              <strong>
                <Money amount={subtotal} />
              </strong>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 6 }}>
              <span className="cell-muted">Tax Split (CGST + SGST)</span>
              <span>
                <Money amount={taxAmount} />
              </span>
            </div>
            <div
              style={{
                display: 'flex',
                justifyContent: 'space-between',
                paddingTop: 8,
                borderTop: '1px solid var(--color-border)',
                fontSize: '1.2rem',
                fontWeight: 700,
              }}
            >
              <span>Grand Total</span>
              <span style={{ color: 'var(--color-primary)' }}>
                <Money amount={grandTotal} />
              </span>
            </div>
          </div>

          <Button
            disabled={cart.length === 0 || saleCheckoutMutation.isPending}
            onClick={handleCheckout}
            style={{ width: '100%', padding: '12px', fontSize: '1.05rem' }}
            variant="primary"
          >
            <CheckCircle2 aria-hidden="true" size={18} style={{ marginRight: 8 }} />
            {saleCheckoutMutation.isPending ? 'Processing Sale...' : `Complete Sale (₹${grandTotal.toFixed(2)})`}
          </Button>
        </div>
      </div>

      {/* MODAL: LAST SALE SUCCESS RECEIPT */}
      {lastReceipt && (
        <div
          role="dialog"
          aria-modal="true"
          aria-labelledby="receipt-success-title"
          style={{
            position: 'fixed',
            inset: 0,
            backgroundColor: 'rgba(0,0,0,0.5)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 1000,
            padding: 'var(--space-md)',
          }}
        >
          <div
            className="panel-card"
            style={{
              width: '100%',
              maxWidth: 480,
              backgroundColor: 'var(--color-surface)',
              borderRadius: 'var(--radius-lg)',
              padding: 'var(--space-lg)',
              border: '1px solid var(--color-border)',
              textAlign: 'center',
            }}
          >
            <CheckCircle2 aria-hidden="true" size={48} color="var(--color-success)" style={{ margin: '0 auto 12px' }} />
            <h3 id="receipt-success-title" style={{ fontSize: '1.3rem', fontWeight: 700, margin: '0 0 4px' }}>
              Sale Completed!
            </h3>
            <p className="table-code" style={{ fontSize: '1.1rem', fontWeight: 600, color: 'var(--color-primary)' }}>
              Receipt #{lastReceipt.receiptNumber}
            </p>

            <div style={{ padding: '12px 16px', background: 'var(--color-bg-subtle)', borderRadius: 'var(--radius-md)', margin: '16px 0', textAlign: 'left' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
                <span className="cell-muted">Payment Mode:</span>
                <strong>{lastReceipt.paymentMode}</strong>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
                <span className="cell-muted">Total Amount:</span>
                <strong><Money amount={lastReceipt.total} /></strong>
              </div>
              {lastReceipt.changeReturned > 0 && (
                <div style={{ display: 'flex', justifyContent: 'space-between', color: 'var(--color-success)', fontWeight: 600 }}>
                  <span>Change Returned:</span>
                  <span><Money amount={lastReceipt.changeReturned} /></span>
                </div>
              )}
            </div>

            <div style={{ display: 'flex', gap: 'var(--space-sm)', justifyContent: 'center' }}>
              <Button onClick={() => setLastReceipt(null)} variant="primary">
                New Sale
              </Button>
              <Link className="btn btn--secondary" to={`/sales-receipts/${lastReceipt.id}`}>
                View Receipt
              </Link>
            </div>
          </div>
        </div>
      )}

      {/* MODAL: OPEN REGISTER */}
      {isOpenRegisterOpen && (
        <div
          role="dialog"
          aria-modal="true"
          aria-labelledby="open-reg-title"
          style={{
            position: 'fixed',
            inset: 0,
            backgroundColor: 'rgba(0,0,0,0.5)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 1000,
            padding: 'var(--space-md)',
          }}
        >
          <div
            className="panel-card"
            style={{
              width: '100%',
              maxWidth: 420,
              backgroundColor: 'var(--color-surface)',
              borderRadius: 'var(--radius-lg)',
              padding: 'var(--space-lg)',
              border: '1px solid var(--color-border)',
            }}
          >
            <h3 id="open-reg-title" style={{ fontSize: '1.2rem', fontWeight: 600, marginBottom: 'var(--space-sm)' }}>
              Open Today's Cash Register
            </h3>
            <p className="cell-muted" style={{ fontSize: '0.85rem', marginBottom: 'var(--space-md)' }}>
              Count and enter initial float cash in drawer to start today's counter billing.
            </p>
            <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
              Opening Cash Balance (₹)
            </label>
            <input
              style={{
                width: '100%',
                padding: '8px 12px',
                borderRadius: 'var(--radius-md)',
                border: '1px solid var(--color-border)',
                fontSize: '1.1rem',
                fontWeight: 600,
                marginBottom: 'var(--space-md)',
              }}
              onChange={(e) => setOpeningCashInput(e.target.value)}
              type="number"
              value={openingCashInput}
            />
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 'var(--space-sm)' }}>
              <Button onClick={() => setIsOpenRegisterOpen(false)} variant="secondary">
                Cancel
              </Button>
              <Button
                disabled={openRegisterMutation.isPending}
                onClick={() =>
                  openRegisterMutation.mutate({
                    amount: Number(openingCashInput || 0),
                  })
                }
                variant="primary"
              >
                {openRegisterMutation.isPending ? 'Opening...' : 'Open Register'}
              </Button>
            </div>
          </div>
        </div>
      )}

      {/* MODAL: CASH EXPENSE / PAYOUT */}
      {isExpenseOpen && (
        <div
          role="dialog"
          aria-modal="true"
          aria-labelledby="payout-title"
          style={{
            position: 'fixed',
            inset: 0,
            backgroundColor: 'rgba(0,0,0,0.5)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 1000,
            padding: 'var(--space-md)',
          }}
        >
          <div
            className="panel-card"
            style={{
              width: '100%',
              maxWidth: 420,
              backgroundColor: 'var(--color-surface)',
              borderRadius: 'var(--radius-lg)',
              padding: 'var(--space-lg)',
              border: '1px solid var(--color-border)',
            }}
          >
            <h3 id="payout-title" style={{ fontSize: '1.2rem', fontWeight: 600, marginBottom: 'var(--space-sm)' }}>
              Record Cash Payout
            </h3>
            <p className="cell-muted" style={{ fontSize: '0.85rem', marginBottom: 'var(--space-md)' }}>
              Deduct petty cash expense directly from drawer (e.g. courier, tea, supplies).
            </p>
            <div style={{ marginBottom: 'var(--space-sm)' }}>
              <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                Payout Amount (₹)
              </label>
              <input
                style={{
                  width: '100%',
                  padding: '8px 12px',
                  borderRadius: 'var(--radius-md)',
                  border: '1px solid var(--color-border)',
                  fontWeight: 600,
                }}
                onChange={(e) => setExpenseAmount(e.target.value)}
                placeholder="50.00"
                type="number"
                value={expenseAmount}
              />
            </div>
            <div style={{ marginBottom: 'var(--space-md)' }}>
              <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                Reason / Description
              </label>
              <input
                style={{
                  width: '100%',
                  padding: '8px 12px',
                  borderRadius: 'var(--radius-md)',
                  border: '1px solid var(--color-border)',
                }}
                onChange={(e) => setExpenseReason(e.target.value)}
                placeholder="e.g. Courier dispatch fee"
                type="text"
                value={expenseReason}
              />
            </div>
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 'var(--space-sm)' }}>
              <Button onClick={() => setIsExpenseOpen(false)} variant="secondary">
                Cancel
              </Button>
              <Button
                disabled={!expenseAmount || !expenseReason || addExpenseMutation.isPending}
                onClick={() =>
                  addExpenseMutation.mutate({
                    amount: Number(expenseAmount),
                    description: expenseReason,
                  })
                }
                variant="primary"
              >
                {addExpenseMutation.isPending ? 'Recording...' : 'Record Payout'}
              </Button>
            </div>
          </div>
        </div>
      )}

      {/* MODAL: CLOSE REGISTER */}
      {isCloseRegisterOpen && (
        <div
          role="dialog"
          aria-modal="true"
          aria-labelledby="close-reg-title"
          style={{
            position: 'fixed',
            inset: 0,
            backgroundColor: 'rgba(0,0,0,0.5)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 1000,
            padding: 'var(--space-md)',
          }}
        >
          <div
            className="panel-card"
            style={{
              width: '100%',
              maxWidth: 440,
              backgroundColor: 'var(--color-surface)',
              borderRadius: 'var(--radius-lg)',
              padding: 'var(--space-lg)',
              border: '1px solid var(--color-border)',
            }}
          >
            <h3 id="close-reg-title" style={{ fontSize: '1.2rem', fontWeight: 600, marginBottom: 'var(--space-sm)' }}>
              Close Day Cash Register
            </h3>
            <p className="cell-muted" style={{ fontSize: '0.85rem', marginBottom: 'var(--space-sm)' }}>
              Expected drawer cash balance is{' '}
              <strong><Money amount={register?.expectedClosing || 0} /></strong>.
            </p>
            <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
              Actual Cash Counted (₹)
            </label>
            <input
              style={{
                width: '100%',
                padding: '8px 12px',
                borderRadius: 'var(--radius-md)',
                border: '1px solid var(--color-border)',
                fontSize: '1.1rem',
                fontWeight: 600,
                marginBottom: 'var(--space-md)',
              }}
              onChange={(e) => setClosingCashInput(e.target.value)}
              placeholder="Counted cash"
              type="number"
              value={closingCashInput}
            />
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 'var(--space-sm)' }}>
              <Button onClick={() => setIsCloseRegisterOpen(false)} variant="secondary">
                Cancel
              </Button>
              <Button
                disabled={!closingCashInput || closeRegisterMutation.isPending}
                onClick={() =>
                  closeRegisterMutation.mutate({
                    actual: Number(closingCashInput),
                  })
                }
                variant="primary"
              >
                {closeRegisterMutation.isPending ? 'Closing...' : 'Confirm Day Close'}
              </Button>
            </div>
          </div>
        </div>
      )}
    </section>
  )
}
