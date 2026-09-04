import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, Check, X, ShieldAlert, FileText, CheckCircle2 } from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import {
  getQcInspection,
  finalizeInspection,
  recordInspectionDisposition,
  getCertificateOfAnalysis,
} from '@/features/qc-inspections/qc-inspections-api'

export function QcInspectionDetailPage() {
  const { inspectionId, id: routeId } = useParams()
  const id = inspectionId || routeId
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const [isFinalizeOpen, setIsFinalizeOpen] = useState(false)
  const [acceptedQty, setAcceptedQty] = useState('50')
  const [rejectedQty, setRejectedQty] = useState('0')
  const [finalizeNotes, setFinalizeNotes] = useState('')

  const [isDispositionOpen, setIsDispositionOpen] = useState(false)
  const [decision, setDecision] = useState('ACCEPT')
  const [dispositionNotes, setDispositionNotes] = useState('')

  const [coaData, setCoaData] = useState<Record<string, unknown> | null>(null)

  const query = useQuery({
    queryKey: ['qc-inspections', id],
    queryFn: () => getQcInspection(id!),
    enabled: Boolean(id),
  })

  const finalizeMutation = useMutation({
    mutationFn: () => finalizeInspection(id!, {
      acceptedQty: Number(acceptedQty),
      rejectedQty: Number(rejectedQty),
      notes: finalizeNotes,
    }),
    onSuccess: () => {
      setIsFinalizeOpen(false)
      queryClient.invalidateQueries({ queryKey: ['qc-inspections', id] })
    },
  })

  const dispositionMutation = useMutation({
    mutationFn: () => recordInspectionDisposition(id!, {
      decision,
      acceptedQty: Number(acceptedQty),
      rejectedQty: Number(rejectedQty),
      notes: dispositionNotes,
    }),
    onSuccess: () => {
      setIsDispositionOpen(false)
      queryClient.invalidateQueries({ queryKey: ['qc-inspections', id] })
    },
  })

  const handleFetchCoa = async () => {
    if (!id) return
    const res = await getCertificateOfAnalysis(id)
    setCoaData(res)
  }

  if (!id) return <div className="directory-state">No Inspection ID provided.</div>
  if (query.isLoading) return <div className="directory-state">Loading QC inspection details...</div>
  if (query.isError || !query.data) {
    return (
      <div className="directory-state directory-state--error">
        <strong>Unable to load QC inspection.</strong>
        <Button onClick={() => navigate('/qc-inspections')} variant="secondary">Back to inspections</Button>
      </div>
    )
  }

  const document = query.data

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Quality / QC Inspections"
        title={document.inspectionNumber}
        description={`Audit for: ${document.itemName || `Item ${document.itemId.slice(0, 8)}`} · Type: ${document.inspectionType}`}
        actions={
          <div className="table-actions">
            {document.disposition && (
              <span className={document.disposition === 'ACCEPT' ? 'status-badge status-badge--success' : 'status-badge status-badge--danger'}>
                Disposition: {document.disposition}
              </span>
            )}
            <StatusChip status={formatStatusLabel(document.status)} />
          </div>
        }
      />

      <div className="document-actions">
        <Button onClick={() => navigate('/qc-inspections')} variant="secondary">
          <ArrowLeft aria-hidden="true" size={16} />
          Back to QC inspections
        </Button>

        {document.status === 'PENDING' && (
          <Button onClick={() => setIsFinalizeOpen(true)} variant="primary">
            <CheckCircle2 size={16} />
            Finalize Inspection
          </Button>
        )}

        {document.status === 'COMPLETED' && !document.disposition && (
          <Button onClick={() => setIsDispositionOpen(true)} variant="primary">
            <ShieldAlert size={16} />
            Record Batch Disposition
          </Button>
        )}

        <Button onClick={handleFetchCoa} variant="secondary">
          <FileText size={16} />
          Generate CoA Certificate
        </Button>
      </div>

      <div className="document-layout">
        <section className="document-card">
          <h2>Inspection record details</h2>
          <dl className="document-facts">
            <div className="document-fact"><dt>Item inspected</dt><dd>{document.itemName || document.itemId}</dd></div>
            <div className="document-fact"><dt>Batch / Lot</dt><dd>{document.batchNumber || 'Continuous Lot'}</dd></div>
            <div className="document-fact"><dt>Inspection stage</dt><dd>{document.inspectionType}</dd></div>
            <div className="document-fact"><dt>Inspector</dt><dd>{document.inspectorName || 'QA Lead'}</dd></div>
            <div className="document-fact"><dt>Timestamp</dt><dd>{document.inspectedAt ? formatDate(document.inspectedAt.slice(0, 10)) : '--'}</dd></div>
          </dl>
        </section>

        <aside className="document-card document-card--summary">
          <h2>Inspection Quantity Summary</h2>
          <div className="progress-row">
            <span>Total Inspected</span>
            <Quantity value={document.inspectedQty} />
          </div>
          <div className="progress-row">
            <span>Accepted</span>
            <strong className="text-success">{document.acceptedQty ?? 0} units</strong>
          </div>
          <div className="progress-row">
            <span>Rejected</span>
            <strong className="text-danger">{document.rejectedQty ?? 0} units</strong>
          </div>
        </aside>
      </div>

      <section className="document-card document-card--lines">
        <h2>Parameter Test Results</h2>
        {document.results && document.results.length > 0 ? (
          <DataTable caption="Quality parameter audit results">
            <thead>
              <tr>
                <th scope="col">Parameter</th>
                <th scope="col">Measured / Numeric Value</th>
                <th scope="col">Result</th>
                <th scope="col">Notes</th>
              </tr>
            </thead>
            <tbody>
              {document.results.map((res) => (
                <tr key={res.id}>
                  <td><strong>{res.parameterName || res.parameterId}</strong></td>
                  <td>{res.numericValue !== null ? res.numericValue : (res.measuredValue || '--')}</td>
                  <td>
                    {res.isPassed === true ? (
                      <span className="text-success"><Check size={16} /> PASS</span>
                    ) : res.isPassed === false ? (
                      <span className="text-danger"><X size={16} /> FAIL</span>
                    ) : '--'}
                  </td>
                  <td>{res.notes || '--'}</td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        ) : (
          <p className="cell-muted">No parameter tests logged.</p>
        )}
      </section>

      {coaData && (
        <section className="document-card" style={{ marginTop: '20px' }}>
          <h2>Certificate of Analysis (CoA) Data Preview</h2>
          <pre style={{ background: 'var(--bg-muted)', padding: '12px', borderRadius: '6px', fontSize: '12px', overflowX: 'auto' }}>
            {JSON.stringify(coaData, null, 2)}
          </pre>
        </section>
      )}

      {isFinalizeOpen && (
        <div className="modal-backdrop">
          <div className="modal-card">
            <h3>Finalize Inspection Outcome</h3>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', marginTop: '12px' }}>
              <label>
                <span style={{ fontSize: '13px', fontWeight: 600 }}>Accepted Quantity:</span>
                <input
                  className="search-input"
                  onChange={(e) => setAcceptedQty(e.target.value)}
                  style={{ width: '100%', marginTop: '4px' }}
                  type="number"
                  value={acceptedQty}
                />
              </label>
              <label>
                <span style={{ fontSize: '13px', fontWeight: 600 }}>Rejected Quantity:</span>
                <input
                  className="search-input"
                  onChange={(e) => setRejectedQty(e.target.value)}
                  style={{ width: '100%', marginTop: '4px' }}
                  type="number"
                  value={rejectedQty}
                />
              </label>
              <label>
                <span style={{ fontSize: '13px', fontWeight: 600 }}>Final QA Remarks:</span>
                <textarea
                  className="search-input"
                  onChange={(e) => setFinalizeNotes(e.target.value)}
                  placeholder="Approved per standard monograph..."
                  rows={2}
                  style={{ width: '100%', marginTop: '4px' }}
                  value={finalizeNotes}
                />
              </label>
            </div>
            <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end', marginTop: '16px' }}>
              <Button onClick={() => setIsFinalizeOpen(false)} variant="secondary">Cancel</Button>
              <Button
                disabled={finalizeMutation.isPending}
                onClick={() => finalizeMutation.mutate()}
                variant="primary"
              >
                Finalize Inspection
              </Button>
            </div>
          </div>
        </div>
      )}

      {isDispositionOpen && (
        <div className="modal-backdrop">
          <div className="modal-card">
            <h3>Record Quality Batch Disposition</h3>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', marginTop: '12px' }}>
              <label>
                <span style={{ fontSize: '13px', fontWeight: 600 }}>Disposition Decision:</span>
                <select
                  className="search-input"
                  onChange={(e) => setDecision(e.target.value)}
                  style={{ width: '100%', marginTop: '4px' }}
                  value={decision}
                >
                  <option value="ACCEPT">ACCEPT (Release to active inventory)</option>
                  <option value="REJECT">REJECT (Scrap / Return to vendor)</option>
                  <option value="QUARANTINE">QUARANTINE (Hold for re-test)</option>
                  <option value="REWORK">REWORK (Reprocess in floor)</option>
                </select>
              </label>
              <label>
                <span style={{ fontSize: '13px', fontWeight: 600 }}>Disposition Notes:</span>
                <textarea
                  className="search-input"
                  onChange={(e) => setDispositionNotes(e.target.value)}
                  placeholder="Authorizing QA manager notes..."
                  rows={2}
                  style={{ width: '100%', marginTop: '4px' }}
                  value={dispositionNotes}
                />
              </label>
            </div>
            <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end', marginTop: '16px' }}>
              <Button onClick={() => setIsDispositionOpen(false)} variant="secondary">Cancel</Button>
              <Button
                disabled={dispositionMutation.isPending}
                onClick={() => dispositionMutation.mutate()}
                variant="primary"
              >
                Apply Disposition
              </Button>
            </div>
          </div>
        </div>
      )}
    </section>
  )
}