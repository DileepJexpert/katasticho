import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useNavigate, useParams } from 'react-router-dom'
import {
  ArrowLeft,
  CheckCircle2,
  DollarSign,
  MapPin,
  Play,
  ShoppingBag,
  Square,
  X,
  XCircle,
} from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate } from '@/shared/format/format'
import {
  checkInVisit,
  checkOutVisit,
  completeRoute,
  getExecution,
  getExecutionVisits,
  recordVisitCollection,
  recordVisitOrder,
  skipVisit,
  startRoute,
  type FieldVisit,
} from '@/features/field-sales/field-sales-api'

export function RouteExecutionDetailPage() {
  const { executionId = '' } = useParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [selectedVisit, setSelectedVisit] = useState<FieldVisit | null>(null)
  const [actionModal, setActionModal] = useState<'order' | 'collection' | 'skip' | null>(null)

  const { data: execution, isLoading, isError } = useQuery({
    queryKey: ['field-sales', 'executions', executionId],
    queryFn: () => getExecution(executionId),
    enabled: !!executionId,
  })

  const { data: visits = [] } = useQuery({
    queryKey: ['field-sales', 'executions', executionId, 'visits'],
    queryFn: () => getExecutionVisits(executionId),
    enabled: !!executionId,
  })

  const startRunMutation = useMutation({
    mutationFn: () => startRoute(executionId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['field-sales', 'executions', executionId] })
    },
  })

  const completeRunMutation = useMutation({
    mutationFn: () => completeRoute(executionId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['field-sales', 'executions', executionId] })
    },
  })

  const checkInMutation = useMutation({
    mutationFn: (visitId: string) => checkInVisit(visitId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['field-sales', 'executions', executionId] })
    },
  })

  const checkOutMutation = useMutation({
    mutationFn: (visitId: string) => checkOutVisit(visitId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['field-sales', 'executions', executionId] })
    },
  })

  const orderMutation = useMutation({
    mutationFn: ({ visitId, orderValue, salesOrderId }: { visitId: string; orderValue: number; salesOrderId?: string }) =>
      recordVisitOrder(visitId, salesOrderId, orderValue),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['field-sales', 'executions', executionId] })
      setActionModal(null)
    },
  })

  const collectionMutation = useMutation({
    mutationFn: ({ visitId, amount, paymentMode, referenceNumber }: { visitId: string; amount: number; paymentMode: string; referenceNumber?: string }) =>
      recordVisitCollection(visitId, amount, paymentMode, referenceNumber),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['field-sales', 'executions', executionId] })
      setActionModal(null)
    },
  })

  const skipMutation = useMutation({
    mutationFn: ({ visitId, reason }: { visitId: string; reason: string }) =>
      skipVisit(visitId, reason),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['field-sales', 'executions', executionId] })
      setActionModal(null)
    },
  })

  if (isLoading) return <div className="directory-state">Loading route run workbench...</div>
  if (isError || !execution) return <DocumentError onBack={() => navigate('/field-sales/executions')} />

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <div style={{ display: 'flex', gap: 8 }}>
            {execution.status === 'SCHEDULED' ? (
              <Button
                disabled={startRunMutation.isPending}
                onClick={() => startRunMutation.mutate()}
                type="button"
                variant="primary"
              >
                <Play aria-hidden="true" size={16} />
                <span>Start Field Run</span>
              </Button>
            ) : execution.status === 'IN_PROGRESS' ? (
              <Button
                disabled={completeRunMutation.isPending}
                onClick={() => completeRunMutation.mutate()}
                type="button"
                variant="secondary"
              >
                <Square aria-hidden="true" size={16} />
                <span>Complete Route Run</span>
              </Button>
            ) : null}
          </div>
        }
        description={`Salesperson: ${execution.salespersonName || 'Assigned'} | Van: ${execution.vanCode || 'Direct'} | Date: ${formatDate(execution.executionDate)}`}
        eyebrow="Route Execution Workbench"
        title={`${execution.routeName || 'Field Run'} â€” Execution`}
      />

      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 16 }}>
        <button className="button button--ghost" onClick={() => navigate('/field-sales/executions')} type="button">
          <ArrowLeft aria-hidden="true" size={16} />
          <span>Back to Executions</span>
        </button>
      </div>

      <div className="summary-strip">
        <div className="metric-cell">
          <span className="metric-label">Run Status</span>
          <strong className="metric-value"><StatusChip status={execution.status} /></strong>
        </div>
        <div className="metric-cell">
          <span className="metric-label">Completed Visits</span>
          <strong className="metric-value">{execution.completedVisits ?? 0} / {execution.totalVisits ?? 0}</strong>
        </div>
        <div className="metric-cell">
          <span className="metric-label">Orders Booked</span>
          <strong className="metric-value">
            <Money amount={execution.totalOrderValue ?? 0} />
          </strong>
        </div>
        <div className="metric-cell">
          <span className="metric-label">Collections Logged</span>
          <strong className="metric-value">
            <Money amount={execution.totalCollections ?? 0} />
          </strong>
        </div>
      </div>

      <div className="table-card">
        <div className="card-header" style={{ padding: '16px 20px', borderBottom: '1px solid var(--k-color-border)' }}>
          <h3 style={{ margin: 0, fontSize: '1rem', fontWeight: 600 }}>Customer Stops & Visit Sequence</h3>
        </div>

        {visits.length === 0 ? (
          <div className="directory-state">
            <MapPin aria-hidden="true" size={32} />
            <p>No customer visit stops generated for this route run.</p>
          </div>
        ) : (
          <DataTable caption="Visit Stops Progression">
            <thead>
              <tr>
                <th scope="col" style={{ width: 80 }}>Seq #</th>
                <th scope="col">Customer / Outlet</th>
                <th scope="col">Status</th>
                <th scope="col" style={{ textAlign: 'right' }}>Order Value</th>
                <th scope="col" style={{ textAlign: 'right' }}>Collection</th>
                <th scope="col" style={{ textAlign: 'right' }}>Field Actions</th>
              </tr>
            </thead>
            <tbody>
              {visits.map((v: FieldVisit) => (
                <tr key={v.id}>
                  <td><strong>#{v.visitSequence ?? 1}</strong></td>
                  <td><strong>{v.contactName || 'Retail Customer'}</strong></td>
                  <td><StatusChip status={v.status} /></td>
                  <td style={{ textAlign: 'right' }}>
                    {v.orderValue ? <Money amount={v.orderValue} /> : 'â€”'}
                  </td>
                  <td style={{ textAlign: 'right' }}>
                    {v.collectionAmount ? <Money amount={v.collectionAmount} /> : 'â€”'}
                  </td>
                  <td style={{ textAlign: 'right' }}>
                    <div style={{ display: 'inline-flex', gap: 6 }}>
                      {v.status === 'PENDING' ? (
                        <Button
                          disabled={checkInMutation.isPending}
                          onClick={() => checkInMutation.mutate(v.id)}
                          type="button"
                          variant="secondary"
                        >
                          <MapPin aria-hidden="true" size={14} />
                          <span>Check In</span>
                        </Button>
                      ) : v.status === 'CHECKED_IN' ? (
                        <>
                          <Button
                            onClick={() => {
                              setSelectedVisit(v)
                              setActionModal('order')
                            }}
                            type="button"
                            variant="secondary"
                          >
                            <ShoppingBag aria-hidden="true" size={14} />
                            <span>Order</span>
                          </Button>
                          <Button
                            onClick={() => {
                              setSelectedVisit(v)
                              setActionModal('collection')
                            }}
                            type="button"
                            variant="secondary"
                          >
                            <DollarSign aria-hidden="true" size={14} />
                            <span>Collection</span>
                          </Button>
                          <Button
                            disabled={checkOutMutation.isPending}
                            onClick={() => checkOutMutation.mutate(v.id)}
                            type="button"
                            variant="primary"
                          >
                            <CheckCircle2 aria-hidden="true" size={14} />
                            <span>Check Out</span>
                          </Button>
                        </>
                      ) : null}

                      {v.status === 'PENDING' ? (
                        <Button
                          onClick={() => {
                            setSelectedVisit(v)
                            setActionModal('skip')
                          }}
                          type="button"
                          variant="ghost"
                        >
                          <XCircle aria-hidden="true" size={14} />
                          <span>Skip</span>
                        </Button>
                      ) : null}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        )}
      </div>

      {actionModal === 'order' && selectedVisit ? (
        <RecordOrderModal
          isPending={orderMutation.isPending}
          onClose={() => {
            setActionModal(null)
            setSelectedVisit(null)
          }}
          onSubmit={(orderValue, salesOrderId) =>
            orderMutation.mutate({ visitId: selectedVisit.id, orderValue, salesOrderId })
          }
          visit={selectedVisit}
        />
      ) : null}

      {actionModal === 'collection' && selectedVisit ? (
        <RecordCollectionModal
          isPending={collectionMutation.isPending}
          onClose={() => {
            setActionModal(null)
            setSelectedVisit(null)
          }}
          onSubmit={(amount, paymentMode, referenceNumber) =>
            collectionMutation.mutate({ visitId: selectedVisit.id, amount, paymentMode, referenceNumber })
          }
          visit={selectedVisit}
        />
      ) : null}

      {actionModal === 'skip' && selectedVisit ? (
        <SkipVisitModal
          isPending={skipMutation.isPending}
          onClose={() => {
            setActionModal(null)
            setSelectedVisit(null)
          }}
          onSubmit={(reason) => skipMutation.mutate({ visitId: selectedVisit.id, reason })}
          visit={selectedVisit}
        />
      ) : null}
    </section>
  )
}

function RecordOrderModal({
  visit,
  onClose,
  onSubmit,
  isPending,
}: {
  visit: FieldVisit
  onClose: () => void
  onSubmit: (orderValue: number, salesOrderId?: string) => void
  isPending: boolean
}) {
  const [orderValue, setOrderValue] = useState(0)
  const [salesOrderId, setSalesOrderId] = useState('')

  return (
    <div className="modal-backdrop">
      <div className="modal-card" style={{ maxWidth: 440 }}>
        <div className="modal-header">
          <h2 className="modal-title">Record Visit Order â€” {visit.contactName || 'Customer'}</h2>
          <button aria-label="Close" className="button button--ghost" onClick={onClose} type="button">
            <X aria-hidden="true" size={18} />
          </button>
        </div>

        <form
          onSubmit={(e) => {
            e.preventDefault()
            onSubmit(orderValue, salesOrderId || undefined)
          }}
        >
          <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            <div>
              <label className="form-label" htmlFor="order-val">Order Value (₹) *</label>
              <input
                className="form-input"
                id="order-val"
                min="0"
                onChange={(e) => setOrderValue(Number(e.target.value))}
                required
                step="0.01"
                type="number"
                value={orderValue}
              />
            </div>

            <div>
              <label className="form-label" htmlFor="order-so-id">Linked Sales Order UUID (Optional)</label>
              <input
                className="form-input"
                id="order-so-id"
                onChange={(e) => setSalesOrderId(e.target.value)}
                placeholder="SO UUID"
                type="text"
                value={salesOrderId}
              />
            </div>
          </div>

          <div className="modal-footer" style={{ display: 'flex', justifyContent: 'flex-end', gap: 8, marginTop: 16 }}>
            <Button onClick={onClose} type="button" variant="secondary">Cancel</Button>
            <Button disabled={isPending || orderValue <= 0} type="submit" variant="primary">
              {isPending ? 'Recording...' : 'Save Order'}
            </Button>
          </div>
        </form>
      </div>
    </div>
  )
}

function RecordCollectionModal({
  visit,
  onClose,
  onSubmit,
  isPending,
}: {
  visit: FieldVisit
  onClose: () => void
  onSubmit: (amount: number, paymentMode: string, referenceNumber?: string) => void
  isPending: boolean
}) {
  const [amount, setAmount] = useState(0)
  const [paymentMode, setPaymentMode] = useState('CASH')
  const [referenceNumber, setReferenceNumber] = useState('')

  return (
    <div className="modal-backdrop">
      <div className="modal-card" style={{ maxWidth: 440 }}>
        <div className="modal-header">
          <h2 className="modal-title">Record Payment Collection â€” {visit.contactName || 'Customer'}</h2>
          <button aria-label="Close" className="button button--ghost" onClick={onClose} type="button">
            <X aria-hidden="true" size={18} />
          </button>
        </div>

        <form
          onSubmit={(e) => {
            e.preventDefault()
            onSubmit(amount, paymentMode, referenceNumber || undefined)
          }}
        >
          <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            <div>
              <label className="form-label" htmlFor="coll-amt">Collected Amount (₹) *</label>
              <input
                className="form-input"
                id="coll-amt"
                min="0"
                onChange={(e) => setAmount(Number(e.target.value))}
                required
                step="0.01"
                type="number"
                value={amount}
              />
            </div>

            <div>
              <label className="form-label" htmlFor="coll-mode">Payment Mode</label>
              <select
                className="form-input"
                id="coll-mode"
                onChange={(e) => setPaymentMode(e.target.value)}
                value={paymentMode}
              >
                <option value="CASH">Cash</option>
                <option value="UPI">UPI / QR Code</option>
                <option value="CHEQUE">Cheque</option>
                <option value="NEFT">Bank Transfer</option>
              </select>
            </div>

            <div>
              <label className="form-label" htmlFor="coll-ref">Reference / UTR Number</label>
              <input
                className="form-input"
                id="coll-ref"
                onChange={(e) => setReferenceNumber(e.target.value)}
                placeholder="e.g. UTR12345678"
                type="text"
                value={referenceNumber}
              />
            </div>
          </div>

          <div className="modal-footer" style={{ display: 'flex', justifyContent: 'flex-end', gap: 8, marginTop: 16 }}>
            <Button onClick={onClose} type="button" variant="secondary">Cancel</Button>
            <Button disabled={isPending || amount <= 0} type="submit" variant="primary">
              {isPending ? 'Saving...' : 'Save Collection'}
            </Button>
          </div>
        </form>
      </div>
    </div>
  )
}

function SkipVisitModal({
  visit,
  onClose,
  onSubmit,
  isPending,
}: {
  visit: FieldVisit
  onClose: () => void
  onSubmit: (reason: string) => void
  isPending: boolean
}) {
  const [reason, setReason] = useState('OUTLET_CLOSED')

  return (
    <div className="modal-backdrop">
      <div className="modal-card" style={{ maxWidth: 440 }}>
        <div className="modal-header">
          <h2 className="modal-title">Skip Visit â€” {visit.contactName || 'Customer'}</h2>
          <button aria-label="Close" className="button button--ghost" onClick={onClose} type="button">
            <X aria-hidden="true" size={18} />
          </button>
        </div>

        <form
          onSubmit={(e) => {
            e.preventDefault()
            onSubmit(reason)
          }}
        >
          <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            <div>
              <label className="form-label" htmlFor="skip-reason">Skip Reason *</label>
              <select
                className="form-input"
                id="skip-reason"
                onChange={(e) => setReason(e.target.value)}
                value={reason}
              >
                <option value="OUTLET_CLOSED">Outlet Closed</option>
                <option value="OWNER_NOT_AVAILABLE">Owner / Decision Maker Not Available</option>
                <option value="STOCK_SUFFICIENT">Sufficient Stock On Hand</option>
                <option value="PAYMENT_DISPUTE">Payment Dispute / Credit Blocked</option>
                <option value="OTHER">Other Reason</option>
              </select>
            </div>
          </div>

          <div className="modal-footer" style={{ display: 'flex', justifyContent: 'flex-end', gap: 8, marginTop: 16 }}>
            <Button onClick={onClose} type="button" variant="secondary">Cancel</Button>
            <Button disabled={isPending} type="submit" variant="destructive">
              {isPending ? 'Skipping...' : 'Confirm Skip'}
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
        <MapPin aria-hidden="true" size={24} />
        <p>Route execution run could not be found or loaded.</p>
        <Button onClick={onBack} type="button" variant="secondary">Return to Executions</Button>
      </div>
    </section>
  )
}
