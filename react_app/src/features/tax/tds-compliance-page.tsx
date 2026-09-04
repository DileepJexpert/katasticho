import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import {
  FileText,
  Download,
  Search,
  Calendar,
  Layers,
  Users,
  Building,
  ShieldCheck,
} from 'lucide-react'
import { Link } from 'react-router-dom'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate } from '@/shared/format/format'
import {
  getTdsRegister,
  getForm26q,
  getForm26qCsvUrl,
  getForm26qFvuUrl,
  getForm24q,
  getForm24qCsvUrl,
  type TdsRegisterEntry,
} from '@/features/tax/tds-tcs-api'

type TabKey = 'register' | 'form26q' | 'form24q'

export function TdsCompliancePage() {
  const [activeTab, setActiveTab] = useState<TabKey>('register')

  // Date range for register
  const today = new Date()
  const firstDay = new Date(today.getFullYear(), today.getMonth(), 1)
  const [fromDate, setFromDate] = useState(firstDay.toISOString().slice(0, 10))
  const [toDate, setToDate] = useState(today.toISOString().slice(0, 10))
  const [search, setSearch] = useState('')
  const [sectionFilter, setSectionFilter] = useState('ALL')

  // FY & Quarter for returns
  const currentFy = today.getMonth() >= 3 ? today.getFullYear() : today.getFullYear() - 1
  const [fy, setFy] = useState(currentFy)
  const [quarter, setQuarter] = useState(Math.floor((today.getMonth() + 9) % 12 / 3) + 1)

  // Queries
  const registerQuery = useQuery({
    queryKey: ['tds-register', fromDate, toDate],
    queryFn: () => getTdsRegister(fromDate, toDate),
    enabled: activeTab === 'register',
  })

  const form26qQuery = useQuery({
    queryKey: ['form26q', fy, quarter],
    queryFn: () => getForm26q(fy, quarter),
    enabled: activeTab === 'form26q',
  })

  const form24qQuery = useQuery({
    queryKey: ['form24q', fy, quarter],
    queryFn: () => getForm24q(fy, quarter),
    enabled: activeTab === 'form24q',
  })

  const registerData: TdsRegisterEntry[] = registerQuery.data ?? []
  const filteredRegister = registerData.filter((entry) => {
    if (sectionFilter !== 'ALL' && entry.section !== sectionFilter) return false
    if (!search.trim()) return true
    const q = search.toLowerCase()
    return (
      (entry.billNumber && entry.billNumber.toLowerCase().includes(q)) ||
      (entry.vendorName && entry.vendorName.toLowerCase().includes(q)) ||
      (entry.vendorPan && entry.vendorPan.toLowerCase().includes(q))
    )
  })

  const totalTdsWithheld = filteredRegister.reduce((sum, r) => sum + Number(r.tdsAmount ?? 0), 0)
  const totalTaxable = filteredRegister.reduce((sum, r) => sum + Number(r.taxableAmount ?? r.billAmount ?? 0), 0)

  const form26qData = form26qQuery.data
  const form24qData = form24qQuery.data

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Tax & Compliance"
        title="TDS Compliance & Returns"
        description="Vendor withholding register (ITNS-281 deposit prep), Form 26Q quarterly vendor returns, and Form 24Q salary deductions."
        actions={
          <div className="table-actions">
            <Link to="/compliance/tcs">
              <Button variant="secondary">
                <Layers aria-hidden="true" size={16} />
                TCS 206C(1H)
              </Button>
            </Link>
            <Link to="/settings/tax-accounts">
              <Button variant="secondary">
                <Building aria-hidden="true" size={16} />
                Tax Account Mappings
              </Button>
            </Link>
          </div>
        }
      />

      <div className="list-tabs" role="tablist">
        <button
          aria-selected={activeTab === 'register'}
          className={activeTab === 'register' ? 'list-tab list-tab--active' : 'list-tab'}
          onClick={() => setActiveTab('register')}
          role="tab"
          type="button"
        >
          <FileText size={15} style={{ marginRight: '6px' }} />
          TDS Deduction Register (ITNS-281)
        </button>
        <button
          aria-selected={activeTab === 'form26q'}
          className={activeTab === 'form26q' ? 'list-tab list-tab--active' : 'list-tab'}
          onClick={() => setActiveTab('form26q')}
          role="tab"
          type="button"
        >
          <Building size={15} style={{ marginRight: '6px' }} />
          Form 26Q (Vendor Returns)
        </button>
        <button
          aria-selected={activeTab === 'form24q'}
          className={activeTab === 'form24q' ? 'list-tab list-tab--active' : 'list-tab'}
          onClick={() => setActiveTab('form24q')}
          role="tab"
          type="button"
        >
          <Users size={15} style={{ marginRight: '6px' }} />
          Form 24Q (Salary TDS)
        </button>
      </div>

      {activeTab === 'register' && (
        <>
          {/* Summary KPIs */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '16px', marginTop: '16px', marginBottom: '16px' }}>
            <div style={{ background: 'var(--bg-subtle)', padding: '12px 16px', borderRadius: '6px', border: '1px solid var(--border-subtle)' }}>
              <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Total TDS Withheld</span>
              <div style={{ fontSize: '20px', fontWeight: 600, color: 'var(--color-primary)', marginTop: '4px' }}>
                <Money amount={totalTdsWithheld} />
              </div>
            </div>
            <div style={{ background: 'var(--bg-subtle)', padding: '12px 16px', borderRadius: '6px', border: '1px solid var(--border-subtle)' }}>
              <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Taxable Bill Value</span>
              <div style={{ fontSize: '20px', fontWeight: 600, marginTop: '4px' }}>
                <Money amount={totalTaxable} />
              </div>
            </div>
            <div style={{ background: 'var(--bg-subtle)', padding: '12px 16px', borderRadius: '6px', border: '1px solid var(--border-subtle)' }}>
              <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Bills with TDS</span>
              <div style={{ fontSize: '20px', fontWeight: 600, marginTop: '4px' }}>
                {filteredRegister.length} bills
              </div>
            </div>
          </div>

          {/* Filters */}
          <div className="list-toolbar">
            <label className="directory-search">
              <Search aria-hidden="true" size={18} />
              <span className="sr-only">Search TDS register</span>
              <input
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Search by vendor, bill #, PAN..."
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
              <select
                className="search-input"
                onChange={(e) => setSectionFilter(e.target.value)}
                style={{ width: '140px' }}
                value={sectionFilter}
              >
                <option value="ALL">All Sections</option>
                <option value="194C">194C (Contractor)</option>
                <option value="194J">194J (Professional)</option>
                <option value="194Q">194Q (Goods)</option>
                <option value="194I">194I (Rent)</option>
                <option value="194H">194H (Commission)</option>
              </select>
            </div>
          </div>

          {registerQuery.isLoading ? (
            <div className="directory-state">Loading TDS deduction register...</div>
          ) : filteredRegister.length === 0 ? (
            <div className="directory-state">
              <ShieldCheck size={24} />
              <strong>No TDS deductions found in this period.</strong>
            </div>
          ) : (
            <DataTable caption="Vendor TDS deductions">
              <thead>
                <tr>
                  <th scope="col">Bill #</th>
                  <th scope="col">Date</th>
                  <th scope="col">Vendor</th>
                  <th scope="col">PAN</th>
                  <th scope="col">Section</th>
                  <th className="numeric-cell" scope="col">Rate %</th>
                  <th className="numeric-cell" scope="col">Taxable Amount</th>
                  <th className="numeric-cell" scope="col">TDS Withheld</th>
                  <th scope="col">Status</th>
                </tr>
              </thead>
              <tbody>
                {filteredRegister.map((r, idx) => (
                  <tr key={r.billId || idx}>
                    <td className="cell-id">
                      {r.billId ? <Link to={`/bills/${r.billId}`}>{r.billNumber || r.billId.slice(0, 8)}</Link> : r.billNumber || '—'}
                    </td>
                    <td>{r.billDate ? formatDate(r.billDate) : '—'}</td>
                    <td><strong>{r.vendorName || r.vendorId || 'Vendor'}</strong></td>
                    <td className="font-mono">{r.vendorPan || '—'}</td>
                    <td><span className="status-badge status-badge--info">{r.section || '194C'}</span></td>
                    <td className="numeric-cell">{r.rate ?? 1}%</td>
                    <td className="numeric-cell"><Money amount={r.taxableAmount ?? r.billAmount} /></td>
                    <td className="numeric-cell" style={{ fontWeight: 600, color: 'var(--color-primary)' }}>
                      <Money amount={r.tdsAmount} />
                    </td>
                    <td><StatusChip status={r.challanNumber ? 'PAID' : 'DRAFT'} /></td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          )}
        </>
      )}

      {activeTab === 'form26q' && (
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
                <option value={currentFy - 2}>FY {currentFy - 2}-{currentFy - 1 - 2000}</option>
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
            <div style={{ display: 'flex', gap: '8px' }}>
              <a href={getForm26qCsvUrl(fy, quarter)} target="_blank" rel="noreferrer">
                <Button variant="secondary">
                  <Download size={15} />
                  Download 26Q CSV
                </Button>
              </a>
              <a href={getForm26qFvuUrl(fy, quarter)} target="_blank" rel="noreferrer">
                <Button variant="primary">
                  <FileText size={15} />
                  Export FVU Block
                </Button>
              </a>
            </div>
          </div>

          {/* Form 26Q Summary Cards */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '16px' }}>
            <div style={{ background: 'var(--bg-card)', padding: '14px 16px', borderRadius: '6px', border: '1px solid var(--border-subtle)' }}>
              <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Total Deductees</span>
              <div style={{ fontSize: '20px', fontWeight: 600, marginTop: '4px' }}>
                {form26qData?.totalDeductees ?? 0}
              </div>
            </div>
            <div style={{ background: 'var(--bg-card)', padding: '14px 16px', borderRadius: '6px', border: '1px solid var(--border-subtle)' }}>
              <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Total Amount Paid</span>
              <div style={{ fontSize: '20px', fontWeight: 600, marginTop: '4px' }}>
                <Money amount={form26qData?.totalAmountPaid ?? 0} />
              </div>
            </div>
            <div style={{ background: 'var(--bg-card)', padding: '14px 16px', borderRadius: '6px', border: '1px solid var(--border-subtle)' }}>
              <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>TDS Deducted</span>
              <div style={{ fontSize: '20px', fontWeight: 600, color: 'var(--color-primary)', marginTop: '4px' }}>
                <Money amount={form26qData?.totalTdsDeducted ?? 0} />
              </div>
            </div>
            <div style={{ background: 'var(--bg-card)', padding: '14px 16px', borderRadius: '6px', border: '1px solid var(--border-subtle)' }}>
              <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>TDS Deposited via ITNS-281</span>
              <div style={{ fontSize: '20px', fontWeight: 600, color: 'var(--color-success)', marginTop: '4px' }}>
                <Money amount={form26qData?.totalTdsDeposited ?? 0} />
              </div>
            </div>
          </div>

          {/* Deductees Table */}
          {form26qData?.deductees && form26qData.deductees.length > 0 ? (
            <DataTable caption="Form 26Q deductee list">
              <thead>
                <tr>
                  <th scope="col">Deductee PAN</th>
                  <th scope="col">Deductee Name</th>
                  <th scope="col">Section</th>
                  <th scope="col">Payment Date</th>
                  <th className="numeric-cell" scope="col">Amount Paid</th>
                  <th className="numeric-cell" scope="col">TDS Deducted</th>
                </tr>
              </thead>
              <tbody>
                {form26qData.deductees.map((d, i) => (
                  <tr key={i}>
                    <td className="font-mono">{d.pan}</td>
                    <td><strong>{d.name}</strong></td>
                    <td><span className="status-badge status-badge--info">{d.section}</span></td>
                    <td>{d.paymentDate ? formatDate(d.paymentDate) : '—'}</td>
                    <td className="numeric-cell"><Money amount={d.amount} /></td>
                    <td className="numeric-cell" style={{ fontWeight: 600, color: 'var(--color-primary)' }}>
                      <Money amount={d.tdsDeducted} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          ) : (
            <div className="directory-state">
              <FileText size={24} />
              <strong>No Form 26Q deductee records for Q{quarter} FY {fy}-{fy + 1 - 2000}.</strong>
            </div>
          )}
        </div>
      )}

      {activeTab === 'form24q' && (
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
            <a href={getForm24qCsvUrl(fy, quarter)} target="_blank" rel="noreferrer">
              <Button variant="secondary">
                <Download size={15} />
                Download 24Q CSV
              </Button>
            </a>
          </div>

          {/* Form 24Q Summary Cards */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '16px' }}>
            <div style={{ background: 'var(--bg-card)', padding: '14px 16px', borderRadius: '6px', border: '1px solid var(--border-subtle)' }}>
              <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Employees Deducted</span>
              <div style={{ fontSize: '20px', fontWeight: 600, marginTop: '4px' }}>
                {form24qData?.totalEmployees ?? 0}
              </div>
            </div>
            <div style={{ background: 'var(--bg-card)', padding: '14px 16px', borderRadius: '6px', border: '1px solid var(--border-subtle)' }}>
              <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Gross Salary Paid</span>
              <div style={{ fontSize: '20px', fontWeight: 600, marginTop: '4px' }}>
                <Money amount={form24qData?.totalGrossSalary ?? 0} />
              </div>
            </div>
            <div style={{ background: 'var(--bg-card)', padding: '14px 16px', borderRadius: '6px', border: '1px solid var(--border-subtle)' }}>
              <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>TDS (Sec 192) Withheld</span>
              <div style={{ fontSize: '20px', fontWeight: 600, color: 'var(--color-primary)', marginTop: '4px' }}>
                <Money amount={form24qData?.totalTdsDeducted ?? 0} />
              </div>
            </div>
          </div>

          {/* Employees Table */}
          {form24qData?.employees && form24qData.employees.length > 0 ? (
            <DataTable caption="Form 24Q salary TDS list">
              <thead>
                <tr>
                  <th scope="col">Employee</th>
                  <th scope="col">PAN</th>
                  <th scope="col">Tax Regime</th>
                  <th className="numeric-cell" scope="col">Gross Salary</th>
                  <th className="numeric-cell" scope="col">Taxable Salary</th>
                  <th className="numeric-cell" scope="col">TDS Deducted</th>
                </tr>
              </thead>
              <tbody>
                {form24qData.employees.map((emp, i) => (
                  <tr key={emp.employeeId || i}>
                    <td><strong>{emp.employeeName}</strong></td>
                    <td className="font-mono">{emp.pan || '—'}</td>
                    <td><span className="status-badge status-badge--info">{emp.regime || 'NEW'}</span></td>
                    <td className="numeric-cell"><Money amount={emp.grossSalary} /></td>
                    <td className="numeric-cell"><Money amount={emp.taxableSalary} /></td>
                    <td className="numeric-cell" style={{ fontWeight: 600, color: 'var(--color-primary)' }}>
                      <Money amount={emp.tdsDeducted} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          ) : (
            <div className="directory-state">
              <Users size={24} />
              <strong>No salary TDS deductions recorded for Q{quarter} FY {fy}-{fy + 1 - 2000}.</strong>
            </div>
          )}
        </div>
      )}
    </section>
  )
}
