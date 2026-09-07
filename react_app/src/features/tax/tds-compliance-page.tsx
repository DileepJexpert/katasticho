import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import {
  FileText,
  Download,
  Calendar,
  Layers,
  Users,
  Building,
  ShieldCheck,
} from 'lucide-react'
import { Link } from 'react-router-dom'
import { Button, DataTable, FormField, Money, PageHeader, SearchInput, SelectInput, StatusChip, TextInput } from '@/design-system'
import { formatDate } from '@/shared/format/format'
import {
  getTdsRegister,
  getForm26q,
  downloadForm26qCsv,
  downloadForm26qFvu,
  getForm24q,
  downloadForm24qCsv,
  type TdsRegisterEntry,
} from '@/features/tax/tds-tcs-api'
import { downloadBlob } from '@/shared/files/download-blob'
import { ComplianceMetric, ComplianceMetricGrid, CompliancePanel, CompliancePeriodToolbar } from '@/features/tax/tax-compliance-primitives'

type TabKey = 'register' | 'form26q' | 'form24q'

export function TdsCompliancePage() {
  const [activeTab, setActiveTab] = useState<TabKey>('register')
  const [downloadError, setDownloadError] = useState<string | null>(null)
  const [downloading, setDownloading] = useState<string | null>(null)

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

  async function downloadExport(key: string, filename: string, load: () => Promise<Blob>) {
    setDownloadError(null)
    setDownloading(key)
    try {
      downloadBlob(await load(), filename)
    } catch (error) {
      setDownloadError(error instanceof Error ? error.message : 'The export could not be downloaded.')
    } finally {
      setDownloading(null)
    }
  }

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

      {downloadError && <div className="feedback-alert feedback-alert--error" role="alert">{downloadError}</div>}

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
          <ComplianceMetricGrid>
            <ComplianceMetric label="Total TDS withheld" tone="brand" value={<Money amount={totalTdsWithheld} />} />
            <ComplianceMetric label="Taxable bill value" value={<Money amount={totalTaxable} />} />
            <ComplianceMetric label="Bills with TDS" value={`${filteredRegister.length} bills`} />
          </ComplianceMetricGrid>

          {/* Filters */}
          <div className="list-toolbar">
            <SearchInput
              ariaLabel="Search TDS register"
              onChange={setSearch}
              onClear={() => setSearch('')}
              placeholder="Search vendor, bill number, or PAN"
              value={search}
            />
            <div className="compliance-register-filters">
              <FormField label="From"><TextInput onChange={(e) => setFromDate(e.target.value)} type="date" value={fromDate} /></FormField>
              <FormField label="To"><TextInput onChange={(e) => setToDate(e.target.value)} type="date" value={toDate} /></FormField>
              <FormField className="field-group--section" label="Section">
                <SelectInput onChange={(e) => setSectionFilter(e.target.value)} value={sectionFilter}>
                  <option value="ALL">All sections</option>
                  <option value="194C">194C: Contractor</option>
                  <option value="194J">194J: Professional</option>
                  <option value="194Q">194Q: Goods</option>
                  <option value="194I">194I: Rent</option>
                  <option value="194H">194H: Commission</option>
                </SelectInput>
              </FormField>
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
        <CompliancePanel>
          <CompliancePeriodToolbar
            actions={
              <>
              <Button disabled={Boolean(downloading)} onClick={() => void downloadExport('26q-csv', `form-26q-fy${fy}-q${quarter}.csv`, () => downloadForm26qCsv(fy, quarter))} variant="secondary">
                  <Download size={15} />
                  {downloading === '26q-csv' ? 'Downloading...' : 'Download 26Q CSV'}
              </Button>
              <Button disabled={Boolean(downloading)} onClick={() => void downloadExport('26q-fvu', `form-26q-fy${fy}-q${quarter}.fvu`, () => downloadForm26qFvu(fy, quarter))} variant="primary">
                  <FileText size={15} />
                  {downloading === '26q-fvu' ? 'Downloading...' : 'Export FVU Block'}
              </Button>
              </>
            }
            controls={
              <>
                <Calendar aria-hidden="true" size={16} />
                <FormField label="Financial year">
                  <SelectInput onChange={(e) => setFy(Number(e.target.value))} value={fy}>
                    <option value={currentFy}>FY {currentFy}-{currentFy + 1 - 2000}</option>
                    <option value={currentFy - 1}>FY {currentFy - 1}-{currentFy - 2000}</option>
                    <option value={currentFy - 2}>FY {currentFy - 2}-{currentFy - 1 - 2000}</option>
                  </SelectInput>
                </FormField>
                <FormField className="field-group--quarter" label="Quarter">
                  <SelectInput onChange={(e) => setQuarter(Number(e.target.value))} value={quarter}>
                    <option value={1}>Q1: Apr-Jun</option><option value={2}>Q2: Jul-Sep</option><option value={3}>Q3: Oct-Dec</option><option value={4}>Q4: Jan-Mar</option>
                  </SelectInput>
                </FormField>
              </>
            }
          />

          {/* Form 26Q Summary Cards */}
          <ComplianceMetricGrid>
            <ComplianceMetric label="Total deductees" value={form26qData?.totalDeductees ?? 0} />
            <ComplianceMetric label="Total amount paid" value={<Money amount={form26qData?.totalAmountPaid ?? 0} />} />
            <ComplianceMetric label="TDS deducted" tone="brand" value={<Money amount={form26qData?.totalTdsDeducted ?? 0} />} />
            <ComplianceMetric label="Deposited via ITNS-281" tone="positive" value={<Money amount={form26qData?.totalTdsDeposited ?? 0} />} />
          </ComplianceMetricGrid>

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
        </CompliancePanel>
      )}

      {activeTab === 'form24q' && (
        <CompliancePanel>
          <CompliancePeriodToolbar
            actions={<Button disabled={Boolean(downloading)} onClick={() => void downloadExport('24q-csv', `form-24q-fy${fy}-q${quarter}.csv`, () => downloadForm24qCsv(fy, quarter))} variant="secondary">
                <Download size={15} />
                {downloading === '24q-csv' ? 'Downloading...' : 'Download 24Q CSV'}
              </Button>}
            controls={<>
              <Calendar aria-hidden="true" size={16} />
              <FormField label="Financial year">
                <SelectInput onChange={(e) => setFy(Number(e.target.value))} value={fy}>
                  <option value={currentFy}>FY {currentFy}-{currentFy + 1 - 2000}</option>
                  <option value={currentFy - 1}>FY {currentFy - 1}-{currentFy - 2000}</option>
                </SelectInput>
              </FormField>
              <FormField className="field-group--quarter" label="Quarter">
                <SelectInput onChange={(e) => setQuarter(Number(e.target.value))} value={quarter}>
                  <option value={1}>Q1: Apr-Jun</option><option value={2}>Q2: Jul-Sep</option><option value={3}>Q3: Oct-Dec</option><option value={4}>Q4: Jan-Mar</option>
                </SelectInput>
              </FormField>
            </>}
          />

          {/* Form 24Q Summary Cards */}
          <ComplianceMetricGrid>
            <ComplianceMetric label="Employees deducted" value={form24qData?.totalEmployees ?? 0} />
            <ComplianceMetric label="Gross salary paid" value={<Money amount={form24qData?.totalGrossSalary ?? 0} />} />
            <ComplianceMetric label="TDS withheld under section 192" tone="brand" value={<Money amount={form24qData?.totalTdsDeducted ?? 0} />} />
          </ComplianceMetricGrid>

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
        </CompliancePanel>
      )}
    </section>
  )
}
