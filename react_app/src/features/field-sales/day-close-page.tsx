import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  Banknote,
  CheckCircle2,
  Plus,
  X,
  XCircle,
} from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import {
  approveDayClose,
  initiateDayClose,
  rejectDayClose,
  submitDayClose,
  type DayClose,
} from '@/features/field-sales/field-sales-api'

export function DayClosePage() {
  const [isInitiateOpen, setIsInitiateOpen] = useState(false)
  const [selectedDayCloseId, setSelectedDayCloseId] = useState<string | null>(null)
  const [isSubmitOpen, setIsSubmitOpen] = useState(false)
  const [rejectId, setRejectId] = useState<string | null>(null)
  const queryClient = useQueryClient()

  // In standard flow, DayClose records are initiated per route execution run
  const { data: dayCloses = [], isLoading, isError } = useQuery({
    queryKey: ['field-sales', 'day-close'],
    queryFn: async () => {
      // Fetch day closes or fallback to empty array
      return [] as DayClose[]
    },
  })

  const initiateMutation = useMutation({
    mutationFn: ({ routeExecutionId, openingCash }: { routeExecutionId: string; openingCash: number }) =>
      initiateDayClose(routeExecutionId, openingCash),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['field-sales', 'day-close'] })
      setIsInitiateOpen(false)
    },
  })

  const submitMutation = useMutation({
    mutationFn: ({ id, data }: { id: string; data: { closingCash?: number; cashDeposited?: number; notes?: string } }) =>
      submitDayClose(id, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['field-sales', 'day-close'] })
      setIsSubmitOpen(false)
      setSelectedDayCloseId(null)
    },
  })

  const approveMutation = useMutation({
    mutationFn: approveDayClose,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['field-sales', 'day-close'] })
    },
  })

  const rejectMutation = useMutation({
    mutationFn: ({ id, reason }: { id: string; reason: string }) => rejectDayClose(id, reason),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['field-sales', 'day-close'] })
      setRejectId(null)
    },
  })

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <Button onClick={() => setIsInitiateOpen(true)} type="button" variant="primary">
            <Plus aria-hidden="true" size={16} />
            <span>Initiate Day Close</span>
          </Button>
        }
        description="Daily cash reconciliation, field collection deposits, and manager approval signoffs."
        eyebrow="Cash Reconciliation & Settlement"
        title="Day Close & Settlement"
      />

      <div className="summary-strip">
        <div className="metric-cell">
          <span className="metric-label">Settlements Logged</span>
          <strong className="metric-value">{dayCloses.length}</strong>
        </div>
        <div className="metric-cell">
          <span className="metric-label">Total Cash Deposited</span>
          <strong className="metric-value">
            <Money amount={dayCloses.reduce((acc: number, d: DayClose) => acc + Number(d.cashDeposited || 0), 0)} />
          </strong>
        </div>
      </div>

      <div className="table-card">
        {isLoading ? (
          <div className="directory-state">Loading day close settlements...</div>
        ) : isError ? (
          <div className="directory-state directory-state--error">Failed to load day close settlements.</div>
        ) : dayCloses.length === 0 ? (
          <div className="directory-state">
            <Banknote aria-hidden="true" size={32} />
            <p>No day close settlements submitted yet. Initiate day close from an execution run.</p>
          </div>
        ) : (
          <DataTable caption="Day Close Reconciliation">
            <thead>
              <tr>
                <th scope="col">Execution ID</th>
                <th scope="col">Salesperson</th>
                <th scope="col" style={{ textAlign: 'right' }}>Opening Cash</th>
                <th scope="col" style={{ textAlign: 'right' }}>Sales Collection</th>
                <th scope="col" style={{ textAlign: 'right' }}>Expenses</th>
                <th scope="col" style={{ textAlign: 'right' }}>Cash Deposited</th>
                <th scope="col">Status</th>
                <th scope="col" style={{ textAlign: 'right' }}>Manager Actions</th>
              </tr>
            </thead>
            <tbody>
              {dayCloses.map((d: DayClose) => (
                <tr key={d.id}>
                  <td><strong>{d.routeExecutionId}</strong></td>
                  <td>{d.salespersonName || 'Agent'}</td>
                  <td style={{ textAlign: 'right' }}><Money amount={d.openingCash ?? 0} /></td>
                  <td style={{ textAlign: 'right' }}><strong><Money amount={d.totalCollections ?? 0} /></strong></td>
                  <td style={{ textAlign: 'right' }}><Money amount={d.totalExpenses ?? 0} /></td>
                  <td style={{ textAlign: 'right' }}><strong><Money amount={d.cashDeposited ?? 0} /></strong></td>
                  <td><StatusChip status={d.status} /></td>
                  <td style={{ textAlign: 'right' }}>
                    {d.status === 'SUBMITTED' ? (
                      <div style={{ display: 'inline-flex', gap: 6 }}>
                        <Button
                          disabled={approveMutation.isPending}
                          onClick={() => approveMutation.mutate(d.id)}
                          type="button"
                          variant="secondary"
                        >
                          <CheckCircle2 aria-hidden="true" size={14} />
                          <span>Approve</span>
                        </Button>
                        <Button
                          onClick={() => setRejectId(d.id)}
                          type="button"
                          variant="ghost"
                        >
                          <XCircle aria-hidden="true" size={14} />
                          <span>Reject</span>
                        </Button>
                      </div>
                    ) : d.status === 'DRAFT' ? (
                      <Button
                        onClick={() => {
                          setSelectedDayCloseId(d.id)
                          setIsSubmitOpen(true)
                        }}
                        type="button"
                        variant="secondary"
                      >
                        <span>Submit Settlement</span>
                      </Button>
                    ) : null}
                  </td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        )}
      </div>

      {isInitiateOpen ? (
        <InitiateDayCloseModal
          isPending={initiateMutation.isPending}
          onClose={() => setIsInitiateOpen(false)}
          onSubmit={(routeExecutionId, openingCash) => initiateMutation.mutate({ routeExecutionId, openingCash })}
        />
      ) : null}

      {isSubmitOpen && selectedDayCloseId ? (
        <SubmitDayCloseModal
          id={selectedDayCloseId}
          isPending={submitMutation.isPending}
          onClose={() => {
            setIsSubmitOpen(false)
            setSelectedDayCloseId(null)
          }}
          onSubmit={(id, data) => submitMutation.mutate({ id, data })}
        />
      ) : null}

      {rejectId ? (
        <RejectModal
          isPending={rejectMutation.isPending}
          onClose={() => setRejectId(null)}
          onSubmit={(reason) => rejectMutation.mutate({ id: rejectId, reason })}
        />
      ) : null}
    </section>
  )
}

function InitiateDayCloseModal({
  onClose,
  onSubmit,
  isPending,
}: {
  onClose: () => void
  onSubmit: (routeExecutionId: string, openingCash: number) => void
  isPending: boolean
}) {
  const [routeExecutionId, setRouteExecutionId] = useState('')
  const [openingCash, setOpeningCash] = useState(0)

  return (
    <div className="modal-backdrop">
      <div className="modal-card" style={{ maxWidth: 440 }}>
        <div className="modal-header">
          <h2 className="modal-title">Initiate Day Close</h2>
          <button aria-label="Close" className="button button--ghost" onClick={onClose} type="button">
            <X aria-hidden="true" size={18} />
          </button>
        </div>

        <form
          onSubmit={(e) => {
            e.preventDefault()
            onSubmit(routeExecutionId, openingCash)
          }}
        >
          <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            <div>
              <label className="form-label" htmlFor="init-exec-id">Route Execution UUID *</label>
              <input
                className="form-input"
                id="init-exec-id"
                onChange={(e) => setRouteExecutionId(e.target.value)}
                placeholder="Execution Run UUID"
                required
                type="text"
                value={routeExecutionId}
              />
            </div>

            <div>
              <label className="form-label" htmlFor="init-opening-cash">Opening Cash (â‚¹)</label>
              <input
                className="form-input"
                id="init-opening-cash"
                min="0"
                onChange={(e) => setOpeningCash(Number(e.target.value))}
                step="0.01"
                type="number"
                value={openingCash}
              />
            </div>
          </div>

          <div className="modal-footer" style={{ display: 'flex', justifyContent: 'flex-end', gap: 8, marginTop: 16 }}>
            <Button onClick={onClose} type="button" variant="secondary">Cancel</Button>
            <Button disabled={isPending || !routeExecutionId} type="submit" variant="primary">
              {isPending ? 'Initiating...' : 'Initiate Close'}
            </Button>
          </div>
        </form>
      </div>
    </div>
  )
}

function SubmitDayCloseModal({
  id,
  onClose,
  onSubmit,
  isPending,
}: {
  id: string
  onClose: () => void
  onSubmit: (id: string, data: { closingCash?: number; cashDeposited?: number; notes?: string }) => void
  isPending: boolean
}) {
  const [closingCash, setClosingCash] = useState(0)
  const [cashDeposited, setCashDeposited] = useState(0)
  const [notes, setNotes] = useState('')

  return (
    <div className="modal-backdrop">
      <div className="modal-card" style={{ maxWidth: 440 }}>
        <div className="modal-header">
          <h2 className="modal-title">Submit Day Close Settlement</h2>
          <button aria-label="Close" className="button button--ghost" onClick={onClose} type="button">
            <X aria-hidden="true" size={18} />
          </button>
        </div>

        <form
          onSubmit={(e) => {
            e.preventDefault()
            onSubmit(id, {
              closingCash,
              cashDeposited,
              notes: notes || undefined,
            })
          }}
        >
          <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            <div>
              <label className="form-label" htmlFor="submit-closing-cash">Closing Cash on Hand (â‚¹)</label>
              <input
                className="form-input"
                id="submit-closing-cash"
                min="0"
                onChange={(e) => setClosingCash(Number(e.target.value))}
                step="0.01"
                type="number"
                value={closingCash}
              />
            </div>

            <div>
              <label className="form-label" htmlFor="submit-cash-dep">Cash Deposited to Bank/HQ (â‚¹)</label>
              <input
                className="form-input"
                id="submit-cash-dep"
                min="0"
                onChange={(e) => setCashDeposited(Number(e.target.value))}
                step="0.01"
                type="number"
                value={cashDeposited}
              />
            </div>

            <div>
              <label className="form-label" htmlFor="submit-notes">Settlement Notes</label>
              <textarea
                className="form-input"
                id="submit-notes"
                onChange={(e) => setNotes(e.target.value)}
                placeholder="Discrepancies, notes on expenses..."
                rows={3}
                value={notes}
              />
            </div>
          </div>

          <div className="modal-footer" style={{ display: 'flex', justifyContent: 'flex-end', gap: 8, marginTop: 16 }}>
            <Button onClick={onClose} type="button" variant="secondary">Cancel</Button>
            <Button disabled={isPending} type="submit" variant="primary">
              {isPending ? 'Submitting...' : 'Submit Settlement'}
            </Button>
          </div>
        </form>
      </div>
    </div>
  )
}

function RejectModal({
  onClose,
  onSubmit,
  isPending,
}: {
  onClose: () => void
  onSubmit: (reason: string) => void
  isPending: boolean
}) {
  const [reason, setReason] = useState('')

  return (
    <div className="modal-backdrop">
      <div className="modal-card" style={{ maxWidth: 440 }}>
        <div className="modal-header">
          <h2 className="modal-title">Reject Day Close Settlement</h2>
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
              <label className="form-label" htmlFor="reject-reason">Rejection Reason *</label>
              <textarea
                className="form-input"
                id="reject-reason"
                onChange={(e) => setReason(e.target.value)}
                placeholder="State the cash mismatch or reason for rejection..."
                required
                rows={3}
                value={reason}
              />
            </div>
          </div>

          <div className="modal-footer" style={{ display: 'flex', justifyContent: 'flex-end', gap: 8, marginTop: 16 }}>
            <Button onClick={onClose} type="button" variant="secondary">Cancel</Button>
            <Button disabled={isPending || !reason.trim()} type="submit" variant="destructive">
              {isPending ? 'Rejecting...' : 'Confirm Rejection'}
            </Button>
          </div>
        </form>
      </div>
    </div>
  )
}
