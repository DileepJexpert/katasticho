import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import {
  FileText,
  Save,
  CheckCircle2,
      QrCode,
  } from 'lucide-react'
import { Button } from '@/design-system/button'
import { PageHeader } from '@/design-system/page-header'
import {
  getPdfTemplate,
  savePdfTemplate,
  } from '@/features/settings/settings-api'

const documentTypes = [
  { key: 'INVOICE', label: 'Tax Invoice' },
  { key: 'ESTIMATE', label: 'Quotation / Estimate' },
  { key: 'DELIVERY_CHALLAN', label: 'Delivery Challan' },
  { key: 'PURCHASE_ORDER', label: 'Purchase Order' },
] as const

export function PdfTemplateCustomizerPage() {
  const queryClient = useQueryClient()
  const [selectedDocType, setSelectedDocType] = useState<string>('INVOICE')
  const [feedback, setFeedback] = useState<string | null>(null)

  // Form State
  const [primaryColor, setPrimaryColor] = useState('#0F8576')
  const [fontFamily, setFontFamily] = useState('Inter')
  const [headerText, setHeaderText] = useState('Katasticho Enterprises Pvt Ltd · GSTIN: 27AAAAA0000A1Z5')
  const [footerText, setFooterText] = useState('Thank you for your business. For support email accounts@company.com')
  const [terms, setTerms] = useState('1. Goods once sold will not be taken back.\n2. Payment due within 30 days.')
  const [showBankDetails, setShowBankDetails] = useState(true)
  const [showQrCode, setShowQrCode] = useState(true)

  useQuery({
    queryKey: ['pdf-template', selectedDocType],
    queryFn: async () => {
      const res = await getPdfTemplate(selectedDocType)
      if (res) {
        setPrimaryColor(res.primaryColor || '#0F8576')
        setFontFamily(res.fontFamily || 'Inter')
        setHeaderText(res.headerText || '')
        setFooterText(res.footerText || '')
        setTerms(res.termsAndConditions || '')
        setShowBankDetails(res.showBankDetails ?? true)
        setShowQrCode(res.showQrCode ?? true)
      }
      return res
    },
  })

  const saveMutation = useMutation({
    mutationFn: () => savePdfTemplate({
      documentType: selectedDocType,
      primaryColor,
      fontFamily,
      headerText,
      footerText,
      termsAndConditions: terms,
      showBankDetails,
      showQrCode,
    }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['pdf-template', selectedDocType] })
      setFeedback(`PDF template settings for ${selectedDocType} saved successfully.`)
    },
  })

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Settings / Document Branding"
        title="PDF Template & Invoice Customizer"
        description="Customize header branding, corporate palette, bank payment details, UPI QR codes, and statutory terms across exported documents."
        actions={
          <div className="table-actions">
            <Button
              disabled={saveMutation.isPending}
              onClick={() => saveMutation.mutate()}
              variant="primary"
            >
              <Save size={15} />
              Save Template
            </Button>
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
        {documentTypes.map((t) => (
          <button
            aria-selected={selectedDocType === t.key}
            className={selectedDocType === t.key ? 'list-tab list-tab--active' : 'list-tab'}
            key={t.key}
            onClick={() => setSelectedDocType(t.key)}
            role="tab"
            type="button"
          >
            <FileText size={15} style={{ marginRight: '6px' }} />
            {t.label}
          </button>
        ))}
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '20px', marginTop: '16px' }}>
        {/* Editor Controls */}
        <section className="document-card">
          <h2>Brand & Layout Configuration</h2>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '14px', marginTop: '14px' }}>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
              <label>
                <span style={{ fontSize: '13px', fontWeight: 600 }}>Brand Accent Color:</span>
                <div style={{ display: 'flex', gap: '8px', alignItems: 'center', marginTop: '4px' }}>
                  <input
                    onChange={(e) => setPrimaryColor(e.target.value)}
                    style={{ width: '40px', height: '36px', padding: 0, border: 'none', borderRadius: '4px', cursor: 'pointer' }}
                    type="color"
                    value={primaryColor}
                  />
                  <input
                    className="search-input"
                    onChange={(e) => setPrimaryColor(e.target.value)}
                    style={{ width: '100px' }}
                    value={primaryColor}
                  />
                </div>
              </label>

              <label>
                <span style={{ fontSize: '13px', fontWeight: 600 }}>Typography Font:</span>
                <select
                  className="search-input"
                  onChange={(e) => setFontFamily(e.target.value)}
                  style={{ width: '100%', marginTop: '4px' }}
                  value={fontFamily}
                >
                  <option value="Inter">Inter (Clean modern)</option>
                  <option value="Roboto">Roboto</option>
                  <option value="IBM Plex Mono">IBM Plex Mono</option>
                  <option value="Helvetica">Helvetica / Arial</option>
                </select>
              </label>
            </div>

            <label>
              <span style={{ fontSize: '13px', fontWeight: 600 }}>Header Letterhead Text:</span>
              <input
                className="search-input"
                onChange={(e) => setHeaderText(e.target.value)}
                style={{ width: '100%', marginTop: '4px' }}
                value={headerText}
              />
            </label>

            <label>
              <span style={{ fontSize: '13px', fontWeight: 600 }}>Terms & Conditions:</span>
              <textarea
                className="search-input"
                onChange={(e) => setTerms(e.target.value)}
                rows={3}
                style={{ width: '100%', marginTop: '4px' }}
                value={terms}
              />
            </label>

            <label>
              <span style={{ fontSize: '13px', fontWeight: 600 }}>Footer Note:</span>
              <input
                className="search-input"
                onChange={(e) => setFooterText(e.target.value)}
                style={{ width: '100%', marginTop: '4px' }}
                value={footerText}
              />
            </label>

            <div style={{ display: 'flex', gap: '16px', marginTop: '4px' }}>
              <label style={{ display: 'flex', alignItems: 'center', gap: '6px', cursor: 'pointer' }}>
                <input
                  checked={showBankDetails}
                  onChange={(e) => setShowBankDetails(e.target.checked)}
                  type="checkbox"
                />
                <span style={{ fontSize: '13px', fontWeight: 600 }}>Print Bank NEFT / IFSC Block</span>
              </label>

              <label style={{ display: 'flex', alignItems: 'center', gap: '6px', cursor: 'pointer' }}>
                <input
                  checked={showQrCode}
                  onChange={(e) => setShowQrCode(e.target.checked)}
                  type="checkbox"
                />
                <span style={{ fontSize: '13px', fontWeight: 600 }}>Print Dynamic UPI QR</span>
              </label>
            </div>
          </div>
        </section>

        {/* Live Visual Preview */}
        <section className="document-card" style={{ background: '#ffffff', color: '#111827', border: '1px solid #d1d5db', fontFamily }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: `3px solid ${primaryColor}`, paddingBottom: '12px' }}>
            <div>
              <h2 style={{ margin: 0, color: primaryColor, fontSize: '20px' }}>TAX INVOICE</h2>
              <span style={{ fontSize: '12px', color: '#6b7280' }}>{headerText}</span>
            </div>
            <div style={{ textAlign: 'right' }}>
              <span style={{ fontSize: '12px', fontWeight: 600 }}>INV-2026-0042</span>
              <div style={{ fontSize: '11px', color: '#6b7280' }}>Date: 04 Sep 2026</div>
            </div>
          </div>

          <div style={{ display: 'flex', justifyContent: 'space-between', margin: '14px 0', fontSize: '12px' }}>
            <div>
              <strong>Billed To:</strong>
              <div>Apex Medico Distributors</div>
              <div style={{ color: '#6b7280' }}>GSTIN: 27ABCDE1234F1Z5</div>
            </div>
            <div style={{ textAlign: 'right' }}>
              <strong>Place of Supply:</strong>
              <div>Maharashtra (27)</div>
            </div>
          </div>

          <table style={{ width: '100%', fontSize: '12px', borderCollapse: 'collapse', margin: '14px 0' }}>
            <thead>
              <tr style={{ background: `${primaryColor}15`, color: primaryColor }}>
                <th style={{ textAlign: 'left', padding: '6px 8px' }}>Item Description</th>
                <th style={{ textAlign: 'right', padding: '6px 8px' }}>Qty</th>
                <th style={{ textAlign: 'right', padding: '6px 8px' }}>Rate</th>
                <th style={{ textAlign: 'right', padding: '6px 8px' }}>Amount</th>
              </tr>
            </thead>
            <tbody>
              <tr style={{ borderBottom: '1px solid #e5e7eb' }}>
                <td style={{ padding: '6px 8px' }}>Amoxicillin 500mg (Batch AX-2601)</td>
                <td style={{ textAlign: 'right', padding: '6px 8px' }}>100 strips</td>
                <td style={{ textAlign: 'right', padding: '6px 8px' }}>₹45.00</td>
                <td style={{ textAlign: 'right', padding: '6px 8px' }}>₹4,500.00</td>
              </tr>
              <tr style={{ borderBottom: '1px solid #e5e7eb' }}>
                <td style={{ padding: '6px 8px' }}>Paracetamol 650mg (Batch PC-2602)</td>
                <td style={{ textAlign: 'right', padding: '6px 8px' }}>50 strips</td>
                <td style={{ textAlign: 'right', padding: '6px 8px' }}>₹28.00</td>
                <td style={{ textAlign: 'right', padding: '6px 8px' }}>₹1,400.00</td>
              </tr>
            </tbody>
          </table>

          <div style={{ display: 'flex', justifyContent: 'flex-end', margin: '10px 0', fontSize: '12px' }}>
            <div style={{ width: '200px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                <span>Subtotal:</span>
                <span>₹5,900.00</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', color: '#6b7280' }}>
                <span>CGST (2.5%):</span>
                <span>₹147.50</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', color: '#6b7280' }}>
                <span>SGST (2.5%):</span>
                <span>₹147.50</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontWeight: 600, borderTop: '1px solid #d1d5db', paddingTop: '4px', marginTop: '4px', fontSize: '14px', color: primaryColor }}>
                <span>Grand Total:</span>
                <span>₹6,195.00</span>
              </div>
            </div>
          </div>

          <div style={{ display: 'flex', justifyContent: 'space-between', borderTop: '1px solid #e5e7eb', paddingTop: '10px', marginTop: '10px', fontSize: '11px' }}>
            <div>
              {showBankDetails && (
                <div>
                  <strong>Bank Details:</strong>
                  <div>HDFC Bank · A/C: 50200012345678 · IFSC: HDFC0001234</div>
                </div>
              )}
              <div style={{ marginTop: '6px', color: '#6b7280', whiteSpace: 'pre-line' }}>
                {terms}
              </div>
            </div>
            {showQrCode && (
              <div style={{ textAlign: 'center', background: '#f3f4f6', padding: '6px 10px', borderRadius: '4px' }}>
                <QrCode size={36} color={primaryColor} />
                <div style={{ fontSize: '9px', color: '#6b7280' }}>UPI Instant Pay</div>
              </div>
            )}
          </div>

          <div style={{ textAlign: 'center', fontSize: '10px', color: '#9ca3af', marginTop: '10px' }}>
            {footerText}
          </div>
        </section>
      </div>
    </section>
  )
}
