import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Banknote, DownloadCloud, Plus } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import {
  listCodRemittances,
  createCodRemittance,
  pullCodRemittance,
  type CreateCodRemittanceRequest,
  type CodLineInput,
} from '@/features/transport/transport-api'

export function CodRemittancesPage() {
  const [isImportModalOpen, setIsImportModalOpen] = useState(false)
  const [isPullModalOpen, setIsPullModalOpen] = useState(false)
  const [feedback, setFeedback] = useState<string | null>(null)
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const remittancesQuery = useQuery({
    queryKey: ['cod-remittances'],
    queryFn: listCodRemittances,
  })

  const pullMutation = useMutation({
    mutationFn: ({ partner, from, to }: { partner: string; from?: string; to?: string }) =>
      pullCodRemittance(partner, from, to),
    onSuccess: (remittance) => {
      setIsPullModalOpen(false)
      setFeedback(`Remittance ${remittance.remittanceNumber} pulled from carrier gateway.`)
      queryClient.invalidateQueries({ queryKey: ['cod-remittances'] })
      navigate(appRoutes.codRemittanceDetail(remittance.id))
    },
  })

  const createMutation = useMutation({
    mutationFn: (data: CreateCodRemittanceRequest) => createCodRemittance(data),
    onSuccess: (remittance) => {
      setIsImportModalOpen(false)
      setFeedback(`Remittance ${remittance.remittanceNumber} created.`)
      queryClient.invalidateQueries({ queryKey: ['cod-remittances'] })
      navigate(appRoutes.codRemittanceDetail(remittance.id))
    },
  })

  const remittances = remittancesQuery.data ?? []

  const totalGross = remittances.reduce((acc, r) => acc + Number(r.grossCollected ?? 0), 0)
  const totalFees = remittances.reduce((acc, r) => acc + Number(r.totalFees ?? 0), 0)
  const totalNet = remittances.reduce((acc, r) => acc + Number(r.netRemitted ?? 0), 0)
  const reconciledCount = remittances.filter((r) => r.status === 'RECONCILED').length

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Logistics & Transport / Remittance"
        title="COD Remittances"
        description="Reconciliation workbench for cash-on-delivery payments, courier fee deductions, and bank UTR settlements."
        actions={
          <div className="button-group">
            <Button onClick={() => setIsPullModalOpen(true)} variant="secondary">
              <DownloadCloud aria-hidden="true" size={16} />
              Pull from Gateway
            </Button>
            <Button onClick={() => setIsImportModalOpen(true)} variant="primary">
              <Plus aria-hidden="true" size={16} />
              Ingest Remittance
            </Button>
          </div>
        }
      />

      {feedback ? (
        <div className="notification-banner notification-banner--success" role="status">
          <p>{feedback}</p>
          <button className="banner-dismiss" onClick={() => setFeedback(null)} type="button">×</button>
        </div>
      ) : null}

      <div className="metrics-grid">
        <article className="metric-card">
          <span className="metric-label">Total Remittances</span>
          <strong className="metric-value">{remittances.length}</strong>
        </article>
        <article className="metric-card">
          <span className="metric-label">Reconciled Remittances</span>
          <strong className="metric-value">{reconciledCount}</strong>
        </article>
        <article className="metric-card">
          <span className="metric-label">Total Gross Collected</span>
          <Money amount={totalGross} />
        </article>
        <article className="metric-card">
          <span className="metric-label">Total Courier COD Fees</span>
          <Money amount={totalFees} />
        </article>
        <article className="metric-card">
          <span className="metric-label">Total Net Remitted</span>
          <Money amount={totalNet} />
        </article>
      </div>

      <section className="list-panel" aria-label="COD remittances directory">
        {remittancesQuery.isError ? (
          <div className="directory-state directory-state--error" role="alert">
            <strong>COD remittances could not be loaded.</strong>
            <p>Check your connection and permissions, then refresh the page.</p>
          </div>
        ) : remittancesQuery.isLoading ? (
          <div aria-live="polite" className="directory-state">Loading COD remittances...</div>
        ) : remittances.length ? (
          <DataTable caption="COD remittances">
            <thead>
              <tr>
                <th scope="col">Remittance #</th>
                <th scope="col">Carrier Partner</th>
                <th scope="col">Date</th>
                <th scope="col">Bank Account / UTR</th>
                <th scope="col">Gross Collected</th>
                <th scope="col">Carrier Fees</th>
                <th scope="col">Net Remitted</th>
                <th scope="col">Variance</th>
                <th scope="col">Status</th>
              </tr>
            </thead>
            <tbody>
              {remittances.map((rem) => (
                <tr
                  className="data-table-row--interactive"
                  key={rem.id}
                  onClick={() => navigate(appRoutes.codRemittanceDetail(rem.id))}
                  tabIndex={0}
                >
                  <td>
                    <div className="cell-stack">
                      <strong>{rem.remittanceNumber}</strong>
                      {rem.notes ? <span className="cell-muted">{rem.notes}</span> : null}
                    </div>
                  </td>
                  <td>{rem.courierPartner}</td>
                  <td>{formatDate(rem.remittanceDate)}</td>
                  <td>
                    <div className="cell-stack">
                      <span>{rem.bankAccount ?? '--'}</span>
                      {rem.utr ? <span className="cell-muted">UTR: {rem.utr}</span> : null}
                    </div>
                  </td>
                  <td><Money amount={rem.grossCollected} /></td>
                  <td><Money amount={rem.totalFees} /></td>
                  <td><Money amount={rem.netRemitted} /></td>
                  <td>
                    {Number(rem.variance ?? 0) !== 0 ? (
                      <span className="text-warning"><Money amount={rem.variance} /></span>
                    ) : (
                      <Money amount={0} />
                    )}
                  </td>
                  <td><StatusChip status={formatStatusLabel(rem.status)} /></td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        ) : (
          <div className="directory-state directory-state--empty">
            <Banknote aria-hidden="true" size={32} />
            <strong>No COD remittances found.</strong>
            <p>Ingest a remittance sheet or pull directly from your courier provider.</p>
          </div>
        )}
      </section>

      {isPullModalOpen ? (
        <PullCodModal
          isSubmitting={pullMutation.isPending}
          onClose={() => setIsPullModalOpen(false)}
          onSubmit={(p) => pullMutation.mutate(p)}
        />
      ) : null}

      {isImportModalOpen ? (
        <CreateCodModal
          isSubmitting={createMutation.isPending}
          onClose={() => setIsImportModalOpen(false)}
          onSubmit={(d) => createMutation.mutate(d)}
        />
      ) : null}
    </section>
  )
}

function PullCodModal({
  isSubmitting,
  onClose,
  onSubmit,
}: {
  isSubmitting: boolean
  onClose: () => void
  onSubmit: (params: { partner: string; from?: string; to?: string }) => void
}) {
  const [partner, setPartner] = useState('BLUEDART')
  const [from, setFrom] = useState('')
  const [to, setTo] = useState('')

  return (
    <div className="modal-backdrop" role="dialog" aria-modal="true">
      <div className="modal-card">
        <header className="modal-header">
          <h2>Pull COD Remittance via API</h2>
          <button className="modal-close" onClick={onClose} type="button">×</button>
        </header>
        <form onSubmit={(e) => { e.preventDefault(); onSubmit({ partner, from: from || undefined, to: to || undefined }); }}>
          <div className="form-group">
            <label htmlFor="pull-partner">Carrier / Aggregator *</label>
            <select
              id="pull-partner"
              value={partner}
              onChange={(e) => setPartner(e.target.value)}
            >
              <option value="BLUEDART">Blue Dart</option>
              <option value="DELHIVERY">Delhivery</option>
              <option value="SHIPROCKET">Shiprocket</option>
              <option value="DTDC">DTDC</option>
            </select>
          </div>

          <div className="form-row">
            <div className="form-group">
              <label htmlFor="pull-from">From Date</label>
              <input
                id="pull-from"
                type="date"
                value={from}
                onChange={(e) => setFrom(e.target.value)}
              />
            </div>
            <div className="form-group">
              <label htmlFor="pull-to">To Date</label>
              <input
                id="pull-to"
                type="date"
                value={to}
                onChange={(e) => setTo(e.target.value)}
              />
            </div>
          </div>

          <footer className="modal-footer">
            <Button onClick={onClose} type="button" variant="secondary">Cancel</Button>
            <Button disabled={isSubmitting} type="submit" variant="primary">
              {isSubmitting ? 'Pulling...' : 'Pull Remittance'}
            </Button>
          </footer>
        </form>
      </div>
    </div>
  )
}

function CreateCodModal({
  isSubmitting,
  onClose,
  onSubmit,
}: {
  isSubmitting: boolean
  onClose: () => void
  onSubmit: (data: CreateCodRemittanceRequest) => void
}) {
  const [courierPartner, setCourierPartner] = useState('BLUEDART')
  const [remittanceDate, setRemittanceDate] = useState(new Date().toISOString().slice(0, 10))
  const [bankAccount, setBankAccount] = useState('')
  const [utr, setUtr] = useState('')
  const [netRemitted, setNetRemitted] = useState<number | undefined>(undefined)
  const [notes, setNotes] = useState('')
  const [lines, setLines] = useState<CodLineInput[]>([
    { awbNumber: '', codAmount: 0, codFee: 0 },
  ])

  const handleAddLine = () => {
    setLines([...lines, { awbNumber: '', codAmount: 0, codFee: 0 }])
  }

  const handleRemoveLine = (idx: number) => {
    setLines(lines.filter((_, i) => i !== idx))
  }

  const handleLineChange = (idx: number, field: keyof CodLineInput, val: unknown) => {
    const updated = [...lines]
    const cur = updated[idx]
    if (!cur) return
    updated[idx] = {
      ...cur,
      [field]: val,
    } as CodLineInput
    setLines(updated)
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    const validLines = lines.filter((l) => l.awbNumber.trim())
    if (!validLines.length) return
    onSubmit({
      courierPartner,
      remittanceDate,
      bankAccount: bankAccount.trim() || null,
      utr: utr.trim() || null,
      netRemitted: netRemitted ?? null,
      notes: notes.trim() || null,
      lines: validLines,
    })
  }

  return (
    <div className="modal-backdrop" role="dialog" aria-modal="true">
      <div className="modal-card modal-card--wide">
        <header className="modal-header">
          <h2>Ingest COD Remittance Sheet</h2>
          <button className="modal-close" onClick={onClose} type="button">×</button>
        </header>
        <form onSubmit={handleSubmit}>
          <div className="form-row">
            <div className="form-group">
              <label htmlFor="cod-partner">Carrier Partner *</label>
              <select
                id="cod-partner"
                value={courierPartner}
                onChange={(e) => setCourierPartner(e.target.value)}
              >
                <option value="BLUEDART">Blue Dart</option>
                <option value="DELHIVERY">Delhivery</option>
                <option value="INDIA_POST">India Post</option>
                <option value="DTDC">DTDC</option>
                <option value="SHIPROCKET">Shiprocket</option>
                <option value="OTHER">Other</option>
              </select>
            </div>
            <div className="form-group">
              <label htmlFor="cod-date">Remittance Date *</label>
              <input
                id="cod-date"
                required
                type="date"
                value={remittanceDate}
                onChange={(e) => setRemittanceDate(e.target.value)}
              />
            </div>
          </div>

          <div className="form-row">
            <div className="form-group">
              <label htmlFor="cod-bank">Bank Account</label>
              <input
                id="cod-bank"
                placeholder="e.g. HDFC 00129384"
                type="text"
                value={bankAccount}
                onChange={(e) => setBankAccount(e.target.value)}
              />
            </div>
            <div className="form-group">
              <label htmlFor="cod-utr">UTR / Settlement Reference</label>
              <input
                id="cod-utr"
                placeholder="e.g. HDFCN26182947192"
                type="text"
                value={utr}
                onChange={(e) => setUtr(e.target.value)}
              />
            </div>
            <div className="form-group">
              <label htmlFor="cod-net">Net Remitted Amount (₹)</label>
              <input
                id="cod-net"
                min="0"
                step="0.01"
                type="number"
                value={netRemitted ?? ''}
                onChange={(e) => setNetRemitted(e.target.value ? Number(e.target.value) : undefined)}
              />
            </div>
          </div>

          <div className="form-group">
            <label htmlFor="cod-notes">Remittance Notes</label>
            <input
              id="cod-notes"
              type="text"
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
            />
          </div>

          <div className="form-group">
            <label>Remitted Consignment AWBs</label>
            <div className="table-wrapper">
              <table className="data-table">
                <thead>
                  <tr>
                    <th>AWB Number *</th>
                    <th>COD Amount Collected (₹) *</th>
                    <th>Courier Fee Deducted (₹)</th>
                    <th>Action</th>
                  </tr>
                </thead>
                <tbody>
                  {lines.map((ln, idx) => (
                    <tr key={idx}>
                      <td>
                        <input
                          placeholder="e.g. 19284719283"
                          required
                          type="text"
                          value={ln.awbNumber}
                          onChange={(e) => handleLineChange(idx, 'awbNumber', e.target.value)}
                        />
                      </td>
                      <td>
                        <input
                          min="0"
                          required
                          step="0.01"
                          type="number"
                          value={ln.codAmount || ''}
                          onChange={(e) => handleLineChange(idx, 'codAmount', Number(e.target.value))}
                        />
                      </td>
                      <td>
                        <input
                          min="0"
                          step="0.01"
                          type="number"
                          value={ln.codFee || ''}
                          onChange={(e) => handleLineChange(idx, 'codFee', Number(e.target.value))}
                        />
                      </td>
                      <td>
                        <Button
                          disabled={lines.length === 1}
                          onClick={() => handleRemoveLine(idx)}
                          type="button"
                          variant="ghost"
                        >
                          Remove
                        </Button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <div style={{ marginTop: '0.5rem' }}>
              <Button onClick={handleAddLine} type="button" variant="secondary">
                <Plus aria-hidden="true" size={14} /> Add Line
              </Button>
            </div>
          </div>

          <footer className="modal-footer">
            <Button onClick={onClose} type="button" variant="secondary">Cancel</Button>
            <Button disabled={isSubmitting} type="submit" variant="primary">
              {isSubmitting ? 'Ingesting...' : 'Save Remittance'}
            </Button>
          </footer>
        </form>
      </div>
    </div>
  )
}