import { useState } from 'react'
import { useMutation } from '@tanstack/react-query'
import {
  Barcode,
  Printer,
} from 'lucide-react'
import { Button } from '@/design-system/button'
import { PageHeader } from '@/design-system/page-header'
import {
  generateBarcodeLabel,
  type BarcodeLabelRequest,
  type BarcodeLabelResponse,
} from '@/features/inventory/barcode-labels-api'

export function BarcodeLabelsPage() {
  const [itemId, setItemId] = useState('ITEM-001')
  const [itemName, setItemName] = useState('Paracetamol 500mg Tablets')
  const [sku, setSku] = useState('SKU-PARA-500')
  const [batchNumber, setBatchNumber] = useState('B-2026-09')
  const [expiryDate, setExpiryDate] = useState('2028-09')
  const [mrp, setMrp] = useState(45.0)
  const [labelFormat, setLabelFormat] = useState<'THERMAL_50X25' | 'THERMAL_100X50' | 'A4_24UP'>('THERMAL_50X25')
  const [quantity, setQuantity] = useState(1)
  const [includeMrp, setIncludeMrp] = useState(true)
  const [includeExpiry, setIncludeExpiry] = useState(true)
  const [includeQrCode, setIncludeQrCode] = useState(false)

  const [labelResponse, setLabelResponse] = useState<BarcodeLabelResponse | null>(null)

  const mutation = useMutation({
    mutationFn: () => {
      const payload: BarcodeLabelRequest = {
        itemId,
        labelFormat,
        quantity,
        includeMrp,
        includeExpiry,
        includeQrCode,
      }
      return generateBarcodeLabel(payload)
    },
    onSuccess: (res) => {
      setLabelResponse(res)
    },
  })

  function handlePrint() {
    window.print()
  }

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Inventory / Barcoding"
        title="Barcode Label Generation & Designer Hub"
        description="Design and batch print Thermal (50x25mm, 100x50mm) and A4 sheet barcode labels with GS1-128, EAN, MRP, and FEFO expiry."
        actions={
          <Button onClick={handlePrint} variant="primary">
            <Printer size={16} /> Print Labels
          </Button>
        }
      />

      <div style={{ display: 'grid', gridTemplateColumns: 'minmax(320px, 400px) 1fr', gap: '2rem' }}>
        {/* Designer Controls */}
        <section className="document-card">
          <h3>Label Configuration</h3>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem', marginTop: '1rem' }}>
            <label className="field-group">
              <span>Item ID</span>
              <input onChange={(e) => setItemId(e.target.value)} value={itemId} />
            </label>
            <label className="field-group">
              <span>Item Name</span>
              <input onChange={(e) => setItemName(e.target.value)} value={itemName} />
            </label>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
              <label className="field-group">
                <span>SKU / Barcode Data</span>
                <input onChange={(e) => setSku(e.target.value)} value={sku} />
              </label>
              <label className="field-group">
                <span>Batch Number</span>
                <input onChange={(e) => setBatchNumber(e.target.value)} value={batchNumber} />
              </label>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
              <label className="field-group">
                <span>Expiry (MM/YY)</span>
                <input onChange={(e) => setExpiryDate(e.target.value)} value={expiryDate} />
              </label>
              <label className="field-group">
                <span>MRP (₹)</span>
                <input onChange={(e) => setMrp(Number(e.target.value))} type="number" value={mrp} />
              </label>
            </div>

            <label className="field-group">
              <span>Label Format / Media</span>
              <select onChange={(e) => setLabelFormat(e.target.value as 'THERMAL_50X25' | 'THERMAL_100X50' | 'A4_24UP')} value={labelFormat}>
                <option value="THERMAL_50X25">Thermal Roll (50 x 25 mm - 2" x 1")</option>
                <option value="THERMAL_100X50">Thermal Shipping (100 x 50 mm - 4" x 2")</option>
                <option value="A4_24UP">A4 Sheet (24-up Labels 3x8)</option>
              </select>
            </label>

            <label className="field-group">
              <span>Print Quantity</span>
              <input min={1} onChange={(e) => setQuantity(Number(e.target.value))} type="number" value={quantity} />
            </label>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem', marginTop: '0.5rem' }}>
              <label style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
                <input checked={includeMrp} onChange={(e) => setIncludeMrp(e.target.checked)} type="checkbox" />
                <span>Print MRP Badge</span>
              </label>
              <label style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
                <input checked={includeExpiry} onChange={(e) => setIncludeExpiry(e.target.checked)} type="checkbox" />
                <span>Print Mfg / Expiry Date</span>
              </label>
              <label style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
                <input checked={includeQrCode} onChange={(e) => setIncludeQrCode(e.target.checked)} type="checkbox" />
                <span>Include 2D QR Code</span>
              </label>
            </div>

            <Button disabled={mutation.isPending} onClick={() => mutation.mutate()} variant="secondary">
              <Barcode size={16} /> Generate ZPL & SVG
            </Button>
          </div>
        </section>

        {/* Live Visual Printable Preview */}
        <section className="document-card">
          <h3>Visual Print Preview</h3>
          <p style={{ fontSize: '0.875rem', color: 'var(--color-muted)', marginBottom: '1.5rem' }}>
            Scale preview according to media geometry: {labelFormat}
          </p>

          <div
            id="printable-label-canvas"
            style={{
              display: 'flex',
              flexWrap: 'wrap',
              gap: '12px',
              padding: '24px',
              backgroundColor: '#f8f9fa',
              borderRadius: '8px',
              border: '1px dashed var(--color-border)',
              justifyContent: 'center',
            }}
          >
            {Array.from({ length: Math.min(quantity, 8) }).map((_, idx) => (
              <div
                key={idx}
                style={{
                  width: labelFormat === 'THERMAL_100X50' ? '320px' : '220px',
                  height: labelFormat === 'THERMAL_100X50' ? '160px' : '110px',
                  backgroundColor: '#ffffff',
                  border: '1px solid #111827',
                  borderRadius: '4px',
                  padding: '8px',
                  display: 'flex',
                  flexDirection: 'column',
                  justifyContent: 'space-between',
                  boxShadow: '0 2px 4px rgba(0,0,0,0.06)',
                  fontFamily: 'monospace',
                }}
              >
                <div style={{ borderBottom: '1px solid #e5e7eb', paddingBottom: '4px' }}>
                  <div style={{ fontSize: '11px', fontWeight: 'bold', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                    {itemName}
                  </div>
                  <div style={{ fontSize: '9px', color: '#4b5563' }}>SKU: {sku}</div>
                </div>

                {/* Simulated Barcode */}
                <div style={{ textAlign: 'center', margin: '4px 0' }}>
                  <div
                    style={{
                      height: '28px',
                      background: 'repeating-linear-gradient(90deg, #000 0, #000 2px, transparent 2px, transparent 4px, #000 4px, #000 7px, transparent 7px, transparent 9px)',
                      width: '80%',
                      margin: '0 auto',
                    }}
                  />
                  <div style={{ fontSize: '9px', letterSpacing: '2px' }}>*{sku}*</div>
                </div>

                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '9px', borderTop: '1px solid #e5e7eb', paddingTop: '4px' }}>
                  <div>
                    {batchNumber && <div>B: {batchNumber}</div>}
                    {includeExpiry && <div>EXP: {expiryDate}</div>}
                  </div>
                  {includeMrp && (
                    <div style={{ textAlign: 'right', fontWeight: 'bold' }}>
                      MRP: ₹{mrp.toFixed(2)}
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>

          {labelResponse?.zplPayload && (
            <div style={{ marginTop: '1.5rem' }}>
              <h4>Raw ZPL (Zebra Programming Language) Output</h4>
              <pre style={{ backgroundColor: '#1e293b', color: '#f8fafc', padding: '1rem', borderRadius: '6px', fontSize: '0.75rem', overflowX: 'auto' }}>
                {labelResponse.zplPayload}
              </pre>
            </div>
          )}
        </section>
      </div>
    </section>
  )
}