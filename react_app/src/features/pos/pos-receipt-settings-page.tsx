import { useState } from 'react'
import {
  CheckCircle2,
  Printer,
  QrCode,
  Receipt,
  RotateCcw,
  Save,
  Sliders,
  Store,
} from 'lucide-react'
import { Link } from 'react-router-dom'
import { Button } from '@/design-system/button'
import { PageHeader } from '@/design-system/page-header'
import {
  defaultReceiptSettings,
  loadPosReceiptSettings,
  savePosReceiptSettings,
  type PosReceiptSettings,
} from '@/features/pos/pos-api'

export function PosReceiptSettingsPage() {
  const [settings, setSettings] = useState<PosReceiptSettings>(() => loadPosReceiptSettings())
  const [isSaved, setIsSaved] = useState(false)

  const handleChange = <K extends keyof PosReceiptSettings>(key: K, val: PosReceiptSettings[K]) => {
    setSettings((prev) => ({ ...prev, [key]: val }))
    setIsSaved(false)
  }

  const handleSave = (e: React.FormEvent) => {
    e.preventDefault()
    savePosReceiptSettings(settings)
    setIsSaved(true)
    setTimeout(() => setIsSaved(false), 4000)
  }

  const handleReset = () => {
    setSettings(defaultReceiptSettings)
    savePosReceiptSettings(defaultReceiptSettings)
    setIsSaved(true)
    setTimeout(() => setIsSaved(false), 4000)
  }

  const handleTestPrint = () => {
    window.print()
  }

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Point of Sale Configuration"
        title="Thermal Receipt & Printer Settings"
        description="Configure retail store receipt branding, 58mm/80mm roll width, statutory tax breakdown, and hardware drawer triggers."
        actions={
          <div style={{ display: 'flex', gap: 'var(--space-sm)' }}>
            <Link className="btn btn--secondary" to="/pos">
              <Receipt aria-hidden="true" size={14} style={{ marginRight: 6 }} />
              Open POS Counter
            </Link>
            <Button onClick={handleTestPrint} variant="secondary">
              <Printer aria-hidden="true" size={14} style={{ marginRight: 6 }} />
              Test Print Slip
            </Button>
          </div>
        }
      />

      {isSaved && (
        <div className="banner banner--success" role="status" style={{ marginBottom: 'var(--space-md)' }}>
          <CheckCircle2 size={16} />
          <span>Receipt template and printer preferences saved successfully.</span>
        </div>
      )}

      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'minmax(0, 1.4fr) minmax(320px, 1fr)',
          gap: 'var(--space-lg)',
          alignItems: 'start',
        }}
      >
        {/* Form Settings */}
        <form onSubmit={handleSave} style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-md)' }}>
          {/* Store Branding */}
          <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
            <h3 style={{ fontSize: '1.05rem', margin: '0 0 var(--space-sm) 0', display: 'flex', alignItems: 'center', gap: 8 }}>
              <Store size={18} /> Store Branding & Header Details
            </h3>
            <div className="form-grid">
              <div className="form-field form-field--full">
                <label htmlFor="storeName">Store / Business Trade Name *</label>
                <input
                  id="storeName"
                  type="text"
                  required
                  value={settings.storeName}
                  onChange={(e) => handleChange('storeName', e.target.value)}
                />
              </div>

              <div className="form-field form-field--full">
                <label htmlFor="tagline">Tagline / Subtitle (Optional)</label>
                <input
                  id="tagline"
                  type="text"
                  value={settings.tagline}
                  onChange={(e) => handleChange('tagline', e.target.value)}
                />
              </div>

              <div className="form-field">
                <label htmlFor="addressLine1">Address Line 1 *</label>
                <input
                  id="addressLine1"
                  type="text"
                  required
                  value={settings.addressLine1}
                  onChange={(e) => handleChange('addressLine1', e.target.value)}
                />
              </div>

              <div className="form-field">
                <label htmlFor="addressLine2">Address Line 2 / City / Pincode</label>
                <input
                  id="addressLine2"
                  type="text"
                  value={settings.addressLine2}
                  onChange={(e) => handleChange('addressLine2', e.target.value)}
                />
              </div>

              <div className="form-field">
                <label htmlFor="phone">Store Phone / Helpdesk *</label>
                <input
                  id="phone"
                  type="text"
                  required
                  value={settings.phone}
                  onChange={(e) => handleChange('phone', e.target.value)}
                />
              </div>

              <div className="form-field">
                <label htmlFor="email">Email Address</label>
                <input
                  id="email"
                  type="email"
                  value={settings.email}
                  onChange={(e) => handleChange('email', e.target.value)}
                />
              </div>

              <div className="form-field">
                <label htmlFor="gstin">GSTIN (GST Number)</label>
                <input
                  id="gstin"
                  type="text"
                  value={settings.gstin}
                  onChange={(e) => handleChange('gstin', e.target.value)}
                />
              </div>

              <div className="form-field">
                <label htmlFor="drugLicenseNo">Drug License No (DL / Form 20/21)</label>
                <input
                  id="drugLicenseNo"
                  type="text"
                  value={settings.drugLicenseNo}
                  onChange={(e) => handleChange('drugLicenseNo', e.target.value)}
                />
              </div>
            </div>
          </div>

          {/* Paper Format & Content Toggles */}
          <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
            <h3 style={{ fontSize: '1.05rem', margin: '0 0 var(--space-sm) 0', display: 'flex', alignItems: 'center', gap: 8 }}>
              <Sliders size={18} /> Roll Width & Line Content Preferences
            </h3>

            <div className="form-grid">
              <div className="form-field">
                <label htmlFor="paperWidth">Thermal Paper Roll Width</label>
                <select
                  id="paperWidth"
                  value={settings.paperWidth}
                  onChange={(e) => handleChange('paperWidth', e.target.value as '58mm' | '80mm')}
                >
                  <option value="80mm">80 mm (3-inch standard ESC/POS)</option>
                  <option value="58mm">58 mm (2-inch compact mobile)</option>
                </select>
              </div>

              <div className="form-field">
                <label htmlFor="headerNote">Header Document Title</label>
                <input
                  id="headerNote"
                  type="text"
                  value={settings.headerNote}
                  onChange={(e) => handleChange('headerNote', e.target.value)}
                />
              </div>
            </div>

            <div style={{ marginTop: 'var(--space-md)', display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 'var(--space-sm)' }}>
              <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer', fontSize: '0.9rem' }}>
                <input
                  type="checkbox"
                  checked={settings.showHsn}
                  onChange={(e) => handleChange('showHsn', e.target.checked)}
                />
                <span>Print HSN & GST Rate on lines</span>
              </label>

              <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer', fontSize: '0.9rem' }}>
                <input
                  type="checkbox"
                  checked={settings.showBatches}
                  onChange={(e) => handleChange('showBatches', e.target.checked)}
                />
                <span>Print Batch Number & Expiry Date</span>
              </label>

              <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer', fontSize: '0.9rem' }}>
                <input
                  type="checkbox"
                  checked={settings.showSavings}
                  onChange={(e) => handleChange('showSavings', e.target.checked)}
                />
                <span>Print "You Saved ₹..." banner</span>
              </label>

              <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer', fontSize: '0.9rem' }}>
                <input
                  type="checkbox"
                  checked={settings.showLoyalty}
                  onChange={(e) => handleChange('showLoyalty', e.target.checked)}
                />
                <span>Print Customer Points Balance</span>
              </label>

              <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer', fontSize: '0.9rem' }}>
                <input
                  type="checkbox"
                  checked={settings.showCashier}
                  onChange={(e) => handleChange('showCashier', e.target.checked)}
                />
                <span>Print Cashier / Counter name</span>
              </label>

              <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer', fontSize: '0.9rem' }}>
                <input
                  type="checkbox"
                  checked={settings.showQr}
                  onChange={(e) => handleChange('showQr', e.target.checked)}
                />
                <span>Print Digital Invoice QR Code</span>
              </label>
            </div>

            <div className="form-field" style={{ marginTop: 'var(--space-md)' }}>
              <label htmlFor="footerNote">Footer Note / Return Policy</label>
              <textarea
                id="footerNote"
                rows={2}
                value={settings.footerNote}
                onChange={(e) => handleChange('footerNote', e.target.value)}
              />
            </div>
          </div>

          {/* Hardware Triggers */}
          <div className="panel-card" style={{ padding: 'var(--space-md)' }}>
            <h3 style={{ fontSize: '1.05rem', margin: '0 0 var(--space-sm) 0', display: 'flex', alignItems: 'center', gap: 8 }}>
              <Printer size={18} /> Hardware Automation Triggers
            </h3>

            <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-sm)' }}>
              <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer', fontSize: '0.9rem' }}>
                <input
                  type="checkbox"
                  checked={settings.autoPrint}
                  onChange={(e) => handleChange('autoPrint', e.target.checked)}
                />
                <span>Auto-trigger print dialog immediately upon bill payment</span>
              </label>

              <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer', fontSize: '0.9rem' }}>
                <input
                  type="checkbox"
                  checked={settings.openDrawerPulse}
                  onChange={(e) => handleChange('openDrawerPulse', e.target.checked)}
                />
                <span>Send ESC/POS drawer kick pulse (Pin 2 / Pin 5) on cash tender</span>
              </label>
            </div>
          </div>

          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <Button onClick={handleReset} type="button" variant="ghost">
              <RotateCcw size={14} style={{ marginRight: 6 }} /> Reset to Defaults
            </Button>
            <Button type="submit" variant="primary">
              <Save size={14} style={{ marginRight: 6 }} /> Save Receipt Settings
            </Button>
          </div>
        </form>

        {/* Live Thermal Receipt Simulator */}
        <div style={{ position: 'sticky', top: 'var(--space-md)' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 'var(--space-xs)' }}>
            <span className="cell-muted" style={{ fontSize: '0.85rem', fontWeight: 600 }}>
              Live Thermal Simulator ({settings.paperWidth})
            </span>
            <span className="cell-muted" style={{ fontSize: '0.75rem' }}>
              ESC/POS Monospace
            </span>
          </div>

          <div
            className="thermal-receipt-preview"
            style={{
              width: '100%',
              maxWidth: settings.paperWidth === '58mm' ? 260 : 340,
              margin: '0 auto',
              backgroundColor: '#fff',
              color: '#111',
              fontFamily: 'monospace',
              fontSize: '0.75rem',
              lineHeight: 1.35,
              padding: '16px 14px',
              borderRadius: 'var(--radius-sm)',
              boxShadow: '0 4px 14px rgba(0,0,0,0.12)',
              border: '1px solid #d1d5db',
            }}
          >
            <div style={{ textAlign: 'center', marginBottom: 8 }}>
              <div style={{ fontWeight: 'bold', fontSize: '0.95rem' }}>{settings.storeName}</div>
              {settings.tagline && <div style={{ fontSize: '0.7rem' }}>{settings.tagline}</div>}
              <div>{settings.addressLine1}</div>
              {settings.addressLine2 && <div>{settings.addressLine2}</div>}
              <div>Ph: {settings.phone}</div>
              {settings.gstin && <div>GSTIN: {settings.gstin}</div>}
              {settings.drugLicenseNo && <div>DL: {settings.drugLicenseNo}</div>}
              <div style={{ marginTop: 4, fontWeight: 'bold', borderTop: '1px dashed #444', borderBottom: '1px dashed #444', padding: '2px 0' }}>
                {settings.headerNote}
              </div>
            </div>

            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.7rem', marginBottom: 6 }}>
              <span>Bill #: REC-2026-0042</span>
              <span>24-Aug-2026 14:32</span>
            </div>
            {settings.showCashier && (
              <div style={{ fontSize: '0.7rem', marginBottom: 6 }}>Cashier: Counter 1 (Admin)</div>
            )}
            <div style={{ fontSize: '0.7rem', marginBottom: 6 }}>Customer: Ramesh Kumar (Walk-in)</div>

            <div style={{ borderBottom: '1px dashed #444', paddingBottom: 4, marginBottom: 4 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontWeight: 'bold' }}>
                <span>Item</span>
                <span>Qty x Rate = Amt</span>
              </div>
            </div>

            {/* Sample items */}
            <div style={{ marginBottom: 6 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                <span style={{ fontWeight: 'bold' }}>Paracetamol 650mg Tab</span>
                <span>2 x 35.00 = 70.00</span>
              </div>
              {settings.showBatches && (
                <div style={{ fontSize: '0.65rem', color: '#555' }}>B: PCM2604 | Exp: 05/28</div>
              )}
              {settings.showHsn && (
                <div style={{ fontSize: '0.65rem', color: '#555' }}>HSN: 30049099 | GST 12%</div>
              )}
            </div>

            <div style={{ marginBottom: 6 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                <span style={{ fontWeight: 'bold' }}>Cetirizine 10mg Tab</span>
                <span>1 x 45.00 = 45.00</span>
              </div>
              {settings.showBatches && (
                <div style={{ fontSize: '0.65rem', color: '#555' }}>B: CTZ2611 | Exp: 11/27</div>
              )}
              {settings.showHsn && (
                <div style={{ fontSize: '0.65rem', color: '#555' }}>HSN: 30049099 | GST 12%</div>
              )}
            </div>

            {/* Totals */}
            <div style={{ borderTop: '1px dashed #444', paddingTop: 4, marginTop: 6 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                <span>Subtotal:</span>
                <span>₹102.68</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                <span>CGST (6%):</span>
                <span>₹6.16</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                <span>SGST (6%):</span>
                <span>₹6.16</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontWeight: 'bold', fontSize: '0.85rem', margin: '4px 0', borderTop: '1px solid #111', borderBottom: '1px solid #111', padding: '2px 0' }}>
                <span>NET TOTAL:</span>
                <span>₹115.00</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                <span>Tender (CASH):</span>
                <span>₹200.00</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontWeight: 'bold' }}>
                <span>Change Returned:</span>
                <span>₹85.00</span>
              </div>
            </div>

            {/* Savings */}
            {settings.showSavings && (
              <div style={{ margin: '8px 0', padding: '4px', textAlign: 'center', background: '#f3f4f6', border: '1px dashed #9ca3af', fontWeight: 'bold' }}>
                *** YOU SAVED ₹25.00 ON MRP ***
              </div>
            )}

            {/* Loyalty */}
            {settings.showLoyalty && (
              <div style={{ fontSize: '0.7rem', textAlign: 'center', margin: '4px 0' }}>
                Loyalty Pts: +11 earned | Bal: 145 pts
              </div>
            )}

            {/* QR */}
            {settings.showQr && (
              <div style={{ textAlign: 'center', margin: '8px 0' }}>
                <div style={{ display: 'inline-block', padding: 4, border: '1px solid #9ca3af' }}>
                  <QrCode size={40} />
                </div>
                <div style={{ fontSize: '0.65rem' }}>Scan for e-Invoice</div>
              </div>
            )}

            {/* Footer */}
            <div style={{ borderTop: '1px dashed #444', paddingTop: 6, textAlign: 'center', fontSize: '0.68rem' }}>
              {settings.footerNote}
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}
