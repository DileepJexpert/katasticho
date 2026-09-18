import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Link, useSearchParams } from 'react-router-dom'
import { Button, DataTable, Fact, FactList, FilterTabs, FormCard, FormGrid, Modal, Money, PageHeader, StatusChip, TablePagination } from '@/design-system'
import { TextField } from '@/design-system/text-field'
import { useSessionStore } from '@/shared/session/session-store'
import { WorkspaceBoundary } from '@/shared/workflows/workspace-boundary'
import { QueryFeedback } from '@/shared/workflows/query-feedback'
import { ConfirmedAction } from '@/shared/workflows/confirmed-action'
import { approveDayClose, getDayClose, getDayCloseByExecution, getExecution, initiateDayClose, listDayCloses, rejectDayClose, submitDayClose, type DayClose } from './field-sales-api'

export function DayClosePage() {
  const [params] = useSearchParams()
  const id = params.get('dayCloseId') ?? ''
  const executionId = params.get('executionId') ?? ''
  return <WorkspaceBoundary roles={['OWNER', 'ADMIN', 'OPERATOR']}><DayCloseWorkspace key={`${id}:${executionId}`} id={id} executionId={executionId} /></WorkspaceBoundary>
}

function DayCloseWorkspace({ id: initialId, executionId }: { id: string; executionId: string }) {
  const user = useSessionStore((s) => s.user!)
  const [, setParams] = useSearchParams()
  const client = useQueryClient()
  const [page, setPage] = useState(0)
  const [statusFilter, setStatusFilter] = useState('')
  const [opening, setOpening] = useState('')
  const [action, setAction] = useState<'submit' | 'approve' | 'reject' | null>(null)

  const byExec = useQuery({
    queryKey: ['field-sales', user.orgId, 'day-close-by-exec', executionId],
    queryFn: () => getDayCloseByExecution(executionId),
    enabled: !!executionId && !initialId,
    retry: false,
  })

  const effectiveId = initialId || byExec.data?.id || ''

  const run = useQuery({
    queryKey: ['field-sales', user.orgId, 'execution', executionId],
    queryFn: () => getExecution(executionId),
    enabled: !!executionId && !effectiveId,
  })

  const close = useQuery({
    queryKey: ['field-sales', user.orgId, 'day-close', effectiveId],
    queryFn: () => getDayClose(effectiveId),
    enabled: !!effectiveId,
  })

  const listQuery = useQuery({
    queryKey: ['field-sales', user.orgId, 'day-closes', statusFilter, page],
    queryFn: () => listDayCloses(statusFilter, page),
    enabled: !effectiveId && !executionId,
  })

  const start = useMutation({
    mutationFn: () => initiateDayClose(executionId, Number(opening)),
    retry: false,
    onSuccess: (result) => {
      if (useSessionStore.getState().user?.orgId === user.orgId && useSessionStore.getState().user?.id === user.id) {
        setParams({ dayCloseId: result.id }, { replace: true })
      }
    },
  })

  const admin = ['OWNER', 'ADMIN'].includes(user.role)
  const record = close.data || byExec.data
  const canSubmit = record && (admin || record.salespersonId === user.id)
  const refresh = () => {
    setAction(null)
    if (effectiveId) {
      void client.invalidateQueries({ queryKey: ['field-sales', user.orgId, 'day-close', effectiveId] })
    }
    void client.invalidateQueries({ queryKey: ['field-sales', user.orgId, 'day-closes'] })
  }

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Field sales / Cash reconciliation"
        title="Day close and settlement"
        description="Reconcile actual cash after a completed route. Approval is not a bank deposit or journal posting."
        actions={effectiveId ? <Button variant="secondary" onClick={() => setParams({}, { replace: true })}>View all day closes</Button> : undefined}
      />
      <div style={{ display: 'flex', gap: '1rem', marginBottom: '1rem' }}>
        <Link to="/field-sales/executions">Choose a completed route execution</Link>
      </div>

      {!effectiveId && executionId && (
        <QueryFeedback query={run}>
          {run.data && (
            <FormCard title={`Route close for ${run.data.executionDate}`}>
              <StatusChip status={run.data.status} />
              {run.data.status === 'COMPLETED' && (admin || run.data.salespersonId === user.id) ? (
                <>
                  <TextField
                    label="Actual opening cash"
                    type="number"
                    min="0"
                    step="any"
                    value={opening}
                    onChange={(e) => setOpening(e.target.value)}
                  />
                  <p>Initiating creates a new close record. The server will calculate variance based on collections and expenses.</p>
                  {start.error && <p role="alert" className="form-error">{start.error.message}</p>}
                  <Button
                    disabled={!opening.trim() || !Number.isFinite(Number(opening)) || Number(opening) < 0 || start.isPending || start.isError}
                    loading={start.isPending}
                    onClick={() => start.mutate()}
                  >
                    Create day close
                  </Button>
                </>
              ) : (
                <p>Only a completed execution can be closed by its salesperson or an administrator.</p>
              )}
            </FormCard>
          )}
        </QueryFeedback>
      )}

      {effectiveId && (
        <QueryFeedback query={close}>
          {record && (
            <FormCard title={`Day close: ${record.closeDate ?? ''}`} headerAction={<StatusChip status={record.status} />}>
              <FactList>
                <Fact label="Opening cash" value={<Money amount={record.openingCash ?? 0} />} />
                <Fact label="Cash collections" value={<Money amount={record.cashCollections ?? 0} />} />
                <Fact label="All-channel collections" value={<Money amount={record.totalCollections ?? 0} />} />
                <Fact label="Cash expenses" value={<Money amount={record.cashExpenses ?? 0} />} />
                <Fact label="Closing cash" value={<Money amount={record.closingCash ?? 0} />} />
                <Fact label="Deposited cash" value={<Money amount={record.cashDeposited ?? 0} />} />
                <Fact label="Server-calculated variance" value={<Money amount={record.cashVariance ?? 0} />} />
                <Fact label="Notes" value={record.notes} />
                <Fact label="Rejection reason" value={record.rejectionReason} />
              </FactList>
              <div className="document-actions">
                {record.status === 'PENDING' && canSubmit && (
                  <Button onClick={() => setAction('submit')}>Reconcile and submit</Button>
                )}
                {record.status === 'SUBMITTED' && admin && (
                  <>
                    <Button onClick={() => setAction('approve')}>Approve day close</Button>
                    <Button variant="destructive" onClick={() => setAction('reject')}>Reject day close</Button>
                  </>
                )}
              </div>
              {record.status === 'REJECTED' && canSubmit && (
                <div style={{ marginTop: '0.75rem' }}>
                  <Button onClick={() => setAction('submit')}>Re-submit corrected reconciliation</Button>
                </div>
              )}
            </FormCard>
          )}
        </QueryFeedback>
      )}

      {!effectiveId && !executionId && (
        <QueryFeedback query={listQuery}>
          <FilterTabs
            ariaLabel="Day close status"
            activeValue={statusFilter}
            onChange={(v) => { setStatusFilter(v); setPage(0) }}
            items={[
              { value: '', label: 'All' },
              { value: 'PENDING', label: 'Pending' },
              { value: 'SUBMITTED', label: 'Submitted' },
              { value: 'APPROVED', label: 'Approved' },
              { value: 'REJECTED', label: 'Rejected' },
            ]}
          />
          <DataTable caption="Day Closes">
            <thead>
              <tr>
                <th>Close Date</th>
                <th>Status</th>
                <th className="numeric-cell">Opening</th>
                <th className="numeric-cell">Collections</th>
                <th className="numeric-cell">Variance</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              {listQuery.data?.content.map((dc) => (
                <tr key={dc.id}>
                  <td className="table-code">{dc.closeDate ?? '--'}</td>
                  <td><StatusChip status={dc.status} /></td>
                  <td className="numeric-cell"><Money amount={dc.openingCash ?? 0} /></td>
                  <td className="numeric-cell"><Money amount={dc.totalCollections ?? 0} /></td>
                  <td className="numeric-cell"><Money amount={dc.cashVariance ?? 0} /></td>
                  <td>
                    <Button variant="ghost" onClick={() => setParams({ dayCloseId: dc.id })}>
                      View details
                    </Button>
                  </td>
                </tr>
              ))}
            </tbody>
          </DataTable>
          {(!listQuery.data?.content || listQuery.data.content.length === 0) && (
            <div className="directory-state">No day closes found.</div>
          )}
          <TablePagination
            page={page}
            totalPages={listQuery.data?.totalPages ?? 0}
            totalElements={listQuery.data?.totalElements ?? 0}
            onPageChange={setPage}
            itemLabel="day close"
          />
        </QueryFeedback>
      )}

      {action === 'approve' && (
        <ConfirmedAction
          title="Approve day close"
          description="Approve the submitted cash reconciliation after checking its variance? This does not perform a bank deposit."
          run={() => approveDayClose(effectiveId)}
          onClose={() => setAction(null)}
          onDone={refresh}
        />
      )}
      {record && (action === 'submit' || action === 'reject') && (
        <DayCloseForm
          record={record}
          reject={action === 'reject'}
          onClose={() => setAction(null)}
          onDone={refresh}
        />
      )}
    </section>
  )
}
function DayCloseForm({ record, reject, onClose, onDone }: { record: DayClose; reject: boolean; onClose: () => void; onDone: () => void }) {
  const [closing, setClosing] = useState('')
  const [deposit, setDeposit] = useState('')
  const [notes, setNotes] = useState('')
  const valid = reject ? !!notes.trim() : [closing, deposit].every((value) => value.trim() && Number.isFinite(Number(value)) && Number(value) >= 0)
  const save = useMutation({ mutationFn: () => reject ? rejectDayClose(record.id, notes.trim()) : submitDayClose(record.id, { closingCash: Number(closing), cashDeposited: Number(deposit), notes }), onSuccess: onDone })
  return <Modal isOpen title={reject ? 'Reject reconciliation' : 'Submit actual cash reconciliation'} error={save.error?.message} onClose={() => { if (!save.isPending) onClose() }} footer={<><Button variant="secondary" disabled={save.isPending} onClick={onClose}>Cancel</Button><Button loading={save.isPending} disabled={!valid || save.isPending} onClick={() => save.mutate()}>Confirm {reject ? 'rejection' : 'submission'}</Button></>}><FormGrid>{!reject && <><TextField label="Actual closing cash" type="number" min="0" step="any" value={closing} onChange={(e) => setClosing(e.target.value)} /><TextField label="Actual cash deposited" type="number" min="0" step="any" value={deposit} onChange={(e) => setDeposit(e.target.value)} /></>}<TextField label={reject ? 'Rejection reason' : 'Reconciliation notes'} required={reject} value={notes} onChange={(e) => setNotes(e.target.value)} /></FormGrid><p>The server calculates cash variance. Enter counted cash and actual deposits, not expected amounts.</p></Modal>
}
