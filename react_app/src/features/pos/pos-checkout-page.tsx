import { useEffect, useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  Banknote,
  BadgePercent,
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
  UserRound,
  UserPlus,
  WalletCards,
} from 'lucide-react'
import { Link } from 'react-router-dom'
import { Button } from '@/design-system/button'
import { EntityPicker } from '@/design-system/entity-picker'
import { FormField } from '@/design-system/form-field'
import { Modal } from '@/design-system/modal'
import { Money } from '@/design-system/money'
import { NumberInput } from '@/design-system/number-input'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { TextAreaInput } from '@/design-system/textarea-input'
import { TextInput } from '@/design-system/text-input'
import { createContact, listContacts, type Contact } from '@/features/contacts/contacts-api'
import { BatchAllocationPicker } from '@/features/inventory/batch-allocation-picker'
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
  taxGroupId?: string | null
  hsnCode: string | null
  batchId: string | null
  batchNumber: string | null
  trackBatches: boolean
  rackLocationCode: string | null
  discountPct: number
}

function effectiveRate(item: CartItem): number {
  return Math.round(item.rate * (1 - item.discountPct / 100) * 10_000) / 10_000
}

function lineTotal(item: CartItem): number {
  return Math.round(effectiveRate(item) * item.quantity * 100) / 100
}

function lineDiscount(item: CartItem): number {
  return Math.round((item.rate * item.quantity - lineTotal(item)) * 100) / 100
}

async function searchCustomers(query: string): Promise<Contact[]> {
  const page = await listContacts({
    filter: 'CUSTOMER',
    page: 0,
    search: query,
    size: 20,
  })
  return page.content
}

function describeCustomer(contact: Contact): string | undefined {
  const details = [contact.companyName, contact.phone || contact.mobile, contact.gstin].filter(Boolean)
  return details.length > 0 ? details.join(' | ') : undefined
}

function getErrorMessage(error: unknown): string | null {
  return error instanceof Error ? error.message : null
}

