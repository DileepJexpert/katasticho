import { useState } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { Package } from 'lucide-react'
import { Button, DataTable, DirectoryToolbar, DocumentCard, EmptyState, FilterTabs, Money, PageHeader, Quantity, SearchInput, StatusChip } from '@/design-system'
import { useSessionStore } from '@/shared/session/session-store'
import { formatDate } from '@/shared/format/format'
import { getFifoValuation, getLowStockAlert, getStockSummary, getStockValuation, type FifoValuationReport } from './stock-summary-api'

type StockView = 'balances' | 'valuation' | 'fifo'

export function StockSummaryPage() {
  const client = useQueryClient()
  const role = useSessionStore((state) => state.user?.role)
  const canViewValuation = ['OWNER', 'ADMIN', 'ACCOUNTANT'].includes(role ?? '')
  const [view, setView] = useState<StockView>('balances')
  const [search, setSearch] = useState('')
  const [status, setStatus] = useState('all')
  const balances = useQuery({ queryKey: ['inventory', 'stock-summary'], queryFn: getStockSummary, enabled: canViewValuation && view === 'balances' })
  const lowStock = useQuery({ queryKey: ['inventory', 'low-stock-alert'], queryFn: getLowStockAlert, enabled: canViewValuation && view === 'balances' })
  const report = balances.data
  const rows = (report?.items ?? []).filter((item) => {
    const qty = Number(item.quantityOnHand)
    if (status === 'out' && qty > 0) return false
    if (status === 'low' && !(Number(item.reorderLevel) > 0 && qty <= Number(item.reorderLevel))) return false
    if (status === 'in' && qty <= 0) return false
    return `${item.itemName ?? ''} ${item.sku ?? ''}`.toLowerCase().includes(search.toLowerCase())
  })
  if (!canViewValuation) return <section className="workspace-page"><PageHeader title="Stock summary & valuation" description="These inventory-report APIs are restricted to owners, admins, and accountants. Item-level stock quantities remain available in the Items directory." /></section>
  return <section className="workspace-page">
    <PageHeader eyebrow="Inventory / Stock control" title="Stock summary & valuation" description="Review balances, replenishment needs, and current inventory values."
      actions={<Button variant="secondary" aria-label="Refresh stock summary data" onClick={() => void client.invalidateQueries({ queryKey: ['inventory'] })}>Refresh</Button>} />
    <FilterTabs ariaLabel="Inventory view" activeValue={view} onChange={(value) => { setView(value as StockView); setSearch(''); setStatus('all') }}
      items={[{ value: 'balances', label: 'Stock balances' }, ...(canViewValuation ? [{ value: 'valuation', label: 'Warehouse valuation' }, { value: 'fifo', label: 'FIFO cost lots' }] : [])]} />
    {view === 'balances' ? <>
      {balances.isPending ? <div className="directory-state" role="status">Loading stock balances...</div>
        : balances.isError ? <div className="directory-state directory-state--error" role="alert">{balances.error.message}<Button variant="secondary" onClick={() => void balances.refetch()}>Retry balances</Button></div>
          : report && <>
            <div className="inventory-metrics" aria-label="Stock summary metrics">
              <article><span>Purchase-price stock value</span><strong><Money amount={report.totalInventoryValue} /></strong><small>Reference value using item purchase prices</small></article>
              <article><span>Stock rows</span><strong><Quantity value={report.itemCount} /></strong><small>Report date {formatDate(report.asOfDate)}</small></article>
              <article><span>Low-stock rows</span><strong><Quantity value={report.lowStockCount} /></strong><small>As classified in the stock report</small></article>
            </div>
            <section className="list-panel">
              <DirectoryToolbar><SearchInput ariaLabel="Search by item name or SKU" value={search} onChange={setSearch} placeholder="Search item or SKU" />
                <FilterTabs ariaLabel="Stock status" activeValue={status} onChange={setStatus} items={[{ value: 'all', label: 'All' }, { value: 'low', label: 'Low stock' }, { value: 'out', label: 'Out of stock' }, { value: 'in', label: 'In stock' }]} />
              </DirectoryToolbar>
              {rows.length ? <DataTable caption="Current stock balances"><thead><tr><th scope="col">Item / SKU</th><th scope="col">Unit</th><th scope="col" className="numeric-cell">On hand</th><th scope="col" className="numeric-cell">Purchase price</th><th scope="col" className="numeric-cell">Reference value</th><th scope="col" className="numeric-cell">Reorder level</th><th scope="col">Status</th></tr></thead>
                <tbody>{rows.map((item, index) => <tr key={`${item.itemId}-${index}`}>
                  <td><div className="cell-stack"><strong>{item.itemName}</strong><code>{item.sku ?? '--'}</code></div></td><td>{item.unit ?? '--'}</td>
                  <td className="numeric-cell"><Quantity value={item.quantityOnHand} /></td><td className="numeric-cell"><Money amount={item.purchasePrice} /></td><td className="numeric-cell"><Money amount={item.inventoryValue} /></td><td className="numeric-cell"><Quantity value={item.reorderLevel} /></td>
                  <td><StatusChip status={Number(item.quantityOnHand) <= 0 ? 'Out of stock' : Number(item.reorderLevel) > 0 && Number(item.quantityOnHand) <= Number(item.reorderLevel) ? 'Low stock' : 'In stock'} /></td>
                </tr>)}</tbody></DataTable> : <EmptyState icon={Package} title="No matching stock rows" description="Adjust the filters or record a stock receipt." />}
            </section>
          </>}
      {lowStock.isError ? <div className="banner banner--error" role="alert">Replenishment advisory could not be loaded. <Button variant="ghost" onClick={() => void lowStock.refetch()}>Retry advisory</Button></div>
        : lowStock.data && lowStock.data.itemCount > 0 && <DocumentCard title="Replenishment advisory" variant="notes"><p><Quantity value={lowStock.data.itemCount} /> items need replenishment. Estimated purchase cost: <Money amount={lowStock.data.estimatedPurchaseCost} />.</p><Button variant="secondary" onClick={() => setStatus('low')}>Show low stock</Button></DocumentCard>}
    </> : canViewValuation ? <ValuationReportView key={view} view={view} /> : <p>Your role cannot access inventory valuation reports.</p>}
  </section>
}

