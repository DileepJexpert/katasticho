import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useNavigate, useParams } from 'react-router-dom'
import {
  ArrowLeft,
  CheckCircle2,
  FileText,
  Plus,
  Send,
  X,
} from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate } from '@/shared/format/format'
import {
  addDcrDoctorCall,
  approveDcr,
  getDcr,
  submitDcr,
} from '@/features/field-sales/field-sales-api'

export function DcrDetailPage() {
  const { dcrId = '' } = useParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [isAddCallOpen, setIsAddCallOpen] = useState(false)

  const { data: dcr, isLoading, isError } = useQuery({
    queryKey: ['mr', 'dcr', dcrId],
    queryFn: () => getDcr(dcrId),
    enabled: !!dcrId,
  })

  const submitMutation = useMutation({
    mutationFn: () => submitDcr(dcrId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['mr', 'dcr', dcrId] })
    },
  })

  const approveMutation = useMutation({
    mutationFn: () => approveDcr(dcrId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['mr', 'dcr', dcrId] })
    },
  })

  const addCallMutation = useMutation({
    mutationFn: (payload: {
      doctorId: string
      doctorName?: string
      specialty?: string
      productsDetailed?: string[]
      samplesGiven?: Array<{ productName: string; quantity: number }>
      pobAmount?: number
      nextFollowUpDate?: string
      remarks?: string
    }) => addDcrDoctorCall(dcrId, payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['mr', 'dcr', dcrId] })
      setIsAddCallOpen(false)
    },
  })

  if (isLoading) return <div className="directory-state">Loading DCR workbench...</div>
  if (isError || !dcr) return <DocumentError onBack={() => navigate('/mr/dcr')} />

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <div style={{ display: 'flex', gap: 8 }}>
            {dcr.status === 'DRAFT' ? (
              <>
                <Button onClick={() => setIsAddCallOpen(true)} type="button" variant="secondary">
                  <Plus aria-hidden="true" size={16} />
                  <span>Log Doctor Call</span>
                </Button>
                <Button
                  disabled={submitMutation.isPending}
                  onClick={() => submitMutation.mutate()}
                  type="button"
                  variant="primary"
                >
                  <Send aria-hidden="true" size={16} />
                  <span>Submit for Signoff</span>
                </Button>
              </>
            ) : null}

            {dcr.status === 'SUBMITTED' ? (
              <Button
                disabled={approveMutation.isPending}
                onClick={() => approveMutation.mutate()}
                type="button"
                variant="primary"
              >
                <CheckCircle2 aria-hidden="true" size={16} />
                <span>Approve DCR</span>
              </Button>
            ) : null}
          </div>
        }
        description={`Report Date: ${formatDate(dcr.reportDate)} | Work Type: ${dcr.workType}`}
        eyebrow="Daily Call Report"
        title={`DCR â€” ${dcr.salespersonName || 'Medical Rep'}`}
      />

      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 16 }}>
        <button className="button button--ghost" onClick={() => navigate('/mr/dcr')} type="button">
          <ArrowLeft aria-hidden="true" size={16} />
          <span>Back to DCRs</span>
        </button>
      </div>

      <div className="summary-strip">
        <div className="metric-cell">
          <span className="metric-label">DCR Status</span>
          <strong className="metric-value"><StatusChip status={dcr.status} /></strong>
        </div>
        <div className="metric-cell">
          <span className="metric-label">Doctor Calls</span>
          <strong className="metric-value">{dcr.totalDoctorCalls ?? 0}</strong>
        </div>
        <div className="metric-cell">
          <span className="metric-label">Chemist Calls</span>
          <strong className="metric-value">{dcr.totalChemistCalls ?? 0}</strong>
        </div>
        <div className="metric-cell">
          <span className="metric-label">Total POB Booked</span>
          <strong className="metric-value"><Money amount={dcr.totalPobValue ?? 0} /></strong>
        </div>
      </div>

      <div className="table-card">
        <div className="card-header" style={{ padding: '16px 20px', borderBottom: '1px solid var(--k-color-border)' }}>
          <h3 style={{ margin: 0, fontSize: '1rem', fontWeight: 600 }}>Doctor & Chemist Call Logs</h3>
        </div>

        <DataTable caption="Doctor Call Logs">
          <thead>
            <tr>
              <th scope="col">Doctor / Contact</th>
              <th scope="col">Specialty</th>
              <th scope="col">Products Detailed</th>
              <th scope="col" style={{ textAlign: 'right' }}>Samples Given</th>
              <th scope="col" style={{ textAlign: 'right' }}>POB Value</th>
              <th scope="col">Remarks</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td><strong>Dr. Rajesh Sharma, MD</strong></td>
              <td>Cardiologist</td>
              <td>Atorvastatin 20mg, Telmisartan 40mg</td>
              <td style={{ textAlign: 'right' }}>4 units</td>
              <td style={{ textAlign: 'right' }}><strong><Money amount={12500} /></strong></td>
              <td>Prescribing regular brand switches</td>
            </tr>
          </tbody>
        </DataTable>
      </div>

      {isAddCallOpen ? (
        <AddDoctorCallModal
          isPending={addCallMutation.isPending}
          onClose={() => setIsAddCallOpen(false)}
          onSubmit={(payload) => addCallMutation.mutate(payload)}
        />
      ) : null}
    </section>
  )
}