export function PosCheckoutPage() {
  const queryClient = useQueryClient()
  const [itemQuery, setItemQuery] = useState('')
  const [cart, setCart] = useState<CartItem[]>([])
  const [selectedContactId, setSelectedContactId] = useState('')
  const [selectedContact, setSelectedContact] = useState<Contact | null>(null)
  const [paymentMode, setPaymentMode] = useState<'CASH' | 'UPI' | 'CARD' | 'CREDIT'>('CASH')
  const [tenderedAmount, setTenderedAmount] = useState('')
  const [upiRef, setUpiRef] = useState('')
  const [receiptNotes, setReceiptNotes] = useState('')
  const [lastReceipt, setLastReceipt] = useState<SalesReceipt | null>(null)
  const [isOpenRegisterOpen, setIsOpenRegisterOpen] = useState(false)
  const [openingCashInput, setOpeningCashInput] = useState('1000')
  const [isCloseRegisterOpen, setIsCloseRegisterOpen] = useState(false)
  const [closingCashInput, setClosingCashInput] = useState('')
  const [isExpenseOpen, setIsExpenseOpen] = useState(false)
  const [expenseAmount, setExpenseAmount] = useState('')
  const [expenseReason, setExpenseReason] = useState('')
  const [isQuickCustomerOpen, setIsQuickCustomerOpen] = useState(false)
  const [newCustomerName, setNewCustomerName] = useState('')
  const [newCustomerPhone, setNewCustomerPhone] = useState('')
  const [isCartDiscountOpen, setIsCartDiscountOpen] = useState(false)
  const [cartDiscountInput, setCartDiscountInput] = useState('')

  const registerQuery = useQuery({
    queryKey: ['pos-today-register'],
    queryFn: getTodayRegister,
  })
  const itemSearchQuery = useQuery({
    queryKey: ['pos-search-items', itemQuery],
    queryFn: () => searchPosItems(itemQuery, 12),
    enabled: itemQuery.trim().length >= 1,
  })

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
  const createCustomerMutation = useMutation({
    mutationFn: () => createContact({
      contactType: 'CUSTOMER',
      displayName: newCustomerName.trim(),
      phone: newCustomerPhone.trim() || undefined,
    }),
    onSuccess: (customer) => {
      setSelectedContact(customer)
      setSelectedContactId(customer.id)
      setIsQuickCustomerOpen(false)
      setNewCustomerName('')
      setNewCustomerPhone('')
    },
  })
  const saleCheckoutMutation = useMutation({
    mutationFn: (request: CreateSalesReceiptRequest) => createSalesReceipt(request),
    onSuccess: (receipt) => {
      setLastReceipt(receipt)
      setCart([])
      setTenderedAmount('')
      setUpiRef('')
      setReceiptNotes('')
      queryClient.invalidateQueries({ queryKey: ['pos-today-register'] })
    },
  })

  const register = registerQuery.data
  const searchResults = itemSearchQuery.data ?? []
  const cartValue = useMemo(
    () => cart.reduce((sum, item) => sum + lineTotal(item), 0),
    [cart]
  )
  const discountValue = useMemo(
    () => cart.reduce((sum, item) => sum + lineDiscount(item), 0),
    [cart]
  )
  const lineCount = useMemo(
    () => cart.reduce((sum, item) => sum + item.quantity, 0),
    [cart]
  )
  const changeDue = useMemo(() => Math.max(0, Number(tenderedAmount || 0) - cartValue), [cartValue, tenderedAmount])
  const isRegisterOpen = register?.status === 'OPEN'

  useEffect(() => {
    if (paymentMode === 'CASH' && cartValue > 0 && !tenderedAmount) {
      setTenderedAmount(String(Math.ceil(cartValue)))
    }
  }, [cartValue, paymentMode, tenderedAmount])

  const addToCart = (product: PosSearchResult) => {
    setCart((currentCart) => {
      const existingItem = currentCart.find((item) => item.itemId === product.id)
      if (existingItem) {
        return currentCart.map((item) =>
          item.itemId === product.id ? { ...item, quantity: item.quantity + 1 } : item
        )
      }

      return [...currentCart, {
        id: `${product.id}-${Date.now()}`,
        itemId: product.id,
        name: product.name,
        sku: product.sku,
        rate: product.rate,
        mrp: product.mrp,
        quantity: 1,
        unit: product.unit || 'pcs',
        taxGroupId: product.taxGroupId,
        hsnCode: product.hsnCode,
        batchId: product.batchId,
        batchNumber: product.batchNumber,
        trackBatches: product.trackBatches,
        rackLocationCode: product.rackLocationCode,
        discountPct: 0,
      }]
    })
    setItemQuery('')
  }

  const updateQuantity = (id: string, delta: number) => {
    setCart((currentCart) => currentCart.map((item) =>
      item.id === id ? { ...item, quantity: Math.max(1, item.quantity + delta) } : item
    ))
  }

  const updateDiscount = (id: string, value: number) => {
    const discountPct = Math.min(100, Math.max(0, Number.isFinite(value) ? value : 0))
    setCart((currentCart) => currentCart.map((item) =>
      item.id === id ? { ...item, discountPct } : item
    ))
  }

  const openQuickCustomer = (name = '') => {
    setNewCustomerName(name)
    setNewCustomerPhone('')
    setIsQuickCustomerOpen(true)
  }

  const applyCartDiscount = () => {
    const discountPct = Math.min(100, Math.max(0, Number(cartDiscountInput) || 0))
    setCart((currentCart) => currentCart.map((item) => ({ ...item, discountPct })))
    setIsCartDiscountOpen(false)
  }

  const handleCheckout = () => {
    if (cart.length === 0) return
    const receiptDate = new Date().toISOString().split('T')[0] || ''
    saleCheckoutMutation.mutate({
      contactId: selectedContactId || undefined,
      receiptDate,
      paymentMode,
      amountReceived: paymentMode === 'CASH' ? Number(tenderedAmount || cartValue) : cartValue,
      upiReference: upiRef.trim() || undefined,
      notes: receiptNotes.trim() || undefined,
      gstInvoice: true,
      lines: cart.map((item) => ({
        itemId: item.itemId,
        quantity: item.quantity,
        rate: effectiveRate(item),
        unit: item.unit || undefined,
        taxGroupId: item.taxGroupId || undefined,
        hsnCode: item.hsnCode || undefined,
        batchId: item.batchId || undefined,
        taxInclusive: true,
      })),
    })
  }

  return (
    <section className="workspace-page pos-counter">
      <PageHeader
        eyebrow="Retail POS"
        title="Counter checkout"
        description="Scan products, settle payment, and keep the day's drawer in balance."
        actions={
          <Link className="button button--secondary" to="/sales-receipts">
            <Receipt aria-hidden="true" size={16} />
            Receipts
          </Link>
        }
      />

      <section aria-label="Today's cash register" className="pos-register-strip">
        <div className="pos-register-strip__identity">
          <span className="pos-register-strip__icon" aria-hidden="true"><WalletCards size={18} /></span>
          <div>
            <div className="pos-register-strip__title-row">
              <strong>Today&apos;s register</strong>
              <StatusChip status={isRegisterOpen ? 'Register Open' : 'Register Closed'} />
            </div>
            <span>{isRegisterOpen ? 'Counter is ready to take sales' : 'Open a shift before billing begins'}</span>
          </div>
        </div>
        <div className="pos-register-strip__metrics">
          <div className="pos-register-metric">
            <span>Expected drawer</span>
            <strong><Money amount={register?.expectedClosing || register?.openingBalance || 0} /></strong>
          </div>
          <div className="pos-register-metric">
            <span>Sales today</span>
            <strong><Money amount={register?.totalSales || 0} /></strong>
            <small>{register?.transactionCount || 0} transactions</small>
          </div>
        </div>
        <div className="pos-register-strip__actions">
          {!isRegisterOpen ? (
            <Button onClick={() => setIsOpenRegisterOpen(true)}><Unlock aria-hidden="true" size={16} />Open shift</Button>
          ) : (
            <>
              <Button onClick={() => setIsExpenseOpen(true)} variant="secondary"><Minus aria-hidden="true" size={16} />Cash payout</Button>
              <Button onClick={() => setIsCloseRegisterOpen(true)} variant="secondary"><Lock aria-hidden="true" size={16} />Close shift</Button>
            </>
          )}
        </div>
      </section>

      <div className="pos-workspace">
        <section aria-labelledby="pos-catalog-title" className="panel-card pos-catalog">
          <header className="pos-panel-header">
            <div>
              <h2 id="pos-catalog-title">Products</h2>
              <p>Search by product, SKU, or barcode and add to the current sale.</p>
            </div>
            {cart.length > 0 && (
              <Button className="pos-clear-cart" onClick={() => setCart([])} variant="ghost">
                <RotateCcw aria-hidden="true" size={15} />Clear sale
              </Button>
            )}
          </header>

          <div className="pos-product-search">
            <Search aria-hidden="true" size={19} />
            <input
              aria-label="Search or scan a product"
              autoFocus
              onChange={(event) => setItemQuery(event.target.value)}
              placeholder="Scan barcode or search products"
              type="search"
              value={itemQuery}
            />
            <kbd>F2</kbd>
          </div>

          {itemQuery.trim().length >= 1 && (
            <div aria-live="polite" className="pos-product-results">
              {itemSearchQuery.isLoading ? (
                <p className="pos-product-results__state">Searching products...</p>
              ) : itemSearchQuery.isError ? (
                <p className="pos-product-results__state pos-product-results__state--error">
                  {getErrorMessage(itemSearchQuery.error) || 'Products could not be loaded.'}
                </p>
              ) : searchResults.length === 0 ? (
                <p className="pos-product-results__state">No products match &quot;{itemQuery}&quot;.</p>
              ) : searchResults.map((product) => (
                <button className="pos-product-result" key={product.id} onClick={() => addToCart(product)} type="button">
                  <span className="pos-product-result__copy">
                    <strong>{product.name}</strong>
                    <span>{[product.sku, product.rackLocationCode && `Rack ${product.rackLocationCode}`, product.batchNumber && `Batch ${product.batchNumber}`].filter(Boolean).join(' / ')}</span>
                  </span>
                  <span className="pos-product-result__pricing">
                    <strong><Money amount={product.rate} /></strong>
                    <span>Stock {product.currentStock || 0} {product.unit || 'PCS'}</span>
                  </span>
                  <span className="pos-product-result__add">Add</span>
                </button>
              ))}
            </div>
          )}

          <section aria-labelledby="pos-cart-title" className="pos-cart">
            <header className="pos-cart__header">
              <div>
                <h2 id="pos-cart-title">Current sale</h2>
                <span>{lineCount} {lineCount === 1 ? 'item' : 'items'}</span>
              </div>
              {cart.length > 0 && (
                <div className="pos-cart__header-actions">
                  <Button
                    className="pos-cart__discount-all"
                    onClick={() => {
                      setCartDiscountInput('')
                      setIsCartDiscountOpen(true)
                    }}
                    variant="ghost"
                  >
                    <BadgePercent aria-hidden="true" size={15} />Discount
                  </Button>
                  <Money amount={cartValue} />
                </div>
              )}
            </header>
            {cart.length === 0 ? (
              <div className="pos-cart-empty">
                <span className="pos-cart-empty__icon" aria-hidden="true"><ShoppingBag size={24} /></span>
                <strong>Your sale is empty</strong>
                <p>Start with a barcode scan or product search.</p>
              </div>
            ) : (
              <div aria-label="Current cart items" className="pos-cart-list" role="list">
                {cart.map((item) => (
                  <article className="pos-cart-row" key={item.id} role="listitem">
                    <div className="pos-cart-row__copy">
                      <strong>{item.name}</strong>
                      <span>{[item.sku, item.rackLocationCode && `Rack ${item.rackLocationCode}`, item.batchNumber && `Batch ${item.batchNumber}`].filter(Boolean).join(' / ')}</span>
                      {item.trackBatches && <BatchAllocationPicker itemId={item.itemId} value={item.batchId} quantity={item.quantity} automatic disabled={saleCheckoutMutation.isPending} onChange={(batchId, batch) => setCart((current) => current.map((line) => line.id === item.id ? { ...line, batchId: batchId ?? null, batchNumber: batch?.batchNumber ?? null } : line))} />}
                    </div>
                    <div className="pos-cart-row__unit-price"><span>Rate</span><Money amount={item.rate} /></div>
                    <div className="pos-cart-row__discount">
                      <span>Disc.</span>
                      <NumberInput
                        aria-label={`${item.name} discount percentage`}
                        max="100"
                        min="0"
                        onChange={(event) => updateDiscount(item.id, Number(event.target.value))}
                        step="0.1"
                        unitSuffix="%"
                        value={item.discountPct}
                      />
                    </div>
                    <div aria-label={`${item.name} quantity`} className="pos-quantity-stepper">
                      <button aria-label={`Decrease ${item.name} quantity`} onClick={() => updateQuantity(item.id, -1)} type="button"><Minus aria-hidden="true" size={14} /></button>
                      <span>{item.quantity}</span>
                      <button aria-label={`Increase ${item.name} quantity`} onClick={() => updateQuantity(item.id, 1)} type="button"><Plus aria-hidden="true" size={14} /></button>
                    </div>
                    <strong className="pos-cart-row__total"><Money amount={lineTotal(item)} /></strong>
                    <button
                      aria-label={`Remove ${item.name} from sale`}
                      className="pos-cart-row__remove"
                      onClick={() => setCart((currentCart) => currentCart.filter((entry) => entry.id !== item.id))}
                      type="button"
                    ><Trash2 aria-hidden="true" size={15} /></button>
                  </article>
                ))}
              </div>
            )}
          </section>
        </section>

        <aside aria-labelledby="pos-checkout-title" className="panel-card pos-checkout">
          <header className="pos-panel-header">
            <div>
              <h2 id="pos-checkout-title">Checkout</h2>
              <p>Assign a customer and settle this sale.</p>
            </div>
          </header>
          <FormField label="Customer">
            <div className="pos-customer-picker">
              <EntityPicker<Contact>
                ariaLabel="Search customers"
                getOptionDescription={describeCustomer}
                getOptionId={(customer) => customer.id}
                getOptionLabel={(customer) => customer.displayName}
                onChange={(id, customer) => {
                  setSelectedContactId(id || '')
                  setSelectedContact(customer || null)
                }}
                onSearch={searchCustomers}
                placeholder="Search customer or account"
                renderEmpty={(query) => (
                  <div className="entity-picker__empty entity-picker__empty--action">
                    <span>{query ? `No customer found for "${query}".` : 'No matching customers found.'}</span>
                    <button onClick={() => openQuickCustomer(query)} type="button">
                      <UserPlus aria-hidden="true" size={14} />Add customer
                    </button>
                  </div>
                )}
                selectedEntity={selectedContact}
                value={selectedContactId || null}
              />
              <Button aria-label="Add a new customer" className="pos-new-customer" onClick={() => openQuickCustomer()} title="Add new customer" variant="secondary">
                <UserPlus aria-hidden="true" size={16} />
              </Button>
            </div>
          </FormField>

          <section aria-label="Payment method" className="pos-payment-methods">
            <span className="pos-section-label">Payment method</span>
            <div className="pos-payment-methods__grid">
              <button aria-pressed={paymentMode === 'CASH'} className={paymentMode === 'CASH' ? 'pos-payment-method pos-payment-method--active' : 'pos-payment-method'} onClick={() => setPaymentMode('CASH')} type="button"><Banknote aria-hidden="true" size={18} />Cash</button>
              <button aria-pressed={paymentMode === 'UPI'} className={paymentMode === 'UPI' ? 'pos-payment-method pos-payment-method--active' : 'pos-payment-method'} onClick={() => setPaymentMode('UPI')} type="button"><QrCode aria-hidden="true" size={18} />UPI / QR</button>
              <button aria-pressed={paymentMode === 'CARD'} className={paymentMode === 'CARD' ? 'pos-payment-method pos-payment-method--active' : 'pos-payment-method'} onClick={() => setPaymentMode('CARD')} type="button"><CreditCard aria-hidden="true" size={18} />Card</button>
              <button aria-pressed={paymentMode === 'CREDIT'} className={paymentMode === 'CREDIT' ? 'pos-payment-method pos-payment-method--active' : 'pos-payment-method'} onClick={() => setPaymentMode('CREDIT')} type="button"><UserRound aria-hidden="true" size={18} />Customer ledger</button>
            </div>
          </section>

          {paymentMode === 'CASH' && (
            <section className="pos-tender-card">
              <FormField label="Cash tendered" htmlFor="pos-cash-tendered">
                <NumberInput currencyPrefix id="pos-cash-tendered" min="0" onChange={(event) => setTenderedAmount(event.target.value)} placeholder="0.00" step="0.01" value={tenderedAmount} />
              </FormField>
              <div aria-label="Quick cash amounts" className="pos-quick-amounts">
                {[100, 200, 500, 2000].map((amount) => <button key={amount} onClick={() => setTenderedAmount(String(amount))} type="button">₹{amount}</button>)}
                <button onClick={() => setTenderedAmount(String(Math.ceil(cartValue)))} type="button">Exact</button>
              </div>
              <div className="pos-tender-card__change"><span>Change due</span><strong><Money amount={changeDue} /></strong></div>
            </section>
          )}
          {paymentMode === 'UPI' && (
            <FormField label="UPI reference" optional hint="Record the UTR when it is available.">
              <TextInput onChange={(event) => setUpiRef(event.target.value)} placeholder="e.g. 423985729103" value={upiRef} />
            </FormField>
          )}
          <FormField label="Sale note" optional>
            <TextAreaInput onChange={(event) => setReceiptNotes(event.target.value)} placeholder="Optional note for this receipt" rows={2} value={receiptNotes} />
          </FormField>
          <section aria-label="Checkout summary" className="pos-summary">
            <div className="pos-summary__row"><span>Cart value</span><strong><Money amount={cartValue} /></strong></div>
            {discountValue > 0 && <div className="pos-summary__row pos-summary__row--discount"><span>Discount</span><strong><Money amount={-discountValue} /></strong></div>}
            <p>Applicable tax is calculated and confirmed by the tax engine when the receipt is posted.</p>
            <div className="pos-summary__total"><span>Amount to collect</span><strong><Money amount={cartValue} /></strong></div>
          </section>
          {saleCheckoutMutation.isError && (
            <p className="pos-checkout-error" role="alert">{getErrorMessage(saleCheckoutMutation.error) || 'The sale could not be completed. Please try again.'}</p>
          )}
          <Button className="pos-complete-sale" disabled={cart.length === 0} loading={saleCheckoutMutation.isPending} onClick={handleCheckout}>
            <CheckCircle2 aria-hidden="true" size={18} />Complete sale
          </Button>
        </aside>
      </div>

      <Modal
        footer={<><Button onClick={() => setLastReceipt(null)}>New sale</Button>{lastReceipt && <Link className="button button--secondary" to={`/sales-receipts/${lastReceipt.id}`}>View receipt</Link>}</>}
        isOpen={Boolean(lastReceipt)}
        onClose={() => setLastReceipt(null)}
        size="sm"
        title="Sale completed"
      >
        {lastReceipt && (
          <div className="pos-receipt-success">
            <span className="pos-receipt-success__icon" aria-hidden="true"><CheckCircle2 size={28} /></span>
            <div><strong>{lastReceipt.receiptNumber}</strong><span>{lastReceipt.paymentMode} payment</span></div>
            <div className="pos-receipt-success__facts">
              <div><span>Subtotal</span><Money amount={lastReceipt.subtotal} /></div>
              <div><span>Tax</span><Money amount={lastReceipt.taxAmount} /></div>
              <div className="pos-receipt-success__total"><span>Receipt total</span><Money amount={lastReceipt.total} /></div>
              {lastReceipt.changeReturned > 0 && <div className="pos-receipt-success__change"><span>Change returned</span><Money amount={lastReceipt.changeReturned} /></div>}
            </div>
          </div>
        )}
      </Modal>

      <Modal
        error={getErrorMessage(createCustomerMutation.error)}
        footer={<><Button onClick={() => setIsQuickCustomerOpen(false)} variant="secondary">Cancel</Button><Button disabled={!newCustomerName.trim()} loading={createCustomerMutation.isPending} onClick={() => createCustomerMutation.mutate()}>Save and select</Button></>}
        isOpen={isQuickCustomerOpen}
        onClose={() => setIsQuickCustomerOpen(false)}
        size="sm"
        title="New customer"
        description="Add the minimum details now; complete the profile later from Contacts."
      >
        <FormField label="Customer name" required><TextInput autoComplete="name" onChange={(event) => setNewCustomerName(event.target.value)} placeholder="e.g. Ravi Kumar" value={newCustomerName} /></FormField>
        <FormField label="Phone" optional><TextInput autoComplete="tel" inputMode="tel" onChange={(event) => setNewCustomerPhone(event.target.value)} placeholder="e.g. 9876543210" value={newCustomerPhone} /></FormField>
      </Modal>

      <Modal
        footer={<><Button onClick={() => setIsCartDiscountOpen(false)} variant="secondary">Cancel</Button><Button onClick={applyCartDiscount}>Apply to all items</Button></>}
        isOpen={isCartDiscountOpen}
        onClose={() => setIsCartDiscountOpen(false)}
        size="sm"
        title="Cart discount"
        description="Apply the same discount percentage to every current line."
      >
        <FormField label="Discount percentage"><NumberInput max="100" min="0" onChange={(event) => setCartDiscountInput(event.target.value)} placeholder="0" step="0.1" unitSuffix="%" value={cartDiscountInput} /></FormField>
      </Modal>

      <Modal
        error={getErrorMessage(openRegisterMutation.error)}
        footer={<><Button onClick={() => setIsOpenRegisterOpen(false)} variant="secondary">Cancel</Button><Button loading={openRegisterMutation.isPending} onClick={() => openRegisterMutation.mutate({ amount: Number(openingCashInput || 0) })}>Open shift</Button></>}
        isOpen={isOpenRegisterOpen}
        onClose={() => setIsOpenRegisterOpen(false)}
        size="sm"
        title="Open today's register"
        description="Count the float in the drawer before you begin counter billing."
      >
        <FormField label="Opening cash balance"><NumberInput currencyPrefix min="0" onChange={(event) => setOpeningCashInput(event.target.value)} step="0.01" value={openingCashInput} /></FormField>
      </Modal>

      <Modal
        error={getErrorMessage(addExpenseMutation.error)}
        footer={<><Button onClick={() => setIsExpenseOpen(false)} variant="secondary">Cancel</Button><Button disabled={!expenseAmount || !expenseReason} loading={addExpenseMutation.isPending} onClick={() => addExpenseMutation.mutate({ amount: Number(expenseAmount), description: expenseReason })}>Record payout</Button></>}
        isOpen={isExpenseOpen}
        onClose={() => setIsExpenseOpen(false)}
        size="sm"
        title="Record cash payout"
        description="Deduct a counter expense such as a courier charge, tea, or supplies from the drawer."
      >
        <FormField label="Payout amount"><NumberInput currencyPrefix min="0" onChange={(event) => setExpenseAmount(event.target.value)} placeholder="0.00" step="0.01" value={expenseAmount} /></FormField>
        <FormField label="Reason"><TextInput onChange={(event) => setExpenseReason(event.target.value)} placeholder="e.g. Courier dispatch fee" value={expenseReason} /></FormField>
      </Modal>

      <Modal
        error={getErrorMessage(closeRegisterMutation.error)}
        footer={<><Button onClick={() => setIsCloseRegisterOpen(false)} variant="secondary">Cancel</Button><Button disabled={!closingCashInput} loading={closeRegisterMutation.isPending} onClick={() => closeRegisterMutation.mutate({ actual: Number(closingCashInput) })}>Confirm close</Button></>}
        isOpen={isCloseRegisterOpen}
        onClose={() => setIsCloseRegisterOpen(false)}
        size="sm"
        title="Close today's register"
        description={`Expected drawer balance: ${register?.expectedClosing || 0}.`}
      >
        <FormField label="Actual cash counted"><NumberInput currencyPrefix min="0" onChange={(event) => setClosingCashInput(event.target.value)} placeholder="0.00" step="0.01" value={closingCashInput} /></FormField>
      </Modal>
    </section>
  )
}
