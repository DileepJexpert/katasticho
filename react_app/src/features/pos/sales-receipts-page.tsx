import { useMemo, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import {
  DollarSign,
  FileText,
  Receipt,
  Search,
  Share2,
  ShoppingBag,
} from 'lucide-react'
import { Link } from 'react-router-dom'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import {
  getReceiptWhatsAppLink,
  listSalesReceipts,
  type SalesReceipt,
} from '@/features/pos/pos-api'

export function SalesReceiptsPage() {
  const [searchTerm, setSearchTerm] = useState('')
  const [paymentModeFilter, setPaymentModeFilter] = useState<string>('all')
  const [dateFrom, setDateFrom] = useState('')
  const [dateTo, setDateTo] = useState('')

  const query = useQuery({
    queryKey: ['sales-receipts-list', paymentModeFilter, dateFrom, dateTo],
    queryFn: () =>
      listSalesReceipts(
        0,
        150,
        paymentModeFilter === 'all' ? undefined : paymentModeFilter,
        dateFrom || undefined,
        dateTo || undefined
      ),
  })

  const receipts: SalesReceipt[] = query.data?.content ?? []

  const filtered = useMemo(() => {
    const term = searchTerm.trim().toLowerCase()
    if (!term) return receipts
    return receipts.filter(
      (r: SalesReceipt) =>
        r.receiptNumber.toLowerCase().includes(term) ||
        (r.contactName && r.contactName.toLowerCase().includes(term)) ||
        (r.offlineReceiptNumber && r.offlineReceiptNumber.toLowerCase().includes(term))
    )
  }, [receipts, searchTerm])

  const totalSales = useMemo(() => {
    return filtered.reduce((sum: number, r: SalesReceipt) => sum + Number(r.total || 0), 0)
  }, [filtered])

  const cashSales = useMemo(() => {
    return filtered
      .filter((r: SalesReceipt) => r.paymentMode === 'CASH')
      .reduce((sum: number, r: SalesReceipt) => sum + Number(r.total || 0), 0)
  }, [filtered])

  const upiSales = useMemo(() => {
    return filtered
      .filter((r: SalesReceipt) => r.paymentMode === 'UPI')
      .reduce((sum: number, r: SalesReceipt) => sum + Number(r.total || 0), 0)
  }, [filtered])

  const cardSales = useMemo(() => {
    return filtered
      .filter((r: SalesReceipt) => r.paymentMode === 'CARD')
      .reduce((sum: number, r: SalesReceipt) => sum + Number(r.total || 0), 0)
  }, [filtered])

  const handleShareWhatsApp = async (receipt: SalesReceipt) => {
    try {
      const res = await getReceiptWhatsAppLink(receipt.id)
      if (res.shareUrl) {
        window.open(res.shareUrl, '_blank')
      } else {
        const text = encodeURIComponent(
          `Receipt #${receipt.receiptNumber} from Katasticho Store. Total: ₹${receipt.total}. Thank you for shopping with us!`
        )
        window.open(`https://wa.me/?text=${text}`, '_blank')
      }
    } catch {
      const text = encodeURIComponent(
        `Receipt #${receipt.receiptNumber} from Katasticho Store. Total: ₹${receipt.total}. Thank you for shopping with us!`
      )
      window.open(`https://wa.me/?text=${text}`, '_blank')
    }
  }

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Sales & Retail Billing"
        title="POS Sales Receipts"
        description="Completed counter sales receipts, tender breakdowns, tax invoices, and sales return audit records."
        actions={
          <div style={{ display: 'flex', gap: 'var(--space-sm)' }}>
            <Link className="btn btn--secondary" to="/pos/cash-registers">
              <DollarSign aria-hidden="true" size={14} style={{ marginRight: 6 }} />
              Cash Registers
            </Link>
            <Link className="btn btn--primary" to="/pos">
              <ShoppingBag aria-hidden="true" size={14} style={{ marginRight: 6 }} />
              Open POS Counter
            </Link>
          </div>
        }
      />

      <div className="summary-strip">
        <div className="summary-card">
          <span className="summary-card__label">Total Receipts</span>
          <strong className="summary-card__value">
            <Quantity value={filtered.length} />
          </strong>
          <span className="summary-card__hint">Completed transactions</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__label">Cash Receipts</span>
          <strong className="summary-card__value">
            <Money amount={cashSales} />
          </strong>
          <span className="summary-card__hint">Counter drawer cash</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__label">Digital / UPI</span>
          <strong className="summary-card__value">
            <Money amount={upiSales} />
          </strong>
          <span className="summary-card__hint">Direct UPI transfers</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__label">Card Payments</span>
          <strong className="summary-card__value">
            <Money amount={cardSales} />
          </strong>
          <span className="summary-card__hint">POS swipe / EDC</span>
        </div>
        <div className="summary-card summary-card--accent">
          <span className="summary-card__label">Total POS Volume</span>
          <strong className="summary-card__value">
            <Money amount={totalSales} />
          </strong>
          <span className="summary-card__hint">Gross retail revenue</span>
        </div>
      </div>

      <div
        className="list-toolbar"
        style={{ justifyContent: 'space-between', flexWrap: 'wrap', gap: 'var(--space-sm)' }}
      >
        <div style={{ display: 'flex', gap: 'var(--space-sm)', flexWrap: 'wrap', alignItems: 'center' }}>
          <div className="search-field" style={{ maxWidth: 320 }}>
            <Search aria-hidden="true" size={16} />
            <input
              aria-label="Search receipts by receipt number or customer"
              onChange={(e) => setSearchTerm(e.target.value)}
              placeholder="Search receipt # or customer..."
              type="search"
              value={searchTerm}
            />
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <span className="cell-muted" style={{ fontSize: '0.85rem' }}>
              From:
            </span>
            <input
              type="date"
              value={dateFrom}
              onChange={(e) => setDateFrom(e.target.value)}
              style={{
                padding: '4px 8px',
                borderRadius: 'var(--radius-sm)',
                border: '1px solid var(--color-border)',
              }}
            />
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <span className="cell-muted" style={{ fontSize: '0.85rem' }}>
              To:
            </span>
            <input
              type="date"
              value={dateTo}
              onChange={(e) => setDateTo(e.target.value)}
              style={{
                padding: '4px 8px',
                borderRadius: 'var(--radius-sm)',
                border: '1px solid var(--color-border)',
              }}
            />
          </div>
        </div>

        <div className="filter-chip-group">
          {['all', 'CASH', 'UPI', 'CARD', 'CREDIT'].map((mode) => (
            <button
              key={mode}
              className={`filter-chip ${paymentModeFilter === mode ? 'filter-chip--active' : ''}`}
              onClick={() => setPaymentModeFilter(mode)}
              type="button"
            >
              {mode === 'all' ? 'All Modes' : mode}
            </button>
          ))}
        </div>
      </div>

      {query.isLoading ? (
        <div aria-live="polite" className="directory-state">
          Loading sales receipts...
        </div>
      ) : query.isError ? (
        <div className="directory-state directory-state--error" role="alert">
          <FileText aria-hidden="true" size={24} />
          <strong>Unable to load receipts.</strong>
          <Button onClick={() => query.refetch()} variant="secondary">
            Retry
          </Button>
        </div>
      ) : filtered.length === 0 ? (
        <div className="directory-state">
          <Receipt aria-hidden="true" size={24} />
          <strong>No sales receipts found.</strong>
          <p>{searchTerm ? 'Try a different search keyword.' : 'Ring up items in the POS checkout counter.'}</p>
        </div>
      ) : (
        <DataTable caption="POS Sales Receipts list">
          <thead>
            <tr>
              <th scope="col">Receipt Number</th>
              <th scope="col">Date</th>
              <th scope="col">Customer</th>
              <th scope="col">Payment Mode</th>
              <th className="numeric-cell" scope="col">Subtotal</th>
              <th className="numeric-cell" scope="col">Tax</th>
              <th className="numeric-cell" scope="col">Total</th>
              <th scope="col">Status</th>
              <th className="numeric-cell" scope="col">Actions</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((receipt) => (
              <tr key={receipt.id}>
                <td>
                  <span className="table-code">
                    <Link className="table-row-link" to={`/pos/receipts/${receipt.id}`}>
                      {receipt.receiptNumber}
                    </Link>
                  </span>
                  {receipt.offlineReceiptNumber && (
                    <span className="cell-muted" style={{ display: 'block', fontSize: '0.72rem' }}>
                      Offline: {receipt.offlineReceiptNumber}
                    </span>
                  )}
                </td>
                <td>
                  <span className="cell-muted">{receipt.receiptDate}</span>
                </td>
                <td>
                  <strong>{receipt.contactName || 'Walk-in Cash Customer'}</strong>
                </td>
                <td>
                  <StatusChip status={receipt.paymentMode} />
                </td>
                <td className="numeric-cell">
                  <Money amount={receipt.subtotal} />
                </td>
                <td className="numeric-cell">
                  <Money amount={receipt.taxAmount} />
                </td>
                <td className="numeric-cell">
                  <strong>
                    <Money amount={receipt.total} />
                  </strong>
                </td>
                <td>
                  <StatusChip status={receipt.status || 'POSTED'} />
                </td>
                <td className="numeric-cell">
                  <div style={{ display: 'inline-flex', gap: 6, alignItems: 'center' }}>
                    <button
                      title="Share Receipt on WhatsApp"
                      onClick={() => handleShareWhatsApp(receipt)}
                      type="button"
                      style={{
                        background: 'none',
                        border: 'none',
                        color: 'var(--color-primary)',
                        cursor: 'pointer',
                        padding: 4,
                      }}
                    >
                      <Share2 size={15} />
                    </button>
                    <Link className="table-row-action" to={`/pos/receipts/${receipt.id}`}>
                      View
                    </Link>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      )}
    </section>
  )
}