function AddDoctorCallModal({
  onClose,
  onSubmit,
  isPending,
}: {
  onClose: () => void
  onSubmit: (payload: {
    doctorId: string
    doctorName?: string
    specialty?: string
    productsDetailed?: string[]
    pobAmount?: number
    remarks?: string
  }) => void
  isPending: boolean
}) {
  const [doctorName, setDoctorName] = useState('')
  const [specialty, setSpecialty] = useState('Physician')
  const [productsDetailed, setProductsDetailed] = useState('Paracetamol 650mg, Amoxicillin 500mg')
  const [pobAmount, setPobAmount] = useState(0)
  const [remarks, setRemarks] = useState('')

  return (
    <div className="modal-backdrop">
      <div className="modal-card" style={{ maxWidth: 480 }}>
        <div className="modal-header">
          <h2 className="modal-title">Log Doctor Call & Detailing</h2>
          <button aria-label="Close" className="button button--ghost" onClick={onClose} type="button">
            <X aria-hidden="true" size={18} />
          </button>
        </div>

        <form
          onSubmit={(e) => {
            e.preventDefault()
            onSubmit({
              doctorId: 'doc-uuid',
              doctorName,
              specialty,
              productsDetailed: productsDetailed.split(',').map((s) => s.trim()).filter(Boolean),
              pobAmount,
              remarks,
            })
          }}
        >
          <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: 12 }}>
              <div className="form-field">
                <label className="form-label" htmlFor="doc-name">Doctor Name *</label>
                <input
                  className="form-input"
                  id="doc-name"
                  onChange={(e) => setDoctorName(e.target.value)}
                  placeholder="Dr. S. K. Gupta"
                  required
                  value={doctorName}
                />
              </div>

              <div className="form-field">
                <label className="form-label" htmlFor="doc-spec">Specialty</label>
                <input
                  className="form-input"
                  id="doc-spec"
                  onChange={(e) => setSpecialty(e.target.value)}
                  placeholder="Physician"
                  value={specialty}
                />
              </div>
            </div>

            <div className="form-field">
              <label className="form-label" htmlFor="doc-prods">Products Detailed (comma separated)</label>
              <input
                className="form-input"
                id="doc-prods"
                onChange={(e) => setProductsDetailed(e.target.value)}
                placeholder="Product A, Product B"
                value={productsDetailed}
              />
            </div>

            <div className="form-field">
              <label className="form-label" htmlFor="doc-pob">Personal Order Booking (POB) â‚¹</label>
              <input
                className="form-input"
                id="doc-pob"
                min={0}
                onChange={(e) => setPobAmount(parseFloat(e.target.value) || 0)}
                type="number"
                value={pobAmount || ''}
              />
            </div>

            <div className="form-field">
              <label className="form-label" htmlFor="doc-rem">Call Discussion Notes</label>
              <textarea
                className="form-input"
                id="doc-rem"
                onChange={(e) => setRemarks(e.target.value)}
                placeholder="Discussed clinical trial results, sample gifted..."
                rows={2}
                value={remarks}
              />
            </div>
          </div>

          <div className="modal-footer">
            <Button onClick={onClose} type="button" variant="secondary">Cancel</Button>
            <Button disabled={isPending || !doctorName} type="submit" variant="primary">
              {isPending ? 'Logging...' : 'Save Doctor Call'}
            </Button>
          </div>
        </form>
      </div>
    </div>
  )
}

function DocumentError({ onBack }: { onBack: () => void }) {
  return (
    <section className="workspace-page">
      <div className="directory-state directory-state--error" role="alert">
        <FileText aria-hidden="true" size={24} />
        <p>Daily Call Report could not be found or loaded.</p>
        <Button onClick={onBack} type="button" variant="secondary">Return to DCRs</Button>
      </div>
    </section>
  )
}
