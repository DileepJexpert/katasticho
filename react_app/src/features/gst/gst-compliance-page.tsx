import { useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  Bot,
  CheckCircle2,
  Clock,
  Download,
  FileCheck,
  FileSpreadsheet,
  RefreshCw,
  Search,
  ShieldAlert,
  Truck,
  Zap,
} from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import {
  actionImsEntry,
  applyAiRecommendations,
  bulkActionIms,
  cancelEInvoice,
  cancelEwayBill,
  generateEInvoiceViaGsp,
  generateEwayBillViaGsp,
  getComplianceCalendar,
  getGstr1,
  getGstr3b,
  getImsSummary,
  getItcRiskReport,
  getMonthEndCloseChecklist,
  listEInvoices,
  listEwayBills,
  listGstr2bEntries,
  recordEInvoice,
  recordEwayBill,
  refreshItcRiskAlerts,
  resetImsAction,
  type EInvoice,
  type EwayBill,
  type Gstr2bEntry,
} from '@/features/gst/gst-api'

type TabType = 'returns' | 'ims' | 'recon' | 'einvoice_ewb' | 'close'

export function GstCompliancePage() {
  const queryClient = useQueryClient()
  const [activeTab, setActiveTab] = useState<TabType>('returns')

  // Period state
  const currentDate = new Date()
  const [selectedYear, setSelectedYear] = useState<number>(currentDate.getFullYear())
  const [selectedMonth, setSelectedMonth] = useState<number>(currentDate.getMonth() + 1)
  const periodString = `${selectedYear}-${String(selectedMonth).padStart(2, '0')}`

  // IMS filters
  const [imsSearchTerm, setImsSearchTerm] = useState('')
  const [imsStatusFilter, setImsStatusFilter] = useState<string>('ALL')
  const [selectedImsIds, setSelectedImsIds] = useState<string[]>([])

  // Modal states
  const [activeImsEntry, setActiveImsEntry] = useState<Gstr2bEntry | null>(null)
  const [imsRemarks, setImsRemarks] = useState('')
  const [isRecordEwbOpen, setIsRecordEwbOpen] = useState(false)
  const [activeEwb, setActiveEwb] = useState<EwayBill | null>(null)
  const [manualEwbNumber, setManualEwbNumber] = useState('')
  const [isRecordIrnOpen, setIsRecordIrnOpen] = useState(false)
  const [activeEInvoice, setActiveEInvoice] = useState<EInvoice | null>(null)
  const [manualIrn, setManualIrn] = useState('')
  const [manualAckNo, setManualAckNo] = useState('')

  // â”€â”€ Queries â”€â”€
  const gstr1Query = useQuery({
    queryKey: ['gst-gstr1', selectedYear, selectedMonth],
    queryFn: () => getGstr1(selectedYear, selectedMonth),
    enabled: activeTab === 'returns',
  })

  const gstr3bQuery = useQuery({
    queryKey: ['gst-gstr3b', selectedYear, selectedMonth],
    queryFn: () => getGstr3b(selectedYear, selectedMonth),
    enabled: activeTab === 'returns',
  })

  const calendarQuery = useQuery({
    queryKey: ['gst-calendar'],
    queryFn: () => getComplianceCalendar(),
    enabled: activeTab === 'returns',
  })

  const imsSummaryQuery = useQuery({
    queryKey: ['gst-ims-summary', periodString],
    queryFn: () => getImsSummary(periodString),
    enabled: activeTab === 'ims',
  })

  const gstr2bQuery = useQuery({
    queryKey: ['gst-gstr2b-entries', periodString],
    queryFn: () => listGstr2bEntries(periodString),
    enabled: activeTab === 'ims' || activeTab === 'recon',
  })

  const itcRiskQuery = useQuery({
    queryKey: ['gst-itc-risk', periodString],
    queryFn: () => getItcRiskReport(periodString),
    enabled: activeTab === 'recon',
  })

  const ewayBillsQuery = useQuery({
    queryKey: ['gst-eway-bills'],
    queryFn: () => listEwayBills(),
    enabled: activeTab === 'einvoice_ewb',
  })

  const einvoicesQuery = useQuery({
    queryKey: ['gst-einvoices'],
    queryFn: () => listEInvoices(),
    enabled: activeTab === 'einvoice_ewb',
  })

  const closeChecklistQuery = useQuery({
    queryKey: ['gst-month-close', selectedYear, selectedMonth],
    queryFn: () => getMonthEndCloseChecklist(selectedYear, selectedMonth),
    enabled: activeTab === 'close',
  })

  // â”€â”€ Mutations â”€â”€
  const actionMutation = useMutation({
    mutationFn: ({ id, action, remarks }: { id: string; action: 'ACCEPT' | 'REJECT' | 'PENDING'; remarks?: string }) =>
      actionImsEntry(id, action, remarks),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['gst-gstr2b-entries', periodString] })
      queryClient.invalidateQueries({ queryKey: ['gst-ims-summary', periodString] })
      setActiveImsEntry(null)
      setImsRemarks('')
    },
  })

  const bulkActionMutation = useMutation({
    mutationFn: ({ ids, action }: { ids: string[]; action: 'ACCEPT' | 'REJECT' | 'PENDING' }) =>
      bulkActionIms(ids, action),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['gst-gstr2b-entries', periodString] })
      queryClient.invalidateQueries({ queryKey: ['gst-ims-summary', periodString] })
      setSelectedImsIds([])
    },
  })

  const applyAiMutation = useMutation({
    mutationFn: () => applyAiRecommendations(periodString),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['gst-gstr2b-entries', periodString] })
      queryClient.invalidateQueries({ queryKey: ['gst-ims-summary', periodString] })
    },
  })

  const resetActionMutation = useMutation({
    mutationFn: (id: string) => resetImsAction(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['gst-gstr2b-entries', periodString] })
      queryClient.invalidateQueries({ queryKey: ['gst-ims-summary', periodString] })
    },
  })

  const ewbGspMutation = useMutation({
    mutationFn: (id: string) => generateEwayBillViaGsp(id),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['gst-eway-bills'] }),
  })

  const recordEwbMutation = useMutation({
    mutationFn: ({ id, ewbNo }: { id: string; ewbNo: string }) => recordEwayBill(id, ewbNo),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['gst-eway-bills'] })
      setIsRecordEwbOpen(false)
      setManualEwbNumber('')
    },
  })

  const cancelEwbMutation = useMutation({
    mutationFn: (id: string) => cancelEwayBill(id, 'Cancelled from ERP portal'),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['gst-eway-bills'] }),
  })

  const einvoiceGspMutation = useMutation({
    mutationFn: (id: string) => generateEInvoiceViaGsp(id),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['gst-einvoices'] }),
  })

  const recordIrnMutation = useMutation({
    mutationFn: ({ id, irn, ackNo }: { id: string; irn: string; ackNo: string }) =>
      recordEInvoice(id, irn, ackNo),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['gst-einvoices'] })
      setIsRecordIrnOpen(false)
      setManualIrn('')
      setManualAckNo('')
    },
  })

  const cancelEInvoiceMutation = useMutation({
    mutationFn: (id: string) => cancelEInvoice(id, 'Cancelled from ERP portal'),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['gst-einvoices'] }),
  })

  const alertMutation = useMutation({
    mutationFn: () => refreshItcRiskAlerts(periodString),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['gst-itc-risk', periodString] }),
  })

  // â”€â”€ Data derivations â”€â”€
  const gstr1 = gstr1Query.data
  const gstr3b = gstr3bQuery.data
  const imsSummary = imsSummaryQuery.data
  const gstr2bEntries = gstr2bQuery.data ?? []
  const itcRisk = itcRiskQuery.data
  const ewayBills = ewayBillsQuery.data ?? []
  const einvoices = einvoicesQuery.data ?? []
  const closeChecklist = closeChecklistQuery.data
  const deadlines = calendarQuery.data ?? []

  const filteredImsEntries = useMemo(() => {
    const term = imsSearchTerm.trim().toLowerCase()
    return gstr2bEntries.filter((entry) => {
      if (imsStatusFilter === 'ACTIONED' && !entry.imsAction) return false
      if (imsStatusFilter === 'PENDING_ACTION' && Boolean(entry.imsAction)) return false
      if (imsStatusFilter === 'ACCEPTED' && entry.imsAction !== 'ACCEPT') return false
      if (imsStatusFilter === 'REJECTED' && entry.imsAction !== 'REJECT') return false
      if (imsStatusFilter === 'PENDING' && entry.imsAction !== 'PENDING') return false

      if (!term) return true
      return (
        entry.invoiceNumber.toLowerCase().includes(term) ||
        entry.supplierGstin.toLowerCase().includes(term) ||
        (entry.supplierTradeName && entry.supplierTradeName.toLowerCase().includes(term))
      )
    })
  }, [gstr2bEntries, imsSearchTerm, imsStatusFilter])

  const toggleSelectAllIms = () => {
    if (selectedImsIds.length === filteredImsEntries.length) {
      setSelectedImsIds([])
    } else {
      setSelectedImsIds(filteredImsEntries.map((e) => e.id))
    }
  }

  const toggleSelectIms = (id: string) => {
    setSelectedImsIds((prev) =>
      prev.includes(id) ? prev.filter((item) => item !== id) : [...prev, id]
    )
  }

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Statutory Compliance / India GST"
        title="GST Compliance & Filings Suite"
        description="GSTR-1 & GSTR-3B return preparation, Sec 38 IMS workbench, GSTR-2B reconciliation, ITC risk monitor, e-Way bills & e-Invoices."
        actions={
          <div style={{ display: 'flex', gap: 'var(--space-sm)', alignItems: 'center' }}>
            <select
              aria-label="Select filing year"
              className="select-field"
              onChange={(e) => setSelectedYear(Number(e.target.value))}
              style={{ padding: '6px 12px', fontWeight: 600 }}
              value={selectedYear}
            >
              {[2024, 2025, 2026, 2027].map((y) => (
                <option key={y} value={y}>
                  FY {y}-{String(y + 1).slice(2)} ({y})
                </option>
              ))}
            </select>
            <select
              aria-label="Select filing month"
              className="select-field"
              onChange={(e) => setSelectedMonth(Number(e.target.value))}
              style={{ padding: '6px 12px', fontWeight: 600 }}
              value={selectedMonth}
            >
              {[
                { m: 1, name: 'Jan' },
                { m: 2, name: 'Feb' },
                { m: 3, name: 'Mar' },
                { m: 4, name: 'Apr' },
                { m: 5, name: 'May' },
                { m: 6, name: 'Jun' },
                { m: 7, name: 'Jul' },
                { m: 8, name: 'Aug' },
                { m: 9, name: 'Sep' },
                { m: 10, name: 'Oct' },
                { m: 11, name: 'Nov' },
                { m: 12, name: 'Dec' },
              ].map(({ m, name }) => (
                <option key={m} value={m}>
                  {name}
                </option>
              ))}
            </select>
            <StatusChip status={`Period: ${periodString}`} />
          </div>
        }
      />

      {/* Tabs Bar */}
      <div className="tab-bar" style={{ display: 'flex', gap: 'var(--space-xs)', borderBottom: '1px solid var(--color-border)', marginBottom: 'var(--space-md)' }}>
        {[
          { key: 'returns' as TabType, label: 'GSTR-1 & GSTR-3B Returns', icon: FileSpreadsheet },
          { key: 'ims' as TabType, label: 'IMS Action Workbench (Sec 38)', icon: FileCheck },
          { key: 'recon' as TabType, label: 'GSTR-2B Recon & ITC Risk', icon: ShieldAlert },
          { key: 'einvoice_ewb' as TabType, label: 'e-Way Bills & e-Invoices', icon: Truck },
          { key: 'close' as TabType, label: 'Month-End Close Checklist', icon: CheckCircle2 },
        ].map((tab) => {
          const Icon = tab.icon
          const isActive = activeTab === tab.key
          return (
            <button
              key={tab.key}
              className={`tab-btn ${isActive ? 'tab-btn--active' : ''}`}
              onClick={() => setActiveTab(tab.key)}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: 6,
                padding: '8px 16px',
                border: 'none',
                background: isActive ? 'var(--color-surface)' : 'transparent',
                borderBottom: isActive ? '2px solid var(--color-primary)' : '2px solid transparent',
                color: isActive ? 'var(--color-primary)' : 'var(--color-text-secondary)',
                fontWeight: isActive ? 600 : 500,
                cursor: 'pointer',
                borderRadius: 'var(--radius-md) var(--radius-md) 0 0',
              }}
              type="button"
            >
              <Icon aria-hidden="true" size={15} />
              {tab.label}
            </button>
          )
        })}
      </div>

      {/* â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */}
      {/* TAB 1: GSTR-1 & GSTR-3B RETURNS */}
      {/* â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */}
      {activeTab === 'returns' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-md)' }}>
          {/* Summary Strip */}
          <div className="summary-strip">
            <div className="summary-card">
              <span className="summary-card__label">Outward Taxable Value (GSTR-1)</span>
              <strong className="summary-card__value">
                <Money amount={gstr1?.totalTaxable || 0} />
              </strong>
              <span className="summary-card__hint">B2B + B2C + Exports</span>
            </div>

            <div className="summary-card">
              <span className="summary-card__label">Total Output GST (GSTR-1)</span>
              <strong className="summary-card__value" style={{ color: 'var(--color-primary)' }}>
                <Money amount={gstr1?.totalTax || 0} />
              </strong>
              <span className="summary-card__hint">
                CGST + SGST + IGST + Cess
              </span>
            </div>

            <div className="summary-card">
              <span className="summary-card__label">Eligible Input Tax Credit (GSTR-3B)</span>
              <strong className="summary-card__value" style={{ color: 'var(--color-success)' }}>
                <Money
                  amount={
                    (gstr3b?.itcAllOther.cgst || 0) +
                    (gstr3b?.itcAllOther.sgst || 0) +
                    (gstr3b?.itcAllOther.igst || 0)
                  }
                />
              </strong>
              <span className="summary-card__hint">Table 4(A)(5) All Other ITC</span>
            </div>

            <div className="summary-card summary-card--accent">
              <span className="summary-card__label">Net GST Cash Payable</span>
              <strong className="summary-card__value" style={{ color: 'var(--color-error)' }}>
                <Money
                  amount={
                    (gstr3b?.netPayable.cgst || 0) +
                    (gstr3b?.netPayable.sgst || 0) +
                    (gstr3b?.netPayable.igst || 0)
                  }
                />
              </strong>
              <span className="summary-card__hint">Tax payable after ITC offset</span>
            </div>
          </div>

          {/* Two Return Grid Columns */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 'var(--space-md)' }}>
            {/* GSTR-1 Breakdown Panel */}
            <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 'var(--space-sm)' }}>
                <h3 style={{ fontSize: '1.05rem', fontWeight: 600 }}>GSTR-1 Outward Supplies Summary</h3>
                <a
                  className="btn btn--secondary"
                  href={`/api/v1/gst/gstr1/export?year=${selectedYear}&month=${selectedMonth}`}
                  style={{ fontSize: '0.8rem', padding: '4px 8px' }}
                >
                  <Download aria-hidden="true" size={12} style={{ marginRight: 4 }} />
                  GSTN JSON
                </a>
              </div>

              <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 12px', background: 'var(--color-bg-subtle)', borderRadius: 'var(--radius-md)' }}>
                  <span>Table 4A - B2B Invoices ({gstr1?.b2bCount || 0} invoices)</span>
                  <strong><Money amount={gstr1?.b2bTaxable || 0} /></strong>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 12px', background: 'var(--color-bg-subtle)', borderRadius: 'var(--radius-md)' }}>
                  <span>Table 5 - B2C Large Supplies ({gstr1?.b2clCount || 0} invoices)</span>
                  <strong><Money amount={gstr1?.b2clTaxable || 0} /></strong>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 12px', background: 'var(--color-bg-subtle)', borderRadius: 'var(--radius-md)' }}>
                  <span>Table 7 - B2C Small Supplies ({gstr1?.b2csCount || 0} receipts)</span>
                  <strong><Money amount={gstr1?.b2csTaxable || 0} /></strong>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 12px', background: 'var(--color-bg-subtle)', borderRadius: 'var(--radius-md)' }}>
                  <span>Table 6 - Zero Rated Exports ({gstr1?.exportCount || 0} orders)</span>
                  <strong><Money amount={gstr1?.exportTaxable || 0} /></strong>
                </div>
              </div>

              <div style={{ marginTop: 'var(--space-md)', paddingTop: 'var(--space-sm)', borderTop: '1px solid var(--color-border)' }}>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 8, textAlign: 'center' }}>
                  <div style={{ padding: 8, background: 'var(--color-surface)', border: '1px solid var(--color-border)', borderRadius: 'var(--radius-md)' }}>
                    <span className="cell-muted" style={{ fontSize: '0.75rem' }}>CGST Output</span>
                    <strong style={{ display: 'block' }}><Money amount={gstr1?.totalCgst || 0} /></strong>
                  </div>
                  <div style={{ padding: 8, background: 'var(--color-surface)', border: '1px solid var(--color-border)', borderRadius: 'var(--radius-md)' }}>
                    <span className="cell-muted" style={{ fontSize: '0.75rem' }}>SGST Output</span>
                    <strong style={{ display: 'block' }}><Money amount={gstr1?.totalSgst || 0} /></strong>
                  </div>
                  <div style={{ padding: 8, background: 'var(--color-surface)', border: '1px solid var(--color-border)', borderRadius: 'var(--radius-md)' }}>
                    <span className="cell-muted" style={{ fontSize: '0.75rem' }}>IGST Output</span>
                    <strong style={{ display: 'block' }}><Money amount={gstr1?.totalIgst || 0} /></strong>
                  </div>
                </div>
              </div>
            </div>

            {/* GSTR-3B Tax Computation Panel */}
            <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 'var(--space-sm)' }}>
                <h3 style={{ fontSize: '1.05rem', fontWeight: 600 }}>GSTR-3B Tax Liability & Offset</h3>
                <a
                  className="btn btn--secondary"
                  href={`/api/v1/gst/gstr3b/export?year=${selectedYear}&month=${selectedMonth}`}
                  style={{ fontSize: '0.8rem', padding: '4px 8px' }}
                >
                  <Download aria-hidden="true" size={12} style={{ marginRight: 4 }} />
                  GSTR-3B JSON
                </a>
              </div>

              <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 12px', background: 'var(--color-bg-subtle)', borderRadius: 'var(--radius-md)' }}>
                  <span>3.1(a) Outward Taxable Supplies</span>
                  <strong><Money amount={gstr3b?.outwardTaxable || 0} /></strong>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 12px', background: 'var(--color-bg-subtle)', borderRadius: 'var(--radius-md)' }}>
                  <span>4(A)(5) All Other Eligible ITC</span>
                  <strong style={{ color: 'var(--color-success)' }}>
                    + <Money amount={(gstr3b?.itcAllOther.cgst || 0) + (gstr3b?.itcAllOther.sgst || 0) + (gstr3b?.itcAllOther.igst || 0)} />
                  </strong>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 12px', background: 'var(--color-bg-subtle)', borderRadius: 'var(--radius-md)' }}>
                  <span>4(B) Ineligible ITC / Reversals</span>
                  <strong style={{ color: 'var(--color-error)' }}>
                    - <Money amount={(gstr3b?.itcIneligible.cgst || 0) + (gstr3b?.itcIneligible.sgst || 0) + (gstr3b?.itcIneligible.igst || 0)} />
                  </strong>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 12px', background: 'var(--color-surface)', border: '1px solid var(--color-border)', borderRadius: 'var(--radius-md)' }}>
                  <span style={{ fontWeight: 600 }}>Table 6.1 Net Tax Payable in Cash</span>
                  <strong style={{ color: 'var(--color-error)', fontSize: '1.05rem' }}>
                    <Money amount={(gstr3b?.netPayable.cgst || 0) + (gstr3b?.netPayable.sgst || 0) + (gstr3b?.netPayable.igst || 0)} />
                  </strong>
                </div>
              </div>

              {/* Compliance Deadlines */}
              <div style={{ marginTop: 'var(--space-md)', paddingTop: 'var(--space-sm)', borderTop: '1px solid var(--color-border)' }}>
                <h4 style={{ fontSize: '0.85rem', fontWeight: 600, color: 'var(--color-text-secondary)', marginBottom: 6 }}>
                  Upcoming Statutory Deadlines
                </h4>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
                  {deadlines.slice(0, 3).map((dl, idx) => (
                    <div key={idx} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: '0.8rem' }}>
                      <span style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                        <Clock aria-hidden="true" size={12} />
                        <strong>{dl.form}</strong> - {dl.description}
                      </span>
                      <StatusChip status={dl.isOverdue ? 'OVERDUE' : `${dl.daysRemaining} days left`} />
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */}
      {/* TAB 2: IMS ACTION WORKBENCH (SEC 38) */}
      {/* â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */}
      {activeTab === 'ims' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-md)' }}>
          {/* Deemed acceptance warning alert */}
          <div
            style={{
              padding: '12px 16px',
              borderRadius: 'var(--radius-md)',
              background: 'rgba(234, 88, 12, 0.08)',
              border: '1px solid rgba(234, 88, 12, 0.3)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <ShieldAlert color="rgb(234, 88, 12)" size={20} />
              <div>
                <strong style={{ color: 'rgb(234, 88, 12)' }}>Sec 38 IMS Action Rule in Effect</strong>
                <p style={{ fontSize: '0.85rem', color: 'var(--color-text-secondary)', margin: 0 }}>
                  Unactioned inward invoices automatically default to <strong>Deemed Accepted</strong> in GSTR-2B upon period cutoff. Action your invoices to avoid unwanted ITC liabilities.
                </p>
              </div>
            </div>
            <Button
              disabled={applyAiMutation.isPending}
              onClick={() => applyAiMutation.mutate()}
              variant="primary"
            >
              <Zap aria-hidden="true" size={14} style={{ marginRight: 6 }} />
              {applyAiMutation.isPending ? 'Applying...' : 'Apply AI Recommendations'}
            </Button>
          </div>

          {/* IMS KPI summary strip */}
          <div className="summary-strip">
            <div className="summary-card">
              <span className="summary-card__label">Total Inward Invoices</span>
              <strong className="summary-card__value">
                <Quantity value={imsSummary?.totalEntries || 0} />
              </strong>
              <span className="summary-card__hint">
                Exposure: <Money amount={imsSummary?.totalItcExposure || 0} />
              </span>
            </div>

            <div className="summary-card">
              <span className="summary-card__label">Pending Action</span>
              <strong className="summary-card__value" style={{ color: 'var(--color-warning)' }}>
                <Quantity value={imsSummary?.noActionCount || 0} />
              </strong>
              <span className="summary-card__hint">
                At risk: <Money amount={imsSummary?.noActionItc || 0} />
              </span>
            </div>

            <div className="summary-card">
              <span className="summary-card__label">Accepted</span>
              <strong className="summary-card__value" style={{ color: 'var(--color-success)' }}>
                <Quantity value={imsSummary?.acceptedCount || 0} />
              </strong>
              <span className="summary-card__hint">Eligible for GSTR-2B credit</span>
            </div>

            <div className="summary-card">
              <span className="summary-card__label">Rejected / Disputed</span>
              <strong className="summary-card__value" style={{ color: 'var(--color-error)' }}>
                <Quantity value={imsSummary?.rejectedCount || 0} />
              </strong>
              <span className="summary-card__hint">Removed from 2B claim</span>
            </div>
          </div>

          {/* Toolbar & Filters */}
          <div className="list-toolbar" style={{ justifyContent: 'space-between' }}>
            <div style={{ display: 'flex', gap: 'var(--space-sm)', alignItems: 'center' }}>
              <div className="search-field" style={{ width: 280 }}>
                <Search aria-hidden="true" size={16} />
                <input
                  aria-label="Search invoices by number or GSTIN"
                  onChange={(e) => setImsSearchTerm(e.target.value)}
                  placeholder="Search invoice or supplier..."
                  type="text"
                  value={imsSearchTerm}
                />
              </div>

              <div className="filter-chips">
                {[
                  { key: 'ALL', label: 'All Invoices' },
                  { key: 'PENDING_ACTION', label: 'Unactioned' },
                  { key: 'ACCEPTED', label: 'Accepted' },
                  { key: 'REJECTED', label: 'Rejected' },
                  { key: 'PENDING', label: 'Pending / Hold' },
                ].map((f) => (
                  <button
                    key={f.key}
                    className={`filter-chip ${imsStatusFilter === f.key ? 'filter-chip--active' : ''}`}
                    onClick={() => setImsStatusFilter(f.key)}
                    type="button"
                  >
                    {f.label}
                  </button>
                ))}
              </div>
            </div>

            {selectedImsIds.length > 0 && (
              <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
                <span style={{ fontSize: '0.85rem', fontWeight: 600 }}>{selectedImsIds.length} selected:</span>
                <Button
                  onClick={() => bulkActionMutation.mutate({ ids: selectedImsIds, action: 'ACCEPT' })}
                  variant="primary"
                >
                  Accept Selected
                </Button>
                <Button
                  onClick={() => bulkActionMutation.mutate({ ids: selectedImsIds, action: 'REJECT' })}
                  variant="destructive"
                >
                  Reject Selected
                </Button>
              </div>
            )}
          </div>

          {/* IMS Invoices Table */}
          <DataTable caption="IMS Inward Invoices Workbench">
            <thead>
              <tr>
                <th scope="col" style={{ width: 36 }}>
                  <input
                    aria-label="Select all rows"
                    checked={selectedImsIds.length > 0 && selectedImsIds.length === filteredImsEntries.length}
                    onChange={toggleSelectAllIms}
                    type="checkbox"
                  />
                </th>
                <th scope="col">Supplier & GSTIN</th>
                <th scope="col">Invoice Details</th>
                <th className="numeric-cell" scope="col">Taxable Value</th>
                <th className="numeric-cell" scope="col">ITC Claimable</th>
                <th scope="col">Match Status</th>
                <th scope="col">AI Recommendation</th>
                <th scope="col">IMS Action</th>
                <th className="numeric-cell" scope="col">Action</th>
              </tr>
            </thead>
            <tbody>
              {filteredImsEntries.map((entry) => (
                <tr key={entry.id}>
                  <td>
                    <input
                      aria-label={`Select invoice ${entry.invoiceNumber}`}
                      checked={selectedImsIds.includes(entry.id)}
                      onChange={() => toggleSelectIms(entry.id)}
                      type="checkbox"
                    />
                  </td>
                  <td>
                    <strong>{entry.supplierTradeName || entry.supplierLegalName || 'Supplier'}</strong>
                    <span className="table-code" style={{ display: 'block', fontSize: '0.75rem', marginTop: 2 }}>
                      {entry.supplierGstin}
                    </span>
                  </td>
                  <td>
                    <span className="table-code">{entry.invoiceNumber}</span>
                    <span className="cell-muted" style={{ display: 'block', fontSize: '0.75rem' }}>
                      {entry.invoiceDate}
                    </span>
                  </td>
                  <td className="numeric-cell">
                    <Money amount={entry.taxableValue} />
                  </td>
                  <td className="numeric-cell">
                    <strong style={{ color: 'var(--color-primary)' }}>
                      <Money amount={entry.cgst + entry.sgst + entry.igst} />
                    </strong>
                  </td>
                  <td>
                    <StatusChip status={entry.matchStatus} />
                  </td>
                  <td>
                    {entry.aiRecommendedAction ? (
                      <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, fontSize: '0.8rem', color: 'var(--color-primary)', fontWeight: 600 }}>
                        <Bot aria-hidden="true" size={12} />
                        {entry.aiRecommendedAction}
                      </span>
                    ) : (
                      <span className="cell-muted">Ã¢â‚¬â€</span>
                    )}
                  </td>
                  <td>
                    <StatusChip status={entry.imsAction || 'NO_ACTION'} />
                  </td>
                  <td className="numeric-cell">
                    <div style={{ display: 'flex', gap: 4, justifyContent: 'flex-end' }}>
                      <Button
                        onClick={() => {
                          setActiveImsEntry(entry)
                          setImsRemarks(entry.imsRemarks || '')
                        }}
                        variant="secondary"
                      >
                        Action
                      </Button>
                      {entry.imsAction && (
                        <Button
                          onClick={() => resetActionMutation.mutate(entry.id)}
                          variant="ghost"
                        >
                          Reset
                        </Button>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        </div>
      )}

      {/* â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */}
      {/* TAB 3: GSTR-2B RECON & ITC RISK */}
      {/* â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */}
      {activeTab === 'recon' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-md)' }}>
          <div className="summary-strip">
            <div className="summary-card">
              <span className="summary-card__label">Total ITC At Risk</span>
              <strong className="summary-card__value" style={{ color: 'var(--color-error)' }}>
                <Money amount={itcRisk?.totalItcAtRisk || 0} />
              </strong>
              <span className="summary-card__hint">From delayed/unfiled supplier GSTR-1</span>
            </div>

            <div className="summary-card">
              <span className="summary-card__label">High Risk Suppliers</span>
              <strong className="summary-card__value">
                <Quantity value={itcRisk?.totalSuppliersAtRisk || 0} />
              </strong>
              <span className="summary-card__hint">Requires follow-up communication</span>
            </div>

            <div className="summary-card summary-card--accent">
              <span className="summary-card__label">Action Trigger</span>
              <Button
                disabled={alertMutation.isPending}
                onClick={() => alertMutation.mutate()}
                variant="primary"
              >
                <RefreshCw aria-hidden="true" size={14} style={{ marginRight: 6 }} />
                {alertMutation.isPending ? 'Syncing...' : 'Sync 2A & Raise Alerts'}
              </Button>
            </div>
          </div>

          <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
            <h3 style={{ fontSize: '1.05rem', fontWeight: 600, marginBottom: 'var(--space-sm)' }}>
              Supplier Non-Compliance & ITC Exposure Ledger
            </h3>
            <DataTable caption="Supplier ITC risk list">
              <thead>
                <tr>
                  <th scope="col">Supplier GSTIN & Name</th>
                  <th className="numeric-cell" scope="col">Pending Invoices</th>
                  <th className="numeric-cell" scope="col">ITC Blocked</th>
                  <th scope="col">Portal GSTR-1 Status</th>
                  <th scope="col">Risk Level</th>
                  <th className="numeric-cell" scope="col">Follow-up Action</th>
                </tr>
              </thead>
              <tbody>
                {(itcRisk?.suppliers ?? []).map((sup) => (
                  <tr key={sup.supplierGstin}>
                    <td>
                      <strong>{sup.supplierName}</strong>
                      <span className="table-code" style={{ display: 'block', fontSize: '0.75rem', marginTop: 2 }}>
                        {sup.supplierGstin}
                      </span>
                    </td>
                    <td className="numeric-cell">
                      <Quantity value={sup.invoiceCount} />
                    </td>
                    <td className="numeric-cell">
                      <strong style={{ color: 'var(--color-error)' }}>
                        <Money amount={sup.totalItcAtRisk} />
                      </strong>
                    </td>
                    <td>
                      <StatusChip status={sup.gstr1FilingStatus} />
                    </td>
                    <td>
                      <StatusChip status={sup.riskLevel} />
                    </td>
                    <td className="numeric-cell">
                      <a
                        className="btn btn--secondary"
                        href={`mailto:accounts@supplier.com?subject=Pending%20GSTR-1%20Filing%20for%20${periodString}`}
                        style={{ fontSize: '0.8rem', padding: '4px 8px' }}
                      >
                        Send Payment Hold Alert
                      </a>
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          </div>
        </div>
      )}

      {/* â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */}
      {/* TAB 4: E-WAY BILLS & E-INVOICES (IRN) */}
      {/* â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */}
      {activeTab === 'einvoice_ewb' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-lg)' }}>
          {/* E-Way Bills Section */}
          <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 'var(--space-sm)' }}>
              <div>
                <h3 style={{ fontSize: '1.1rem', fontWeight: 600 }}>e-Way Bills (Transit Compliance)</h3>
                <p className="cell-muted" style={{ fontSize: '0.85rem' }}>
                  Statutory transit documents for consignments exceeding Ã¢â€šÂ¹50,000 threshold.
                </p>
              </div>
            </div>

            <DataTable caption="e-Way bills list">
              <thead>
                <tr>
                  <th scope="col">Doc Number</th>
                  <th scope="col">Date</th>
                  <th scope="col">Route & Distance</th>
                  <th scope="col">Vehicle / Transporter</th>
                  <th className="numeric-cell" scope="col">Consignment Value</th>
                  <th scope="col">EWB Number</th>
                  <th scope="col">Status</th>
                  <th className="numeric-cell" scope="col">Actions</th>
                </tr>
              </thead>
              <tbody>
                {ewayBills.map((ewb) => (
                  <tr key={ewb.id}>
                    <td>
                      <span className="table-code">{ewb.documentNumber}</span>
                      <span className="cell-muted" style={{ display: 'block', fontSize: '0.75rem' }}>
                        {ewb.documentType}
                      </span>
                    </td>
                    <td>
                      <span className="cell-muted">{ewb.documentDate}</span>
                    </td>
                    <td>
                      <strong>{ewb.fromPincode} &rarr; {ewb.toPincode}</strong>
                      <span className="cell-muted" style={{ display: 'block', fontSize: '0.75rem' }}>
                        {ewb.distanceKm} km
                      </span>
                    </td>
                    <td>
                      <strong>{ewb.vehicleNumber || '—'}</strong>
                      <span className="cell-muted" style={{ display: 'block', fontSize: '0.75rem' }}>
                        {ewb.transporterName || 'Self / Own Fleet'}
                      </span>
                    </td>
                    <td className="numeric-cell">
                      <Money amount={ewb.totalAmount} />
                    </td>
                    <td>
                      {ewb.ewbNumber ? (
                        <span className="table-code" style={{ color: 'var(--color-success)', fontWeight: 600 }}>
                          {ewb.ewbNumber}
                        </span>
                      ) : (
                        <span className="cell-muted">Pending Generation</span>
                      )}
                    </td>
                    <td>
                      <StatusChip status={ewb.status} />
                    </td>
                    <td className="numeric-cell">
                      <div style={{ display: 'flex', gap: 4, justifyContent: 'flex-end' }}>
                        {ewb.status === 'PENDING' && (
                          <>
                            <Button
                              onClick={() => ewbGspMutation.mutate(ewb.id)}
                              variant="primary"
                            >
                              Generate GSP
                            </Button>
                            <Button
                              onClick={() => {
                                setActiveEwb(ewb)
                                setIsRecordEwbOpen(true)
                              }}
                              variant="secondary"
                            >
                              Record No.
                            </Button>
                          </>
                        )}
                        {ewb.status === 'GENERATED' && (
                          <Button
                            onClick={() => cancelEwbMutation.mutate(ewb.id)}
                            variant="destructive"
                          >
                            Cancel
                          </Button>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          </div>

          {/* E-Invoices (IRN) Section */}
          <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 'var(--space-sm)' }}>
              <div>
                <h3 style={{ fontSize: '1.1rem', fontWeight: 600 }}>e-Invoices (IRN & Signed QR Code)</h3>
                <p className="cell-muted" style={{ fontSize: '0.85rem' }}>
                  Mandatory B2B Invoice Registration Portal (IRP) hash generation and statutory validation.
                </p>
              </div>
            </div>

            <DataTable caption="e-Invoices list">
              <thead>
                <tr>
                  <th scope="col">Invoice Number</th>
                  <th scope="col">Date</th>
                  <th scope="col">Customer GSTIN & Name</th>
                  <th className="numeric-cell" scope="col">Invoice Total</th>
                  <th scope="col">IRN / Ack Number</th>
                  <th scope="col">Status</th>
                  <th className="numeric-cell" scope="col">Actions</th>
                </tr>
              </thead>
              <tbody>
                {einvoices.map((einv) => (
                  <tr key={einv.id}>
                    <td>
                      <span className="table-code">{einv.invoiceNumber}</span>
                    </td>
                    <td>
                      <span className="cell-muted">{einv.invoiceDate}</span>
                    </td>
                    <td>
                      <strong>{einv.customerName}</strong>
                      <span className="table-code" style={{ display: 'block', fontSize: '0.75rem', marginTop: 2 }}>
                        {einv.customerGstin}
                      </span>
                    </td>
                    <td className="numeric-cell">
                      <Money amount={einv.totalAmount} />
                    </td>
                    <td>
                      {einv.irn ? (
                        <div>
                          <span className="table-code" style={{ fontSize: '0.7rem', color: 'var(--color-primary)' }}>
                            {einv.irn.slice(0, 16)}...
                          </span>
                          <span className="cell-muted" style={{ display: 'block', fontSize: '0.75rem' }}>
                            Ack: {einv.ackNumber || '—'}
                          </span>
                        </div>
                      ) : (
                        <span className="cell-muted">Unregistered</span>
                      )}
                    </td>
                    <td>
                      <StatusChip status={einv.status} />
                    </td>
                    <td className="numeric-cell">
                      <div style={{ display: 'flex', gap: 4, justifyContent: 'flex-end' }}>
                        {einv.status === 'PENDING' && (
                          <>
                            <Button
                              onClick={() => einvoiceGspMutation.mutate(einv.id)}
                              variant="primary"
                            >
                              Generate IRN
                            </Button>
                            <Button
                              onClick={() => {
                                setActiveEInvoice(einv)
                                setIsRecordIrnOpen(true)
                              }}
                              variant="secondary"
                            >
                              Record IRN
                            </Button>
                          </>
                        )}
                        {einv.status === 'GENERATED' && (
                          <Button
                            onClick={() => cancelEInvoiceMutation.mutate(einv.id)}
                            variant="destructive"
                          >
                            Cancel
                          </Button>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          </div>
        </div>
      )}

      {/* â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */}
      {/* TAB 5: MONTH-END CLOSE CHECKLIST */}
      {/* â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */}
      {activeTab === 'close' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-md)' }}>
          <div className="summary-strip">
            <div className="summary-card">
              <span className="summary-card__label">Filing Readiness State</span>
              <strong className="summary-card__value">
                <StatusChip status={closeChecklist?.overallStatus === 'GREEN' ? 'READY_TO_FILE' : 'ACTION_REQUIRED'} />
              </strong>
              <span className="summary-card__hint">Overall period traffic-light</span>
            </div>

            <div className="summary-card">
              <span className="summary-card__label">Audit Checklist Tasks</span>
              <strong className="summary-card__value">
                <Quantity value={closeChecklist?.items.length || 0} /> tasks
              </strong>
              <span className="summary-card__hint">Automated readiness checks</span>
            </div>
          </div>

          <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
            <h3 style={{ fontSize: '1.05rem', fontWeight: 600, marginBottom: 'var(--space-sm)' }}>
              Month-End GST Close & Period Lock Checklist ({periodString})
            </h3>

            <DataTable caption="Month end checklist">
              <thead>
                <tr>
                  <th scope="col">Compliance Area</th>
                  <th scope="col">Requirement & Verification</th>
                  <th scope="col">Status</th>
                  <th scope="col">Audit Detail</th>
                </tr>
              </thead>
              <tbody>
                {(closeChecklist?.items ?? []).map((item) => (
                  <tr key={item.id}>
                    <td>
                      <strong>{item.category}</strong>
                    </td>
                    <td>
                      <span>{item.title}</span>
                    </td>
                    <td>
                      <StatusChip status={item.status} />
                    </td>
                    <td>
                      <span className="cell-muted">{item.detail}</span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          </div>
        </div>
      )}

      {/* MODAL: ACTION SINGLE IMS INVOICE */}
      {activeImsEntry && (
        <div
          role="dialog"
          aria-modal="true"
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
            }}
          >
            <h3 style={{ fontSize: '1.2rem', fontWeight: 600, marginBottom: 'var(--space-xs)' }}>
              Action Inward Invoice (Sec 38)
            </h3>
            <p className="cell-muted" style={{ fontSize: '0.85rem', marginBottom: 'var(--space-md)' }}>
              Invoice <strong>{activeImsEntry.invoiceNumber}</strong> from <strong>{activeImsEntry.supplierTradeName || activeImsEntry.supplierGstin}</strong> (Ã¢â€šÂ¹{activeImsEntry.taxableValue})
            </p>

            <div style={{ marginBottom: 'var(--space-md)' }}>
              <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 6 }}>
                IMS Decision
              </label>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 8 }}>
                <Button
                  onClick={() => actionMutation.mutate({ id: activeImsEntry.id, action: 'ACCEPT', remarks: imsRemarks })}
                  variant="primary"
                >
                  Accept
                </Button>
                <Button
                  onClick={() => actionMutation.mutate({ id: activeImsEntry.id, action: 'REJECT', remarks: imsRemarks })}
                  variant="destructive"
                >
                  Reject
                </Button>
                <Button
                  onClick={() => actionMutation.mutate({ id: activeImsEntry.id, action: 'PENDING', remarks: imsRemarks })}
                  variant="secondary"
                >
                  Hold / Pending
                </Button>
              </div>
            </div>

            <div style={{ marginBottom: 'var(--space-md)' }}>
              <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                Reason / Audit Remarks (Optional)
              </label>
              <input
                style={{
                  width: '100%',
                  padding: '8px 12px',
                  borderRadius: 'var(--radius-md)',
                  border: '1px solid var(--color-border)',
                }}
                onChange={(e) => setImsRemarks(e.target.value)}
                placeholder="e.g. Price dispute on line 3, pending vendor credit"
                type="text"
                value={imsRemarks}
              />
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
              <Button onClick={() => setActiveImsEntry(null)} variant="secondary">
                Close
              </Button>
            </div>
          </div>
        </div>
      )}

      {/* MODAL: RECORD MANUAL E-WAY BILL */}
      {isRecordEwbOpen && activeEwb && (
        <div
          role="dialog"
          aria-modal="true"
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
            <h3 style={{ fontSize: '1.2rem', fontWeight: 600, marginBottom: 'var(--space-xs)' }}>
              Record e-Way Bill Number
            </h3>
            <p className="cell-muted" style={{ fontSize: '0.85rem', marginBottom: 'var(--space-md)' }}>
              Document: <strong>{activeEwb.documentNumber}</strong>
            </p>

            <div style={{ marginBottom: 'var(--space-md)' }}>
              <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                12-digit EWB Number
              </label>
              <input
                style={{
                  width: '100%',
                  padding: '8px 12px',
                  borderRadius: 'var(--radius-md)',
                  border: '1px solid var(--color-border)',
                  fontFamily: 'monospace',
                  fontSize: '1rem',
                  fontWeight: 600,
                }}
                onChange={(e) => setManualEwbNumber(e.target.value)}
                placeholder="e.g. 181029384756"
                type="text"
                value={manualEwbNumber}
              />
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
              <Button onClick={() => setIsRecordEwbOpen(false)} variant="secondary">
                Cancel
              </Button>
              <Button
                disabled={!manualEwbNumber.trim()}
                onClick={() => recordEwbMutation.mutate({ id: activeEwb.id, ewbNo: manualEwbNumber })}
                variant="primary"
              >
                Save EWB No.
              </Button>
            </div>
          </div>
        </div>
      )}

      {/* MODAL: RECORD MANUAL E-INVOICE IRN */}
      {isRecordIrnOpen && activeEInvoice && (
        <div
          role="dialog"
          aria-modal="true"
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
            }}
          >
            <h3 style={{ fontSize: '1.2rem', fontWeight: 600, marginBottom: 'var(--space-xs)' }}>
              Record e-Invoice IRN & Ack
            </h3>
            <p className="cell-muted" style={{ fontSize: '0.85rem', marginBottom: 'var(--space-md)' }}>
              Invoice: <strong>{activeEInvoice.invoiceNumber}</strong>
            </p>

            <div style={{ marginBottom: 'var(--space-sm)' }}>
              <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                64-character IRN Hash
              </label>
              <input
                style={{
                  width: '100%',
                  padding: '8px 12px',
                  borderRadius: 'var(--radius-md)',
                  border: '1px solid var(--color-border)',
                  fontFamily: 'monospace',
                  fontSize: '0.85rem',
                }}
                onChange={(e) => setManualIrn(e.target.value)}
                placeholder="e.g. 4a2b9f..."
                type="text"
                value={manualIrn}
              />
            </div>

            <div style={{ marginBottom: 'var(--space-md)' }}>
              <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                IRP Acknowledgement Number (Optional)
              </label>
              <input
                style={{
                  width: '100%',
                  padding: '8px 12px',
                  borderRadius: 'var(--radius-md)',
                  border: '1px solid var(--color-border)',
                }}
                onChange={(e) => setManualAckNo(e.target.value)}
                placeholder="e.g. 1223490123"
                type="text"
                value={manualAckNo}
              />
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
              <Button onClick={() => setIsRecordIrnOpen(false)} variant="secondary">
                Cancel
              </Button>
              <Button
                disabled={!manualIrn.trim()}
                onClick={() => recordIrnMutation.mutate({ id: activeEInvoice.id, irn: manualIrn, ackNo: manualAckNo })}
                variant="primary"
              >
                Save IRN
              </Button>
            </div>
          </div>
        </div>
      )}
    </section>
  )
}