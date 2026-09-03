import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { CheckCircle, ExternalLink, ShieldAlert, Sliders } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import { TextField } from '@/design-system/text-field'
import { formatStatusLabel } from '@/shared/format/format'
import {
  getThreeWayMatchSettings,
  listThreeWayMatchExceptions,
  updateThreeWayMatchSettings,
} from './three-way-match-api'

export function ThreeWayMatchPage() {
  const [tab, setTab] = useState<'exceptions' | 'settings'>('exceptions')
  const [page] = useState(0)
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const exceptionsQuery = useQuery({
    queryKey: ['three-way-match', 'exceptions', page],
    queryFn: () => listThreeWayMatchExceptions(page),
    enabled: tab === 'exceptions',
  })

  const settingsQuery = useQuery({
    queryKey: ['three-way-match', 'settings'],
    queryFn: () => getThreeWayMatchSettings(),
    enabled: tab === 'settings',
  })

  const [settingsForm, setSettingsForm] = useState({
    required: 'true',
    qty_tolerance_pct: '0',
    price_tolerance_abs: '1',
    price_tolerance_pct: '0.005',
    bypass_threshold: '0',
  })
  const [settingsLoaded, setSettingsLoaded] = useState(false)
  const [feedback, setFeedback] = useState<string | null>(null)

  if (settingsQuery.data && !settingsLoaded) {
    setSettingsForm({
      required: settingsQuery.data.required ?? 'true',
      qty_tolerance_pct: settingsQuery.data.qty_tolerance_pct ?? '0',
      price_tolerance_abs: settingsQuery.data.price_tolerance_abs ?? '1',
      price_tolerance_pct: settingsQuery.data.price_tolerance_pct ?? '0.005',
      bypass_threshold: settingsQuery.data.bypass_threshold ?? '0',
    })
    setSettingsLoaded(true)
  }

  const saveSettingsMutation = useMutation({
    mutationFn: () => updateThreeWayMatchSettings(settingsForm),
    onSuccess: () => {
      setFeedback('3-way match tolerance parameters saved successfully.')
      queryClient.invalidateQueries({ queryKey: ['three-way-match', 'settings'] })
    },
    onError: (err: Error) => {
      setFeedback(`Failed to save settings: ${err.message}`)
    },
  })

  const exceptions = exceptionsQuery.data?.content || []

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Purchases / AP Controls / 3-Way Match Console"
        title="3-Way Match Verification"
        description="Audit reconciliation between Purchase Orders, Goods Receipt Notes, and Vendor Bills"
        actions={
          <div style={{ display: 'flex', gap: '8px' }}>
            <Button
              onClick={() => { setTab('exceptions'); setFeedback(null); }}
              variant={tab === 'exceptions' ? 'primary' : 'secondary'}
            >
              <ShieldAlert size={16} />
              Exception Inbox ({exceptionsQuery.data?.totalElements ?? 0})
            </Button>
            <Button
              onClick={() => { setTab('settings'); setFeedback(null); }}
              variant={tab === 'settings' ? 'primary' : 'secondary'}
            >
              <Sliders size={16} />
              Tolerance Rules
            </Button>
          </div>
        }
      />

      {feedback ? (
        <div className="alert-banner" style={{ background: '#0F857615', border: '1px solid #0F8576', padding: '12px 16px', borderRadius: '6px', color: '#0F8576' }}>
          {feedback}
        </div>
      ) : null}

      {tab === 'exceptions' ? (
        <>
          <div className="summary-strip" style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '16px', marginBottom: '16px' }}>
            <div className="document-card">
              <span style={{ fontSize: '12px', color: 'var(--k-color-text-secondary)' }}>Open Exceptions</span>
              <strong style={{ fontSize: '24px', display: 'block', marginTop: '4px' }}>
                {exceptionsQuery.data?.totalElements ?? 0}
              </strong>
            </div>
            <div className="document-card">
              <span style={{ fontSize: '12px', color: 'var(--k-color-text-secondary)' }}>Tolerance Mode</span>
              <strong style={{ fontSize: '18px', display: 'block', marginTop: '4px', color: '#0F8576' }}>
                Active Gate
              </strong>
            </div>
          </div>

          <section className="document-card">
            <h2>Exceptions Requiring Resolution</h2>
            {exceptionsQuery.isLoading ? (
              <p className="document-loading">Loading 3-way match exceptions...</p>
            ) : exceptions.length === 0 ? (
              <div style={{ textAlign: 'center', padding: '32px' }}>
                <CheckCircle size={32} color="#0F8576" style={{ margin: '0 auto 8px' }} />
                <h3>No 3-Way Match Exceptions</h3>
                <p style={{ fontSize: '13px', color: 'var(--k-color-text-secondary)' }}>
                  All purchase bills are cleanly matched within configured price and quantity tolerances.
                </p>
              </div>
            ) : (
              <DataTable caption="3-Way Match Exceptions">
                <thead>
                  <tr>
                    <th scope="col">Status</th>
                    <th scope="col">Bill ID</th>
                    <th className="numeric-cell" scope="col">Billed Qty</th>
                    <th className="numeric-cell" scope="col">Received Qty</th>
                    <th className="numeric-cell" scope="col">Qty Var</th>
                    <th className="numeric-cell" scope="col">Bill Price</th>
                    <th className="numeric-cell" scope="col">PO Price</th>
                    <th className="numeric-cell" scope="col">Price Var</th>
                    <th className="numeric-cell" scope="col">Total Var</th>
                    <th scope="col">Action</th>
                  </tr>
                </thead>
                <tbody>
                  {exceptions.map((e) => (
                    <tr key={e.id}>
                      <td>
                        <StatusChip status={formatStatusLabel(e.status)} />
                      </td>
                      <td>
                        <code>{e.billId.slice(0, 8)}...</code>
                      </td>
                      <td className="numeric-cell">
                        <Quantity value={e.billedQty} />
                      </td>
                      <td className="numeric-cell">
                        <Quantity value={e.receivedQty ?? 0} />
                      </td>
                      <td className="numeric-cell" style={{ color: Number(e.qtyVariance) > 0 ? '#BE3A34' : 'inherit' }}>
                        {e.qtyVariance ? Number(e.qtyVariance) : '0'}
                      </td>
                      <td className="numeric-cell">
                        <Money amount={e.billUnitPrice} />
                      </td>
                      <td className="numeric-cell">
                        <Money amount={e.poUnitPrice ?? 0} />
                      </td>
                      <td className="numeric-cell" style={{ color: Number(e.priceVariance) > 0 ? '#BE3A34' : 'inherit' }}>
                        <Money amount={e.priceVariance ?? 0} />
                      </td>
                      <td className="numeric-cell" style={{ color: Number(e.amountVariance) > 0 ? '#BE3A34' : 'inherit', fontWeight: 600 }}>
                        <Money amount={e.amountVariance ?? 0} />
                      </td>
                      <td>
                        <Button
                          onClick={() => navigate(`/bills/${e.billId}/three-way-match`)}
                          variant="secondary"
                        >
                          <ExternalLink size={14} />
                          Inspect Match
                        </Button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </DataTable>
            )}
          </section>
        </>
      ) : (
        <section className="document-card" style={{ maxWidth: '640px' }}>
          <h2>3-Way Match Tolerances & Policy</h2>
          <p style={{ fontSize: '13px', color: 'var(--k-color-text-secondary)', marginBottom: '20px' }}>
            Configure automatic approval thresholds for vendor bill posting and disbursement controls.
          </p>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
            <div>
              <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer' }}>
                <input
                  checked={settingsForm.required === 'true'}
                  onChange={(e) => setSettingsForm((f) => ({ ...f, required: e.target.checked ? 'true' : 'false' }))}
                  type="checkbox"
                />
                <strong>Enforce 3-Way Match Before Payment</strong>
              </label>
              <span style={{ fontSize: '12px', color: 'var(--k-color-text-secondary)', display: 'block', marginTop: '4px' }}>
                When checked, bills in EXCEPTION state are strictly blocked from vendor disbursement.
              </span>
            </div>

            <TextField
              label="Quantity Tolerance Percentage (%)"
              onChange={(e) => setSettingsForm((f) => ({ ...f, qty_tolerance_pct: e.target.value }))}
              placeholder="0"
              value={settingsForm.qty_tolerance_pct}
            />

            <TextField
              label="Price Tolerance Absolute (₹)"
              onChange={(e) => setSettingsForm((f) => ({ ...f, price_tolerance_abs: e.target.value }))}
              placeholder="1.0"
              value={settingsForm.price_tolerance_abs}
            />

            <TextField
              label="Price Tolerance Percentage (%)"
              onChange={(e) => setSettingsForm((f) => ({ ...f, price_tolerance_pct: e.target.value }))}
              placeholder="0.005"
              value={settingsForm.price_tolerance_pct}
            />

            <TextField
              label="Bypass Threshold Amount (₹)"
              onChange={(e) => setSettingsForm((f) => ({ ...f, bypass_threshold: e.target.value }))}
              placeholder="0"
              value={settingsForm.bypass_threshold}
            />

            <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: '12px' }}>
              <Button
                disabled={saveSettingsMutation.isPending}
                onClick={() => saveSettingsMutation.mutate()}
                variant="primary"
              >
                {saveSettingsMutation.isPending ? 'Saving...' : 'Save Tolerances'}
              </Button>
            </div>
          </div>
        </section>
      )}
    </section>
  )
}