function ValuationReportView({ view }: { view: 'valuation' | 'fifo' }) {
  const [search, setSearch] = useState('')
  const report = useQuery({ queryKey: ['inventory', view === 'fifo' ? 'fifo-valuation' : 'warehouse-valuation'], queryFn: view === 'fifo' ? getFifoValuation : getStockValuation })
  if (report.isPending) return <div className="directory-state" role="status">Loading valuation report...</div>
  if (report.isError) return <div className="directory-state directory-state--error" role="alert">{report.error.message}<Button variant="secondary" onClick={() => void report.refetch()}>Retry valuation</Button></div>
  const data = report.data
  const rows = data.rows.filter((row) => Object.values(row).some((value) => String(value ?? '').toLowerCase().includes(search.toLowerCase())))
  return <>
    <div className="inventory-metrics" aria-label="Valuation report metrics">{data.metrics.map((metric) => <article key={metric.key}><span>{metric.label}</span><strong>{metric.format === 'currency' ? <Money amount={metric.value} currency={data.currency} /> : <Quantity value={metric.value} />}</strong><small>Report date {formatDate(data.endDate)}</small></article>)}</div>
    <DocumentCard title={data.title} variant="lines">
      <p className="inventory-report-note">{view === 'fifo' ? 'Remaining cost lots valued at their receipt cost. This view does not change the organisation costing method.' : 'Warehouse stock values use the organisation costing method. Average cost is shown separately for reference.'}</p>
      <DirectoryToolbar><SearchInput ariaLabel="Search valuation rows" value={search} onChange={setSearch} placeholder="Search item, warehouse, or receipt date" /></DirectoryToolbar>
      {rows.length ? <DataTable caption={data.title}><thead><tr>{data.columns.map((column) => <th key={column.key} scope="col" className={['currency', 'number'].includes(column.type) ? 'numeric-cell' : undefined}>{column.label}</th>)}</tr></thead>
        <tbody>{rows.map((row, index) => <tr key={index}>{data.columns.map((column) => <td key={column.key} className={['currency', 'number'].includes(column.type) ? 'numeric-cell' : undefined}><ReportValue value={row[column.key]} column={column} currency={data.currency} /></td>)}</tr>)}</tbody></DataTable>
        : <EmptyState icon={Package} title={search ? 'No matching valuation rows' : view === 'fifo' ? 'No open FIFO cost lots' : 'No warehouse stock rows'} description={search ? 'Adjust your search.' : 'The report returned no rows. This does not confirm reconciliation with physical stock or the general ledger.'} />}
    </DocumentCard>
  </>
}

function ReportValue({ value, column, currency }: { value: unknown; column: FifoValuationReport['columns'][number]; currency: string }) {
  if (value === null || value === undefined) return <>--</>
  if (column.type === 'currency') return <Money amount={String(value)} currency={currency} />
  if (column.type === 'number') return <Quantity value={String(value)} />
  if (column.type === 'date') return <>{formatDate(String(value))}</>
  return column.key === 'sku' ? <code>{String(value)}</code> : <>{String(value)}</>
}
