import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { ChevronLeft, ChevronRight, PackageCheck, Plus } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import { listStockReceipts, type StockReceipt } from '@/features/stock-receipts/stock-receipts-api'

const statusTabs = [
  { label: 'All', value: 'ALL' },
  { label: 'Draft', value: 'DRAFT' },
  { label: 'Received', value: 'RECEIVED' },
  { label: 'Cancelled', value: 'CANCELLED' },
] as const

type StatusFilter = (typeof statusTabs)[number]['value']

export function StockReceiptsPage() {
  const [selectedTab, setSelectedTab] = useState<StatusFilter>('ALL')
  const [page, setPage] = useState(0)
  const navigate = useNavigate()

  const receipts = useQuery({
    queryKey: ['stock-receipts', { page }],
    queryFn: () => listStockReceipts({ page }),
  })
  const receiptPage = receipts.data

  const filteredReceipts = (receiptPage?.content ?? []).filter((receipt) => {
    if (selectedTab === 'ALL') return true
    return receipt.status?.toUpperCase() === selectedTab
  })

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Purchases / Procurement"
        title="Stock Receipts (GRN)"
        description="Goods receipt notes, inbound shipments, batch and landed cost verification."
        actions={
          <Button onClick={() => navigate(appRoutes.stockReceiptCreate)} variant="primary">
            <Plus aria-hidden="true" size={16} />
            <span>New Stock Receipt</span>
          </Button>
        }
      />

      <section className="list-panel" aria-label="Stock receipt directory">
        <div className="list-toolbar list-toolbar--stacked">
          <div className="filter-chips" role="tablist" aria-label="Filter by receipt status">
            {statusTabs.map((tab) => {
              const count = tab.value === 'ALL'
                ? receiptPage?.content.length ?? 0
                : (receiptPage?.content ?? []).filter((r) => r.status?.toUpperCase() === tab.value).length

              return (
                <button
                  key={tab.value}
                  aria-selected={selectedTab === tab.value}
                  className={`filter-chip ${selectedTab === tab.value ? 'filter-chip--active' : ''}`}
                  onClick={() => {
                    setSelectedTab(tab.value)
                  }}
                  role="tab"
                  type="button"
                >
                  <span>{tab.label}</span>
                  {receiptPage ? <span className="filter-chip-count">{count}</span> : null}
                </button>
              )
            })}
          </div>
          <p className="list-toolbar-note">
            Goods receipts verify delivered vendor items, record landed costs, and increment warehouse stock balances upon receiving.
          </p>
        </div>

        {receipts.isError ? (
          <div className="directory-state directory-state--error" role="alert">
            <strong>Stock receipts could not be loaded.</strong>
            <p>Check your connection and permissions, then refresh the page.</p>
          </div>
        ) : receipts.isLoading ? (
          <div aria-live="polite" className="directory-state">Loading stock receipts...</div>
        ) : filteredReceipts.length ? (
          <>
            <DataTable caption="Stock receipts (GRN)">
              <thead>
                <tr>
                  <th scope="col">Receipt #</th>
                  <th scope="col">Supplier</th>
                  <th scope="col">Warehouse</th>
                  <th scope="col">Receipt date</th>
                  <th scope="col">Supplier invoice</th>
                  <th className="numeric-cell" scope="col">Total amount</th>
                  <th scope="col">Status</th>
                </tr>
              </thead>
              <tbody>
                {filteredReceipts.map((receipt) => (
                  <StockReceiptRow
                    key={receipt.id}
                    onOpen={() => navigate(appRoutes.stockReceiptDetail(receipt.id))}
                    receipt={receipt}
                  />
                ))}
              </tbody>
            </DataTable>
            <footer className="table-footer">
              <span>Showing {filteredReceipts.length} of {receiptPage?.totalElements ?? 0} receipts · Page {(receiptPage?.page ?? 0) + 1} of {Math.max(receiptPage?.totalPages ?? 1, 1)}</span>
              <div className="pagination-actions">
                <Button
                  aria-label="Previous page"
                  disabled={page === 0}
                  onClick={() => setPage((current) => Math.max(0, current - 1))}
                  variant="secondary"
                >
                  <ChevronLeft aria-hidden="true" size={16} />
                </Button>
                <Button
                  aria-label="Next page"
                  disabled={receiptPage?.last || page + 1 >= (receiptPage?.totalPages ?? 1)}
                  onClick={() => setPage((current) => current + 1)}
                  variant="secondary"
                >
                  <ChevronRight aria-hidden="true" size={16} />
                </Button>
              </div>
            </footer>
          </>
        ) : (
          <div className="directory-state">
            <PackageCheck aria-hidden="true" size={24} />
            <strong>No stock receipts found</strong>
            <p>Inbound warehouse receipts and purchase order GRNs will appear here.</p>
            <Button onClick={() => navigate(appRoutes.stockReceiptCreate)} variant="primary">
              <Plus aria-hidden="true" size={16} />
              <span>New Stock Receipt</span>
            </Button>
          </div>
        )}
      </section>
    </section>
  )
}

function StockReceiptRow({ receipt, onOpen }: { receipt: StockReceipt; onOpen: () => void }) {
  return (
    <tr>
      <td>
        <Button className="document-link" onClick={onOpen} variant="ghost">
          <code>{receipt.receiptNumber}</code>
        </Button>
      </td>
      <td>
        <div className="cell-stack">
          <strong>{receipt.supplierName}</strong>
          {receipt.supplierGstin ? <code>GSTIN: {receipt.supplierGstin}</code> : null}
        </div>
      </td>
      <td>
        <strong>{receipt.warehouseName}</strong>
      </td>
      <td>{formatDate(receipt.receiptDate)}</td>
      <td>
        {receipt.supplierInvoiceNo ? (
          <div className="cell-stack">
            <code>{receipt.supplierInvoiceNo}</code>
            {receipt.supplierInvoiceDate ? <span className="cell-muted">{formatDate(receipt.supplierInvoiceDate)}</span> : null}
          </div>
        ) : (
          <span className="cell-muted">--</span>
        )}
      </td>
      <td className="numeric-cell">
        <Money amount={receipt.totalAmount} currency={receipt.currency} />
      </td>
      <td>
        <StatusChip status={formatStatusLabel(receipt.status)} />
      </td>
    </tr>
  )
}
