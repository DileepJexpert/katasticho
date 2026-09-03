import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, CheckCircle2, Plus } from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import { getNcr, updateNcr, closeNcr } from '@/features/ncrs/ncrs-api'
import { listCapasByNcr, raiseCapa } from '@/features/capa/capa-api'

export function NcrDetailPage() {
  const { ncrId, id: routeId } = useParams()
  const id = ncrId || routeId
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const [isUpdateOpen, setIsUpdateOpen] = useState(false)
  const [rootCause, setRootCause] = useState('')
  const [correctiveAction, setCorrectiveAction] = useState('')

  const [isRaiseCapaOpen, setIsRaiseCapaOpen] = useState(false)
  const [capaTitle, setCapaTitle] = useState('')
  const [capaAction, setCapaAction] = useState('')

  const query = useQuery({
    queryKey: ['ncrs', id],
    queryFn: () => getNcr(id!),
    enabled: Boolean(id),
  })

  const capasQuery = useQuery({
    queryKey: ['capas-by-ncr', id],
    queryFn: () => listCapasByNcr(id!),
    enabled: Boolean(id),
  })

  const updateMutation = useMutation({
    mutationFn: () => updateNcr(id!, {
      rootCause,
      correctiveAction,
      status: 'INVESTIGATING',
    }),
    onSuccess: () => {
      setIsUpdateOpen(false)
      queryClient.invalidateQueries({ queryKey: ['ncrs', id] })
    },
  })

  const closeMutation = useMutation({
    mutationFn: () => closeNcr(id!),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['ncrs', id] }),
  })

  const raiseCapaMutation = useMutation({
    mutationFn: () => raiseCapa({
      ncrId: id,
      capaType: 'CORRECTIVE',
      title: capaTitle,
      proposedAction: capaAction,
      priority: 'HIGH',
    }),
    onSuccess: () => {
      setIsRaiseCapaOpen(false)
      queryClient.invalidateQueries({ queryKey: ['capas-by-ncr', id] })
      queryClient.invalidateQueries({ queryKey: ['ncrs', id] })
    },
  })

  if (!id) return <div className="directory-state">No NCR ID provided.</div>
  if (query.isLoading) return <div className="directory-state">Loading NCR details...</div>
  if (query.isError || !query.data) {
    return (
      <div className="directory-state directory-state--error">
        <strong>Unable to load NCR.</strong>
        <Button onClick={() => navigate('/ncrs')} variant="secondary">Back to NCRs</Button>
      </div>
    )
  }

  const document = query.data
  const linkedCapas = capasQuery.data ?? []

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Quality / Non-Conformance Reports"
        title={document.ncrNumber}
        description={`Defect report for: ${document.itemName || document.itemId} Â· Severity: ${document.severity}`}
        actions={
          <div className="table-actions">
            <span className={document.severity === 'CRITICAL' ? 'status-badge status-badge--danger' : 'status-badge status-badge--warning'}>
              {document.severity}
            </span>
            <StatusChip status={formatStatusLabel(document.status)} />
          </div>
        }
      />

      <div className="document-actions">
        <Button onClick={() => navigate('/ncrs')} variant="secondary">
          <ArrowLeft aria-hidden="true" size={16} />
          Back to NCRs
        </Button>

        {document.status !== 'CLOSED' && (
          <>
            <Button onClick={() => setIsUpdateOpen(true)} variant="secondary">
              Update Investigation
            </Button>
            <Button onClick={() => setIsRaiseCapaOpen(true)} variant="primary">
              <Plus size={16} />
              Raise CAPA Action
            </Button>
            <Button
              disabled={closeMutation.isPending}
              onClick={() => closeMutation.mutate()}
              variant="destructive"
            >
              <CheckCircle2 size={16} />
              Close NCR
            </Button>
          </>
        )}
      </div>

      <div className="document-layout">
        <section className="document-card">
          <h2>NCR Investigation Facts</h2>
          <dl className="document-facts">
            <div className="document-fact"><dt>Item</dt><dd>{document.itemName || document.itemId}</dd></div>
            <div className="document-fact"><dt>Batch</dt><dd>{document.batchNumber || 'Lot unassigned'}</dd></div>
            <div className="document-fact"><dt>Defect Reason</dt><dd>{document.reason || '--'}</dd></div>
            <div className="document-fact"><dt>Root Cause</dt><dd>{document.rootCause || 'Under investigation'}</dd></div>
            <div className="document-fact"><dt>Corrective Action</dt><dd>{document.correctiveAction || 'Pending remediation'}</dd></div>
            <div className="document-fact"><dt>Reported Date</dt><dd>{formatDate(document.createdAt)}</dd></div>
          </dl>
        </section>
      </div>

      <section className="document-card document-card--lines">
        <h2>Linked CAPA Remediations</h2>
        {linkedCapas.length > 0 ? (
          <DataTable caption="Corrective actions raised for this NCR">
            <thead>
              <tr>
                <th scope="col">CAPA #</th>
                <th scope="col">Title</th>
                <th scope="col">Proposed Action</th>
                <th scope="col">Status</th>
              </tr>
            </thead>
            <tbody>
              {linkedCapas.map((capa) => (
                <tr key={capa.id}>
                  <td><code>{capa.capaNumber}</code></td>
                  <td><strong>{capa.title}</strong></td>
                  <td>{capa.proposedAction || '--'}</td>
                  <td><StatusChip status={formatStatusLabel(capa.status)} /></td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        ) : (
          <p className="cell-muted">No CAPA actions linked yet.</p>
        )}
      </section>

      {isUpdateOpen && (
        <div className="modal-backdrop">
          <div className="modal-card">
            <h3>Update Root Cause & Corrective Action</h3>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', marginTop: '12px' }}>
              <label>
                <span style={{ fontSize: '13px', fontWeight: 600 }}>Root Cause Analysis:</span>
                <textarea
                  className="search-input"
                  onChange={(e) => setRootCause(e.target.value)}
                  placeholder="Why did this defect occur? (e.g. operator temperature setpoint drift)..."
                  rows={2}
                  style={{ width: '100%', marginTop: '4px' }}
                  value={rootCause}
                />
              </label>
              <label>
                <span style={{ fontSize: '13px', fontWeight: 600 }}>Immediate Corrective Action:</span>
                <textarea
                  className="search-input"
                  onChange={(e) => setCorrectiveAction(e.target.value)}
                  placeholder="Immediate remedial action taken..."
                  rows={2}
                  style={{ width: '100%', marginTop: '4px' }}
                  value={correctiveAction}
                />
              </label>
            </div>
            <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end', marginTop: '16px' }}>
              <Button onClick={() => setIsUpdateOpen(false)} variant="secondary">Cancel</Button>
              <Button
                disabled={updateMutation.isPending}
                onClick={() => updateMutation.mutate()}
                variant="primary"
              >
                Save Investigation
              </Button>
            </div>
          </div>
        </div>
      )}

      {isRaiseCapaOpen && (
        <div className="modal-backdrop">
          <div className="modal-card">
            <h3>Raise CAPA for this NCR</h3>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', marginTop: '12px' }}>
              <label>
                <span style={{ fontSize: '13px', fontWeight: 600 }}>CAPA Action Title:</span>
                <input
                  className="search-input"
                  onChange={(e) => setCapaTitle(e.target.value)}
                  placeholder="e.g. Install thermal interlock on sealing head"
                  style={{ width: '100%', marginTop: '4px' }}
                  value={capaTitle}
                />
              </label>
              <label>
                <span style={{ fontSize: '13px', fontWeight: 600 }}>Proposed Remediation:</span>
                <textarea
                  className="search-input"
                  onChange={(e) => setCapaAction(e.target.value)}
                  placeholder="Engineering & process modifications required..."
                  rows={2}
                  style={{ width: '100%', marginTop: '4px' }}
                  value={capaAction}
                />
              </label>
            </div>
            <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end', marginTop: '16px' }}>
              <Button onClick={() => setIsRaiseCapaOpen(false)} variant="secondary">Cancel</Button>
              <Button
                disabled={raiseCapaMutation.isPending || !capaTitle.trim()}
                onClick={() => raiseCapaMutation.mutate()}
                variant="primary"
              >
                Raise CAPA
              </Button>
            </div>
          </div>
        </div>
      )}
    </section>
  )
}