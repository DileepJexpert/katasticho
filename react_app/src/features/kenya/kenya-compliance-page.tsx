import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import {
  Globe,
  Smartphone,
  CheckCircle2,
    DollarSign,
    } from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDateTime } from '@/shared/format/format'
import {
  listKraEtimsInvoices,
  submitToKraEtims,
  listMpesaTransactions,
  initiateMpesaStkPush,
  calculateKenyaPaye,
  type KenyaPayeResult,
} from '@/features/kenya/kenya-api'

type TabKey = 'etims' | 'mpesa' | 'paye'

export function KenyaCompliancePage() {
  const queryClient = useQueryClient()
  const [activeTab, setActiveTab] = useState<TabKey>('etims')
  const [feedback, setFeedback] = useState<string | null>(null)

  // M-Pesa STK Modal
  const [isStkOpen, setIsStkOpen] = useState(false)
  const [stkPhone, setStkPhone] = useState('254712345678')
  const [stkAmount, setStkAmount] = useState('1500')
  const [stkRef, setStkRef] = useState('INV-2026-001')

  // PAYE Calculator State
  const [calcGross, setCalcGross] = useState('75000')
  const [payeResult, setPayeResult] = useState<KenyaPayeResult | null>(null)

  // Queries
  const etimsQuery = useQuery({
    queryKey: ['kenya-etims-invoices'],
    queryFn: () => listKraEtimsInvoices(),
    enabled: activeTab === 'etims',
  })

  const mpesaQuery = useQuery({
    queryKey: ['kenya-mpesa-transactions'],
    queryFn: () => listMpesaTransactions(),
    enabled: activeTab === 'mpesa',
  })

  // Mutations
  const submitEtimsMutation = useMutation({
    mutationFn: (invoiceId: string) => submitToKraEtims(invoiceId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['kenya-etims-invoices'] })
      setFeedback('Invoice submitted to KRA eTIMS server. QR code generated.')
    },
  })

  const stkPushMutation = useMutation({
    mutationFn: () => initiateMpesaStkPush({
      phoneNumber: stkPhone,
      amount: Number(stkAmount),
      accountReference: stkRef,
      transactionDesc: 'Katasticho POS Payment',
    }),
    onSuccess: (res) => {
      setIsStkOpen(false)
      queryClient.invalidateQueries({ queryKey: ['kenya-mpesa-transactions'] })
      setFeedback(`M-Pesa STK push prompt sent to ${stkPhone} (${res.checkoutRequestId}).`)
    },
  })

  const handleCalculatePaye = async () => {
    const res = await calculateKenyaPaye(Number(calcGross))
    setPayeResult(res)
  }

  const etimsInvoices = etimsQuery.data ?? []
  const mpesaTransactions = mpesaQuery.data ?? []

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Internationalization / Africa"
        title="Kenya Statutory Localization Pack"
        description="KRA eTIMS electronic invoice transmissions, Safaricom Daraja M-Pesa STK push payments, and Kenya PAYE/SHIF statutory payroll calculations."
        actions={
          <div className="table-actions">
            {activeTab === 'mpesa' && (
              <Button onClick={() => setIsStkOpen(true)} variant="primary">
                <Smartphone aria-hidden="true" size={16} />
                Initiate M-Pesa STK Push
              </Button>
            )}
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
          aria-selected={activeTab === 'etims'}
          className={activeTab === 'etims' ? 'list-tab list-tab--active' : 'list-tab'}
          onClick={() => setActiveTab('etims')}
          role="tab"
          type="button"
        >
          <Globe size={15} style={{ marginRight: '6px' }} />
          KRA eTIMS Transmissions ({etimsInvoices.length})
        </button>
        <button
          aria-selected={activeTab === 'mpesa'}
          className={activeTab === 'mpesa' ? 'list-tab list-tab--active' : 'list-tab'}
          onClick={() => setActiveTab('mpesa')}
          role="tab"
          type="button"
        >
          <Smartphone size={15} style={{ marginRight: '6px' }} />
          M-Pesa Mobile Payments ({mpesaTransactions.length})
        </button>
        <button
          aria-selected={activeTab === 'paye'}
          className={activeTab === 'paye' ? 'list-tab list-tab--active' : 'list-tab'}
          onClick={() => setActiveTab('paye')}
          role="tab"
          type="button"
        >
          <DollarSign size={15} style={{ marginRight: '6px' }} />
          Kenya PAYE & SHIF Calculator
        </button>
      </div>

      {activeTab === 'etims' && (
        <div style={{ marginTop: '16px' }}>
          {etimsQuery.isLoading ? (
            <div className="directory-state">Loading eTIMS transmissions...</div>
          ) : etimsInvoices.length === 0 ? (
            <div className="directory-state">
              <Globe size={24} />
              <strong>No eTIMS invoices transmitted to KRA yet.</strong>
            </div>
          ) : (
            <DataTable caption="KRA eTIMS invoices">
              <thead>
                <tr>
                  <th scope="col">Invoice #</th>
                  <th scope="col">Customer PIN</th>
                  <th scope="col">Customer Name</th>
                  <th className="numeric-cell" scope="col">Taxable Value</th>
                  <th className="numeric-cell" scope="col">VAT (16%)</th>
                  <th className="numeric-cell" scope="col">Total (KES)</th>
                  <th scope="col">Control #</th>
                  <th scope="col">Status</th>
                  <th scope="col">Action</th>
                </tr>
              </thead>
              <tbody>
                {etimsInvoices.map((inv) => (
                  <tr key={inv.id}>
                    <td className="cell-id"><strong>{inv.invoiceNumber}</strong></td>
                    <td className="font-mono">{inv.customerPin || '—'}</td>
                    <td>{inv.customerName || 'Customer'}</td>
                    <td className="numeric-cell"><Money amount={inv.taxableAmount} currency="KES" /></td>
                    <td className="numeric-cell"><Money amount={inv.vatAmount} currency="KES" /></td>
                    <td className="numeric-cell" style={{ fontWeight: 600 }}><Money amount={inv.totalAmount} currency="KES" /></td>
                    <td className="font-mono">{inv.controlNumber || '—'}</td>
                    <td><StatusChip status={inv.status} /></td>
                    <td>
                      {inv.status !== "ACCEPTED" && (
                        <Button
                          disabled={submitEtimsMutation.isPending}
                          onClick={() => submitEtimsMutation.mutate(inv.invoiceId || inv.id)}
                          variant="secondary"
                        >
                          Re-submit
                        </Button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          )}
        </div>
      )}

      {activeTab === 'mpesa' && (
        <div style={{ marginTop: '16px' }}>
          {mpesaQuery.isLoading ? (
            <div className="directory-state">Loading M-Pesa transactions...</div>
          ) : mpesaTransactions.length === 0 ? (
            <div className="directory-state">
              <Smartphone size={24} />
              <strong>No M-Pesa mobile money receipts logged yet.</strong>
            </div>
          ) : (
            <DataTable caption="M-Pesa receipts">
              <thead>
                <tr>
                  <th scope="col">Receipt #</th>
                  <th scope="col">Phone Number</th>
                  <th className="numeric-cell" scope="col">Amount (KES)</th>
                  <th scope="col">Account Ref</th>
                  <th scope="col">Status</th>
                  <th scope="col">Date</th>
                </tr>
              </thead>
              <tbody>
                {mpesaTransactions.map((tx) => (
                  <tr key={tx.id}>
                    <td className="cell-id"><strong>{tx.mpesaReceiptNumber || tx.checkoutRequestId.slice(0, 10)}</strong></td>
                    <td className="font-mono">{tx.phoneNumber}</td>
                    <td className="numeric-cell" style={{ fontWeight: 600, color: 'var(--color-primary)' }}>
                      <Money amount={tx.amount} currency="KES" />
                    </td>
                    <td>{tx.referenceId || 'POS'}</td>
                    <td><StatusChip status={tx.status} /></td>
                    <td>{tx.createdAt ? formatDateTime(tx.createdAt) : '—'}</td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          )}
        </div>
      )}

      {activeTab === 'paye' && (
        <section className="document-card" style={{ maxWidth: '650px', marginTop: '16px' }}>
          <h2>Kenya Statutory Payroll Calculator</h2>
          <p style={{ fontSize: '13px', color: 'var(--text-muted)', marginBottom: '16px' }}>
            Calculates 2026 Kenya statutory bands: PAYE graduated tax, SHIF (2.75%), NSSF Tier 1 & Tier 2, and Affordable Housing Levy (1.5%).
          </p>

          <div style={{ display: 'flex', gap: '8px', marginBottom: '16px' }}>
            <input
              className="search-input"
              onChange={(e) => setCalcGross(e.target.value)}
              placeholder="Gross Salary (KES)"
              style={{ width: '200px' }}
              type="number"
              value={calcGross}
            />
            <Button onClick={handleCalculatePaye} variant="primary">
              Calculate Deductions
            </Button>
          </div>

          {payeResult && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', background: 'var(--bg-subtle)', padding: '16px', borderRadius: '6px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                <span>Gross Monthly Salary:</span>
                <strong><Money amount={payeResult.grossSalary} currency="KES" /></strong>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                <span>NSSF (Tier 1 + Tier 2):</span>
                <span><Money amount={payeResult.totalNssf} currency="KES" /></span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                <span>Taxable Pay:</span>
                <span><Money amount={payeResult.taxablePay} currency="KES" /></span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                <span>PAYE Tax (Net of Personal Relief):</span>
                <span style={{ color: 'var(--color-primary)', fontWeight: 600 }}>
                  <Money amount={payeResult.netPaye} currency="KES" />
                </span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                <span>SHIF / NHIF (2.75%):</span>
                <span><Money amount={payeResult.nhifShif} currency="KES" /></span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                <span>Affordable Housing Levy (1.5%):</span>
                <span><Money amount={payeResult.housingLevy} currency="KES" /></span>
              </div>
              <hr style={{ border: 'none', borderTop: '1px solid var(--border-subtle)', margin: '8px 0' }} />
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '16px' }}>
                <strong>Net Take-Home Pay:</strong>
                <strong style={{ color: 'var(--color-success)' }}>
                  <Money amount={payeResult.netTakeHome} currency="KES" />
                </strong>
              </div>
            </div>
          )}
        </section>
      )}

      {/* M-Pesa STK Modal */}
      {isStkOpen && (
        <div className="modal-backdrop">
          <div className="modal-card">
            <h3>Initiate M-Pesa STK Push Payment</h3>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', marginTop: '12px' }}>
              <label>
                <span style={{ fontSize: '13px', fontWeight: 600 }}>Customer Safaricom Number (254...):</span>
                <input
                  className="search-input"
                  onChange={(e) => setStkPhone(e.target.value)}
                  placeholder="e.g. 254712345678"
                  style={{ width: '100%', marginTop: '4px' }}
                  value={stkPhone}
                />
              </label>
              <label>
                <span style={{ fontSize: '13px', fontWeight: 600 }}>Amount (KES):</span>
                <input
                  className="search-input"
                  onChange={(e) => setStkAmount(e.target.value)}
                  style={{ width: '100%', marginTop: '4px' }}
                  type="number"
                  value={stkAmount}
                />
              </label>
              <label>
                <span style={{ fontSize: '13px', fontWeight: 600 }}>Account Reference / Invoice #:</span>
                <input
                  className="search-input"
                  onChange={(e) => setStkRef(e.target.value)}
                  style={{ width: '100%', marginTop: '4px' }}
                  value={stkRef}
                />
              </label>
            </div>

            <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end', marginTop: '16px' }}>
              <Button onClick={() => setIsStkOpen(false)} variant="secondary">Cancel</Button>
              <Button
                disabled={stkPushMutation.isPending || !stkPhone || !stkAmount}
                onClick={() => stkPushMutation.mutate()}
                variant="primary"
              >
                Send STK Push
              </Button>
            </div>
          </div>
        </div>
      )}
    </section>
  )
}
