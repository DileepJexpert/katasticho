import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import {
  FileText,
  Download,
  Search,
  Calendar,
  Layers,
  Settings,
  ShieldCheck,
  CheckCircle2,
} from 'lucide-react'
import { Link } from 'react-router-dom'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate } from '@/shared/format/format'
import {
  getTcsRegister,
  getForm27eq,
  getForm27eqCsvUrl,
  getTcsSettings,
  updateTcsSettings,
  type TcsRegisterEntry,
} from '@/features/tax/tds-tcs-api'

type TabKey = 'register' | 'form27eq' | 'settings'

export function TcsCompliancePage() {
  const queryClient = useQueryClient()
  const [activeTab, setActiveTab] = useState<TabKey>('register')
  const [feedback, setFeedback] = useState<string | null>(null)

  // Date range for register
  const today = new Date()
  const firstDay = new Date(today.getFullYear(), today.getMonth(), 1)
  const [fromDate, setFromDate] = useState(firstDay.toISOString().slice(0, 10))
  const [toDate, setToDate] = useState(today.toISOString().slice(0, 10))
  const [search, setSearch] = useState('')

  // FY & Quarter for returns
  const currentFy = today.getMonth() >= 3 ? today.getFullYear() : today.getFullYear() - 1
  const [fy, setFy] = useState(currentFy)
  const [quarter, setQuarter] = useState(Math.floor((today.getMonth() + 9) % 12 / 3) + 1)

  // Queries
  const registerQuery = useQuery({
    queryKey: ['tcs-register', fromDate, toDate],
    queryFn: () => getTcsRegister(fromDate, toDate),
    enabled: activeTab === 'register',
  })

  const form27eqQuery = useQuery({
    queryKey: ['form27eq', fy, quarter],
    queryFn: () => getForm27eq(fy, quarter),
    enabled: activeTab === 'form27eq',
  })

  const settingsQuery = useQuery({
    queryKey: ['tcs-settings'],
    queryFn: () => getTcsSettings(),
    enabled: activeTab === 'settings',
  })

  // Settings Mutation
  const updateSettingsMutation = useMutation({
    mutationFn: (data: { enabled: boolean; rate: number }) => updateTcsSettings(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['tcs-settings'] })
      setFeedback('TCS Section 206C(1H) settings updated successfully.')
    },
  })

  const registerData: TcsRegisterEntry[] = registerQuery.data ?? []
  const filteredRegister = registerData.filter((entry) => {
    if (!search.trim()) return true
    const q = search.toLowerCase()
    return (
      (entry.invoiceNumber && entry.invoiceNumber.toLowerCase().includes(q)) ||
      (entry.customerName && entry.customerName.toLowerCase().includes(q)) ||
      (entry.customerPan && entry.customerPan.toLowerCase().includes(q))
    )
  })

  const totalTcsCollected = filteredRegister.reduce((sum, r) => sum + Number(r.tcsAmount ?? 0), 0)
  const totalSalesValue = filteredRegister.reduce((sum, r) => sum + Number(r.invoiceAmount ?? 0), 0)

  const form27eqData = form27eqQuery.data
  const settingsData = settingsQuery.data

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Tax & Compliance"
        title="TCS Section 206C(1H) Compliance"
        description="Tax Collection at Source on sale of goods crossing ₹50 lakh threshold, deposit register, and Form 27EQ quarterly returns."
        actions={
          <div className="table-actions">
            <Link to="/compliance/tds">
              <Button variant="secondary">
                <FileText aria-hidden="true" size={16} />
                TDS Hub
              </Button>
            </Link>
          </div>
        }
      />

      {feedback && (
        <div className="feedback-alert feedback-alert--success" role="status">
          <CheckCircle2 size={16} />
          <span>{feedback}</span>
          <button className="feedback-alert__close" onClick={() => setFeedback(null)} type="button">×</button>
        </div>
      )}

      <div className="list-tabs" role="tablist">
        <button
          aria-selected={activeTab === 'register'}
          className={activeTab === 'register' ? 'list-tab list-tab--active' : 'list-tab'}
          onClick={() => setActiveTab('register')}
          role="tab"
          type="button"
        >
          <FileText size={15} style={{ marginRight: '6px' }} />
          TCS Collection Register
        </button>
        <button
          aria-selected={activeTab === 'form27eq'}
          className={activeTab === 'form27eq' ? 'list-tab list-tab--active' : 'list-tab'}
          onClick={() => setActiveTab('form27eq')}
          role="tab"
          type="button"
        >
          <Layers size={15} style={{ marginRight: '6px' }} />
          Form 27EQ (Quarterly Returns)
        </button>
        <button
          aria-selected={activeTab === 'settings'}
          className={activeTab === 'settings' ? 'list-tab list-tab--active' : 'list-tab'}
          onClick={() => setActiveTab('settings')}
          role="tab"
          type="button"
        >
          <Settings size={15} style={{ marginRight: '6px' }} />
          TCS Configuration
        </button>
      </div>

      {activeTab === 'register' && (
        <>
          {/* Summary KPIs */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '16px', marginTop: '16px', marginBottom: '16px' }}>
            <div style={{ background: 'var(--bg-subtle)', padding: '12px 16px', borderRadius: '6px', border: '1px solid var(--border-subtle)' }}>
              <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Total TCS Collected</span>
              <div style={{ fontSize: '20px', fontWeight: 600, color: 'var(--color-primary)', marginTop: '4px' }}>
                <Money amount={totalTcsCollected} />
              </div>
            </div>
            <div style={{ background: 'var(--bg-subtle)', padding: '12px 16px', borderRadius: '6px', border: '1px solid var(--border-subtle)' }}>
              <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Total Sales Value</span>
              <div style={{ fontSize: '20px', fontWeight: 600, marginTop: '4px' }}>
                <Money amount={totalSalesValue} />
              </div>
            </div>
            <div style={{ background: 'var(--bg-subtle)', padding: '12px 16px', borderRadius: '6px', border: '1px solid var(--border-subtle)' }}>
              <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Eligible Invoices</span>
              <div style={{ fontSize: '20px', fontWeight: 600, marginTop: '4px' }}>
                {filteredRegister.length} invoices
              </div>
            </div>
          </div>

          {/* Filters */}
          <div className="list-toolbar">
            <label className="directory-search">
              <Search aria-hidden="true" size={18} />
              <span className="sr-only">Search TCS register</span>
              <input
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Search by customer, invoice #, PAN..."
                type="search"
                value={search}
              />
            </label>
            <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
              <span style={{ fontSize: '13px', color: 'var(--text-muted)' }}>From:</span>
              <input
                className="search-input"
                onChange={(e) => setFromDate(e.target.value)}
                style={{ width: '130px' }}
                type="date"
                value={fromDate}
              />
              <span style={{ fontSize: '13px', color: 'var(--text-muted)' }}>To:</span>
              <input
                className="search-input"
                onChange={(e) => setToDate(e.target.value)}
                style={{ width: '130px' }}
                type="date"
                value={toDate}
              />
            </div>
          </div>

          {registerQuery.isLoading ? (
            <div className="directory-state">Loading TCS collection register...</div>
          ) : filteredRegister.length === 0 ? (
            <div className="directory-state">
              <ShieldCheck size={24} />
              <strong>No TCS collections found in this period.</strong>
            </div>
          ) : (
            <DataTable caption="Customer TCS collections">
              <thead>
                <tr>
                  <th scope="col">Invoice #</th>
                  <th scope="col">Date</th>
                  <th scope="col">Customer</th>
                  <th scope="col">PAN</th>
                  <th className="numeric-cell" scope="col">Cumulative FY Sales</th>
                  <th className="numeric-cell" scope="col">Invoice Value</th>
                  <th className="numeric-cell" scope="col">TCS Collected (0.1%)</th>
                  <th scope="col">Status</th>
                </tr>
              </thead>
              <tbody>
                {filteredRegister.map((r, idx) => (
                  <tr key={r.invoiceId || idx}>
                    <td className="cell-id">
                      {r.invoiceId ? <Link to={`/invoices/${r.invoiceId}`}>{r.invoiceNumber || r.invoiceId.slice(0, 8)}</Link> : r.invoiceNumber || '—'}
                    </td>
                    <td>{r.invoiceDate ? formatDate(r.invoiceDate) : '—'}</td>
                    <td><strong>{r.customerName || r.customerId || 'Customer'}</strong></td>
                    <td className="font-mono">{r.customerPan || '—'}</td>
                    <td className="numeric-cell"><Money amount={r.cumulativeFySales} /></td>
                    <td className="numeric-cell"><Money amount={r.invoiceAmount} /></td>
                    <td className="numeric-cell" style={{ fontWeight: 600, color: 'var(--color-primary)' }}>
                      <Money amount={r.tcsAmount} />
                    </td>
                    <td><StatusChip status={r.challanNumber ? 'DEPOSITED' : 'COLLECTED'} /></td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          )}
        </>
      )}

      {activeTab === 'form27eq' && (
        <div style={{ marginTop: '16px', display: 'flex', flexDirection: 'column', gap: '16px' }}>
          {/* Controls */}
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', background: 'var(--bg-subtle)', padding: '12px 16px', borderRadius: '6px' }}>
            <div style={{ display: 'flex', gap: '12px', alignItems: 'center' }}>
              <Calendar size={16} />
              <span style={{ fontSize: '13px', fontWeight: 600 }}>Financial Year:</span>
              <select
                className="search-input"
                onChange={(e) => setFy(Number(e.target.value))}
                style={{ width: '130px' }}
                value={fy}
              >
                <option value={currentFy}>FY {currentFy}-{currentFy + 1 - 2000}</option>
                <option value={currentFy - 1}>FY {currentFy - 1}-{currentFy - 2000}</option>
              </select>
              <span style={{ fontSize: '13px', fontWeight: 600, marginLeft: '8px' }}>Quarter:</span>
              <select
                className="search-input"
                onChange={(e) => setQuarter(Number(e.target.value))}
                style={{ width: '100px' }}
                value={quarter}
              >
                <option value={1}>Q1 (Apr-Jun)</option>
                <option value={2}>Q2 (Jul-Sep)</option>
                <option value={3}>Q3 (Oct-Dec)</option>
                <option value={4}>Q4 (Jan-Mar)</option>
              </select>
            </div>
            <a href={getForm27eqCsvUrl(fy, quarter)} target="_blank" rel="noreferrer">
              <Button variant="secondary">
                <Download size={15} />
                Download Form 27EQ CSV
              </Button>
            </a>
          </div>

          {/* Form 27EQ Summary Cards */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '16px' }}>
            <div style={{ background: 'var(--bg-card)', padding: '14px 16px', borderRadius: '6px', border: '1px solid var(--border-subtle)' }}>
              <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Total Collectees</span>
              <div style={{ fontSize: '20px', fontWeight: 600, marginTop: '4px' }}>
                {form27eqData?.totalCollectees ?? 0}
              </div>
            </div>
            <div style={{ background: 'var(--bg-card)', padding: '14px 16px', borderRadius: '6px', border: '1px solid var(--border-subtle)' }}>
              <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Total Sales Value</span>
              <div style={{ fontSize: '20px', fontWeight: 600, marginTop: '4px' }}>
                <Money amount={form27eqData?.totalSalesValue ?? 0} />
              </div>
            </div>
            <div style={{ background: 'var(--bg-card)', padding: '14px 16px', borderRadius: '6px', border: '1px solid var(--border-subtle)' }}>
              <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>TCS Collected</span>
              <div style={{ fontSize: '20px', fontWeight: 600, color: 'var(--color-primary)', marginTop: '4px' }}>
                <Money amount={form27eqData?.totalTcsCollected ?? 0} />
              </div>
            </div>
            <div style={{ background: 'var(--bg-card)', padding: '14px 16px', borderRadius: '6px', border: '1px solid var(--border-subtle)' }}>
              <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>TCS Deposited</span>
              <div style={{ fontSize: '20px', fontWeight: 600, color: 'var(--color-success)', marginTop: '4px' }}>
                <Money amount={form27eqData?.totalTcsDeposited ?? 0} />
              </div>
            </div>
          </div>

          {/* Collectees Table */}
          {form27eqData?.collectees && form27eqData.collectees.length > 0 ? (
            <DataTable caption="Form 27EQ collectee list">
              <thead>
                <tr>
                  <th scope="col">Collectee PAN</th>
                  <th scope="col">Collectee Name</th>
                  <th scope="col">Section</th>
                  <th scope="col">Invoice Date</th>
                  <th className="numeric-cell" scope="col">Sales Value</th>
                  <th className="numeric-cell" scope="col">TCS Collected</th>
                </tr>
              </thead>
              <tbody>
                {form27eqData.collectees.map((c, i) => (
                  <tr key={i}>
                    <td className="font-mono">{c.pan}</td>
                    <td><strong>{c.name}</strong></td>
                    <td><span className="status-badge status-badge--info">{c.section}</span></td>
                    <td>{c.invoiceDate ? formatDate(c.invoiceDate) : '—'}</td>
                    <td className="numeric-cell"><Money amount={c.amount} /></td>
                    <td className="numeric-cell" style={{ fontWeight: 600, color: 'var(--color-primary)' }}>
                      <Money amount={c.tcsCollected} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          ) : (
            <div className="directory-state">
              <Layers size={24} />
              <strong>No Form 27EQ collectee records for Q{quarter} FY {fy}-{fy + 1 - 2000}.</strong>
            </div>
          )}
        </div>
      )}

      {activeTab === 'settings' && (
        <section className="document-card" style={{ maxWidth: '600px', marginTop: '16px' }}>
          <h2>TCS Section 206C(1H) Settings</h2>
          <p style={{ fontSize: '13px', color: 'var(--text-muted)', marginBottom: '16px' }}>
            When enabled, sales invoices exceeding ₹50,000,000 cumulative turnover in the financial year will automatically apply 0.1% TCS on the excess consideration.
          </p>
          <form
            onSubmit={(e) => {
              e.preventDefault()
              const fd = new FormData(e.currentTarget)
              updateSettingsMutation.mutate({
                enabled: fd.get('enabled') === 'on',
                rate: Number(fd.get('rate') || 0.001),
              })
            }}
          >
            <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer' }}>
                <input
                  defaultChecked={settingsData?.enabled ?? true}
                  name="enabled"
                  type="checkbox"
                />
                <span style={{ fontSize: '14px', fontWeight: 600 }}>Enable TCS Collection under Section 206C(1H)</span>
              </label>

              <label>
                <span style={{ fontSize: '13px', fontWeight: 600 }}>Standard TCS Rate (with PAN):</span>
                <input
                  className="search-input"
                  defaultValue={settingsData?.rate ?? 0.001}
                  name="rate"
                  step="0.0001"
                  style={{ width: '100%', marginTop: '4px' }}
                  type="number"
                />
                <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Default is 0.001 (0.1%).</span>
              </label>

              <div style={{ marginTop: '8px' }}>
                <Button disabled={updateSettingsMutation.isPending} type="submit" variant="primary">
                  Save Settings
                </Button>
              </div>
            </div>
          </form>
        </section>
      )}
    </section>
  )
}
