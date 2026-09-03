import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, CheckCheck } from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import {
  getCodRemittance,
  reconcileCodRemittance,
  type CodLineResponse,
} from '@/features/transport/transport-api'

export function CodRemittanceDetailPage() {
  const { remittanceId } = useParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [feedback, setFeedback] = useState<string | null>(null)

  const remittanceQuery = useQuery({
    queryKey: ['cod-remittance', remittanceId],
    queryFn: () => getCodRemittance(remittanceId!),
    enabled: Boolean(remittanceId),
  })

  const reconcileMutation = useMutation({
    mutationFn: () => reconcileCodRemittance(remittanceId!),
    onSuccess: (res) => {
      setFeedback(
        `Reconciliation complete: ${res.matched} matched & settled, ${res.amountMismatch} amount mismatches, ${res.orphan} orphans.`,
      )
      queryClient.invalidateQueries({ queryKey: ['cod-remittance', remittanceId] })
      queryClient.invalidateQueries({ queryKey: ['cod-remittances'] })
    },
  })

  if (!remittanceId) return <div className="directory-state directory-state--error">Remittance ID missing.</div>
  if (remittanceQuery.isLoading) return <div className="directory-state">Loading remittance...</div>
  if (remittanceQuery.isError || !remittanceQuery.data) {
    return (
      <div className="directory-state directory-state--error">
        <strong>COD Remittance could not be loaded.</strong>
        <Button onClick={() => navigate(appRoutes.codRemittances)} variant="secondary">Back to Remittances</Button>
      </div>
    )
  }

  const remittance = remittanceQuery.data

  const matchedLines = remittance.lines?.filter((l) => l.matchStatus === 'MATCHED').length ?? 0
  const mismatchLines = remittance.lines?.filter((l) => l.matchStatus === 'AMOUNT_MISMATCH').length ?? 0
  const orphanLines = remittance.lines?.filter((l) => l.matchStatus === 'ORPHAN').length ?? 0

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Logistics & Transport / COD Remittance"
        title={remittance.remittanceNumber}
        description={`${remittance.courierPartner} Â· ${formatDate(remittance.remittanceDate)} Â· UTR: ${remittance.utr ?? 'Pending'}`}
        actions={
          <div className="button-group">
            {remittance.status !== 'RECONCILED' ? (
              <Button
                disabled={reconcileMutation.isPending}
                onClick={() => reconcileMutation.mutate()}
                variant="primary"
              >
                <CheckCheck aria-hidden="true" size={16} />
                {reconcileMutation.isPending ? 'Reconciling...' : 'Reconcile & Settle Invoices'}
              </Button>
            ) : null}
          </div>
        }
      />

      <div className="document-actions">
        <Button onClick={() => navigate(appRoutes.codRemittances)} variant="secondary">
          <ArrowLeft aria-hidden="true" size={16} />
          Back to Remittances
        </Button>
        <StatusChip status={formatStatusLabel(remittance.status)} />
      </div>

      {feedback ? (
        <div className="notification-banner notification-banner--success" role="status">
          <p>{feedback}</p>
          <button className="banner-dismiss" onClick={() => setFeedback(null)} type="button">×</button>
        </div>
      ) : null}

      <div className="document-layout">
        <section className="document-card">
          <h2>Remittance Settlement Summary</h2>
          <dl className="document-facts">
            <div className="document-fact">
              <dt>Courier Partner</dt>
              <dd>{remittance.courierPartner}</dd>
            </div>
            <div className="document-fact">
              <dt>Remittance Date</dt>
              <dd>{formatDate(remittance.remittanceDate)}</dd>
            </div>
            <div className="document-fact">
              <dt>Bank Account</dt>
              <dd>{remittance.bankAccount ?? '--'}</dd>
            </div>
            <div className="document-fact">
              <dt>UTR / Ref Number</dt>
              <dd>{remittance.utr ?? '--'}</dd>
            </div>
            <div className="document-fact">
              <dt>Gross Collected</dt>
              <dd><Money amount={remittance.grossCollected} /></dd>
            </div>
            <div className="document-fact">
              <dt>Total Courier Fees</dt>
              <dd><Money amount={remittance.totalFees} /></dd>
            </div>
            <div className="document-fact">
              <dt>Net Remitted</dt>
              <dd><Money amount={remittance.netRemitted} /></dd>
            </div>
            <div className="document-fact">
              <dt>Expected Net</dt>
              <dd><Money amount={remittance.expectedNet} /></dd>
            </div>
            <div className="document-fact">
              <dt>Variance</dt>
              <dd>
                {Number(remittance.variance ?? 0) !== 0 ? (
                  <span className="text-warning"><Money amount={remittance.variance} /></span>
                ) : (
                  <Money amount={0} />
                )}
              </dd>
            </div>
          </dl>
        </section>

        <aside className="document-card document-card--summary">
          <h2>Reconciliation Scorecard</h2>
          <div className="progress-row">
            <span>Matched & Auto-settled</span>
            <span className="text-success font-semibold">{matchedLines}</span>
          </div>
          <div className="progress-row">
            <span>Amount Mismatches</span>
            <span className="text-warning font-semibold">{mismatchLines}</span>
          </div>
          <div className="progress-row">
            <span>Orphan AWBs (Unlinked)</span>
            <span className="text-destructive font-semibold">{orphanLines}</span>
          </div>
          <div className="progress-row">
            <span>Total Lines Ingested</span>
            <strong>{remittance.lines?.length ?? 0}</strong>
          </div>
        </aside>
      </div>

      <section className="document-card">
        <h2>Ingested AWB Lines & Match Workbench</h2>
        {remittance.lines && remittance.lines.length > 0 ? (
          <DataTable caption="COD line items">
            <thead>
              <tr>
                <th scope="col">AWB Number</th>
                <th scope="col">Shipment Link</th>
                <th scope="col">Invoice Link</th>
                <th scope="col">COD Collected</th>
                <th scope="col">Fee Deducted</th>
                <th scope="col">Net Amount</th>
                <th scope="col">Match Status</th>
                <th scope="col">Payment Posted</th>
              </tr>
            </thead>
            <tbody>
              {remittance.lines.map((line: CodLineResponse) => (
                <tr key={line.id}>
                  <td>
                    <strong>{line.awbNumber}</strong>
                  </td>
                  <td>
                    {line.courierShipmentId ? (
                      <button
                        className="link-button"
                        onClick={() => navigate(appRoutes.courierShipmentDetail(line.courierShipmentId!))}
                        type="button"
                      >
                        View Shipment
                      </button>
                    ) : (
                      <span className="cell-muted">Unlinked</span>
                    )}
                  </td>
                  <td>
                    {line.invoiceId ? (
                      <button
                        className="link-button"
                        onClick={() => navigate(appRoutes.invoiceDetail(line.invoiceId!))}
                        type="button"
                      >
                        View Invoice
                      </button>
                    ) : (
                      <span className="cell-muted">--</span>
                    )}
                  </td>
                  <td><Money amount={line.codAmount} /></td>
                  <td><Money amount={line.codFee} /></td>
                  <td><Money amount={line.netAmount} /></td>
                  <td>
                    <StatusChip status={formatStatusLabel(line.matchStatus)} />
                  </td>
                  <td>
                    {line.paymentId ? (
                      <button
                        className="link-button"
                        onClick={() => navigate(appRoutes.paymentDetail(line.paymentId!))}
                        type="button"
                      >
                        Payment Journal
                      </button>
                    ) : (
                      <span className="cell-muted">Pending settlement</span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        ) : (
          <div className="directory-state directory-state--empty">
            <p>No lines found in this remittance.</p>
          </div>
        )}
      </section>
    </section>
  )
}