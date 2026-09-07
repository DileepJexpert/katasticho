import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import {
  FileText,
  Download,
  Calendar,
  Layers,
  Settings,
  ShieldCheck,
  CheckCircle2,
} from 'lucide-react'
import { Link } from 'react-router-dom'
import { Button, CheckboxInput, DataTable, FormCard, FormField, Money, PageHeader, SearchInput, SelectInput, StatusChip, TextInput } from '@/design-system'
import { formatDate } from '@/shared/format/format'
import {
  getTcsRegister,
  getForm27eq,
  downloadForm27eqCsv,
  getTcsSettings,
  updateTcsSettings,
  type TcsRegisterEntry,
} from '@/features/tax/tds-tcs-api'
import { downloadBlob } from '@/shared/files/download-blob'
import { ComplianceMetric, ComplianceMetricGrid, CompliancePanel, CompliancePeriodToolbar } from '@/features/tax/tax-compliance-primitives'

type TabKey = 'register' | 'form27eq' | 'settings'

export function TcsCompliancePage() {
  const queryClient = useQueryClient()
  const [activeTab, setActiveTab] = useState<TabKey>('register')
  const [feedback, setFeedback] = useState<string | null>(null)
  const [downloadError, setDownloadError] = useState<string | null>(null)
  const [downloading, setDownloading] = useState(false)

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

  async function downloadExport() {
    setDownloadError(null)
    setDownloading(true)
    try {
      downloadBlob(await downloadForm27eqCsv(fy, quarter), `form-27eq-fy${fy}-q${quarter}.csv`)
    } catch (error) {
      setDownloadError(error instanceof Error ? error.message : 'The export could not be downloaded.')
    } finally {
      setDownloading(false)
    }
  }

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
          <ComplianceMetricGrid>
            <ComplianceMetric label="Total TCS collected" tone="brand" value={<Money amount={totalTcsCollected} />} />
            <ComplianceMetric label="Total sales value" value={<Money amount={totalSalesValue} />} />
            <ComplianceMetric label="Eligible invoices" value={`${filteredRegister.length} invoices`} />
          </ComplianceMetricGrid>

          {/* Filters */}
          <div className="list-toolbar">
            <SearchInput
              ariaLabel="Search TCS register"
              onChange={setSearch}
              onClear={() => setSearch('')}
              placeholder="Search customer, invoice number, or PAN"
              value={search}
            />
            <div className="compliance-register-filters">
              <FormField label="From"><TextInput onChange={(e) => setFromDate(e.target.value)} type="date" value={fromDate} /></FormField>
              <FormField label="To"><TextInput onChange={(e) => setToDate(e.target.value)} type="date" value={toDate} /></FormField>
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
        <CompliancePanel>
          <CompliancePeriodToolbar
            actions={<Button disabled={downloading} onClick={() => void downloadExport()} variant="secondary">
                <Download size={15} />
                {downloading ? 'Downloading...' : 'Download Form 27EQ CSV'}
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

          {/* Form 27EQ Summary Cards */}
          <ComplianceMetricGrid>
            <ComplianceMetric label="Total collectees" value={form27eqData?.totalCollectees ?? 0} />
            <ComplianceMetric label="Total sales value" value={<Money amount={form27eqData?.totalSalesValue ?? 0} />} />
            <ComplianceMetric label="TCS collected" tone="brand" value={<Money amount={form27eqData?.totalTcsCollected ?? 0} />} />
            <ComplianceMetric label="TCS deposited" tone="positive" value={<Money amount={form27eqData?.totalTcsDeposited ?? 0} />} />
          </ComplianceMetricGrid>

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
        </CompliancePanel>
      )}

      {activeTab === 'settings' && (
        <FormCard
          className="tax-compliance-settings"
          description="When enabled, sales invoices exceeding ₹50,000,000 cumulative turnover in the financial year automatically apply 0.1% TCS on the excess consideration."
          title="TCS Section 206C(1H) settings"
        >
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
            <div className="tax-compliance-settings__body">
              <CheckboxInput
                defaultChecked={settingsData?.enabled ?? true}
                description="Collect TCS automatically when the configured statutory threshold is crossed."
                label="Enable TCS collection under Section 206C(1H)"
                name="enabled"
              />

              <FormField hint="Default is 0.001 (0.1%)." label="Standard TCS rate with PAN">
                <TextInput defaultValue={settingsData?.rate ?? 0.001} name="rate" step="0.0001" type="number" />
              </FormField>

              <div className="table-actions">
                <Button disabled={updateSettingsMutation.isPending} type="submit" variant="primary">
                  {updateSettingsMutation.isPending ? 'Saving...' : 'Save settings'}
                </Button>
              </div>
            </div>
          </form>
        </FormCard>
      )}
    </section>
  )
}
