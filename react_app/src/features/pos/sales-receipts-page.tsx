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
    <section className="workspace-page pos-receipts-page">
      <PageHeader
        eyebrow="Sales & Retail Billing"
        title="Sales receipts"
        description="Completed counter sales, tender details, GST receipts, and return audit records."
        actions={
          <div className="pos-receipts-page__actions">
            <Link className="button button--secondary" to="/pos/cash-registers">
              <DollarSign aria-hidden="true" size={15} />
              Cash Registers
            </Link>
            <Link className="button" to="/pos">
              <ShoppingBag aria-hidden="true" size={15} />
              Open POS Counter
            </Link>
          </div>
        }
      />

      <section aria-label="Sales receipt totals" className="pos-receipts-summary">
        <div><span>Receipts</span><strong><Quantity value={filtered.length} /></strong></div>
        <div><span>Cash</span><strong><Money amount={cashSales} /></strong></div>
        <div><span>UPI</span><strong><Money amount={upiSales} /></strong></div>
        <div><span>Card</span><strong><Money amount={cardSales} /></strong></div>
        <div className="pos-receipts-summary__total"><span>POS volume</span><strong><Money amount={totalSales} /></strong></div>
      </section>

      <section aria-label="Receipt filters" className="pos-receipts-toolbar">
        <div className="pos-receipts-toolbar__filters">
          <div className="directory-search pos-receipts-toolbar__search">
            <Search aria-hidden="true" size={16} />
            <input
              aria-label="Search receipts by receipt number or customer"
              onChange={(e) => setSearchTerm(e.target.value)}
              placeholder="Search receipt # or customer..."
              type="search"
              value={searchTerm}
            />
          </div>

          <label className="pos-receipts-date-filter">
            <span>From</span>
            <input
              type="date"
              value={dateFrom}
              onChange={(e) => setDateFrom(e.target.value)}
            />
          </label>
          <label className="pos-receipts-date-filter">
            <span>To</span>
            <input
              type="date"
              value={dateTo}
              onChange={(e) => setDateTo(e.target.value)}
            />
          </label>
        </div>

        <div aria-label="Payment mode" className="filter-chips pos-receipts-toolbar__modes">
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
      </section>

      {query.isLoading ? (
        <div aria-live="polite" className="directory-state">
          Loading sales receipts...
        </div>
      ) : query.isError ? (
        <div className="pos-receipts-error" role="alert">
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
                  <div className="pos-receipts-row-actions">
                    <button
                      aria-label={`Share ${receipt.receiptNumber} on WhatsApp`}
                      title="Share Receipt on WhatsApp"
                      onClick={() => handleShareWhatsApp(receipt)}
                      type="button"
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
